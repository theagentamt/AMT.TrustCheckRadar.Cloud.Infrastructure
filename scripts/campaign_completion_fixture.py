#!/usr/bin/env python3
"""Provision or remove only tagged disposable SECUR4ALL-207 runtime fixtures."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import time
from datetime import datetime, timezone
ACCOUNT = '107827791950'
REGION = 'us-east-1'
PURPOSE = 'campaign-completion-qualification'
BASE_TABLES = ('pipeline', 'ledger', 'users')
COMPONENT_TABLES = ('devices', 'recovery', 'abuse', 'outbox', 'entitlements',
                    'history-control', 'history-content', 'authority', 'tokens')

def table_kinds(kind):
    if kind not in ('campaign', 'all-components'):
        raise ValueError('FIXTURE_KIND_REJECTED')
    return BASE_TABLES + (COMPONENT_TABLES if kind == 'all-components' else ())

def fixture_timeout(kind):
    table_kinds(kind)  # Validate before choosing the bounded runtime budget.
    return 120 if kind == 'all-components' else 60

def table_environment(tables):
    return {'QUALIFICATION_' + kind.upper().replace('-', '_') + '_TABLE': name
            for kind, name in tables.items()}


def identity(run):
    if not re.fullmatch('[0-9a-f]{12}', run):
        raise ValueError('INVALID_RUN')
    prefix = 'amt-campaign-completion-qual-' + run
    return (prefix, {'Purpose': PURPOSE, 'QualificationRunId': run, 'Environment': 'dev', 'Project': 'trustcheckradar'})

def validate_journal(doc, run):
    prefix, tags = identity(run)
    if not (doc['runId'] == run and doc['account'] == ACCOUNT and (doc['region'] == REGION)):
        raise ValueError('FIXTURE_BOUNDARY_REJECTED')
    if not (doc['prefix'] == prefix and doc['tags'] == tags):
        raise ValueError('FIXTURE_BOUNDARY_REJECTED')
    if not doc['tables'] == {x: prefix + '-' + x for x in table_kinds(doc.get('fixtureKind', 'campaign'))}:
        raise ValueError('FIXTURE_BOUNDARY_REJECTED')
    if not (doc['role'] == prefix + '-role' and doc['function'] == prefix + '-runner'):
        raise ValueError('FIXTURE_BOUNDARY_REJECTED')
    real = doc.get('realCognito', False)
    if type(real) is not bool or (real and doc.get('fixtureKind') != 'all-components'):
        raise ValueError('COGNITO_MODE_REJECTED')
    cognito_fields = {'cognitoPoolName', 'cognitoPoolId', 'cognitoSubject', 'cognitoPoolCreateAttempted', 'cognitoUserCreateAttempted', 'cognitoPoolRecoveredByExactTags'}
    if not real and cognito_fields.intersection(doc):
        raise ValueError('COGNITO_MODE_REJECTED')
    if real:
        if any(type(doc[field]) is not bool for field in ['cognitoPoolCreateAttempted', 'cognitoUserCreateAttempted', 'cognitoPoolRecoveredByExactTags'] if field in doc):
            raise ValueError('COGNITO_JOURNAL_FLAG_REJECTED')
        if doc.get('cognitoPoolName') != prefix + '-cognito':
            raise ValueError('COGNITO_POOL_BOUNDARY_REJECTED')
        if doc.get('cognitoPoolId') is not None:
            if doc.get('cognitoPoolCreateAttempted') is not True:
                raise ValueError('COGNITO_JOURNAL_FLAG_REJECTED')
            cognito_pool_arn(doc['cognitoPoolId'])
        subject = doc.get('cognitoSubject')
        if subject is not None and (doc.get('cognitoUserCreateAttempted') is not True or not doc.get('cognitoPoolId') or not re.fullmatch('[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', subject)):
            raise ValueError('COGNITO_SUBJECT_REJECTED')
    key = doc.get('keyArn')
    if not (key is None or re.fullmatch(f'arn:aws:kms:{REGION}:{ACCOUNT}:key/[0-9a-f-]{{36}}', key)):
        raise ValueError('FIXTURE_BOUNDARY_REJECTED')
    return doc

def runtime_policy(tables, key, pool_id=None):
    resources = [f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{name}' for name in tables.values()]
    index=f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{tables["ledger"]}/index/CampaignRecoveryDueIndex'
    policy = {'Version': '2012-10-17', 'Statement': [{'Effect': 'Allow', 'Action': ['dynamodb:DescribeTable', 'dynamodb:ListTagsOfResource', 'dynamodb:GetItem', 'dynamodb:Query', 'dynamodb:Scan', 'dynamodb:PutItem', 'dynamodb:UpdateItem', 'dynamodb:DeleteItem', 'dynamodb:ConditionCheckItem'], 'Resource': resources}, {'Effect':'Allow','Action':['dynamodb:Query'],'Resource':index}, {'Effect': 'Allow', 'Action': ['kms:DescribeKey', 'kms:ListResourceTags', 'kms:GenerateMac'], 'Resource': key}]}
    if pool_id is not None:
        policy['Statement'].append({'Effect': 'Allow', 'Action': ['cognito-idp:DescribeUserPool', 'cognito-idp:AdminGetUser', 'cognito-idp:AdminUserGlobalSignOut', 'cognito-idp:AdminDeleteUser'], 'Resource': cognito_pool_arn(pool_id)})
    return policy


def cognito_pool_arn(pool_id):
    if not isinstance(pool_id, str) or not re.fullmatch(REGION + r'_[A-Za-z0-9]{1,55}', pool_id):
        raise ValueError('COGNITO_POOL_ID_REJECTED')
    return f'arn:aws:cognito-idp:{REGION}:{ACCOUNT}:userpool/{pool_id}'


def cognito_pool_request(run):
    prefix, tags = identity(run)
    return {'PoolName': prefix + '-cognito', 'UserPoolTags': tags,
            'UsernameAttributes': ['email'], 'AutoVerifiedAttributes': [],
            'LambdaConfig': {}, 'MfaConfiguration': 'OFF', 'DeletionProtection': 'INACTIVE',
            'AdminCreateUserConfig': {'AllowAdminCreateUserOnly': True},
            'AccountRecoverySetting': {'RecoveryMechanisms': [{'Priority': 1, 'Name': 'admin_only'}]}}


def validate_cognito_pool(pool, doc):
    if (pool.get('Name') != doc['cognitoPoolName'] or
            pool.get('Arn') != cognito_pool_arn(pool.get('Id')) or
            (doc.get('cognitoPoolId') is not None and pool['Id'] != doc['cognitoPoolId']) or
            pool.get('UserPoolTags') != doc['tags'] or
            pool.get('UsernameAttributes') != ['email'] or pool.get('AliasAttributes') or
            pool.get('LambdaConfig') or pool.get('AutoVerifiedAttributes') or
            pool.get('MfaConfiguration') != 'OFF' or pool.get('DeletionProtection') != 'INACTIVE' or
            pool.get('AdminCreateUserConfig', {}).get('AllowAdminCreateUserOnly') is not True):
        raise ValueError('COGNITO_POOL_BOUNDARY_REJECTED')
    return pool['Id']


def cognito_user_request(doc):
    return {'UserPoolId': doc['cognitoPoolId'],
            'Username': 'fixture-' + doc['runId'] + '@example.invalid',
            'MessageAction': 'SUPPRESS', 'ForceAliasCreation': False,
            'UserAttributes': [{'Name': 'email', 'Value': 'fixture-' + doc['runId'] + '@example.invalid'}]}


def validate_cognito_user(user, doc):
    entries = user.get('Attributes', user.get('UserAttributes', []))
    attrs = {entry['Name']: entry['Value'] for entry in entries}
    subject = attrs.get('sub')
    if (len(attrs) != len(entries) or not isinstance(subject, str) or
            not re.fullmatch('[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', subject) or
            user.get('Username') != subject or
            attrs.get('email') != 'fixture-' + doc['runId'] + '@example.invalid' or
            (doc.get('cognitoSubject') is not None and doc['cognitoSubject'] != subject)):
        raise ValueError('COGNITO_SUBJECT_BOUNDARY_REJECTED')
    return subject


def discover_cognito_pool(client, doc, deadline):
    found = []; token = None
    for _ in range(10):
        if time.monotonic() >= deadline:
            raise TimeoutError('COGNITO_DISCOVERY_DEADLINE')
        response = client.list_user_pools(MaxResults=60, **({'NextToken': token} if token else {}))
        for entry in response['UserPools']:
            if entry.get('Name') != doc['cognitoPoolName']:
                continue
            if time.monotonic() >= deadline:
                raise TimeoutError('COGNITO_DISCOVERY_DEADLINE')
            pool = client.describe_user_pool(UserPoolId=entry['Id'])['UserPool']
            found.append(validate_cognito_pool(pool, doc))
        token = response.get('NextToken')
        if not token:
            break
    else:
        raise ValueError('COGNITO_DISCOVERY_INCOMPLETE')
    if len(found) != 1:
        raise ValueError('AMBIGUOUS_COGNITO_POOL_CREATION')
    return found[0]


def cleanup_cognito(client, doc, save, poll, deadline):
    if not doc.get('realCognito') or not doc.get('cognitoPoolCreateAttempted'):
        return {'requested': False}
    if not doc.get('cognitoPoolId'):
        doc['cognitoPoolId'] = discover_cognito_pool(client, doc, deadline)
        doc['cognitoPoolRecoveredByExactTags'] = True
        save()
    pool_id = doc['cognitoPoolId']
    def missing(exc):
        return getattr(exc, 'response', {}).get('Error', {}).get('Code') == 'ResourceNotFoundException'
    try:
        pool = client.describe_user_pool(UserPoolId=pool_id)['UserPool']
        validate_cognito_pool(pool, doc)
    except Exception as exc:
        if not missing(exc):
            raise
        return {'requested': True, 'poolAbsent': True, 'subjectAbsentWithPool': True}
    if doc.get('cognitoSubject'):
        try:
            user = client.admin_get_user(UserPoolId=pool_id, Username=doc['cognitoSubject'])
            validate_cognito_user(user, doc)
            client.admin_delete_user(UserPoolId=pool_id, Username=doc['cognitoSubject'])
        except Exception as exc:
            if getattr(exc, 'response', {}).get('Error', {}).get('Code') != 'UserNotFoundException':
                raise
    # Deleting the owned pool also removes a user whose create response was lost.
    client.delete_user_pool(UserPoolId=pool_id)
    def gone():
        try:
            client.describe_user_pool(UserPoolId=pool_id)
            return False
        except Exception as exc:
            if not missing(exc):
                raise
            return True
    poll(gone, bool)
    return {'requested': True, 'poolAbsent': True, 'subjectAbsentWithPool': True}


def table_request(name,kind,tags):
    request=dict(TableName=name,KeySchema=[{'AttributeName':'PK','KeyType':'HASH'},{'AttributeName':'SK','KeyType':'RANGE'}],AttributeDefinitions=[{'AttributeName':x,'AttributeType':'S'} for x in ['PK','SK']],BillingMode='PAY_PER_REQUEST',OnDemandThroughput={'MaxReadRequestUnits':25,'MaxWriteRequestUnits':25},Tags=[{'Key':k,'Value':v} for k,v in tags.items()])
    if kind=='ledger':
        request['AttributeDefinitions'] += [{'AttributeName':'campaignRecoveryPartition','AttributeType':'S'},{'AttributeName':'nextAttemptAtEpoch','AttributeType':'N'}]
        request['GlobalSecondaryIndexes']=[{'IndexName':'CampaignRecoveryDueIndex','KeySchema':[{'AttributeName':'campaignRecoveryPartition','KeyType':'HASH'},{'AttributeName':'nextAttemptAtEpoch','KeyType':'RANGE'}],'Projection':{'ProjectionType':'KEYS_ONLY'},'OnDemandThroughput':{'MaxReadRequestUnits':25,'MaxWriteRequestUnits':25}}]
    return request

def main():
    import boto3
    from botocore.config import Config
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['prepare', 'cleanup'])
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--journal', required=True)
    parser.add_argument('--zip')
    parser.add_argument('--zip-sha256')
    parser.add_argument('--source-sha')
    parser.add_argument('--profile', default='trustcheckradar')
    parser.add_argument('--fixture-kind', choices=['campaign', 'all-components'], default='campaign')
    parser.add_argument('--real-cognito', action='store_true', help='Separate identity integration fixture; requires all-components and its separately reviewed package.')
    args = parser.parse_args()
    if args.real_cognito and args.fixture_kind != 'all-components':
        raise ValueError('COGNITO_MODE_REJECTED')
    prefix, tags = identity(args.run_id)
    path = Path(args.journal)
    session = boto3.Session(profile_name=args.profile, region_name=REGION)
    cfg = Config(connect_timeout=5, read_timeout=15, retries={'total_max_attempts': 1})
    clients = {x: session.client(x, config=cfg) for x in ['sts', 'dynamodb', 'kms', 'iam', 'lambda', 'cognito-idp']}
    if not clients['sts'].get_caller_identity()['Account'] == ACCOUNT:
        raise ValueError('FIXTURE_BOUNDARY_REJECTED')
    ddb, kms, iam, lam = [clients[x] for x in ['dynamodb', 'kms', 'iam', 'lambda']]
    cognito = clients['cognito-idp']
    deadline = time.monotonic() + 600

    def save():
        path.write_text(json.dumps(doc, indent=2, sort_keys=True) + '\n')

    def poll(fn, predicate, interval=3):
        while time.monotonic() < deadline:
            value = fn()
            if predicate(value):
                return value
            time.sleep(interval)
        raise TimeoutError('FIXTURE_DEADLINE')

    def tagged(observed):
        if not all((observed.get(k) == v for k, v in tags.items())):
            raise ValueError('TAG_MISMATCH')

    def absent(exc):
        return getattr(exc, 'response', {}).get('Error', {}).get('Code') in ['ResourceNotFoundException', 'NoSuchEntityException', 'NoSuchEntity', 'NotFoundException']
    if args.operation == 'prepare':
        if not not path.exists():
            raise ValueError('JOURNAL_ALREADY_EXISTS')
        if not (args.zip and re.fullmatch('[0-9a-f]{64}', args.zip_sha256 or '') and re.fullmatch('[0-9a-f]{40}', args.source_sha or '')):
            raise ValueError('FIXTURE_BOUNDARY_REJECTED')
        archive = Path(args.zip).read_bytes()
        if not hashlib.sha256(archive).hexdigest() == args.zip_sha256:
            raise ValueError('FIXTURE_BOUNDARY_REJECTED')
        doc = {'schemaVersion': 1, 'runId': args.run_id, 'account': ACCOUNT, 'region': REGION, 'prefix': prefix, 'tags': tags, 'fixtureKind': args.fixture_kind, 'tables': {x: prefix + '-' + x for x in table_kinds(args.fixture_kind)}, 'role': prefix + '-role', 'function': prefix + '-runner', 'sourceSha': args.source_sha, 'zipSha256': args.zip_sha256, 'createdAtUtc': datetime.now(timezone.utc).isoformat(), 'created': []}
        if args.real_cognito:
            doc.update(realCognito=True, cognitoPoolName=prefix + '-cognito')
        save()
        for kind,name in doc['tables'].items():
            ddb.create_table(**table_request(name,kind,tags))
            doc['created'].append(name)
            save()
        if args.real_cognito:
            doc['cognitoPoolCreateAttempted'] = True
            save()
            pool = cognito.create_user_pool(**cognito_pool_request(args.run_id))['UserPool']
            # Save the returned ID before response validation so cleanup can inspect it.
            doc['cognitoPoolId'] = pool['Id']
            save()
            validate_cognito_pool(cognito.describe_user_pool(UserPoolId=pool['Id'])['UserPool'], doc)
            doc['cognitoUserCreateAttempted'] = True
            save()
            user = cognito.admin_create_user(**cognito_user_request(doc))['User']
            doc['cognitoSubject'] = validate_cognito_user(user, doc)
            save()
            validate_cognito_user(cognito.admin_get_user(UserPoolId=pool['Id'], Username=doc['cognitoSubject']), doc)
        doc['keyCreateAttempted'] = True
        save()
        key = kms.create_key(KeySpec='HMAC_256', KeyUsage='GENERATE_VERIFY_MAC', Description='Disposable campaign completion runtime qualification', Tags=[{'TagKey': k, 'TagValue': v} for k, v in tags.items()])['KeyMetadata']['Arn']
        doc['keyArn'] = key
        save()
        iam.create_role(RoleName=doc['role'], AssumeRolePolicyDocument=json.dumps({'Version': '2012-10-17', 'Statement': [{'Effect': 'Allow', 'Principal': {'Service': 'lambda.amazonaws.com'}, 'Action': 'sts:AssumeRole'}]}), Tags=[{'Key': k, 'Value': v} for k, v in tags.items()])
        doc['created'].append(doc['role'])
        save()
        policy = runtime_policy(doc['tables'], key, doc.get('cognitoPoolId'))
        iam.put_role_policy(RoleName=doc['role'], PolicyName='synthetic-fixtures-only', PolicyDocument=json.dumps(policy))
        doc['policySha256'] = hashlib.sha256(json.dumps(policy, sort_keys=True).encode()).hexdigest()
        save()
        for name in doc['tables'].values():
            poll(lambda n=name: ddb.describe_table(TableName=n), lambda x: x['Table']['TableStatus'] == 'ACTIVE' and all(i['IndexStatus']=='ACTIVE' for i in x['Table'].get('GlobalSecondaryIndexes',[])))
        env = {'QUALIFICATION_RUN_ID': args.run_id, 'QUALIFICATION_KEY_ARN': key, 'QUALIFICATION_FUNCTION_NAME': doc['function'], 'QUALIFICATION_SOURCE_SHA': args.source_sha}
        env.update(table_environment(doc['tables']))
        if args.real_cognito:
            env.update(QUALIFICATION_COGNITO_POOL_ID=doc['cognitoPoolId'], QUALIFICATION_COGNITO_SUBJECT=doc['cognitoSubject'])
        for attempt in range(20):
            try:
                lam.create_function(FunctionName=doc['function'], Runtime='python3.14', Architectures=['arm64'], Role=f"arn:aws:iam::{ACCOUNT}:role/{doc['role']}", Handler='cognito_qualification.lambda_handler' if args.real_cognito else 'campaign_qualification.lambda_handler', Code={'ZipFile': archive}, Timeout=fixture_timeout(args.fixture_kind), MemorySize=512, Environment={'Variables': env}, Tags=tags, Publish=False)
                break
            except Exception as exc:
                code = getattr(exc, 'response', {}).get('Error', {}).get('Code')
                if code != 'InvalidParameterValueException' or 'cannot be assumed' not in str(exc) or attempt == 19:
                    raise
                time.sleep(3)
        doc['created'].append(doc['function'])
        save()
        lam.put_function_concurrency(FunctionName=doc['function'], ReservedConcurrentExecutions=1)
        poll(lambda: lam.get_function_configuration(FunctionName=doc['function']), lambda x: x['State'] == 'Active' and x['LastUpdateStatus'] == 'Successful')
        doc['prepared'] = True
        save()
        print(json.dumps({'prepared': True, 'runId': args.run_id, 'function': doc['function']}))
        return
    doc = validate_journal(json.loads(path.read_text()), args.run_id)
    results = {}
    try:
        f = lam.get_function(FunctionName=doc['function'])
        tagged(f['Tags'])
        lam.delete_function(FunctionName=doc['function'])
        results['functionDeleted'] = True
    except Exception as exc:
        if not absent(exc):
            raise
        results['functionDeleted'] = True
    results['cognito'] = cleanup_cognito(cognito, doc, save, poll, deadline)
    for name in doc['tables'].values():
        try:
            arn = ddb.describe_table(TableName=name)['Table']['TableArn']
            t = ddb.list_tags_of_resource(ResourceArn=arn)
            if not not t.get('NextToken'):
                raise ValueError('FIXTURE_BOUNDARY_REJECTED')
            tagged({x['Key']: x['Value'] for x in t['Tags']})
            ddb.delete_table(TableName=name)
        except Exception as exc:
            if not absent(exc):
                raise
        results[name] = 'delete-requested-or-absent'
    try:
        r = iam.get_role(RoleName=doc['role'])['Role']
        tagged({x['Key']: x['Value'] for x in r['Tags']})
        policies = iam.list_role_policies(RoleName=doc['role'])
        if not (not policies.get('IsTruncated') and set(policies['PolicyNames']) <= {'synthetic-fixtures-only'}):
            raise ValueError('FIXTURE_BOUNDARY_REJECTED')
        attached = iam.list_attached_role_policies(RoleName=doc['role'])
        if not (not attached.get('IsTruncated') and (not attached['AttachedPolicies'])):
            raise ValueError('FIXTURE_BOUNDARY_REJECTED')
        for policy in policies['PolicyNames']:
            iam.delete_role_policy(RoleName=doc['role'], PolicyName=policy)
        iam.delete_role(RoleName=doc['role'])
        results['roleDeleted'] = True
    except Exception as exc:
        if not absent(exc):
            raise
        results['roleDeleted'] = True
    if doc.get('keyCreateAttempted') and (not doc.get('keyArn')):
        found = []
        marker = None
        for _ in range(10):
            response = kms.list_keys(Limit=100, **{'Marker': marker} if marker else {})
            for entry in response['Keys']:
                if time.monotonic() >= deadline:
                    raise TimeoutError('DISCOVERY_DEADLINE')
                tag_response = kms.list_resource_tags(KeyId=entry['KeyArn'])
                observed = {x['TagKey']: x['TagValue'] for x in tag_response['Tags']}
                if not tag_response.get('Truncated') and all((observed.get(k) == v for k, v in tags.items())):
                    found.append(entry['KeyArn'])
            if not response.get('Truncated'):
                break
            marker = response['NextMarker']
        else:
            raise ValueError('KEY_DISCOVERY_INCOMPLETE')
        if len(found) != 1:
            doc['cleanupIncompleteReason'] = 'AMBIGUOUS_KEY_CREATION'
            save()
            raise ValueError('AMBIGUOUS_KEY_CREATION')
        doc['keyArn'] = found[0]
        doc['keyRecoveredByExactTags'] = True
        save()
    if doc.get('keyArn'):
        t = kms.list_resource_tags(KeyId=doc['keyArn'])
        if not not t.get('Truncated'):
            raise ValueError('FIXTURE_BOUNDARY_REJECTED')
        tagged({x['TagKey']: x['TagValue'] for x in t['Tags']})
        key = kms.describe_key(KeyId=doc['keyArn'])['KeyMetadata']
        if key['KeyState'] != 'PendingDeletion':
            kms.schedule_key_deletion(KeyId=doc['keyArn'], PendingWindowInDays=7)
        key = kms.describe_key(KeyId=doc['keyArn'])['KeyMetadata']
        if not key['KeyState'] == 'PendingDeletion':
            raise ValueError('FIXTURE_BOUNDARY_REJECTED')
        results['keyState'] = 'PendingDeletion'
        results['keyDeletionDate'] = key['DeletionDate'].isoformat()
    for name in doc['tables'].values():

        def gone(n=name):
            try:
                ddb.describe_table(TableName=n)
                return False
            except Exception as exc:
                if not absent(exc):
                    raise
                return True
        poll(gone, bool)
        results[name] = 'absent'
    doc['cleanup'] = results
    doc['cleanupAtUtc'] = datetime.now(timezone.utc).isoformat()
    save()
    print(json.dumps({'fixturesRemoved': True, 'keyState': results.get('keyState'), 'keyDestroyed': False}))
if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(json.dumps({'operationComplete': False, 'reason': type(exc).__name__, 'cleanupRequired': 'Run cleanup with the same run-id and journal; inspect ambiguous creation before declaring resources removed.'}))
        raise SystemExit(1)
