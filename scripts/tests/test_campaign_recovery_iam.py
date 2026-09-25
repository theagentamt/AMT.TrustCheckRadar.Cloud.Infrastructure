"""Offline policy isolation, refusal, and cleanup tests; never contacts AWS."""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'qualify_campaign_recovery_iam.py'
spec = importlib.util.spec_from_file_location('recovery_qualification', SCRIPT)
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)


def source_policy():
    table = 'arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger'
    return {'Version': '2012-10-17', 'Statement': [
        {'Sid': 'DiscoverDueCampaignRecoveryKeys', 'Effect': 'Allow', 'Action': 'dynamodb:Query', 'Resource': table + '/index/CampaignRecoveryDueIndex', 'Condition': {'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': [f'CAMPAIGN_RECOVERY#dev#{n:02d}' for n in range(16)]}}},
        {'Sid': 'ReadCampaignRecoveryInventory', 'Effect': 'Allow', 'Action': 'dynamodb:GetItem', 'Resource': table, 'Condition': {'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': 'INVENTORY#dev'}}},
        {'Sid': 'CheckCampaignRecoveryInventory', 'Effect': 'Allow', 'Action': 'dynamodb:ConditionCheckItem', 'Resource': table, 'Condition': {'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': 'INVENTORY#dev'}, 'StringEqualsIfExists': {'dynamodb:ReturnValues': 'NONE'}}},
        {'Sid': 'AdvanceOwnedRecoveryRetryTransaction', 'Effect': 'Allow', 'Action': 'dynamodb:UpdateItem', 'Resource': table, 'Condition': {'ForAllValues:StringLike': {'dynamodb:LeadingKeys': 'ACCOUNT#*'}, 'ForAnyValue:StringEquals': {'dynamodb:EnclosingOperation': 'TransactWriteItems'}}},
    ]}


def plan(policy=None):
    return {'resource_changes': [{'address': q.ADDRESS, 'mode': 'managed', 'type': 'aws_iam_role_policy', 'change': {'after': {'policy': json.dumps(policy or source_policy())}, 'after_unknown': {}}}]}


class AwsError(Exception):
    def __init__(self, code, reasons=None):
        self.response = {'Error': {'Code': code}}
        if reasons is not None:
            self.response['CancellationReasons'] = reasons


def raises(code, reasons=None):
    def call():
        raise AwsError(code, reasons)
    return call


class RecoveryIamTests(unittest.TestCase):
    def test_valid_policy_is_defensively_copied(self):
        original = source_policy()
        actual = q.validate_policy(original)
        actual['Statement'][0]['Condition'].clear()
        self.assertTrue(original['Statement'][0]['Condition'])

    def test_resource_rewrite_preserves_index_path_and_all_guards(self):
        source = source_policy()
        name = 'amt-recovery-qual-' + 'a' * 32 + '-ledger'
        fixture = q.fixture_policy(source, name)
        for old, new in zip(source['Statement'], fixture['Statement']):
            self.assertEqual(old['Action'], new['Action'])
            self.assertEqual(old['Condition'], new['Condition'])
            suffix = '/index/CampaignRecoveryDueIndex' if old['Sid'] == 'DiscoverDueCampaignRecoveryKeys' else ''
            self.assertEqual(q.TABLE_ROOT + name + suffix, new['Resource'])
        self.assertNotIn('trustcheckradar-dev-', q.canonical(fixture))
        self.assertIn('trustcheckradar-dev-', q.canonical(source))

    def test_fixture_name_cannot_reference_a_live_table_or_wildcard(self):
        for name in ['trustcheckradar-dev-deletion-ledger', 'amt-recovery-qual-' + 'a' * 32 + '-ledger*', 'amt-recovery-qual-short-ledger', '*']:
            with self.subTest(name=name), self.assertRaisesRegex(q.QualificationError, 'fixture_table_name'):
                q.fixture_policy(source_policy(), name)

    def test_rejects_foreign_account_region_and_extra_resource(self):
        for resource in [q.SOURCE_INDEX.replace(q.ACCOUNT, '123456789012'), q.SOURCE_INDEX.replace(q.REGION, 'us-west-2'), q.SOURCE_TABLE, '*', [q.SOURCE_INDEX, q.SOURCE_TABLE]]:
            value = source_policy()
            value['Statement'][0]['Resource'] = resource
            with self.assertRaisesRegex(q.QualificationError, 'unexpected_resource'):
                q.validate_policy(value)

    def test_shards_must_be_exactly_sixteen_padded_dev_values(self):
        expected = [f'CAMPAIGN_RECOVERY#dev#{n:02d}' for n in range(16)]
        self.assertEqual(expected, q.SHARDS)
        for bad in [expected[:-1], expected + ['CAMPAIGN_RECOVERY#dev#16'], ['CAMPAIGN_RECOVERY#dev#*'], [p.replace('#00', '#0') for p in expected], [p.replace('#dev#', '#prod#') for p in expected], expected + [expected[0]]]:
            value = source_policy()
            value['Statement'][0]['Condition']['ForAllValues:StringEquals']['dynamodb:LeadingKeys'] = bad
            with self.assertRaises(q.QualificationError):
                q.validate_policy(value)

    def test_condition_check_unsupported_context_and_old_return_values_rejected(self):
        for change in ['enclosing', 'old_values', 'missing_none', 'wrong_inventory']:
            value = source_policy()
            conditions = value['Statement'][2]['Condition']
            if change == 'enclosing':
                conditions['ForAnyValue:StringEquals'] = {'dynamodb:EnclosingOperation': 'TransactWriteItems'}
            elif change == 'old_values':
                conditions['StringEqualsIfExists']['dynamodb:ReturnValues'] = 'ALL_OLD'
            elif change == 'missing_none':
                conditions.pop('StringEqualsIfExists')
            else:
                conditions['ForAllValues:StringEquals']['dynamodb:LeadingKeys'] = 'INVENTORY#*'
            with self.assertRaisesRegex(q.QualificationError, 'unexpected_condition'):
                q.validate_policy(value)

    def test_update_must_remain_account_scoped_and_transaction_only(self):
        for change in ['standalone', 'any_key', 'wrong_operator']:
            value = source_policy()
            conditions = value['Statement'][3]['Condition']
            if change == 'standalone':
                conditions.pop('ForAnyValue:StringEquals')
            elif change == 'any_key':
                conditions['ForAllValues:StringLike']['dynamodb:LeadingKeys'] = '*'
            else:
                conditions['StringEquals'] = conditions.pop('ForAnyValue:StringEquals')
            with self.assertRaisesRegex(q.QualificationError, 'unexpected_condition'):
                q.validate_policy(value)

    def test_scan_put_delete_or_extra_statement_never_copied(self):
        for action in ['dynamodb:Scan', 'dynamodb:PutItem', 'dynamodb:DeleteItem', 'dynamodb:*']:
            value = source_policy()
            value['Statement'][0]['Action'] = action
            with self.assertRaises(q.QualificationError):
                q.fixture_policy(value, 'amt-recovery-qual-' + 'a' * 32 + '-ledger')
        value = source_policy()
        value['Statement'].append({'Sid': 'Foreign', 'Effect': 'Allow', 'Action': '*', 'Resource': '*'})
        with self.assertRaisesRegex(q.QualificationError, 'statement_count'):
            q.validate_policy(value)

    def test_duplicate_sid_and_missing_or_deny_fields_are_rejected(self):
        for change in ['duplicate', 'no_condition', 'deny', 'not_resource']:
            value = source_policy()
            if change == 'duplicate':
                value['Statement'][1]['Sid'] = value['Statement'][0]['Sid']
            elif change == 'no_condition':
                value['Statement'][1].pop('Condition')
            elif change == 'deny':
                value['Statement'][1]['Effect'] = 'Deny'
            else:
                value['Statement'][1]['NotResource'] = value['Statement'][1].pop('Resource')
            with self.assertRaises(q.QualificationError):
                q.validate_policy(value)

    def test_only_permission_denials_count_as_denials(self):
        for code in ('AccessDenied', 'AccessDeniedException'):
            q.denied(raises(code))
        for code in ('TransactionCanceledException', 'ResourceNotFoundException', 'ValidationException', 'ThrottlingException'):
            with self.assertRaisesRegex(q.QualificationError, 'unexpected_denial_type'):
                q.denied(raises(code))
        with self.assertRaisesRegex(q.QualificationError, 'expected_access_denied'):
            q.denied(lambda: {})

    def test_atomic_cancellation_requires_expected_guard_and_no_item(self):
        q.canceled(raises('TransactionCanceledException', [{'Code': 'None'}, {'Code': 'ConditionalCheckFailed'}]))
        for reasons in [[], [{'Code': 'ConditionalCheckFailed'}, {'Code': 'None'}], [{'Code': 'None'}, {'Code': 'ConditionalCheckFailed', 'Item': {}}]]:
            with self.assertRaises(q.QualificationError):
                q.canceled(raises('TransactionCanceledException', reasons))
        with self.assertRaises(q.QualificationError):
            q.canceled(raises('AccessDenied'))
        with self.assertRaises(q.QualificationError):
            q.canceled(lambda: {})

    def test_plan_requires_exact_known_managed_policy(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'plan.json'
            for change in ['wrong_address', 'duplicate', 'unknown_policy', 'wrong_type']:
                value = plan()
                if change == 'wrong_address':
                    value['resource_changes'][0]['address'] = 'aws_iam_role_policy.other[0]'
                elif change == 'duplicate':
                    value['resource_changes'] *= 2
                elif change == 'unknown_policy':
                    value['resource_changes'][0]['change']['after_unknown']['policy'] = True
                else:
                    value['resource_changes'][0]['type'] = 'aws_iam_policy'
                path.write_text(json.dumps(value))
                with self.assertRaises(q.QualificationError):
                    q.load_policy(path)

    def test_default_cli_validates_without_loading_aws_sdk(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'plan.json'
            path.write_text(json.dumps(plan()))
            output = io.StringIO()
            with patch.object(sys, 'argv', ['qualify', '--plan', str(path)]), patch.dict(sys.modules, {'boto3': None}), contextlib.redirect_stdout(output):
                self.assertEqual(0, q.main())
            report = json.loads(output.getvalue())
            self.assertFalse(report['cloudExecuted'])
            self.assertTrue(report['policyValidationPassed'])
            self.assertEqual(64, len(report['sourcePlanSha256']))

    def test_read_count_queries_target_only_index_and_due_shard(self):
        args = q.query_args('synthetic', q.SHARDS[0])
        self.assertEqual('CampaignRecoveryDueIndex', args['IndexName'])
        self.assertEqual('COUNT', args['Select'])
        self.assertEqual({'S': 'CAMPAIGN_RECOVERY#dev#00'}, args['ExpressionAttributeValues'][':shard'])
        self.assertNotIn('ConsistentRead', args)

    def test_failed_fixture_setup_still_removes_owned_table(self):
        # A real AWS SDK never loads: fake modules/clients record only the safety
        # boundary. Failure occurs before any role grant or fixture transaction.
        calls = []
        class Client:
            def get_caller_identity(self):
                return {'Account': q.ACCOUNT, 'Arn': f'arn:aws:iam::{q.ACCOUNT}:user/synthetic-reviewer'}
            def create_table(self, **kwargs):
                self.table = kwargs['TableName']; self.tags = kwargs['Tags']
                calls.append(('create', self.table))
            def describe_table(self, **kwargs):
                return {'Table': {'TableStatus': 'ACTIVE', 'GlobalSecondaryIndexes': [{'IndexName': q.INDEX, 'IndexStatus': 'ACTIVE'}]}}
            def describe_continuous_backups(self, **kwargs):
                # Intentional setup failure must not escape cleanup.
                return {'ContinuousBackupsDescription': {'PointInTimeRecoveryDescription': {'PointInTimeRecoveryStatus': 'ENABLED'}}}
            def list_tags_of_resource(self, **kwargs):
                self.asserted_arn = kwargs['ResourceArn']
                return {'Tags': self.tags}
            def delete_table(self, **kwargs):
                calls.append(('delete', kwargs['TableName']))
            def close(self):
                pass
        client = Client()
        session = types.SimpleNamespace(client=lambda *args, **kwargs: client)
        modules = {'boto3': types.ModuleType('boto3'), 'botocore.config': types.SimpleNamespace(Config=lambda **kwargs: object())}
        with patch.dict(sys.modules, modules), patch.object(q, 'wait_table', lambda *args: None):
            result = q.qualify(session, source_policy(), 'a' * 64)
        self.assertFalse(result['passed'])
        self.assertEqual('unexpected_pitr', result['failure'])
        self.assertTrue(result['cleanupComplete'])
        self.assertEqual(calls[0][1], calls[1][1])
        self.assertEqual(['create', 'delete'], [call[0] for call in calls])
        self.assertRegex(calls[0][1], '^amt-recovery-qual-[a-f0-9]{32}-ledger$')
        self.assertNotIn('trustcheckradar-dev-', client.asserted_arn)


if __name__ == '__main__':
    unittest.main()
