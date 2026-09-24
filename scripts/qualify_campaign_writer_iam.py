#!/usr/bin/env python3
"""Qualify reviewed campaign DynamoDB IAM using disposable synthetic fixtures only.

Offline by default. --execute requires independent review before use. No Lambda,
stream, queue, KMS, or application-data operation is performed. Table/index read
permissions are preserved but only the write/check boundary is exercised.
"""
import argparse
import copy
import hashlib
import json
import re
import time
import uuid
from pathlib import Path

ACCOUNT = '107827791950'
REGION = 'us-east-1'
TABLE_ROOT = f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/'
TABLES = {name: TABLE_ROOT + 'trustcheckradar-dev-' + name for name in (
    'campaign-pipeline', 'campaign-intelligence', 'campaign-outbox', 'users', 'deletion-ledger')}
ROLES = ('publisher', 'cluster', 'deletion', 'lifecycle')
STREAM_ACTIONS = {'dynamodb:ListStreams', 'dynamodb:GetShardIterator', 'dynamodb:GetRecords', 'dynamodb:DescribeStream'}
MUTATIONS = {'dynamodb:PutItem', 'dynamodb:UpdateItem', 'dynamodb:DeleteItem', 'dynamodb:BatchWriteItem'}
FIXTURE_PATTERN = r'amt-campaign-qual-[a-f0-9]{32}-(pipeline|intelligence|outbox|users|ledger)'


class QualificationError(Exception):
    """Only fixed, content-free error identifiers may be used as messages."""


def require(condition, reason):
    if not condition:
        raise QualificationError(reason)


def seq(value):
    return value if isinstance(value, list) else [value]


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


def sha(value):
    return hashlib.sha256(value).hexdigest()


def keys_condition(patterns, equals=False):
    return {'ForAllValues:StringEquals' if equals else 'ForAllValues:StringLike': {'dynamodb:LeadingKeys': patterns}}


def expected_statement(actions, resources, patterns=None, check=False, tx=False, equals=False):
    conditions = keys_condition(patterns, equals) if patterns else {}
    if check:
        conditions['StringEqualsIfExists'] = {'dynamodb:ReturnValues': 'NONE'}
    if tx:
        conditions['ForAnyValue:StringEquals'] = {'dynamodb:EnclosingOperation': 'TransactWriteItems'}
    return {'actions': set(seq(actions)), 'resources': set(seq(resources)), 'conditions': conditions}


def specifications():
    p, i, o, u, d = (TABLES[x] for x in TABLES)
    def read(resources, actions=('dynamodb:Query', 'dynamodb:GetItem'), patterns=None):
        return expected_statement(list(actions), resources, patterns)
    def check(resource, patterns, equals=False):
        return expected_statement('dynamodb:ConditionCheckItem', resource, patterns, check=True, equals=equals)
    def write(resource, patterns, actions=('dynamodb:UpdateItem', 'dynamodb:PutItem', 'dynamodb:DeleteItem'), tx=True):
        return expected_statement(list(actions), resource, patterns, tx=tx)
    inventory = check(p, 'INVENTORY#dev', equals=True)
    return {
        'publisher': {
            'CheckLocatorInventoryTransaction': inventory,
            'ReadFixedAccountDeletionFence': read(d, ('dynamodb:GetItem',), 'ACCOUNT#*'),
            'CheckFixedAccountDeletionFenceTransactionally': check(d, 'ACCOUNT#*'),
            'CheckContributorTombstoneTransaction': check(p, 'CONTRIB#*'),
            'WriteTransientPipeline': read(p, ('dynamodb:GetItem',)),
            'WriteFencedTransientPipeline': write(p, ['EVENT#*', 'CONTRIB#*'], ('dynamodb:UpdateItem', 'dynamodb:PutItem')),
            'ReadParticipationState': read(u, ('dynamodb:GetItem',), 'USER#*'),
            'CheckParticipationStateInTransaction': check(u, 'USER#*'),
        },
        'cluster': {
            'ReadResearchEligibilityLedger': read(d, ('dynamodb:GetItem',), 'ACCOUNT#*'),
            'ReadResearchEligibilityOutbox': read(o, ('dynamodb:GetItem',), 'EVENT#*'),
            'ReadResearchEligibilityUsers': read(u, ('dynamodb:GetItem',), 'USER#*'),
            'CheckResearchEligibilityLedger': check(d, 'ACCOUNT#*'),
            'CheckResearchEligibilityOutbox': check(o, 'EVENT#*'),
            'CheckResearchEligibilityUsers': check(u, 'USER#*'),
            'CheckCandidateLifecycleTransaction': check(p, 'CANDIDATE#*'),
            'CheckLocatorInventoryTransaction': inventory,
            'CheckContributorTombstoneTransaction': check(p, 'CONTRIB#*'),
            'ReadTransientCandidates': read([p, p + '/index/CandidateBucketIndex']),
            'UpdatePersistentAggregates': read([i, i + '/index/PublicationIndex']),
            'WriteMutableCandidateFamilies': write(p, ['EVENT#*', 'CONTRIB#*', 'CANDIDATE#*', 'BUCKET#*']),
        },
        'deletion': {
            'CheckLocatorInventoryTransaction': inventory,
            'DeleteActiveContributions': read([p, p + '/index/ContributorPeriodIndex']),
            'CompleteParticipationWithdrawal': read(u, ('dynamodb:GetItem',), 'USER#*'),
            'CompleteDeletionLedgerCommand': read(d, ('dynamodb:GetItem',), 'ACCOUNT#*'),
            'GuardedRepairWrites': write(p, ['CONTRIB#*', 'EVENT#*', 'CANDIDATE#*']),
            'GuardedDeletionCommand': check(d, 'ACCOUNT#*'),
            'GuardedRepairChecks': check(p, ['CONTRIB#*', 'EVENT#*', 'CANDIDATE#*']),
        },
        'lifecycle': {
            'LifecycleTableAccess': read([p, p + '/index/ExpirationIndex', p + '/index/CandidateBucketIndex', i]),
            'WriteLifecycleAggregates': write(i, 'CAMPAIGN#*', tuple(sorted(MUTATIONS)), tx=False),
            'WriteMutableLifecyclePipeline': write(p, ['PERIOD#*', 'EVENT#*', 'CONTRIB#*', 'CANDIDATE#*', 'BUCKET#*'], tuple(sorted(MUTATIONS)), tx=False),
            'CheckLifecycleAggregate': check(i, 'CAMPAIGN#*'),
            'CheckLifecyclePipelineProof': check(p, ['CANDIDATE#*', 'INVENTORY#dev']),
        },
    }


SPECS = specifications()


def normalized_conditions(conditions):
    require(isinstance(conditions, dict), 'conditions_schema')
    result = {}
    for operator, values in conditions.items():
        require(isinstance(values, dict), 'conditions_schema')
        result[operator] = {key: sorted(seq(value)) for key, value in values.items()}
    return result


def validate_policy(policy, kind):
    require(set(policy) == {'Version', 'Statement'} and policy['Version'] == '2012-10-17', 'policy_schema')
    require(isinstance(policy['Statement'], list), 'statement_schema')
    retained, omitted, seen = [], [], set()
    for st in policy['Statement']:
        require(isinstance(st, dict) and set(st) <= {'Sid', 'Effect', 'Action', 'Resource', 'Condition'}, 'statement_fields')
        require(st.get('Effect') == 'Allow' and isinstance(st.get('Sid'), str), 'statement_effect_or_sid')
        sid = st['Sid']
        require(sid not in seen, 'duplicate_sid')
        seen.add(sid)
        actions = seq(st.get('Action'))
        resources = seq(st.get('Resource'))
        require(all(isinstance(x, str) for x in actions + resources), 'action_resource_schema')
        ddb = [x.startswith('dynamodb:') for x in actions]
        require(all(ddb) or not any(ddb), 'mixed_service_statement')
        if not any(ddb):
            # Omitted permissions are never copied into fixture roles. Validate
            # their resource account/region boundary, but do not qualify behavior.
            require(all(x == '*' or re.fullmatch(r'arn:aws:(kms|sqs):' + REGION + ':' + ACCOUNT + r':.+', x) for x in resources), 'foreign_omitted_resource')
            require(all(x.startswith(('kms:', 'sqs:')) for x in actions), 'unexpected_omitted_service')
            omitted.append({'sid': sid, 'reason': 'non_dynamodb_not_qualified', 'actions': actions})
            continue
        if set(actions) <= STREAM_ACTIONS:
            require(all(any(re.fullmatch(re.escape(arn) + r'/stream/[0-9TZ:.+-]+', x) for arn in TABLES.values()) for x in resources), 'unexpected_stream_resource')
            omitted.append({'sid': sid, 'reason': 'stream_not_qualified', 'actions': actions})
            continue
        require(sid in SPECS[kind], 'unexpected_dynamodb_statement')
        exp = SPECS[kind][sid]
        require(set(actions) == exp['actions'] and len(actions) == len(set(actions)), 'unexpected_dynamodb_actions')
        require(set(resources) == exp['resources'] and len(resources) == len(set(resources)), 'unexpected_table_or_index')
        require(normalized_conditions(st.get('Condition', {})) == normalized_conditions(exp['conditions']), 'unexpected_dynamodb_conditions')
        retained.append(copy.deepcopy(st))
    require({s['Sid'] for s in retained} == set(SPECS[kind]), 'missing_dynamodb_statement')
    return {'Version': policy['Version'], 'Statement': retained}, omitted


def load_policies(path):
    raw = Path(path).read_bytes()
    plan = json.loads(raw)
    result, omitted = {}, {}
    for kind in ROLES:
        matches = [r for r in plan.get('resource_changes', []) if r.get('address') == f'aws_iam_role_policy.{kind}_runtime[0]']
        require(len(matches) == 1, 'policy_address_missing_or_ambiguous')
        change = matches[0]['change']
        require(change.get('after_unknown', {}).get('policy') is not True, 'policy_unknown')
        policy = json.loads(change['after']['policy'])
        result[kind], omitted[kind] = validate_policy(policy, kind)
    return result, omitted, sha(raw)


def fixture_policy(policy, names):
    require(set(names) == set(TABLES), 'fixture_table_set')
    require(len(set(names.values())) == len(TABLES), 'fixture_table_collision')
    require(all(re.fullmatch(FIXTURE_PATTERN, x) for x in names.values()), 'fixture_table_name')
    result = copy.deepcopy(policy)
    for st in result['Statement']:
        rewritten = []
        for resource in seq(st['Resource']):
            matches = [(key, arn) for key, arn in TABLES.items() if resource == arn or resource.startswith(arn + '/index/')]
            require(len(matches) == 1, 'unmapped_live_resource')
            key_name, original = matches[0]
            rewritten.append(TABLE_ROOT + names[key_name] + resource[len(original):])
        st['Resource'] = rewritten if isinstance(st['Resource'], list) else rewritten[0]
        require(all(a.startswith('dynamodb:') and a not in STREAM_ACTIONS for a in seq(st['Action'])), 'fixture_non_table_action')
    require('trustcheckradar-dev-' not in canonical(result), 'live_resource_leaked')
    return result


def error_code(exc):
    return getattr(exc, 'response', {}).get('Error', {}).get('Code', '')


def denied(call):
    try:
        call()
    except Exception as exc:
        require(error_code(exc) in ('AccessDeniedException', 'AccessDenied'), 'unexpected_denial_type')
        return
    raise QualificationError('expected_access_denied')


def canceled_without_item(call, guard_index):
    try:
        call()
    except Exception as exc:
        require(error_code(exc) == 'TransactionCanceledException', 'unexpected_cancellation_type')
        reasons = getattr(exc, 'response', {}).get('CancellationReasons', [])
        require(len(reasons) == 2 and reasons[guard_index].get('Code') == 'ConditionalCheckFailed', 'missing_guard_cancellation')
        require(all('Item' not in x for x in reasons), 'cancellation_returned_item')
        return
    raise QualificationError('guard_did_not_cancel')


def key(pk, sk='FIXTURE'):
    return {'PK': {'S': pk}, 'SK': {'S': sk}}


def wait_table(client, name, present, seconds=90):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            status = client.describe_table(TableName=name)['Table']['TableStatus']
            if present and status == 'ACTIVE':
                return
        except Exception as exc:
            if error_code(exc) == 'ResourceNotFoundException' and not present:
                return
            require(error_code(exc) == 'ResourceNotFoundException', 'table_wait_failed')
        time.sleep(2)
    raise QualificationError('table_wait_timeout')


def action_call(client, action, table, pk):
    if action == 'dynamodb:PutItem':
        return lambda: client.put_item(TableName=table, Item={**key(pk), 'fixture': {'BOOL': True}})
    if action == 'dynamodb:UpdateItem':
        return lambda: client.update_item(TableName=table, Key=key(pk), UpdateExpression='SET fixture = :v', ExpressionAttributeValues={':v': {'BOOL': True}})
    if action == 'dynamodb:DeleteItem':
        return lambda: client.delete_item(TableName=table, Key=key(pk))
    if action == 'dynamodb:BatchWriteItem':
        def batch():
            response = client.batch_write_item(RequestItems={table: [{'PutRequest': {'Item': {**key(pk), 'fixture': {'BOOL': True}}}}]})
            require(not response.get('UnprocessedItems'), 'unprocessed_batch_write')
        return batch
    raise QualificationError('unsupported_mutation')


def tx_action(action, table, pk):
    if action == 'dynamodb:PutItem':
        return {'Put': {'TableName': table, 'Item': {**key(pk), 'fixture': {'BOOL': True}}}}
    if action == 'dynamodb:UpdateItem':
        return {'Update': {'TableName': table, 'Key': key(pk), 'UpdateExpression': 'SET fixture = :v', 'ExpressionAttributeValues': {':v': {'BOOL': True}}}}
    if action == 'dynamodb:DeleteItem':
        return {'Delete': {'TableName': table, 'Key': key(pk)}}
    raise QualificationError('unsupported_transaction_mutation')


def check_action(table, pk, rv='NONE'):
    return {'ConditionCheck': {'TableName': table, 'Key': key(pk), 'ConditionExpression': 'attribute_not_exists(PK)', 'ReturnValuesOnConditionCheckFailure': rv}}


def patterns(st):
    for operator, values in st.get('Condition', {}).items():
        if operator.startswith('ForAllValues:') and 'dynamodb:LeadingKeys' in values:
            return seq(values['dynamodb:LeadingKeys'])
    raise QualificationError('missing_partition_patterns')


def table_for(st, names):
    resources = seq(st['Resource'])
    require(len(resources) == 1 and resources[0] in TABLES.values(), 'case_requires_single_table')
    return names[next(k for k, v in TABLES.items() if v == resources[0])]


def seed(client, table, pk):
    client.put_item(TableName=table, Item={**key(pk), 'seed': {'BOOL': True}})


def qualify_role(kind, client, admin, policy, names, report):
    checks = [s for s in policy['Statement'] if seq(s['Action']) == ['dynamodb:ConditionCheckItem']]
    writes = [s for s in policy['Statement'] if set(seq(s['Action'])) & MUTATIONS]
    def record(case):
        report['cases'].append(kind + ':' + case)
    # This first check is retried only for IAM propagation. A conditional failure
    # or throttling response must not be reported as permission success.
    first = checks[0]
    first_table = table_for(first, names)
    first_pk = patterns(first)[0].replace('*', 'propagation')
    admin.delete_item(TableName=first_table, Key=key(first_pk))
    for attempt in range(12):
        try:
            client.transact_write_items(TransactItems=[check_action(first_table, first_pk)])
            break
        except Exception as exc:
            require(error_code(exc) in ('AccessDenied', 'AccessDeniedException'), 'positive_check_failed')
            require(attempt < 11, 'policy_propagation_timeout')
            time.sleep(3)
    for st in checks:
        table = table_for(st, names)
        for n, pattern in enumerate(patterns(st)):
            pk = pattern.replace('*', st['Sid'] + str(n))
            admin.delete_item(TableName=table, Key=key(pk))
            client.transact_write_items(TransactItems=[check_action(table, pk)])
            record(st['Sid'] + ':' + str(n) + ':condition_none_allowed')
            seed(admin, table, pk)
            denied(lambda: client.transact_write_items(TransactItems=[check_action(table, pk, 'ALL_OLD')]))
            record(st['Sid'] + ':' + str(n) + ':all_old_denied')
        denied(lambda: client.transact_write_items(TransactItems=[check_action(table, 'OTHER#foreign')]))
        record(st['Sid'] + ':foreign_partition_denied')
    for st in writes:
        table = table_for(st, names)
        tx_only = 'ForAnyValue:StringEquals' in st.get('Condition', {})
        for n, pattern in enumerate(patterns(st)):
            for action in sorted(set(seq(st['Action'])) & MUTATIONS):
                pk = pattern.replace('*', st['Sid'] + str(n) + action.split(':')[1])
                seed(admin, table, pk)
                if action == 'dynamodb:BatchWriteItem':
                    require(not tx_only, 'invalid_transaction_batch_spec')
                    action_call(client, action, table, pk)()
                else:
                    client.transact_write_items(TransactItems=[tx_action(action, table, pk)])
                observed = admin.get_item(TableName=table, Key=key(pk), ConsistentRead=True).get('Item')
                require(observed is None if action == 'dynamodb:DeleteItem' else observed and observed.get('fixture') == {'BOOL': True}, 'positive_mutation_not_observed')
                record(st['Sid'] + ':' + str(n) + ':' + action.split(':')[1] + ':allowed')
                standalone = action_call(client, action, table, pk)
                if tx_only:
                    denied(standalone)
                    record(st['Sid'] + ':' + str(n) + ':' + action.split(':')[1] + ':standalone_denied')
                else:
                    standalone()
                    record(st['Sid'] + ':' + str(n) + ':' + action.split(':')[1] + ':legacy_standalone_allowed')
                foreign_pk = 'OTHER#mutation'
                if action != 'dynamodb:BatchWriteItem':
                    denied(lambda: client.transact_write_items(TransactItems=[tx_action(action, table, foreign_pk)]))
                denied(action_call(client, action, table, foreign_pk))
                record(st['Sid'] + ':' + str(n) + ':' + action.split(':')[1] + ':foreign_partition_denied')
    # One approved mutation paired with a failing NONE guard proves cancellation
    # is atomic and does not return an item. It is not a production-flow test.
    mutation = writes[0]
    table = table_for(mutation, names)
    pk = patterns(mutation)[0].replace('*', 'atomic')
    seed(admin, table, pk)
    before = admin.get_item(TableName=table, Key=key(pk), ConsistentRead=True)['Item']
    guard = next(s for s in checks if any(p == 'INVENTORY#dev' for p in patterns(s)))
    guard_table = table_for(guard, names)
    guard_pk = 'INVENTORY#dev'
    seed(admin, guard_table, guard_pk)
    canceled_without_item(lambda: client.transact_write_items(TransactItems=[tx_action('dynamodb:PutItem', table, pk), check_action(guard_table, guard_pk)]), 1)
    require(admin.get_item(TableName=table, Key=key(pk), ConsistentRead=True).get('Item') == before, 'canceled_transaction_mutated_fixture')
    record('inventory_guard_atomic_no_returned_item')


def qualify(session, policies, omitted, source_hash):
    import boto3
    from botocore.config import Config
    config = Config(retries={'total_max_attempts': 1}, connect_timeout=5, read_timeout=15)
    sts, iam, ddb = [session.client(service, region_name=REGION, config=config) for service in ('sts', 'iam', 'dynamodb')]
    run_id = uuid.uuid4().hex
    prefix = 'amt-campaign-qual-' + run_id
    suffixes = ('pipeline', 'intelligence', 'outbox', 'users', 'ledger')
    names = {k: prefix + '-' + suffix for k, suffix in zip(TABLES, suffixes)}
    tables, roles, clients = [], [], []
    report = {'schemaVersion': 1, 'accountId': ACCOUNT, 'region': REGION, 'runId': run_id, 'sourcePlanSha256': source_hash, 'harnessSha256': sha(Path(__file__).read_bytes()), 'cloudExecuted': True, 'scope': 'synthetic table IAM write/check qualification; not live worker or campaign cleanup acceptance', 'omittedStatements': omitted, 'unexercised': ['table/index read paths', 'stream permissions', 'SQS permissions', 'KMS permissions', 'application semantics'], 'cases': [], 'passed': False, 'cleanupComplete': False, 'policySha256': {k: sha(canonical(v).encode()) for k, v in policies.items()}}
    try:
        identity = sts.get_caller_identity()
        require(identity['Account'] == ACCOUNT, 'wrong_account')
        caller = identity['Arn']
        assumed = re.fullmatch(r'arn:aws:sts::' + ACCOUNT + r':assumed-role/([^/]+)/[^/]+', caller)
        if assumed:
            principal = iam.get_role(RoleName=assumed.group(1))['Role']['Arn']
        else:
            require(re.fullmatch(r'arn:aws:iam::' + ACCOUNT + r':user/.+', caller) is not None, 'unsupported_caller')
            principal = caller
        require(principal.startswith(f'arn:aws:iam::{ACCOUNT}:'), 'wrong_trust_account')
        for name in names.values():
            tables.append(name)  # Lost create responses still receive tag-checked cleanup.
            ddb.create_table(TableName=name, BillingMode='PAY_PER_REQUEST', AttributeDefinitions=[{'AttributeName': x, 'AttributeType': 'S'} for x in ('PK', 'SK')], KeySchema=[{'AttributeName': 'PK', 'KeyType': 'HASH'}, {'AttributeName': 'SK', 'KeyType': 'RANGE'}], StreamSpecification={'StreamEnabled': False}, Tags=[{'Key': 'Purpose', 'Value': 'synthetic-campaign-qualification'}, {'Key': 'QualificationRun', 'Value': run_id}])
            wait_table(ddb, name, True)
            require(ddb.describe_continuous_backups(TableName=name)['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['PointInTimeRecoveryStatus'] == 'DISABLED', 'unexpected_pitr')
        for kind in ROLES:
            role_name = prefix + '-' + kind
            roles.append(role_name)
            trust = {'Version': '2012-10-17', 'Statement': [{'Effect': 'Allow', 'Principal': {'AWS': principal}, 'Action': 'sts:AssumeRole'}]}
            created = iam.create_role(RoleName=role_name, AssumeRolePolicyDocument=canonical(trust), MaxSessionDuration=3600, Tags=[{'Key': 'QualificationRun', 'Value': run_id}])
            fixture = fixture_policy(policies[kind], names)
            iam.put_role_policy(RoleName=role_name, PolicyName='fixture', PolicyDocument=canonical(fixture))
            require(iam.get_role_policy(RoleName=role_name, PolicyName='fixture')['PolicyDocument'] == fixture, 'fixture_policy_readback_mismatch')
            credentials = None
            for attempt in range(12):
                try:
                    credentials = sts.assume_role(RoleArn=created['Role']['Arn'], RoleSessionName='synthetic-qualification', DurationSeconds=900)['Credentials']
                    break
                except Exception as exc:
                    require(error_code(exc) in ('AccessDenied', 'AccessDeniedException'), 'assume_role_failed')
                    time.sleep(3)
            require(credentials is not None, 'trust_propagation_timeout')
            client = boto3.client('dynamodb', region_name=REGION, aws_access_key_id=credentials['AccessKeyId'], aws_secret_access_key=credentials['SecretAccessKey'], aws_session_token=credentials['SessionToken'], config=config)
            clients.append(client)
            del credentials
            qualify_role(kind, client, ddb, policies[kind], names, report)
        report['passed'] = True
    except Exception as exc:
        report['failure'] = str(exc) if isinstance(exc, QualificationError) else 'qualification_operation_failed'
    finally:
        failures = []
        # Revoke fixture permissions before deleting synthetic data. Cleanup uses
        # unguessable names plus ownership tags; it cannot remove unrelated rows.
        for role in reversed(roles):
            try:
                tags = iam.list_role_tags(RoleName=role)['Tags']
                require({'Key': 'QualificationRun', 'Value': run_id} in tags, 'cleanup_role_ownership')
                try:
                    iam.delete_role_policy(RoleName=role, PolicyName='fixture')
                except Exception as exc:
                    require(error_code(exc) == 'NoSuchEntity', 'cleanup_policy_failed')
                iam.delete_role(RoleName=role)
            except Exception as exc:
                if error_code(exc) != 'NoSuchEntity':
                    failures.append({'kind': 'role', 'name': role})
        for table in reversed(tables):
            try:
                tags = ddb.list_tags_of_resource(ResourceArn=TABLE_ROOT + table)['Tags']
                require({'Key': 'QualificationRun', 'Value': run_id} in tags, 'cleanup_table_ownership')
                ddb.delete_table(TableName=table)
                wait_table(ddb, table, False)
            except Exception as exc:
                if error_code(exc) != 'ResourceNotFoundException':
                    failures.append({'kind': 'table', 'name': table})
        report['cleanupComplete'] = not failures
        report['cleanupOutstanding'] = failures
        for client in clients + [sts, iam, ddb]:
            client.close()
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', required=True)
    parser.add_argument('--profile', default='trustcheckradar')
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    try:
        policies, omitted, source_hash = load_policies(args.plan)
        if not args.execute:
            print(json.dumps({'policyValidationPassed': True, 'cloudExecuted': False, 'policyCount': len(policies), 'sourcePlanSha256': source_hash, 'harnessSha256': sha(Path(__file__).read_bytes()), 'omittedStatements': omitted}, sort_keys=True))
            return 0
        import boto3
        report = qualify(boto3.Session(profile_name=args.profile, region_name=REGION), policies, omitted, source_hash)
        print(json.dumps(report, sort_keys=True))
        return 0 if report['passed'] and report['cleanupComplete'] else 1
    except Exception as exc:
        print(json.dumps({'passed': False, 'failure': str(exc) if isinstance(exc, QualificationError) else 'qualification_setup_failed'}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
