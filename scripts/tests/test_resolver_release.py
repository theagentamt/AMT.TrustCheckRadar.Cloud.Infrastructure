import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('resolver_release', Path(__file__).resolve().parents[1] / 'verify_resolver_release.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)
REVISION = 'a' * 40
ARTIFACT = {'bucket': 'trustcheckradar-dev-107827791950-artifacts', 'key': 'releases/test/url_redirect_resolver.zip', 'object_version': 'version-1', 'source_hash': base64.b64encode(hashlib.sha256(b'fixture').digest()).decode()}


def fixture():
    function = {'function_name': release.FUNCTION, 's3_bucket': ARTIFACT['bucket'], 's3_key': ARTIFACT['key'], 's3_object_version': ARTIFACT['object_version'], 'source_code_hash': ARTIFACT['source_hash'], 'role': 'unchanged-role', 'version': '1'}
    alias = {'name': 'live', 'function_name': release.FUNCTION, 'function_version': '1'}
    return {'complete': True, 'errored': False, 'terraform_version': '1.12.1', 'variables': {k: {'value': v} for k, v in {'environment': 'dev', 'aws_region': release.REGION, 'project_name': 'trustcheckradar', 'enabled': True, 'artifact': ARTIFACT}.items()}, 'resource_changes': [
        {'mode': 'managed', 'address': address, 'change': {'actions': ['no-op'], 'before': copy.deepcopy(value), 'after': copy.deepcopy(value), 'after_unknown': {}}}
        for address, value in [(release.FUNCTION_ADDRESS, function), (release.ALIAS_ADDRESS, alias)]
    ]}


class ResolverReleaseTests(unittest.TestCase):
    def test_noop_plan_and_digest_are_stable(self):
        plan = fixture()
        artifact, digest = release.review(plan, REVISION)
        plan['timestamp'] = 'later'
        self.assertEqual(release.review(plan, REVISION), (artifact, digest))
        self.assertEqual(len(digest), 64)
        self.assertNotEqual(release.review(plan, 'b' * 40)[1], digest)

    def test_code_roll_forward_and_rollback_are_supported(self):
        for version in ('previous-reviewed-version', 'new-reviewed-version'):
            plan = fixture()
            plan['variables']['artifact']['value'] = dict(ARTIFACT, object_version=version)
            change = plan['resource_changes'][0]['change']
            change['actions'] = ['update']
            change['after']['s3_object_version'] = version
            change['after']['version'] = None
            change['after_unknown'] = {'version': True}
            release.review(plan, REVISION)

    def test_network_iam_and_other_function_changes_are_rejected(self):
        for address in ('aws_route_table.private[0]', 'aws_iam_role_policy.execution[0]', 'aws_lambda_function.other[0]'):
            plan = fixture()
            plan['resource_changes'].append({'mode': 'managed', 'address': address, 'change': {'actions': ['update'], 'before': {}, 'after': {}}})
            with self.assertRaisesRegex(ValueError, 'Out-of-scope'):
                release.review(plan, REVISION)

    def test_deletion_creation_and_replacement_are_rejected(self):
        for actions in (['delete'], ['create'], ['delete', 'create'], ['create', 'delete']):
            plan = fixture()
            plan['resource_changes'][0]['change']['actions'] = actions
            with self.assertRaises(ValueError):
                release.review(plan, REVISION)

    def test_role_and_unknown_configuration_changes_are_rejected(self):
        for unknown in (False, True):
            plan = fixture()
            change = plan['resource_changes'][0]['change']
            change['actions'] = ['update']
            if unknown:
                change['after_unknown'] = {'vpc_config': True}
            else:
                change['after']['role'] = 'privileged-role'
            with self.assertRaisesRegex(ValueError, 'configuration'):
                release.review(plan, REVISION)

    def test_wrong_environment_disabled_and_missing_state_are_rejected(self):
        for key, value in [('environment', 'prod'), ('aws_region', 'us-west-2'), ('enabled', False)]:
            plan = fixture()
            plan['variables'][key]['value'] = value
            with self.assertRaises(ValueError):
                release.review(plan, REVISION)
        plan = fixture()
        plan['resource_changes'] = []
        with self.assertRaises(ValueError):
            release.review(plan, REVISION)

    def test_mismatched_or_unpinned_artifact_is_rejected(self):
        for key, value in [('bucket', 'untrusted'), ('object_version', 'null'), ('source_hash', 'bad'), ('key', 'releases/x/other.zip')]:
            plan = fixture()
            plan['variables']['artifact']['value'] = dict(ARTIFACT, **{key: value})
            with self.assertRaises(ValueError):
                release.review(plan, REVISION)
        plan = fixture()
        plan['resource_changes'][0]['change']['after']['s3_object_version'] = 'wrong'
        with self.assertRaisesRegex(ValueError, 'pinned artifact'):
            release.review(plan, REVISION)

    def test_incomplete_or_failed_plan_is_rejected(self):
        for key in ('complete', 'errored'):
            plan = fixture()
            plan[key] = key == 'errored'
            with self.assertRaises(ValueError):
                release.review(plan, REVISION)

    def test_artifact_bytes_and_version_are_checked_and_temp_file_removed(self):
        paths = []
        def read(*args):
            if args[0] == 'sts':
                return {'Account': release.ACCOUNT}
            path = Path(args[-1])
            paths.append(path)
            path.write_bytes(b'fixture')
            self.assertIn('--version-id', args)
            return {'VersionId': ARTIFACT['object_version']}
        release.verify_artifact(ARTIFACT, read)
        self.assertFalse(paths[0].exists())
        for corrupted in (dict(ARTIFACT, source_hash='wrong'), dict(ARTIFACT, object_version='wrong')):
            with self.assertRaises(ValueError):
                release.verify_artifact(corrupted, read)

    def test_wrong_account_stops_before_artifact_download(self):
        calls = []
        def read(*args):
            calls.append(args)
            return {'Account': '999999999999'}
        with self.assertRaises(ValueError):
            release.verify_artifact(ARTIFACT, read)
        self.assertEqual(calls, [('sts', 'get-caller-identity')])

    def test_apply_requires_matching_review_before_any_artifact_read(self):
        plan = fixture()
        digest = release.review(plan, REVISION)[1]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'plan.json'
            path.write_text(json.dumps(plan))
            argv = ['verify', str(path), '--revision', REVISION, '--apply']
            for supplied in ([], ['--expected-digest', 'wrong']):
                with patch('sys.argv', argv + supplied), patch.object(release, 'verify_artifact') as read:
                    with self.assertRaisesRegex(ValueError, 'exact digest'):
                        release.main()
                    read.assert_not_called()
            with patch('sys.argv', argv + ['--expected-digest', digest]), patch.object(release, 'verify_artifact') as read, patch('builtins.print'):
                release.main()
                read.assert_called_once_with(ARTIFACT)


if __name__ == '__main__':
    unittest.main()
