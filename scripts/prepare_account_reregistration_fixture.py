#!/usr/bin/env python3
"""Prepare stage two of an owned disposable-pool re-registration qualification.

Never invokes the test, retries identity creation, or changes application resources.
Cleanup uses campaign_completion_fixture.py with the original fixture journal.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import time

import campaign_completion_fixture as fixture


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def expected_environment(doc):
    env = {
        'QUALIFICATION_RUN_ID': doc['runId'],
        'QUALIFICATION_KEY_ARN': doc['keyArn'],
        'QUALIFICATION_FUNCTION_NAME': doc['function'],
        'QUALIFICATION_SOURCE_SHA': doc['sourceSha'],
        'QUALIFICATION_COGNITO_POOL_ID': doc['cognitoPoolId'],
        'QUALIFICATION_COGNITO_SUBJECT': doc['cognitoSubject'],
    }
    return env | fixture.table_environment(doc['tables'])


def validate_function(response, doc):
    c = response['Configuration']
    require(response.get('Tags') == doc['tags'], 'FUNCTION_TAGS_CHANGED')
    require(c.get('FunctionName') == doc['function'] and
            c.get('FunctionArn') == f"arn:aws:lambda:{fixture.REGION}:{fixture.ACCOUNT}:function:{doc['function']}" and
            c.get('Role') == f"arn:aws:iam::{fixture.ACCOUNT}:role/{doc['role']}" and
            c.get('Handler') == 'cognito_qualification.lambda_handler' and
            c.get('Runtime') == 'python3.14' and c.get('Architectures') == ['arm64'] and
            c.get('State') == 'Active' and c.get('LastUpdateStatus') == 'Successful' and
            c.get('Version') == '$LATEST', 'FUNCTION_BOUNDARY_CHANGED')
    require(c.get('CodeSha256') == base64.b64encode(bytes.fromhex(doc['zipSha256'])).decode(),
            'FUNCTION_CODE_CHANGED')
    require(c.get('Environment', {}).get('Variables') == expected_environment(doc),
            'FUNCTION_ENVIRONMENT_CHANGED')
    require(isinstance(c.get('RevisionId'), str) and bool(c['RevisionId']), 'REVISION_MISSING')
    return c


def require_old_identity_absent(cognito, doc):
    try:
        cognito.admin_get_user(UserPoolId=doc['cognitoPoolId'], Username=doc['cognitoSubject'])
    except Exception as exc:
        if getattr(exc, 'response', {}).get('Error', {}).get('Code') == 'UserNotFoundException':
            return
        raise
    raise ValueError('ORIGINAL_IDENTITY_STILL_PRESENT')


def prepare(doc, clients, save, *, now=time.monotonic, sleep=time.sleep):
    fixture.validate_journal(doc, doc['runId'])
    require(doc.get('realCognito') is True and doc.get('prepared') is True,
            'PREPARED_COGNITO_FIXTURE_REQUIRED')
    require(re.fullmatch('[0-9a-f]{40}', doc.get('sourceSha', '')) is not None and
            re.fullmatch('[0-9a-f]{64}', doc.get('zipSha256', '')) is not None,
            'SOURCE_BINDING_REQUIRED')
    require(clients['sts'].get_caller_identity()['Account'] == fixture.ACCOUNT, 'WRONG_ACCOUNT')
    cognito, lam, ddb = (clients[x] for x in ('cognito-idp', 'lambda', 'dynamodb'))
    fixture.validate_cognito_pool(cognito.describe_user_pool(UserPoolId=doc['cognitoPoolId'])['UserPool'], doc)
    config = validate_function(lam.get_function(FunctionName=doc['function']), doc)
    require(lam.get_function_concurrency(FunctionName=doc['function']).get('ReservedConcurrentExecutions') == 1,
            'CONCURRENCY_CHANGED')
    require_old_identity_absent(cognito, doc)
    key = {'PK': {'S': 'ACCOUNT#' + doc['cognitoSubject']}, 'SK': {'S': 'ACCOUNT_DELETION'}}
    command = ddb.get_item(TableName=doc['tables']['ledger'], Key=key, ConsistentRead=True).get('Item', {})
    require(command.get('status') == {'S': 'COMPLETE'} and
            command.get('accountId') == {'S': doc['cognitoSubject']}, 'ORIGINAL_COMPLETION_REQUIRED')
    # Full original-operation and twelve-receipt validation belongs to the runner.
    state = {'schemaVersion': 1, 'runId': doc['runId'], 'sourceSha': doc['sourceSha'],
             'zipSha256': doc['zipSha256'], 'previousSubject': doc['cognitoSubject'],
             'poolId': doc['cognitoPoolId'], 'function': doc['function'],
             'originalRevision': config['RevisionId'], 'createAttempted': True,
             'prepared': False}
    save(state)  # Durable intent precedes the single create request.
    user = cognito.admin_create_user(**fixture.cognito_user_request(doc))['User']
    candidate = {k: v for k, v in doc.items() if k != 'cognitoSubject'}
    new_subject = fixture.validate_cognito_user(user, candidate)
    require(new_subject != doc['cognitoSubject'], 'IDENTITY_REUSED')
    state['newSubject'] = new_subject
    save(state)
    candidate['cognitoSubject'] = new_subject
    fixture.validate_cognito_user(cognito.admin_get_user(UserPoolId=doc['cognitoPoolId'], Username=new_subject), candidate)
    require_old_identity_absent(cognito, doc)
    current = validate_function(lam.get_function(FunctionName=doc['function']), doc)
    require(current['RevisionId'] == config['RevisionId'], 'REVISION_CHANGED')
    env = expected_environment(doc) | {'QUALIFICATION_COGNITO_SUBJECT': new_subject,
                                     'QUALIFICATION_PREVIOUS_COGNITO_SUBJECT': doc['cognitoSubject']}
    state['configurationAttempted'] = True
    save(state)
    lam.update_function_configuration(FunctionName=doc['function'], RevisionId=config['RevisionId'],
                                      Environment={'Variables': env})
    deadline = now() + 120
    while now() < deadline:
        observed = lam.get_function(FunctionName=doc['function'])
        c = observed['Configuration']
        if c.get('LastUpdateStatus') == 'Failed':
            raise ValueError('CONFIGURATION_FAILED')
        if c.get('LastUpdateStatus') == 'Successful':
            require(c.get('Environment', {}).get('Variables') == env, 'CONFIGURATION_READBACK_MISMATCH')
            # Reuse the original boundary checks after accounting for precisely
            # the two reviewed environment changes. All other fields must match.
            original_view = observed | {'Configuration': c | {'Environment': {'Variables': expected_environment(doc)}}}
            validate_function(original_view, doc)
            state.update(prepared=True, revisionId=c['RevisionId'])
            save(state)
            return {'prepared': True, 'sameEmailRecreated': True, 'distinctSubject': True,
                    'sourceSha': doc['sourceSha'], 'runId': doc['runId'],
                    'fixtureOnly': True, 'testInvoked': False}
        sleep(2)
    raise TimeoutError('CONFIGURATION_READBACK_DEADLINE')


def main():
    import boto3
    from botocore.config import Config
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixture-journal', required=True)
    p.add_argument('--stage-journal', required=True)
    p.add_argument('--profile', default='trustcheckradar')
    args = p.parse_args()
    doc = json.loads(Path(args.fixture_journal).read_text())
    fixture.validate_journal(doc, doc['runId'])
    # Exclusive creation prevents retrying an ambiguous identity mutation.
    fd = os.open(args.stage_journal, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as stream:
        def save(state):
            stream.seek(0)
            json.dump(state, stream, sort_keys=True, indent=2)
            stream.write('\n'); stream.truncate(); stream.flush(); os.fsync(stream.fileno())
        save({'prepared': False, 'runId': doc['runId'], 'createAttempted': False})
        session = boto3.Session(profile_name=args.profile, region_name=fixture.REGION)
        cfg = Config(connect_timeout=5, read_timeout=15, retries={'total_max_attempts': 1})
        clients = {name: session.client(name, config=cfg) for name in ('sts', 'cognito-idp', 'lambda', 'dynamodb')}
        try:
            print(json.dumps(prepare(doc, clients, save)))
        finally:
            for client in clients.values():
                client.close()


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(json.dumps({'prepared': False, 'category': type(exc).__name__,
                          'instruction': 'Do not retry creation. Inspect the stage journal; cleanup uses the original owned-pool fixture journal.'}))
        raise SystemExit(1)
