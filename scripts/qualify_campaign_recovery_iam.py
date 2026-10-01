#!/usr/bin/env python3
"""Qualify the new recovery policy alone using a disposable ledger/GSI and role.

Offline validation is the default. Independently review before --execute. This
is not live-role union, producer-policy, application-flow or activation evidence.
No live table/index grant is ever attached to the disposable role.
"""
import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
import re
import time
import uuid
from pathlib import Path

ACCOUNT = '107827791950'
REGION = 'us-east-1'
TABLE_ROOT = f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/'
SOURCE_TABLE = TABLE_ROOT + 'trustcheckradar-dev-deletion-ledger'
INDEX = 'CampaignRecoveryDueIndex'
SOURCE_INDEX = SOURCE_TABLE + '/index/' + INDEX
ADDRESS = 'aws_iam_role_policy.recovery_runtime[0]'
SHARDS = [f'CAMPAIGN_RECOVERY#dev#{number:02d}' for number in range(16)]
INVENTORY_PK = 'INVENTORY#dev'
INVENTORY_SK = 'CAMPAIGN_RECOVERY_INVENTORY'
FIXTURE_PREFIX = 'amt-recovery-qual-'


class QualificationError(Exception):
    """Fixed content-free failure codes only."""


def require(condition, code):
    if not condition:
        raise QualificationError(code)


def seq(value):
    return value if isinstance(value, list) else [value]


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def expected():
    return {
        'DiscoverDueCampaignRecoveryKeys': ('dynamodb:Query', SOURCE_INDEX, {
            'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': SHARDS}}),
        'ReadCampaignRecoveryInventory': ('dynamodb:GetItem', SOURCE_TABLE, {
            'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': [INVENTORY_PK]}}),
        'CheckCampaignRecoveryInventory': ('dynamodb:ConditionCheckItem', SOURCE_TABLE, {
            'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': [INVENTORY_PK]},
            'StringEqualsIfExists': {'dynamodb:ReturnValues': ['NONE']}}),
        'AdvanceOwnedRecoveryRetryTransaction': ('dynamodb:UpdateItem', SOURCE_TABLE, {
            'ForAllValues:StringLike': {'dynamodb:LeadingKeys': ['ACCOUNT#*']},
            'ForAnyValue:StringEquals': {'dynamodb:EnclosingOperation': ['TransactWriteItems']}}),
    }


def worker_specs():
    guard = {'ForAllValues:StringLike': {'dynamodb:LeadingKeys': ['ACCOUNT#*']}}
    return {
        'CompleteDeletionLedgerCommand': ('dynamodb:GetItem', SOURCE_TABLE, guard),
        'GuardedDeletionCommand': ('dynamodb:ConditionCheckItem', SOURCE_TABLE,
            {**guard, 'StringEqualsIfExists': {'dynamodb:ReturnValues': ['NONE']}}),
    }


def combine_worker_policy(policy, audit_path):
    """Validate every current identity policy before isolating its ledger union.

    Other exact tables, streams, KMS and logging are intentionally not exercised.
    This is not a claim about SCPs or live table resource policies.
    """
    import importlib.util
    spec = importlib.util.spec_from_file_location('campaign_writer_validation',
        Path(__file__).with_name('qualify_campaign_writer_iam.py'))
    writer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(writer)
    raw = Path(audit_path).read_bytes()
    audit = json.loads(raw)
    name = 'trustcheckradar-dev-campaign-deletion-bridge-role'
    role = audit['roles'][name]
    require(role['arn'] == f'arn:aws:iam::{ACCOUNT}:role/{name}', 'worker_role_identity')
    require(not role['managed'] and role['permissionsBoundary'] is None, 'worker_extra_policy_source')
    require(set(role['inline']) == {'content-free-logging', 'deletion-runtime'}, 'worker_inline_sources')
    logging = role['inline']['content-free-logging']
    require(logging.get('Version') == '2012-10-17' and len(logging.get('Statement', [])) == 2, 'worker_logging_schema')
    for st in logging['Statement']:
        require(st.get('Effect') == 'Allow' and set(seq(st.get('Action'))) <=
            {'logs:PutLogEvents', 'logs:CreateLogStream', 'cloudwatch:PutMetricData'} and
            'NotAction' not in st and 'NotResource' not in st, 'worker_logging_overlap')
    validated, omitted = writer.validate_policy(role['inline']['deletion-runtime'], 'deletion')
    additions = [st for st in validated['Statement'] if SOURCE_TABLE in seq(st['Resource'])]
    require({st['Sid'] for st in additions} == set(worker_specs()), 'worker_ledger_overlap')
    combined = copy.deepcopy(policy)
    combined['Statement'].extend(additions)
    validate_policy(combined, worker_union=True)
    return combined, sha(raw)


def conditions(value):
    require(isinstance(value, dict), 'condition_schema')
    result = {}
    for operator, fields in value.items():
        require(isinstance(fields, dict), 'condition_schema')
        result[operator] = {}
        for name, values in fields.items():
            values = seq(values)
            require(all(isinstance(x, str) for x in values) and len(values) == len(set(values)), 'condition_values')
            result[operator][name] = sorted(values)
    return result


def validate_policy(policy, worker_union=False):
    require(isinstance(policy, dict) and set(policy) == {'Version', 'Statement'}, 'policy_schema')
    require(policy['Version'] == '2012-10-17' and isinstance(policy['Statement'], list), 'policy_schema')
    specs, seen = expected(), set()
    if worker_union:
        specs.update(worker_specs())
    require(len(policy['Statement']) == len(specs), 'statement_count')
    for st in policy['Statement']:
        require(isinstance(st, dict) and set(st) == {'Sid', 'Effect', 'Action', 'Resource', 'Condition'}, 'statement_fields')
        sid = st['Sid']
        require(isinstance(sid, str) and sid in specs and sid not in seen, 'unexpected_or_duplicate_sid')
        seen.add(sid)
        action, resource, condition = specs[sid]
        require(st['Effect'] == 'Allow', 'statement_effect')
        require(seq(st['Action']) == [action], 'unexpected_action')
        require(seq(st['Resource']) == [resource], 'unexpected_resource')
        require(conditions(st['Condition']) == conditions(condition), 'unexpected_condition')
    require(seen == set(specs), 'missing_statement')
    return copy.deepcopy(policy)


def load_policy(path):
    raw = Path(path).read_bytes()
    plan = json.loads(raw)
    matches = [r for r in plan.get('resource_changes', []) if r.get('address') == ADDRESS]
    require(len(matches) == 1, 'policy_address_missing_or_ambiguous')
    resource = matches[0]
    require(resource.get('mode') == 'managed' and resource.get('type') == 'aws_iam_role_policy', 'policy_resource_type')
    change = resource['change']
    require(change.get('after_unknown', {}).get('policy') is not True, 'policy_unknown')
    return validate_policy(json.loads(change['after']['policy'])), sha(raw)


def fixture_policy(policy, table_name, worker_union=False):
    require(re.fullmatch(FIXTURE_PREFIX + r'[a-f0-9]{32}-ledger', table_name) is not None, 'fixture_table_name')
    result = validate_policy(policy, worker_union)
    replacements = {SOURCE_TABLE: TABLE_ROOT + table_name, SOURCE_INDEX: TABLE_ROOT + table_name + '/index/' + INDEX}
    for st in result['Statement']:
        original = st['Resource']
        st['Resource'] = [replacements[r] for r in original] if isinstance(original, list) else replacements[original]
    require('trustcheckradar-dev-' not in canonical(result), 'live_resource_leak')
    return result


def error_code(exc):
    return getattr(exc, 'response', {}).get('Error', {}).get('Code', '')


def denied(call):
    try:
        call()
    except Exception as exc:
        require(error_code(exc) in ('AccessDenied', 'AccessDeniedException'), 'unexpected_denial_type')
        return
    raise QualificationError('expected_access_denied')


def canceled(call):
    try:
        call()
    except Exception as exc:
        require(error_code(exc) == 'TransactionCanceledException', 'unexpected_cancellation_type')
        reasons = getattr(exc, 'response', {}).get('CancellationReasons', [])
        require(len(reasons) == 2 and reasons[1].get('Code') == 'ConditionalCheckFailed', 'missing_inventory_cancellation')
        require(all('Item' not in reason for reason in reasons), 'cancellation_returned_item')
        return
    raise QualificationError('inventory_guard_did_not_cancel')


def key(pk, sk='FIXTURE'):
    return {'PK': {'S': pk}, 'SK': {'S': sk}}


def query_args(table_name, shard):
    return {'TableName': table_name, 'IndexName': INDEX, 'Select': 'COUNT',
            'KeyConditionExpression': 'campaignRecoveryPartition = :shard AND nextAttemptAtEpoch <= :due',
            'ExpressionAttributeValues': {':shard': {'S': shard}, ':due': {'N': '100'}}}


def update_args(table_name, pk='ACCOUNT#retry'):
    return {'TableName': table_name, 'Key': key(pk), 'UpdateExpression': 'SET fixture = :yes',
            'ExpressionAttributeValues': {':yes': {'BOOL': True}}}


def check_args(table_name, pk=INVENTORY_PK, return_values='NONE', fail=False):
    return {'TableName': table_name, 'Key': key(pk, INVENTORY_SK),
            'ConditionExpression': 'attribute_not_exists(PK)' if fail else 'attribute_exists(PK)',
            'ReturnValuesOnConditionCheckFailure': return_values}


def wait_table(client, table_name, present):
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        try:
            table = client.describe_table(TableName=table_name)['Table']
            if present and table['TableStatus'] == 'ACTIVE' and any(i['IndexName'] == INDEX and i['IndexStatus'] == 'ACTIVE' for i in table.get('GlobalSecondaryIndexes', [])):
                return
        except Exception as exc:
            if error_code(exc) == 'ResourceNotFoundException' and not present:
                return
            require(error_code(exc) == 'ResourceNotFoundException', 'table_wait_failed')
        time.sleep(2)
    raise QualificationError('table_wait_timeout')


def exercise(client, admin, table_name, report, worker_union=False):
    # Sixteen independent synthetic rows, one per permitted padded partition.
    for n, shard in enumerate(SHARDS):
        admin.put_item(TableName=table_name, Item={**key('ACCOUNT#shard-' + str(n)),
            'campaignRecoveryPartition': {'S': shard}, 'nextAttemptAtEpoch': {'N': '100'}})
    admin.put_item(TableName=table_name, Item={**key(INVENTORY_PK, INVENTORY_SK), 'fixture': {'BOOL': True}})
    admin.put_item(TableName=table_name, Item={**key('ACCOUNT#retry'), 'seed': {'BOOL': True}})
    # Only this initial read retries permission propagation. Other AWS errors
    # never count as denials or as successful permission checks.
    report['phase'] = 'initial_permission_propagation'
    for attempt in range(12):
        try:
            result = client.get_item(TableName=table_name, Key=key(INVENTORY_PK, INVENTORY_SK), ConsistentRead=True)
            require(result.get('Item', {}).get('fixture') == {'BOOL': True}, 'inventory_read_not_observed')
            break
        except Exception as exc:
            require(error_code(exc) in ('AccessDenied', 'AccessDeniedException'), 'initial_inventory_read_failed')
            require(attempt < 11, 'permission_propagation_timeout')
            time.sleep(3)
    report['cases'].append('exact_inventory_get_allowed')
    for n, shard in enumerate(SHARDS):
        report['phase'] = 'query_shard_' + f'{n:02d}'
        # GSI propagation is eventual. Retry empty authorized reads only.
        for attempt in range(15):
            result = client.query(**query_args(table_name, shard))
            if result.get('Count') == 1:
                break
            require(result.get('Count') == 0 and attempt < 14, 'gsi_fixture_not_visible')
            time.sleep(2)
        report['cases'].append('query_shard_' + f'{n:02d}' + '_allowed')
    for label, shard in [('foreign_shard', 'CAMPAIGN_RECOVERY#dev#16'), ('unpadded_shard', 'CAMPAIGN_RECOVERY#dev#0'), ('foreign_environment', 'CAMPAIGN_RECOVERY#prod#00'), ('foreign_namespace', 'OTHER#00')]:
        report['phase'] = label
        denied(lambda: client.query(**query_args(table_name, shard)))
        report['cases'].append(label + '_query_denied')
    report['phase'] = 'base_query_and_scans'
    denied(lambda: client.query(TableName=table_name, KeyConditionExpression='PK = :pk', ExpressionAttributeValues={':pk': {'S': 'ACCOUNT#retry'}}))
    report['cases'].append('base_table_query_denied')
    for label, args in [('base', {'TableName': table_name}), ('index', {'TableName': table_name, 'IndexName': INDEX})]:
        denied(lambda: client.scan(**args))
        report['cases'].append(label + '_scan_denied')
    if worker_union:
        result = client.get_item(TableName=table_name, Key=key('ACCOUNT#retry'), ConsistentRead=True)
        require(result.get('Item', {}).get('seed') == {'BOOL': True}, 'worker_account_get_failed')
        report['cases'].append('worker_account_get_allowed')
    for label, pk in ([('foreign_namespace', 'OTHER#retry')] if worker_union else [('account', 'ACCOUNT#retry')]) + [('foreign_inventory', 'INVENTORY#prod')]:
        report['phase'] = label + '_get'
        denied(lambda: client.get_item(TableName=table_name, Key=key(pk, INVENTORY_SK)))
        report['cases'].append(label + '_get_denied')
    report['phase'] = 'inventory_checks'
    client.transact_write_items(TransactItems=[{'ConditionCheck': check_args(table_name)}])
    report['cases'].append('exact_inventory_condition_none_allowed')
    if worker_union:
        args = check_args(table_name, 'ACCOUNT#retry'); args['Key'] = key('ACCOUNT#retry')
        client.transact_write_items(TransactItems=[{'ConditionCheck': args}])
        report['cases'].append('worker_account_condition_allowed')
        args['ConditionExpression'] = 'attribute_not_exists(PK)'
        args['ReturnValuesOnConditionCheckFailure'] = 'ALL_OLD'
        denied(lambda: client.transact_write_items(TransactItems=[{'ConditionCheck': args}]))
        report['cases'].append('worker_account_condition_all_old_denied')
    for label, pk, rv in [('foreign_inventory', 'INVENTORY#prod', 'NONE'), ('foreign_namespace', 'OTHER#retry', 'NONE') if worker_union else ('account', 'ACCOUNT#retry', 'NONE'), ('failure_return_values', INVENTORY_PK, 'ALL_OLD')]:
        denied(lambda: client.transact_write_items(TransactItems=[{'ConditionCheck': check_args(table_name, pk, rv, fail=True)}]))
        report['cases'].append(label + '_condition_denied')
    report['phase'] = 'transaction_update'
    client.transact_write_items(TransactItems=[{'Update': update_args(table_name)}, {'ConditionCheck': check_args(table_name)}])
    require(admin.get_item(TableName=table_name, Key=key('ACCOUNT#retry'), ConsistentRead=True).get('Item', {}).get('fixture') == {'BOOL': True}, 'transaction_update_not_observed')
    report['cases'].append('account_update_with_inventory_transaction_allowed')
    denied(lambda: client.update_item(**update_args(table_name)))
    report['cases'].append('standalone_account_update_denied')
    for pk in ('OTHER#retry', INVENTORY_PK):
        denied(lambda: client.transact_write_items(TransactItems=[{'Update': update_args(table_name, pk)}]))
    report['cases'].append('foreign_partition_transaction_update_denied')
    for label, operation, standalone in [
        ('put', {'Put': {'TableName': table_name, 'Item': key('ACCOUNT#forbidden')}}, lambda: client.put_item(TableName=table_name, Item=key('ACCOUNT#forbidden'))),
        ('delete', {'Delete': {'TableName': table_name, 'Key': key('ACCOUNT#retry')}}, lambda: client.delete_item(TableName=table_name, Key=key('ACCOUNT#retry'))),
    ]:
        denied(standalone)
        denied(lambda: client.transact_write_items(TransactItems=[operation]))
        report['cases'].append('standalone_and_transaction_' + label + '_denied')
    report['phase'] = 'atomic_inventory_guard'
    admin.put_item(TableName=table_name, Item={**key('ACCOUNT#retry'), 'seed': {'BOOL': True}})
    before = admin.get_item(TableName=table_name, Key=key('ACCOUNT#retry'), ConsistentRead=True)['Item']
    canceled(lambda: client.transact_write_items(TransactItems=[{'Update': update_args(table_name)}, {'ConditionCheck': check_args(table_name, fail=True)}]))
    require(admin.get_item(TableName=table_name, Key=key('ACCOUNT#retry'), ConsistentRead=True).get('Item') == before, 'canceled_transaction_changed_fixture')
    report['cases'].append('inventory_guard_atomic_without_returned_item')
    report['phase'] = 'completed'


def qualify(session, policy, plan_hash, worker_union=False, audit_hash=None):
    import boto3
    from botocore.config import Config
    config = Config(retries={'total_max_attempts': 1}, connect_timeout=5, read_timeout=15)
    sts, iam, ddb = [session.client(service, region_name=REGION, config=config) for service in ('sts', 'iam', 'dynamodb')]
    run_id = uuid.uuid4().hex
    table_name, role_name = FIXTURE_PREFIX + run_id + '-ledger', FIXTURE_PREFIX + run_id + '-role'
    table_started = role_started = False
    client = None
    report = {'schemaVersion': 1, 'observedAtUtc': datetime.now(timezone.utc).isoformat(),
        'accountId': ACCOUNT, 'region': REGION, 'runId': run_id,
        'sourcePlanSha256': plan_hash, 'sourcePolicySha256': sha(canonical(policy).encode()),
        'harnessSha256': sha(Path(__file__).read_bytes()), 'cloudExecuted': True,
        'scope': ('selected recovery + observed worker ledger identity-policy union' if worker_union else 'new recovery policy alone') + ' against disposable synthetic ledger/GSI and assumed fixture role',
        'workerLedgerUnionSelected': worker_union, 'sourceRoleAuditSha256': audit_hash,
        'limitations': ['Does not qualify live SCPs, table resource policies, other tables/services or deployment; observed identity-policy union is qualified only when explicitly selected.', 'Does not qualify producer policies, workload behavior, completion, retention or activation.'],
        'cases': [], 'passed': False, 'cleanupComplete': False, 'phase': 'caller_validation'}
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
        fixture = fixture_policy(policy, table_name, worker_union)
        report['fixturePolicySha256'] = sha(canonical(fixture).encode())
        report['phase'] = 'create_fixture_table'
        table_started = True  # Lost create responses receive ownership-checked cleanup.
        ddb.create_table(TableName=table_name, BillingMode='PAY_PER_REQUEST',
            AttributeDefinitions=[{'AttributeName': name, 'AttributeType': typ} for name, typ in [('PK', 'S'), ('SK', 'S'), ('campaignRecoveryPartition', 'S'), ('nextAttemptAtEpoch', 'N')]],
            KeySchema=[{'AttributeName': 'PK', 'KeyType': 'HASH'}, {'AttributeName': 'SK', 'KeyType': 'RANGE'}],
            GlobalSecondaryIndexes=[{'IndexName': INDEX, 'KeySchema': [{'AttributeName': 'campaignRecoveryPartition', 'KeyType': 'HASH'}, {'AttributeName': 'nextAttemptAtEpoch', 'KeyType': 'RANGE'}], 'Projection': {'ProjectionType': 'KEYS_ONLY'}}],
            StreamSpecification={'StreamEnabled': False}, Tags=[{'Key': 'Purpose', 'Value': 'synthetic-campaign-recovery-qualification'}, {'Key': 'QualificationRun', 'Value': run_id}])
        wait_table(ddb, table_name, True)
        require(ddb.describe_continuous_backups(TableName=table_name)['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['PointInTimeRecoveryStatus'] == 'DISABLED', 'unexpected_pitr')
        report['phase'] = 'create_fixture_role'
        role_started = True
        trust = {'Version': '2012-10-17', 'Statement': [{'Effect': 'Allow', 'Principal': {'AWS': principal}, 'Action': 'sts:AssumeRole'}]}
        created = iam.create_role(RoleName=role_name, AssumeRolePolicyDocument=canonical(trust), MaxSessionDuration=3600, Tags=[{'Key': 'QualificationRun', 'Value': run_id}])
        iam.put_role_policy(RoleName=role_name, PolicyName='fixture', PolicyDocument=canonical(fixture))
        require(iam.get_role_policy(RoleName=role_name, PolicyName='fixture')['PolicyDocument'] == fixture, 'fixture_policy_readback_mismatch')
        credentials = None
        for attempt in range(12):
            try:
                credentials = sts.assume_role(RoleArn=created['Role']['Arn'], RoleSessionName='synthetic-recovery-qualification', DurationSeconds=900)['Credentials']
                break
            except Exception as exc:
                require(error_code(exc) in ('AccessDenied', 'AccessDeniedException'), 'assume_role_failed')
                time.sleep(3)
        require(credentials is not None, 'trust_propagation_timeout')
        client = boto3.client('dynamodb', region_name=REGION, aws_access_key_id=credentials['AccessKeyId'], aws_secret_access_key=credentials['SecretAccessKey'], aws_session_token=credentials['SessionToken'], config=config)
        del credentials
        exercise(client, ddb, table_name, report, worker_union)
        report['passed'] = True
    except Exception as exc:
        report['failure'] = str(exc) if isinstance(exc, QualificationError) else 'qualification_operation_failed'
    finally:
        failures = []
        if role_started:
            try:
                require({'Key': 'QualificationRun', 'Value': run_id} in iam.list_role_tags(RoleName=role_name)['Tags'], 'cleanup_role_ownership')
                try:
                    iam.delete_role_policy(RoleName=role_name, PolicyName='fixture')
                except Exception as exc:
                    require(error_code(exc) == 'NoSuchEntity', 'cleanup_policy_failed')
                iam.delete_role(RoleName=role_name)
            except Exception as exc:
                if error_code(exc) != 'NoSuchEntity':
                    failures.append({'kind': 'role', 'name': role_name})
        if table_started:
            try:
                require({'Key': 'QualificationRun', 'Value': run_id} in ddb.list_tags_of_resource(ResourceArn=TABLE_ROOT + table_name)['Tags'], 'cleanup_table_ownership')
                ddb.delete_table(TableName=table_name)
                wait_table(ddb, table_name, False)
            except Exception as exc:
                if error_code(exc) != 'ResourceNotFoundException':
                    failures.append({'kind': 'table', 'name': table_name})
        report['cleanupComplete'] = not failures
        report['cleanupOutstanding'] = failures
        for connection in [client, sts, iam, ddb]:
            if connection is not None:
                connection.close()
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', required=True)
    parser.add_argument('--profile', default='trustcheckradar')
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--role-audit', help='Select the strictly verified observed worker ledger policy union')
    args = parser.parse_args()
    try:
        policy, plan_hash = load_policy(args.plan)
        audit_hash = None
        if args.role_audit:
            policy, audit_hash = combine_worker_policy(policy, args.role_audit)
        if not args.execute:
            print(json.dumps({'policyValidationPassed': True, 'cloudExecuted': False, 'statementCount': len(policy['Statement']), 'workerLedgerUnionSelected': bool(args.role_audit), 'sourceRoleAuditSha256': audit_hash,
                'sourcePlanSha256': plan_hash, 'sourcePolicySha256': sha(canonical(policy).encode()),
                'harnessSha256': sha(Path(__file__).read_bytes())}, sort_keys=True))
            return 0
        import boto3
        report = qualify(boto3.Session(profile_name=args.profile, region_name=REGION), policy, plan_hash, bool(args.role_audit), audit_hash)
        print(json.dumps(report, sort_keys=True))
        return 0 if report['passed'] and report['cleanupComplete'] else 1
    except Exception as exc:
        print(json.dumps({'passed': False, 'failure': str(exc) if isinstance(exc, QualificationError) else 'qualification_setup_failed'}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
