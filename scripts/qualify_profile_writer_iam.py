#!/usr/bin/env python3
"""Synthetic final-profile-policy qualification. Offline validation by default.

No application rows are read or written. Root must review before --execute.
Requires operator IAM create/delete/assume-role and DynamoDB create/delete rights.
"""
import argparse
import copy
import json
import re
import time
import uuid
from pathlib import Path

ACCOUNT = '107827791950'
REGION = 'us-east-1'
TABLE_PREFIX = f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/'
SOURCE_USERS = TABLE_PREFIX + 'trustcheckradar-dev-users'
SOURCE_LEDGER = TABLE_PREFIX + 'trustcheckradar-dev-deletion-ledger'
POLICIES = {
    'post_confirmation': ('aws_iam_policy.post_confirmation_dynamodb', 'dynamodb:PutItem'),
    'age_attestation': ('aws_iam_policy.age_attestation_dynamodb', 'dynamodb:UpdateItem'),
}


class QualificationError(Exception):
    pass


def require(condition, reason):
    if not condition:
        raise QualificationError(reason)


def seq(value):
    return value if isinstance(value, list) else [value]


def load_policy(path, name):
    plan = json.loads(Path(path).read_text())
    address, write = POLICIES[name]
    matches = [r for r in plan.get('resource_changes', []) if r.get('address') == address]
    require(len(matches) == 1, 'policy_address_missing_or_ambiguous')
    change = matches[0]['change']
    require(change.get('after_unknown', {}).get('policy') is not True, 'policy_unknown')
    policy = json.loads(change['after']['policy'])
    require(set(policy) == {'Version', 'Statement'} and policy['Version'] == '2012-10-17', 'policy_schema')
    statements = policy['Statement']
    require(isinstance(statements, list) and len(statements) == 2, 'policy_statement_count')
    seen = set()
    for st in statements:
        require(set(st) <= {'Sid', 'Effect', 'Action', 'Resource', 'Condition'}, 'policy_extra_fields')
        require(st.get('Effect') == 'Allow', 'policy_not_allow')
        resources = seq(st.get('Resource'))
        actions = seq(st.get('Action'))
        conditions = st.get('Condition', {})
        if resources == [SOURCE_USERS]:
            require(actions == [write], 'policy_not_final_users_actions')
            require(conditions.get('ForAllValues:StringLike', {}).get('dynamodb:LeadingKeys') in ('USER#*', ['USER#*']), 'users_partition_guard')
            require(conditions.get('ForAnyValue:StringEquals', {}).get('dynamodb:EnclosingOperation') in ('TransactWriteItems', ['TransactWriteItems']), 'users_transaction_guard')
            seen.add('users')
        elif resources == [SOURCE_LEDGER]:
            require(actions == ['dynamodb:ConditionCheckItem'], 'ledger_actions')
            require(not any('dynamodb:EnclosingOperation' in v for v in conditions.values()), 'ledger_unsupported_context')
            require(conditions.get('ForAllValues:StringLike', {}).get('dynamodb:LeadingKeys') in ('ACCOUNT#*', ['ACCOUNT#*']), 'ledger_partition_guard')
            require(conditions.get('StringEqualsIfExists', {}).get('dynamodb:ReturnValues') in ('NONE', ['NONE']), 'ledger_return_values_guard')
            seen.add('ledger')
        else:
            raise QualificationError('unexpected_resource')
    require(seen == {'users', 'ledger'}, 'policy_family_missing')
    return policy


def fixture_policy(policy, users, ledger):
    result = copy.deepcopy(policy)
    replacements = {SOURCE_USERS: TABLE_PREFIX + users, SOURCE_LEDGER: TABLE_PREFIX + ledger}
    for st in result['Statement']:
        original = st['Resource']
        st['Resource'] = [replacements[x] for x in original] if isinstance(original, list) else replacements[original]
    return result


def key(pk):
    return {'PK': {'S': pk}, 'SK': {'S': 'PROFILE'}}


def ledger_key(pk):
    return {'PK': {'S': pk}, 'SK': {'S': 'ACCOUNT_DELETION'}}


def error_code(exc):
    return getattr(exc, 'response', {}).get('Error', {}).get('Code', '')


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
            if error_code(exc) != 'ResourceNotFoundException':
                raise QualificationError('table_wait_failed') from None
        time.sleep(2)
    raise QualificationError('table_wait_timeout')


def write_action(kind, users, pk):
    if kind == 'post_confirmation':
        return {'Put': {'TableName': users, 'Item': {**key(pk), 'fixture': {'BOOL': True}}, 'ConditionExpression': 'attribute_not_exists(PK)'}}
    return {'Update': {'TableName': users, 'Key': key(pk), 'UpdateExpression': 'SET fixture = :v', 'ExpressionAttributeValues': {':v': {'BOOL': True}}, 'ConditionExpression': 'attribute_exists(PK)'}}


def transaction(kind, users, ledger, pk, ledger_pk, return_values=None):
    check = {'TableName': ledger, 'Key': ledger_key(ledger_pk), 'ConditionExpression': 'attribute_not_exists(PK)'}
    if return_values is not None:
        check['ReturnValuesOnConditionCheckFailure'] = return_values
    return [write_action(kind, users, pk), {'ConditionCheck': check}]


def denied(call):
    try:
        call()
    except Exception as exc:
        require(error_code(exc) in ('AccessDeniedException', 'AccessDenied'), 'unexpected_denial_type')
        return
    raise QualificationError('expected_access_denied')


def qualify(session, policies):
    import boto3
    from botocore.config import Config
    config = Config(retries={'total_max_attempts': 1}, connect_timeout=5, read_timeout=15)
    sts = session.client('sts', region_name=REGION, config=config)
    iam = session.client('iam', region_name=REGION, config=config)
    ddb = session.client('dynamodb', region_name=REGION, config=config)
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
    run_id = uuid.uuid4().hex
    prefix = 'amt-profile-qual-' + run_id
    users, ledger = prefix + '-users', prefix + '-ledger'
    tables, roles, clients = [], [], []
    report = {'schemaVersion': 1, 'accountId': ACCOUNT, 'region': REGION, 'runId': run_id, 'scope': 'ephemeral synthetic tables and roles only', 'cases': [], 'passed': False, 'cleanupComplete': False}
    try:
        for name in (users, ledger):
            # Track before creation so a lost response still receives cleanup.
            tables.append(name)
            ddb.create_table(TableName=name, BillingMode='PAY_PER_REQUEST', AttributeDefinitions=[{'AttributeName': x, 'AttributeType': 'S'} for x in ('PK', 'SK')], KeySchema=[{'AttributeName': 'PK', 'KeyType': 'HASH'}, {'AttributeName': 'SK', 'KeyType': 'RANGE'}], StreamSpecification={'StreamEnabled': False}, Tags=[{'Key': 'Purpose', 'Value': 'synthetic-profile-qualification'}, {'Key': 'QualificationRun', 'Value': run_id}])
            wait_table(ddb, name, True)
            require(ddb.describe_continuous_backups(TableName=name)['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['PointInTimeRecoveryStatus'] == 'DISABLED', 'unexpected_pitr')
        for kind, policy in policies.items():
            role_name = prefix + ('-post' if kind == 'post_confirmation' else '-age')
            roles.append(role_name)
            trust = {'Version': '2012-10-17', 'Statement': [{'Effect': 'Allow', 'Principal': {'AWS': principal}, 'Action': 'sts:AssumeRole'}]}
            created = iam.create_role(RoleName=role_name, AssumeRolePolicyDocument=json.dumps(trust), MaxSessionDuration=3600, Tags=[{'Key': 'QualificationRun', 'Value': run_id}])
            iam.put_role_policy(RoleName=role_name, PolicyName='fixture', PolicyDocument=json.dumps(fixture_policy(policy, users, ledger)))
            credentials = None
            for attempt in range(12):
                try:
                    credentials = sts.assume_role(RoleArn=created['Role']['Arn'], RoleSessionName='synthetic-qualification', DurationSeconds=900)['Credentials']
                    break
                except Exception as exc:
                    if error_code(exc) not in ('AccessDenied', 'AccessDeniedException'):
                        raise QualificationError('assume_role_failed') from None
                    time.sleep(3)
            require(credentials is not None, 'trust_propagation_timeout')
            client = boto3.client('dynamodb', region_name=REGION, aws_access_key_id=credentials['AccessKeyId'], aws_secret_access_key=credentials['SecretAccessKey'], aws_session_token=credentials['SessionToken'], config=config)
            clients.append(client)
            del credentials
            pk = 'USER#' + kind
            if kind == 'age_attestation':
                ddb.put_item(TableName=users, Item=key(pk))
            # Retry only permission propagation; condition failures are not success.
            for attempt in range(12):
                try:
                    client.transact_write_items(TransactItems=transaction(kind, users, ledger, pk, 'ACCOUNT#absent', 'NONE'), ClientRequestToken=uuid.uuid5(uuid.UUID(run_id), kind).hex)
                    break
                except Exception as exc:
                    if error_code(exc) not in ('AccessDenied', 'AccessDeniedException'):
                        raise QualificationError('positive_transaction_failed') from None
                    if attempt == 11:
                        raise QualificationError('policy_propagation_timeout') from None
                    time.sleep(3)
            observed = ddb.get_item(TableName=users, Key=key(pk), ConsistentRead=True).get('Item', {})
            require(observed.get('fixture') == {'BOOL': True}, 'positive_write_not_observed')
            report['cases'].append(kind + ':transaction_absence_none_allowed')
            op = write_action(kind, users, pk)
            action, arguments = next(iter(op.items()))
            arguments.pop('ConditionExpression', None)
            denied(lambda: getattr(client, 'put_item' if action == 'Put' else 'update_item')(**arguments))
            report['cases'].append(kind + ':standalone_write_denied')
            for case, target_pk, target_ledger, rv in [
                ('unrelated_users_partition', 'OTHER#fixture', 'ACCOUNT#absent', 'NONE'),
                ('unrelated_ledger_partition', 'USER#other', 'OTHER#fixture', 'NONE'),
                ('failure_return_values', 'USER#other', 'ACCOUNT#blocked', 'ALL_OLD'),
            ]:
                ddb.put_item(TableName=ledger, Item=ledger_key('ACCOUNT#blocked'))
                if kind == 'age_attestation':
                    ddb.put_item(TableName=users, Item=key(target_pk))
                denied(lambda: client.transact_write_items(TransactItems=transaction(kind, users, ledger, target_pk, target_ledger, rv)))
                report['cases'].append(kind + ':' + case + '_denied')
            denied(lambda: client.put_item(TableName=ledger, Item=ledger_key('ACCOUNT#unauthorized')))
            report['cases'].append(kind + ':ledger_write_denied')
            if kind == 'age_attestation':
                ddb.put_item(TableName=users, Item=key('USER#tombstone'))
            before = ddb.get_item(TableName=users, Key=key('USER#tombstone'), ConsistentRead=True).get('Item')
            try:
                client.transact_write_items(TransactItems=transaction(kind, users, ledger, 'USER#tombstone', 'ACCOUNT#blocked', 'NONE'))
                raise QualificationError('tombstone_did_not_block')
            except Exception as exc:
                require(error_code(exc) == 'TransactionCanceledException', 'tombstone_wrong_failure')
                reasons = getattr(exc, 'response', {}).get('CancellationReasons', [])
                require(len(reasons) == 2 and reasons[1].get('Code') == 'ConditionalCheckFailed', 'tombstone_reason_missing')
                require(all('Item' not in reason for reason in reasons), 'failure_returned_item')
            require(ddb.get_item(TableName=users, Key=key('USER#tombstone'), ConsistentRead=True).get('Item') == before, 'blocked_write_mutated_row')
            report['cases'].append(kind + ':tombstone_blocks_without_returned_item')
        report['passed'] = True
    except Exception as exc:
        report['failure'] = str(exc) if isinstance(exc, QualificationError) else 'qualification_operation_failed'
    finally:
        failures = []
        # Remove permission before deleting fixtures; held credentials then lose access.
        for role in reversed(roles):
            try:
                try:
                    iam.delete_role_policy(RoleName=role, PolicyName='fixture')
                except Exception as exc:
                    if error_code(exc) != 'NoSuchEntity':
                        raise
                iam.delete_role(RoleName=role)
            except Exception as exc:
                if error_code(exc) != 'NoSuchEntity':
                    failures.append({'kind': 'role', 'name': role})
        for table in reversed(tables):
            try:
                try:
                    ddb.delete_table(TableName=table)
                except Exception as exc:
                    if error_code(exc) != 'ResourceNotFoundException':
                        raise
                wait_table(ddb, table, False)
            except Exception:
                failures.append({'kind': 'table', 'name': table})
        report['cleanupComplete'] = not failures
        report['cleanupOutstanding'] = failures
        for client in clients + [sts, iam, ddb]:
            client.close()
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api-plan', required=True)
    parser.add_argument('--identity-plan', required=True)
    parser.add_argument('--profile', default='trustcheckradar')
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    try:
        policies = {name: load_policy(args.identity_plan if name == 'post_confirmation' else args.api_plan, name) for name in POLICIES}
        if not args.execute:
            print(json.dumps({'policyValidationPassed': True, 'cloudExecuted': False, 'policyCount': 2}))
            return 0
        import boto3
        report = qualify(boto3.Session(profile_name=args.profile, region_name=REGION), policies)
        print(json.dumps(report, sort_keys=True))
        return 0 if report['passed'] and report['cleanupComplete'] else 1
    except Exception as exc:
        print(json.dumps({'passed': False, 'failure': str(exc) if isinstance(exc, QualificationError) else 'qualification_setup_failed'}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
