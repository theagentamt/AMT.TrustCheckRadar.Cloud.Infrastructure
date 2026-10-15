import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_url_qualification_plan import review, manifest, ROOTS, TABLE

REVISION = 'a' * 40
MANIFEST = {'version': 1, 'runId': '1800000000_fixture', 'startEpoch': 1800000000, 'endEpoch': 1800000600,
            'syntheticOnly': True, 'targets': [{'id': 'safe', 'url': 'https://example.com/'}]}
SUBJECT = '00000000-0000-4000-8000-000000000001'


def fixture(root='consumer', phase='install-closed'):
    function, alias, policy, suffix, package = ROOTS[root]
    pin = {'bucket': 'trustcheckradar-dev-107827791950-artifacts', 'key': f'releases/{REVISION}/{package}', 'object_version': 'fixture-v1', 'source_hash': 'A'*43 + '='}
    before = {'function_name': 'trustcheckradar-dev-' + suffix, 'runtime': 'python3.14', 'architectures': ['arm64'],
              's3_bucket': pin['bucket'], 's3_key': pin['key'], 's3_object_version': pin['object_version'], 'source_code_hash': pin['source_hash'],
              'role': 'arn:aws:iam::107827791950:role/preserved-role', 'timeout': 29, 'reserved_concurrent_executions': 2, 'version': '1', 'environment': [{'variables': {'STAGE': 'dev'}}]}
    if root == 'consumer':
        before['environment'][0]['variables'].update({'AUTHORITY_ENABLED': 'false', 'CONSUMER_ENABLED': 'false', 'DEV_SUBJECT_ALLOWLIST_JSON': '[]'})
    elif root == 'resolver':
        before['environment'] = []
    after = copy.deepcopy(before); after['version'] = '2'
    new = dict(before['environment'][0]['variables'] if before['environment'] else {}, STAGE='dev',
               URL_QUALIFICATION_ENABLED='false', URL_PROVIDER_ENABLED='false', URL_RETENTION_APPROVED='false',
               URL_QUALIFICATION_TABLE_NAME=TABLE.split('/')[1], URL_QUALIFICATION_MANIFEST_JSON=json.dumps(MANIFEST))
    if root == 'consumer':
        new.update(URL_NEW_ADMISSION_ENABLED='false', URL_RECONCILIATION_ENABLED='false', URL_SUBJECT_ALLOWLIST_JSON=json.dumps([SUBJECT]))
        if phase == 'rollback-recovery':
            new.update(URL_RECONCILIATION_ENABLED='true', AUTHORITY_ENABLED='true')
            before['environment'][0]['variables'].update(new)
            before['environment'][0]['variables'].update(URL_QUALIFICATION_ENABLED='true', URL_NEW_ADMISSION_ENABLED='true', URL_PROVIDER_ENABLED='true', URL_RETENTION_APPROVED='true')
    after['environment'] = [{'variables': new}]
    p = {'Version': '2012-10-17', 'Statement': [{'Sid': 'Control', 'Effect': 'Allow', 'Action': 'dynamodb:GetItem', 'Resource': TABLE, 'Condition': {'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': ['CONTROL']}}}]}
    def row(address, old, new):
        return {'address': address, 'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws',
                'change': {'actions': ['update'] if old != new else ['no-op'], 'before': old, 'after': new, 'after_unknown': {}}}
    a = {'name': 'live', 'function_name': before['function_name'], 'function_version': '1', 'routing_config': []}
    plan = {'complete': True, 'errored': False, 'terraform_version': '1.12.1', 'variables': {k: {'value': v} for k, v in {'environment': 'dev', 'project_name': 'trustcheckradar', 'aws_region': 'us-east-1', 'enabled': True}.items()}, 'resource_changes': [
        row(function, before, after), row(alias, a, dict(a, function_version='2')),
        row(policy, {'policy': json.dumps(p)}, {'policy': json.dumps(p)})], 'output_changes': {}, 'checks': []}
    if root == 'consumer':
        for name in ('entitlements', 'recovery', 'deletion'):
            preserved = {'function_name': 'preserved-' + name, 'environment': [{'variables': {'UNCHANGED': 'true'}}]}
            plan['resource_changes'].append(row(f'aws_lambda_function.runtime["{name}"]', preserved, copy.deepcopy(preserved)))
    return plan, {'before': pin, 'after': pin, 'policy': p}


class QualificationGuardTests(unittest.TestCase):
    def test_all_closed_components(self):
        for root in ROOTS:
            with self.subTest(root=root):
                plan, expected = fixture(root)
                result = review(plan, root, 'install-closed', expected, REVISION)
                self.assertFalse(result['deploymentAuthorized'])
                self.assertEqual(result['changedResources'], 2)
                self.assertNotIn(SUBJECT, json.dumps(result))
                self.assertNotIn('example.com', json.dumps(result))

    def test_recovery_only_rollback(self):
        plan, expected = fixture(phase='rollback-recovery')
        review(plan, 'consumer', 'rollback-recovery', expected, REVISION)

    def assert_rejected(self, mutate, root='consumer', phase='install-closed'):
        plan, expected = fixture(root, phase)
        mutate(plan, expected)
        with self.assertRaises((ValueError, KeyError, TypeError)):
            review(plan, root, phase, expected, REVISION)

    def test_closed_phase_never_activates(self):
        for flag in ('URL_QUALIFICATION_ENABLED', 'URL_NEW_ADMISSION_ENABLED', 'URL_PROVIDER_ENABLED', 'URL_RETENTION_APPROVED', 'URL_RECONCILIATION_ENABLED', 'CONSUMER_ENABLED'):
            with self.subTest(flag=flag):
                self.assert_rejected(lambda p,e: p['resource_changes'][0]['change']['after']['environment'][0]['variables'].update({flag:'true'}))

    def test_unrelated_env_selections_cannot_change(self):
        for flag in ('DEV_SUBJECT_ALLOWLIST_JSON', 'DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON', 'V1_ENTITLEMENTS_ENABLED', 'TRIAL_AUTHORITY_RETENTION_APPROVED', 'V1_AUTHORITY_DELETION_ENABLED', 'EXPORT_ENABLED', 'HISTORY_ENABLED'):
            with self.subTest(flag=flag):
                self.assert_rejected(lambda p,e: p['resource_changes'][0]['change']['after']['environment'][0]['variables'].update({flag:'unexpected'}))

    def test_unrelated_runtime_change_or_unknown_rejected(self):
        self.assert_rejected(lambda p,e: p['resource_changes'][3]['change']['after']['environment'][0]['variables'].update(UNCHANGED='false'))
        self.assert_rejected(lambda p,e: p['resource_changes'][3]['change'].update(after_unknown={'environment': True}))
        self.assert_rejected(lambda p,e: p['resource_changes'].pop())
        self.assert_rejected(lambda p,e: p['resource_changes'].append({'address':'aws_dynamodb_table.unrelated', 'mode':'managed', 'provider_name':'registry.terraform.io/hashicorp/aws', 'change':{'actions':['delete'], 'before':{}, 'after':None}}))

    def test_bad_plan_identity_and_drift(self):
        self.assert_rejected(lambda p,e: p.update(complete=False))
        self.assert_rejected(lambda p,e: p['variables']['environment'].update(value='prod'))
        self.assert_rejected(lambda p,e: p.update(resource_drift=[{'mode':'managed'}]))
        self.assert_rejected(lambda p,e: p.update(checks=[{'status':'unknown'}]))
        self.assert_rejected(lambda p,e: p['resource_changes'].append(copy.deepcopy(p['resource_changes'][0])))
        def wrong_role_account(plan, expected):
            for side in ('before', 'after'):
                plan['resource_changes'][0]['change'][side]['role'] = 'arn:aws:iam::999999999999:role/preserved-role'
        self.assert_rejected(wrong_role_account)

    def test_package_limits_alias_iam_and_unknown_env(self):
        self.assert_rejected(lambda p,e: p['resource_changes'][0]['change']['after'].update(timeout=60))
        self.assert_rejected(lambda p,e: p['resource_changes'][0]['change']['after'].update(source_code_hash='B'*43+'='))
        self.assert_rejected(lambda p,e: p['resource_changes'][0]['change'].update(after_unknown={'environment':True}))
        self.assert_rejected(lambda p,e: p['resource_changes'][1]['change']['after'].update(function_version='99'))
        self.assert_rejected(lambda p,e: p['resource_changes'][2]['change']['after'].update(policy='{}'))
        self.assert_rejected(lambda p,e: p['resource_changes'][0]['change']['after']['environment'][0]['variables'].update(padding='é'*2100))

    def test_subject_and_private_worker_isolation(self):
        self.assert_rejected(lambda p,e: p['resource_changes'][0]['change']['after']['environment'][0]['variables'].update(URL_SUBJECT_ALLOWLIST_JSON='["*"]'))
        self.assert_rejected(lambda p,e: p['resource_changes'][0]['change']['after']['environment'][0]['variables'].update(URL_SUBJECT_ALLOWLIST_JSON=json.dumps([SUBJECT, SUBJECT])))
        self.assert_rejected(lambda p,e: p['resource_changes'][0]['change']['after']['environment'][0]['variables'].update(URL_SUBJECT_ALLOWLIST_JSON=json.dumps([SUBJECT])), root='assessment')

    def test_policy_cannot_add_wildcards_arrays_or_wrong_partitions(self):
        def add_bad(statement):
            def mutate(plan, expected):
                expected['policy']['Statement'].append(statement)
                plan['resource_changes'][2]['change']['after']['policy'] = json.dumps(expected['policy'])
            return mutate
        for resource in ('*', [TABLE]):
            self.assert_rejected(add_bad({'Effect':'Allow', 'Action':'dynamodb:*', 'Resource':resource}), root='resolver')
        self.assert_rejected(add_bad({'Effect':'Allow', 'Action':'dynamodb:GetItem', 'Resource':TABLE, 'Condition': {'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': ['RUN#1800000000_fixture']}}}), root='resolver')
        self.assert_rejected(add_bad({'Effect':'Allow', 'Action':'dynamodb:UpdateItem', 'Resource':TABLE, 'Condition': {'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': ['CONTROL']}}}))
        self.assert_rejected(add_bad({'Effect':'Allow', 'Action':'dynamodb:UpdateItem', 'Resource':TABLE, 'Condition': {'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': ['RUN#1800000000_fixture']}}}))
        self.assert_rejected(add_bad({'Effect':'Allow', 'Action':'lambda:InvokeFunction', 'Resource':'*'}))

    def test_rollback_keeps_original_subject_and_proof_authority(self):
        self.assert_rejected(lambda p,e: p['resource_changes'][0]['change']['after']['environment'][0]['variables'].update(AUTHORITY_ENABLED='false'), phase='rollback-recovery')
        self.assert_rejected(lambda p,e: p['resource_changes'][0]['change']['after']['environment'][0]['variables'].update(URL_SUBJECT_ALLOWLIST_JSON=json.dumps(['00000000-0000-4000-8000-000000000002'])), phase='rollback-recovery')

    def test_manifest_rejects_bad_window_duplicate_fields_and_private_components(self):
        for patch in ({'endEpoch': 1800004000}, {'runId':'1800000001_reused'}, {'syntheticOnly':False}, {'version':True}, {'extra':'unreviewed'}):
            with self.subTest(patch=patch), self.assertRaises(ValueError):
                manifest(json.dumps(dict(MANIFEST, **patch)))
        with self.assertRaises(ValueError): manifest('{"version":1,"version":1}')
        for url in ('https://user:secret@example.com/', 'https://example.com/#private', 'https://example.com/é', 'https://example.com/\\unsafe', 'file:///tmp/test'):
            with self.subTest(url=url), self.assertRaises(ValueError):
                manifest(json.dumps(dict(MANIFEST, targets=[{'id':'a','url':url}])))
        with self.assertRaises(ValueError): manifest(json.dumps(dict(MANIFEST, targets=MANIFEST['targets'] * 2)))

    def test_cli_failure_does_not_leak_input(self):
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            private = Path(directory)/'private.json'; private.write_text(json.dumps({'SECRET':'never-display-private-input'}))
            run = subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1]/'verify_url_qualification_plan.py'), str(private), '--expected', str(private), '--root', 'consumer', '--phase', 'install-closed', '--revision',REVISION], text=True, capture_output=True)
            self.assertNotEqual(run.returncode, 0)
            self.assertNotIn('never-display-private-input', run.stdout + run.stderr)


if __name__ == '__main__': unittest.main()
