"""Safety-boundary tests; no AWS credentials or live services required."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'qualify_campaign_writer_iam.py'
spec = importlib.util.spec_from_file_location('campaign_qualification', SCRIPT)
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)


def policy(kind):
    statements = []
    for sid, definition in q.SPECS[kind].items():
        st = {'Sid': sid, 'Effect': 'Allow', 'Action': sorted(definition['actions']), 'Resource': sorted(definition['resources'])}
        if definition['conditions']:
            st['Condition'] = copy.deepcopy(definition['conditions'])
        statements.append(st)
    return {'Version': '2012-10-17', 'Statement': statements}


def fixture_names():
    suffixes = ('pipeline', 'intelligence', 'outbox', 'users', 'ledger')
    return {k: 'amt-campaign-qual-' + 'a' * 32 + '-' + v for k, v in zip(q.TABLES, suffixes)}


def statement(value, sid):
    return next(s for s in value['Statement'] if s['Sid'] == sid)


class AwsError(Exception):
    def __init__(self, code, reasons=None):
        self.response = {'Error': {'Code': code}}
        if reasons is not None:
            self.response['CancellationReasons'] = reasons


def raises(code, reasons=None):
    def call():
        raise AwsError(code, reasons)
    return call


class CampaignIamTests(unittest.TestCase):
    def test_fixture_substitution_preserves_only_approved_table_and_index_paths(self):
        names = fixture_names()
        for role in q.ROLES:
            source, omitted = q.validate_policy(policy(role), role)
            self.assertEqual([], omitted)
            rewritten = q.fixture_policy(source, names)
            self.assertEqual(policy(role), source)  # no in-place source mutation
            for original, result in zip(source['Statement'], rewritten['Statement']):
                self.assertEqual(original.get('Condition'), result.get('Condition'))
                self.assertEqual(original['Action'], result['Action'])
                for old, new in zip(q.seq(original['Resource']), q.seq(result['Resource'])):
                    source_key = next(k for k, arn in q.TABLES.items() if old == arn or old.startswith(arn + '/index/'))
                    self.assertEqual(q.TABLE_ROOT + names[source_key] + old[len(q.TABLES[source_key]):], new)
            self.assertNotIn('trustcheckradar-dev-', q.canonical(rewritten))

    def test_omitted_aws_permissions_never_reach_fixture_role(self):
        value = policy('publisher')
        value['Statement'] += [
            {'Sid': 'ReadCampaignOutboxStream', 'Effect': 'Allow', 'Action': sorted(q.STREAM_ACTIONS), 'Resource': q.TABLES['campaign-outbox'] + '/stream/2026-09-06T23:21:14.722'},
            {'Sid': 'CreateKey', 'Effect': 'Allow', 'Action': 'kms:CreateKey', 'Resource': '*'},
            {'Sid': 'SendQueue', 'Effect': 'Allow', 'Action': 'sqs:SendMessage', 'Resource': f'arn:aws:sqs:{q.REGION}:{q.ACCOUNT}:fixture'},
        ]
        retained, omitted = q.validate_policy(value, 'publisher')
        self.assertEqual(3, len(omitted))
        rewritten = q.fixture_policy(retained, fixture_names())
        actions = [action for st in rewritten['Statement'] for action in q.seq(st['Action'])]
        self.assertTrue(all(a.startswith('dynamodb:') and a not in q.STREAM_ACTIONS for a in actions))
        self.assertFalse(any(r == '*' for st in rewritten['Statement'] for r in q.seq(st['Resource'])))

    def test_foreign_resources_and_wildcards_rejected(self):
        for resource in [q.TABLES['users'].replace(q.ACCOUNT, '123456789012'), q.TABLES['users'].replace(q.REGION, 'us-west-2'), '*', q.TABLES['users'] + '*', q.TABLES['users'] + '/index/Injected']:
            with self.subTest(resource=resource):
                value = policy('publisher')
                statement(value, 'ReadParticipationState')['Resource'] = resource
                with self.assertRaisesRegex(q.QualificationError, 'unexpected_table_or_index'):
                    q.validate_policy(value, 'publisher')

    def test_unsupported_check_context_and_return_values_fail_closed(self):
        for modify in ('enclosing', 'no_leading', 'no_return_values', 'all_old', 'broaden_leading'):
            with self.subTest(modify=modify):
                value = policy('publisher')
                condition = statement(value, 'CheckFixedAccountDeletionFenceTransactionally')['Condition']
                if modify == 'enclosing':
                    condition['ForAnyValue:StringEquals'] = {'dynamodb:EnclosingOperation': 'TransactWriteItems'}
                elif modify == 'no_leading':
                    condition.pop('ForAllValues:StringLike')
                elif modify == 'no_return_values':
                    condition.pop('StringEqualsIfExists')
                elif modify == 'all_old':
                    condition['StringEqualsIfExists']['dynamodb:ReturnValues'] = 'ALL_OLD'
                else:
                    condition['ForAllValues:StringLike']['dynamodb:LeadingKeys'] = '*'
                with self.assertRaisesRegex(q.QualificationError, 'unexpected_dynamodb_conditions'):
                    q.validate_policy(value, 'publisher')

    def test_transaction_only_mutation_cannot_be_weakened(self):
        for role, sid in [('publisher', 'WriteFencedTransientPipeline'), ('cluster', 'WriteMutableCandidateFamilies'), ('deletion', 'GuardedRepairWrites')]:
            value = policy(role)
            statement(value, sid)['Condition'].pop('ForAnyValue:StringEquals')
            with self.assertRaisesRegex(q.QualificationError, 'unexpected_dynamodb_conditions'):
                q.validate_policy(value, role)

    def test_lifecycle_legacy_standalone_permissions_are_explicit(self):
        value, _ = q.validate_policy(policy('lifecycle'), 'lifecycle')
        for sid in ('WriteLifecycleAggregates', 'WriteMutableLifecyclePipeline'):
            st = statement(value, sid)
            self.assertNotIn('ForAnyValue:StringEquals', st['Condition'])
            self.assertIn('dynamodb:BatchWriteItem', st['Action'])

    def test_duplicate_missing_or_extra_table_statement_rejected(self):
        for mutation in ('duplicate', 'missing', 'extra'):
            value = policy('publisher')
            if mutation == 'duplicate':
                value['Statement'].append(copy.deepcopy(value['Statement'][0]))
            elif mutation == 'missing':
                value['Statement'].pop()
            else:
                value['Statement'].append({'Sid': 'UnexpectedScan', 'Effect': 'Allow', 'Action': 'dynamodb:Scan', 'Resource': q.TABLES['users']})
            with self.assertRaises(q.QualificationError):
                q.validate_policy(value, 'publisher')

    def test_fixture_names_must_be_disposable_unique_and_complete(self):
        for mutation in ('live_name', 'missing', 'collision', 'wildcard'):
            names = fixture_names()
            if mutation == 'live_name':
                names['users'] = 'trustcheckradar-dev-users'
            elif mutation == 'missing':
                names.pop('users')
            elif mutation == 'collision':
                names['users'] = names['deletion-ledger']
            else:
                names['users'] += '*'
            with self.assertRaises(q.QualificationError):
                q.fixture_policy(policy('publisher'), names)

    def test_defensive_fixture_conversion_rejects_live_resource_and_stream_actions(self):
        for mutation in ('foreign', 'stream_action'):
            value = policy('publisher')
            if mutation == 'foreign':
                value['Statement'][0]['Resource'] = 'arn:aws:dynamodb:us-east-1:123456789012:table/other'
            else:
                value['Statement'][0]['Action'] = 'dynamodb:GetRecords'
            with self.assertRaises(q.QualificationError):
                q.fixture_policy(value, fixture_names())

    def test_only_access_denied_is_counted_as_permission_denial(self):
        for code in ('AccessDenied', 'AccessDeniedException'):
            q.denied(raises(code))
        for code in ('TransactionCanceledException', 'ValidationException', 'ThrottlingException', 'ResourceNotFoundException'):
            with self.assertRaisesRegex(q.QualificationError, 'unexpected_denial_type'):
                q.denied(raises(code))
        with self.assertRaisesRegex(q.QualificationError, 'expected_access_denied'):
            q.denied(lambda: {})

    def test_guard_cancellation_requires_exact_guard_and_no_returned_item(self):
        reasons = [{'Code': 'None'}, {'Code': 'ConditionalCheckFailed'}]
        q.canceled_without_item(raises('TransactionCanceledException', reasons), 1)
        for bad in ([{'Code': 'None'}], [{'Code': 'ConditionalCheckFailed'}, {'Code': 'None'}], [{'Code': 'None'}, {'Code': 'ConditionalCheckFailed', 'Item': {}}]):
            with self.assertRaises(q.QualificationError):
                q.canceled_without_item(raises('TransactionCanceledException', bad), 1)
        with self.assertRaises(q.QualificationError):
            q.canceled_without_item(raises('AccessDenied'), 1)
        with self.assertRaises(q.QualificationError):
            q.canceled_without_item(lambda: {}, 1)

    def test_plan_requires_all_four_exact_known_policy_addresses(self):
        changes = [{'address': f'aws_iam_role_policy.{role}_runtime[0]', 'change': {'after': {'policy': json.dumps(policy(role))}, 'after_unknown': {}}} for role in q.ROLES]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'plan.json'
            path.write_text(json.dumps({'resource_changes': changes}))
            values, omitted, digest = q.load_policies(path)
            self.assertEqual(set(q.ROLES), set(values))
            self.assertEqual(64, len(digest))
            changes[0]['change']['after_unknown']['policy'] = True
            path.write_text(json.dumps({'resource_changes': changes}))
            with self.assertRaisesRegex(q.QualificationError, 'policy_unknown'):
                q.load_policies(path)
            changes[0]['change']['after_unknown'] = {}
            changes.append(copy.deepcopy(changes[0]))
            path.write_text(json.dumps({'resource_changes': changes}))
            with self.assertRaisesRegex(q.QualificationError, 'policy_address_missing_or_ambiguous'):
                q.load_policies(path)

    def test_service_mixing_and_foreign_omitted_resources_rejected(self):
        for actions, resource in [(['kms:CreateKey', 'dynamodb:Scan'], '*'), (['sqs:SendMessage'], 'arn:aws:sqs:us-east-1:123456789012:q')]:
            value = policy('publisher')
            value['Statement'].append({'Sid': 'BadOmitted', 'Effect': 'Allow', 'Action': actions, 'Resource': resource})
            with self.assertRaises(q.QualificationError):
                q.validate_policy(value, 'publisher')


if __name__ == '__main__':
    unittest.main()
