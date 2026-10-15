import copy
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_billing_cleanup_dev_readback as readback
import verify_billing_dev_readback as protected_readback
from test_billing_cleanup_dev_plan import fixture as plan_fixture

OTHER = 'trustcheckradar-dev-v1-play-handoff'


def fixture():
    plan, _, captured = plan_fixture()
    fresh = copy.deepcopy(captured['metadata'])
    fresh['function']['Environment']['Variables'] = copy.deepcopy(plan['resource_changes'][0]['change']['after']['environment'][0]['variables'])
    fresh['function']['Version'] = fresh['alias']['FunctionVersion'] = '4'
    other = {'CodeSha256': 'synthetic', 'Version': '1', 'Environment': {'Variables': {'AUTHORITY_ENABLED': 'false'}}}
    calls = []
    def reader(service, operation, *args):
        calls.append((service, operation, args))
        if operation == 'get-caller-identity': return copy.deepcopy(fresh['identity'])
        if operation == 'list-functions': return {'Functions': [{'FunctionName': name} for name in (readback.prerequisite.FUNCTION, OTHER)]}
        if operation == 'list-aliases':
            assert args == ('--function-name', OTHER)
            return {'Aliases': [{'Name': 'live', 'FunctionVersion': '1'}]}
        if operation in ('get-function-configuration', 'get-function-concurrency') and args[1] == OTHER:
            return copy.deepcopy(other if operation == 'get-function-configuration' else {'ReservedConcurrentExecutions': 2})
        mapping = {'get-function-configuration': 'function', 'get-function-concurrency': 'concurrency',
                   'get-alias': 'alias', 'get-schedule': 'schedule', 'list-event-source-mappings': 'mappings'}
        if operation in mapping: return copy.deepcopy(fresh[mapping[operation]])
        raise AssertionError('Unexpected API; metadata reads only')
    protected = protected_readback.snapshot('cleanup', read=reader)
    calls.clear()
    return plan, captured, fresh, protected, other, calls, reader


class CleanupReadbackTests(unittest.TestCase):
    def test_exact_cleanup_after_and_other_runtime_metadata_pass_without_behavior_claim(self):
        plan, captured, fresh, protected, _, calls, reader = fixture()
        original = copy.deepcopy((plan, captured, fresh, protected))
        result = readback.verify(plan, captured, protected, read=reader)
        self.assertEqual(result, {'billingCleanupConfigurationVerified': True, 'billingSubjectCount': 1,
                                 'cleanupSubjectCount': 2, 'behavioralQualification': False, 'protectedRuntimeCount': 1})
        self.assertEqual((plan, captured, fresh, protected), original)
        self.assertTrue(calls)
        for value in captured['selected']:
            self.assertNotIn(value, json.dumps(result))
        self.assertNotIn(OTHER, json.dumps(result))

    def test_cleanup_snapshot_excludes_only_deletion(self):
        _, _, _, protected, _, calls, _ = fixture()
        self.assertEqual(set(protected), {OTHER})
        self.assertFalse(calls)

    def test_live_configuration_gate_hash_version_and_concurrency_mismatches_rejected(self):
        mutations = [lambda f: f['function'].update(CodeSha256='different'),
                     lambda f: f['function'].update(Runtime='python3.13'),
                     lambda f: f['function'].update(State='Pending'),
                     lambda f: f['function'].update(LastUpdateStatus='InProgress'),
                     lambda f: f['function'].update(Version='$LATEST'),
                     lambda f: f['function'].update(Version='3'),
                     lambda f: f['function']['Environment']['Variables'].update(UNRELATED='changed'),
                     lambda f: f['function']['Environment']['Variables'].update(PLAY_LIFECYCLE_ENABLED='true'),
                     lambda f: f['alias'].update(FunctionVersion='5'),
                     lambda f: f['alias'].update(RoutingConfig={'AdditionalVersionWeights': {'5': 0.1}}),
                     lambda f: f['concurrency'].update(ReservedConcurrentExecutions=0),
                     lambda f: f['identity'].update(Account='000000000000')]
        for index, mutate in enumerate(mutations):
            plan, captured, fresh, protected, _, _, reader = fixture(); mutate(fresh)
            with self.subTest(index=index), self.assertRaises(ValueError):
                readback.verify(plan, captured, protected, read=reader)

    def test_exact_schedule_and_mapping_preserved_except_processing_result(self):
        plan, captured, fresh, protected, _, _, reader = fixture()
        fresh['mappings']['EventSourceMappings'][0]['LastProcessingResult'] = 'new result'
        self.assertTrue(readback.verify(plan, captured, protected, read=reader)['billingCleanupConfigurationVerified'])
        for component, key, value in [('schedule', 'ScheduleExpressionTimezone', 'UTC'), ('schedule', 'Description', 'changed'),
                                      ('mapping', 'LastModified', 'changed'), ('mapping', 'BatchSize', 10),
                                      ('mapping', 'EventSourceArn', 'different')]:
            plan, captured, fresh, protected, _, _, reader = fixture()
            row = fresh['schedule'] if component == 'schedule' else fresh['mappings']['EventSourceMappings'][0]
            row[key] = value
            with self.subTest(component=component, key=key), self.assertRaises(ValueError):
                readback.verify(plan, captured, protected, read=reader)

    def test_protected_runtime_and_snapshot_inventory_changes_rejected(self):
        for mutation in ('runtime', 'missing', 'added', 'empty', 'deletion-included', 'bad-hash'):
            plan, captured, _, protected, other, _, reader = fixture()
            if mutation == 'runtime': other['Version'] = '2'
            if mutation == 'missing': protected.pop(OTHER)
            if mutation == 'added': protected['trustcheckradar-dev-another'] = '0' * 64
            if mutation == 'empty': protected.clear()
            if mutation == 'deletion-included': protected[readback.prerequisite.FUNCTION] = '0' * 64
            if mutation == 'bad-hash': protected[OTHER] = 'bad'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                readback.verify(plan, captured, protected, read=reader)

    def test_plan_pins_publication_environment_and_unknown_flags_remain_required(self):
        for mutation in ('publish', 'package', 'subjects', 'environment', 'version-unknown', 'alias-unknown', 'alias-version'):
            plan, captured, _, protected, _, _, reader = fixture()
            function, alias = [row['change'] for row in plan['resource_changes'][:2]]
            if mutation == 'publish': function['after']['publish'] = False
            if mutation == 'package': function['after']['s3_object_version'] = 'other'
            if mutation == 'subjects': plan['variables']['deletion_activation']['value']['subjects'] = captured['selected']
            if mutation == 'environment': function['after']['environment'][0]['variables']['EXTRA'] = 'value'
            if mutation == 'version-unknown': function['after_unknown']['version'] = False
            if mutation == 'alias-unknown': alias['after_unknown']['function_version'] = False
            if mutation == 'alias-version': alias['after']['function_version'] = '4'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                readback.verify(plan, captured, protected, read=reader)

    def test_known_planned_version_requires_exact_live_version(self):
        plan, captured, _, protected, _, _, reader = fixture()
        function, alias = [row['change'] for row in plan['resource_changes'][:2]]
        function['after']['version'] = alias['after']['function_version'] = '4'
        self.assertTrue(readback.verify(plan, captured, protected, read=reader)['billingCleanupConfigurationVerified'])
        function['after']['version'] = alias['after']['function_version'] = '5'
        with self.assertRaises(ValueError): readback.verify(plan, captured, protected, read=reader)

    def test_cli_captures_private_snapshot_and_rejects_unpaired_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'snapshot.json'
            path.write_text('old'); path.chmod(0o644)
            output = StringIO()
            with patch.object(sys, 'argv', ['readback', '--snapshot', str(path)]), \
                    patch.object(readback, 'snapshot', return_value={OTHER: '0' * 64}), redirect_stdout(output):
                readback.main()
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(output.getvalue()), {'protectedRuntimeCount': 1})
            for option in ('--plan', '--baseline'):
                with patch.object(sys, 'argv', ['readback', '--snapshot', str(path), option, 'private']), \
                        self.assertRaises(SystemExit) as rejected:
                    readback.main()
                self.assertEqual(str(rejected.exception), readback.ERROR)

    def test_cli_never_prints_private_failure(self):
        output = StringIO()
        with patch.object(sys, 'argv', ['readback', '--plan', 'private-plan', '--baseline', 'private-baseline', '--snapshot', 'private-snapshot']), \
                patch.object(readback.prepare, 'load', side_effect=ValueError('private-subject-or-metadata')), redirect_stdout(output), \
                self.assertRaises(SystemExit) as rejected:
            readback.main()
        self.assertEqual(str(rejected.exception), readback.ERROR)
        self.assertEqual(output.getvalue(), '')


if __name__ == '__main__':
    unittest.main()
