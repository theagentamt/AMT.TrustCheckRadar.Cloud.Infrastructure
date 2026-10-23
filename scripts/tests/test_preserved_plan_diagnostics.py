"""Offline rejection/privacy tests; no provider or AWS client is invoked."""
import ast
import contextlib
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_preserved_deployment as v
import test_preserved_deployment as fixtures


class DiagnosticTests(unittest.TestCase):
    def test_all_43_original_predicates_are_unchanged(self):
        tree = ast.parse(Path(v.__file__).read_text())
        calls = [n for n in ast.walk(tree) if isinstance(n, ast.Call) and
                 isinstance(n.func, ast.Name) and n.func.id == 'require']
        conditions = sorted(ast.dump(n.args[0], include_attributes=False) for n in calls)
        digest = hashlib.sha256(json.dumps(conditions, separators=(',', ':')).encode()).hexdigest()
        self.assertEqual(len(calls), 43)
        self.assertEqual(digest, 'ffeb46d15b31d1bf88f7da85e5a350c0a14e58b257d18eaa7142a2830dec0d36')
        self.assertEqual({n.args[1].value for n in calls}, set(v.PREDICATES))

    def test_catalog_and_output_are_finite(self):
        self.assertEqual(len({c for c, _ in v.PREDICATES.values()}), 43)
        for message, (code, category) in v.PREDICATES.items():
            with self.assertRaises(v.Rejection) as raised:
                v.require(False, message)
            record = v.rejection_record(raised.exception, 'PLAN_REVIEW')
            self.assertEqual(record['code'], code)
            self.assertEqual(record['resourceCategory'], category)
            self.assertEqual(set(record), {'status', 'phase', 'code', 'resourceCategory', 'fieldCategories'})
            self.assertNotIn(message, json.dumps(record))

    def test_condition_evaluated_once_and_passing_guard_emits_nothing(self):
        count = []
        def condition():
            count.append(1)
            return True
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            v.require(condition(), 'Exact main revision required.')
        self.assertEqual(count, [1])
        self.assertEqual(out.getvalue(), '')

    def test_unknown_resource_and_field_payloads_never_echo(self):
        private = 'DO_NOT_LOG_SUBJECT_ENVIRONMENT_SECRET_CONTENT'
        with self.assertRaises(v.Rejection) as raised:
            v.require(False, 'Unreviewed computed field.',
                      resource=v.resource_category('aws_lambda_function.' + private),
                      fields=['code_sha256', private])
        record = v.rejection_record(raised.exception, 'PLAN_REVIEW')
        self.assertEqual(record['resourceCategory'], 'OTHER_MANAGED')
        self.assertEqual(record['fieldCategories'], ['OTHER_FIELD', 'code_sha256'])
        self.assertNotIn(private, json.dumps(record))
        self.assertNotIn(private, str(raised.exception))

    def test_real_predicate_failure_names_only_reviewed_resource_category(self):
        fixture = fixtures.PreservedDeploymentTests()
        fixture.setUp()
        try:
            plan, _, _ = fixtures.maintenance()
            row = fixtures.p.inventory(plan)[v.FUNCTION]
            row['change']['after_unknown'] = {'code_sha256': True}
            with self.assertRaises(v.Rejection) as raised:
                v.validate_plan(plan, 'maintenance')
            record = v.rejection_record(raised.exception, 'PLAN_REVIEW')
            self.assertEqual(record['code'], 'UNREVIEWED_COMPUTED_FIELD')
            self.assertEqual(record['resourceCategory'], 'RECOVERY_FUNCTION')
            self.assertEqual(record['fieldCategories'], ['code_sha256'])
        finally:
            fixture.tearDown()

    def test_artifact_command_failures_never_render_arguments_or_stderr(self):
        private = 'DO_NOT_LOG_KEY_SUBJECT_BUCKET_OR_PAYLOAD'
        for operation, expected in ((['sts', 'get-caller-identity'], 'ARTIFACT_STS_READ_FAILED'),
                                    (['s3api', 'get-object'], 'ARTIFACT_S3_READ_FAILED'),
                                    (['unknown', private], 'ARTIFACT_READ_FAILED')):
            error = subprocess.CalledProcessError(1, ['aws', *operation, private], output=private, stderr=private)
            record = v.rejection_record(error, 'ARTIFACT_VERIFY')
            self.assertEqual(record['code'], expected)
            self.assertEqual(record['resourceCategory'], 'ARTIFACT')
            self.assertNotIn(private, json.dumps(record))

    def test_artifact_hash_version_account_and_unknown_have_distinct_codes(self):
        for text, code in (('Downloaded recovery artifact SHA256 does not match.', 'ARTIFACT_HASH'),
                           ('Downloaded recovery artifact version does not match.', 'ARTIFACT_VERSION'),
                           ('Unexpected AWS account; no artifact read performed.', 'ARTIFACT_ACCOUNT'),
                           ('DO_NOT_LOG_PROVIDER_BODY', 'ARTIFACT_UNCLASSIFIED')):
            record = v.rejection_record(ValueError(text), 'ARTIFACT_VERIFY')
            self.assertEqual(record['code'], code)
            self.assertNotIn(text, json.dumps(record))

    def test_unexpected_errors_phases_and_dependency_text_fail_closed(self):
        private = 'DO_NOT_LOG_PRIVATE_VALUE'
        for error in (RuntimeError(private), ValueError(private), KeyError(private)):
            for phase in ('PLAN_REVIEW', private):
                record = v.rejection_record(error, phase)
                self.assertIn(record['code'], v.CODES)
                self.assertIn(record['phase'], v.PHASES)
                self.assertNotIn(private, json.dumps(record))
        record = v.rejection_record(ValueError('ENTITLEMENTS_ENVIRONMENT_PIN_MISMATCH'), 'PLAN_REVIEW')
        self.assertEqual(record['code'], 'ENTITLEMENTS_ENVIRONMENT_PIN_MISMATCH')

    def test_missing_structure_keys_use_only_literal_field_categories(self):
        self.assertEqual(v.rejection_record(KeyError('source_hash'), 'PLAN_REVIEW')['fieldCategories'], ['source_hash'])
        self.assertEqual(v.rejection_record(KeyError('DO_NOT_LOG_PRIVATE_KEY'), 'PLAN_REVIEW')['fieldCategories'], ['OTHER_FIELD'])

    def test_cli_parse_errors_never_echo_private_arguments(self):
        private = 'DO_NOT_LOG_PRIVATE_ARGUMENT_OR_CHOICE'
        for args in (['--mode', private], ['--' + private], [private, '--mode', private]):
            r = subprocess.run([sys.executable, v.__file__, *args], text=True, capture_output=True)
            self.assertNotEqual(r.returncode, 0)
            self.assertEqual(r.stdout, '')
            self.assertNotIn(private, r.stderr)
            self.assertNotIn('Traceback', r.stderr)
            self.assertEqual(json.loads(r.stderr)['code'], 'INPUT_INVALID')

    def test_cli_invalid_private_input_outputs_only_fixed_json(self):
        private = 'DO_NOT_LOG_PRIVATE_INPUT_CONTENT'
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / 'private.json'
            p.write_text(private)
            r = subprocess.run([sys.executable, v.__file__, str(p), '--baseline', str(p),
                                '--capture', str(p), '--revision', 'b' * 40, '--mode', 'maintenance'],
                               text=True, capture_output=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, '')
        self.assertNotIn(private, r.stderr)
        self.assertNotIn('Traceback', r.stderr)
        self.assertEqual(json.loads(r.stderr)['code'], 'INPUT_INVALID')


if __name__ == '__main__':
    unittest.main()
