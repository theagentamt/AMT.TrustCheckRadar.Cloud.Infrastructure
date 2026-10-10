import copy
import json
import sys
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_billing_cleanup_prerequisite as cleanup

BILLING = '00000000-0000-4000-8000-000000000001'
PRESERVED = '00000000-0000-4000-8000-000000000099'
HASH = 'A' * 43 + '='
STREAM = f'arn:aws:dynamodb:us-east-1:{cleanup.ACCOUNT}:table/trustcheckradar-dev-deletion-ledger/stream/2026-09-06T23:20:47.091'


def fixture():
    env = {
        'STAGE': 'dev', 'PLAY_TOKEN_CLEANUP_ENABLED': 'true', 'PLAY_LIFECYCLE_ENABLED': 'false',
        'PLAY_CHECKPOINT_POLICY_APPROVED': 'false', 'PLAY_PREPARATION_ENABLED': 'false', 'AUTHORITY_ENABLED': 'false',
        'PLAY_TOKEN_TABLE_NAME': 'trustcheckradar-dev-play-tokens',
        'AUTHORITY_TABLE_NAME': 'trustcheckradar-dev-purchase-entitlements',
        'PURCHASE_OWNERSHIP_TABLE_NAME': 'trustcheckradar-dev-purchase-entitlements',
        'USERS_TABLE_NAME': 'trustcheckradar-dev-users', 'DEVICE_BINDINGS_TABLE_NAME': 'trustcheckradar-dev-device-bindings',
        'DELETION_LEDGER_TABLE_NAME': 'trustcheckradar-dev-deletion-ledger',
        'AUTHORITY_POLICY_VERSION': 'owner-2026-09-20-v1', 'DELETION_RECEIPT_RETENTION_SECONDS': '10368000',
        'DEV_SUBJECT_ALLOWLIST_JSON': json.dumps([PRESERVED, BILLING]), 'DELETION_LEDGER_STREAM_ARN': STREAM,
    }
    return {
        'identity': {'Account': cleanup.ACCOUNT},
        'function': {'FunctionName': cleanup.FUNCTION, 'Role': f'arn:aws:iam::{cleanup.ACCOUNT}:role/{cleanup.FUNCTION}-execution',
                     'State': 'Active', 'LastUpdateStatus': 'Successful',
                     'Runtime': 'python3.14', 'Handler': 'app.lambda_handler', 'Architectures': ['arm64'],
                     'Timeout': 60, 'MemorySize': 256, 'CodeSha256': HASH, 'Version': '3', 'Environment': {'Variables': env}},
        'alias': {'Name': 'live', 'AliasArn': cleanup.ALIAS, 'FunctionVersion': '3'},
        'concurrency': {'ReservedConcurrentExecutions': 1},
        'schedule': {'Name': cleanup.FUNCTION, 'GroupName': cleanup.GROUP, 'State': 'ENABLED',
                     'ScheduleExpression': 'rate(1 minute)', 'FlexibleTimeWindow': {'Mode': 'OFF'},
                     'Target': {'Arn': cleanup.ALIAS, 'RoleArn': f'arn:aws:iam::{cleanup.ACCOUNT}:role/{cleanup.FUNCTION}-schedule',
                                'RetryPolicy': {'MaximumEventAgeInSeconds': 60, 'MaximumRetryAttempts': 0},
                                'Input': json.dumps({'schemaVersion': 1, 'operation': 'reconcile-play-token-deletion'})}},
        'mappings': {'EventSourceMappings': [{'FunctionArn': cleanup.ALIAS, 'EventSourceArn': STREAM,
                     'State': 'Enabled', 'BatchSize': 5, 'MaximumRetryAttempts': 2, 'MaximumRecordAgeInSeconds': 600,
                     'BisectBatchOnFunctionError': True, 'FunctionResponseTypes': ['ReportBatchItemFailures'],
                     'FilterCriteria': {'Filters': [{'Pattern': json.dumps({'eventName': ['INSERT', 'MODIFY'],
                         'dynamodb': {'Keys': {'SK': {'S': ['ACCOUNT_DELETION']}}}})}]}}]},
    }


class CleanupTests(unittest.TestCase):
    def test_covered_billing_subject_preserves_other_cleanup_subjects_without_behavior_claim(self):
        metadata = fixture()
        before = copy.deepcopy(metadata)
        result = cleanup.verify_metadata([BILLING], metadata, HASH)
        self.assertEqual(metadata, before)
        self.assertEqual(result, {'billingCleanupConfigurationVerified': True, 'billingSubjectCount': 1,
                                 'cleanupSubjectCount': 2, 'behavioralQualification': False})
        self.assertNotIn(BILLING, json.dumps(result))
        self.assertNotIn(PRESERVED, json.dumps(result))

    def test_different_billing_subject_cannot_reuse_history_only_cleanup(self):
        metadata = fixture()
        metadata['function']['Environment']['Variables']['DEV_SUBJECT_ALLOWLIST_JSON'] = json.dumps([PRESERVED])
        with self.assertRaisesRegex(ValueError, cleanup.ERROR):
            cleanup.verify_metadata([BILLING], metadata, HASH)

    def test_bad_or_unbounded_admission_rejected(self):
        for admitted in ([], [BILLING, BILLING], ['invalid'], {'account': BILLING}, [BILLING] * 11):
            metadata = fixture()
            metadata['function']['Environment']['Variables']['DEV_SUBJECT_ALLOWLIST_JSON'] = json.dumps(admitted)
            with self.subTest(admitted=admitted), self.assertRaises(ValueError):
                cleanup.verify_metadata([BILLING], metadata, HASH)
        for subjects in ([], [BILLING, PRESERVED], ['invalid'], None):
            with self.subTest(subjects=subjects), self.assertRaises(ValueError):
                cleanup.verify(subjects, read=lambda *args: self.fail('Invalid input reached AWS'))

    def test_fixed_identity_code_version_and_work_limits(self):
        mutations = [('identity', 'Account', '999999999999'), ('function', 'FunctionName', 'other'),
                     ('function', 'State', 'Inactive'), ('function', 'State', 'Failed'),
                     ('function', 'LastUpdateStatus', 'Failed'), ('function', 'LastUpdateStatus', None),
                     ('function', 'CodeSha256', 'B' * 43 + '='), ('function', 'Version', '$LATEST'),
                     ('function', 'Role', 'other'), ('function', 'Runtime', 'python3.13'),
                     ('function', 'Handler', 'other.handler'), ('function', 'Timeout', 120),
                     ('alias', 'FunctionVersion', '2'), ('alias', 'AliasArn', cleanup.ALIAS.replace(':live', ':other')),
                     ('alias', 'RoutingConfig', {'AdditionalVersionWeights': {'2': 0.1}}),
                     ('concurrency', 'ReservedConcurrentExecutions', 0),
                     ('concurrency', 'ReservedConcurrentExecutions', 2)]
        for section, field, value in mutations:
            metadata = fixture(); metadata[section][field] = value
            with self.subTest(section=section, field=field, value=value), self.assertRaises(ValueError):
                cleanup.verify_metadata([BILLING], metadata, HASH)

    def test_cleanup_only_gates_and_fixed_tables(self):
        mutations = [('STAGE', 'uat'), ('PLAY_TOKEN_CLEANUP_ENABLED', 'false'),
                     ('PLAY_LIFECYCLE_ENABLED', 'true'), ('AUTHORITY_ENABLED', 'true'),
                     ('PLAY_PREPARATION_ENABLED', 'true'), ('PLAY_HANDOFF_ENABLED', 'true'),
                     ('PLAY_CHECKPOINT_POLICY_APPROVED', 'true'), ('PLAY_SCOPED_LIFECYCLE_WORKER_ENABLED', 'true'),
                     ('PLAY_TOKEN_TABLE_NAME', 'other'), ('DELETION_LEDGER_TABLE_NAME', 'other'),
                     ('AUTHORITY_POLICY_VERSION', 'unreviewed'), ('DELETION_LEDGER_STREAM_ARN', STREAM.replace('-deletion-ledger', '-other')),
                     ('GOOGLE_PLAY_SERVICE_ACCOUNT_SECRET_ARN', 'not-a-credential'), ('PLAY_TOKEN_KMS_KEY_ARN', 'other')]
        for field, value in mutations:
            metadata = fixture(); metadata['function']['Environment']['Variables'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                cleanup.verify_metadata([BILLING], metadata, HASH)

    def test_schedule_must_invoke_live_deletion_alias_with_exact_operation(self):
        for field, value in [('State', 'DISABLED'), ('GroupName', 'other'), ('ScheduleExpression', 'rate(1 hour)')]:
            metadata = fixture(); metadata['schedule'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                cleanup.verify_metadata([BILLING], metadata, HASH)
        for field, value in [('Arn', cleanup.ALIAS.replace(':live', ':2')), ('RoleArn', 'other'),
                             ('Input', json.dumps({'schemaVersion': 1, 'operation': 'reconcile-play-lifecycle'}))]:
            metadata = fixture(); metadata['schedule']['Target'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                cleanup.verify_metadata([BILLING], metadata, HASH)

    def test_stream_delivery_cannot_be_disabled_wrong_alias_or_wrong_filter(self):
        mutations = [('State', 'Disabled'), ('FunctionArn', cleanup.ALIAS.replace(':live', ':2')),
                     ('EventSourceArn', STREAM + '0'), ('MaximumRetryAttempts', -1),
                     ('FilterCriteria', {'Filters': []}), ('FunctionResponseTypes', [])]
        for field, value in mutations:
            metadata = fixture(); metadata['mappings']['EventSourceMappings'][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                cleanup.verify_metadata([BILLING], metadata, HASH)
        for rows in ([], fixture()['mappings']['EventSourceMappings'] * 2):
            metadata = fixture(); metadata['mappings']['EventSourceMappings'] = rows
            with self.subTest(count=len(rows)), self.assertRaises(ValueError):
                cleanup.verify_metadata([BILLING], metadata, HASH)

    def test_reader_only_requests_control_plane_metadata(self):
        metadata = fixture(); calls = []
        operations = {('sts', 'get-caller-identity'): 'identity', ('lambda', 'get-function-configuration'): 'function',
                      ('lambda', 'get-alias'): 'alias', ('lambda', 'get-function-concurrency'): 'concurrency',
                      ('scheduler', 'get-schedule'): 'schedule', ('lambda', 'list-event-source-mappings'): 'mappings'}
        def read(service, operation, *args):
            calls.append((service, operation))
            self.assertIn((service, operation), operations)
            if operation == 'list-event-source-mappings':
                self.assertEqual(args, ('--function-name', cleanup.ALIAS))
            return metadata[operations[service, operation]]
        with patch.object(cleanup, 'reviewed_hash', return_value=HASH):
            self.assertTrue(cleanup.verify([BILLING], read=read)['billingCleanupConfigurationVerified'])
        self.assertEqual(set(calls), set(operations))
        self.assertEqual(len(calls), len(operations))

    def test_wrong_account_stops_before_runtime_discovery(self):
        calls = []
        def read(service, operation, *args):
            calls.append((service, operation))
            return {'Account': '999999999999'}
        with self.assertRaises(ValueError): cleanup.verify([BILLING], read=read)
        self.assertEqual(calls, [('sts', 'get-caller-identity')])

    def test_plan_uses_explicit_billing_selection_only(self):
        values = {'environment': 'dev', 'aws_region': cleanup.REGION, 'project_name': 'trustcheckradar', 'enabled': True,
                  'engineering_subjects': [PRESERVED], 'billing_activation': {'mode': 'verification', 'subjects': [BILLING]}}
        plan = {'variables': {key: {'value': value} for key, value in values.items()}}
        self.assertEqual(cleanup.selected_subjects(plan), [BILLING])
        plan['variables']['billing_activation']['value'] = None
        self.assertEqual(cleanup.selected_subjects(plan), [])
        plan['variables']['environment']['value'] = 'uat'
        with self.assertRaises(ValueError): cleanup.selected_subjects(plan)

    def test_inactive_plan_skips_aws_without_claiming_cleanup(self):
        values = {'environment': 'dev', 'aws_region': cleanup.REGION, 'project_name': 'trustcheckradar',
                  'enabled': True, 'billing_activation': None}
        plan = {'variables': {key: {'value': value} for key, value in values.items()}}
        with patch.object(sys, 'argv', ['verify', '--plan', '/unused-private-plan']), \
             patch.object(Path, 'read_text', return_value=json.dumps(plan)), \
             patch.object(cleanup, 'verify', side_effect=AssertionError('Inactive billing must not read AWS')), \
             redirect_stdout(StringIO()) as output:
            cleanup.main()
        result = json.loads(output.getvalue())
        self.assertTrue(result['inactiveBilling'])
        self.assertFalse(result['billingCleanupConfigurationVerified'])
        del plan['variables']['billing_activation']
        with self.assertRaises(ValueError): cleanup.selected_subjects(plan)

    def test_cli_failure_never_prints_private_exception_or_plan(self):
        with patch.object(sys, 'argv', ['verify', '--plan', '/unused-private-plan']), \
             patch.object(Path, 'read_text', side_effect=RuntimeError(BILLING)), redirect_stdout(StringIO()) as output:
            with self.assertRaises(SystemExit) as error:
                cleanup.main()
        self.assertEqual(str(error.exception), cleanup.ERROR)
        self.assertEqual(output.getvalue(), '')


if __name__ == '__main__':
    unittest.main()
