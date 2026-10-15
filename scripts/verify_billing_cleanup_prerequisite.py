#!/usr/bin/env python3
"""Read-only metadata gate for scoped Dev billing token-deletion coverage."""
import argparse
import json
import re
from pathlib import Path

from verify_message_consumer_transition import aws

ACCOUNT = '107827791950'
REGION = 'us-east-1'
PREFIX = 'trustcheckradar-dev'
FUNCTION = PREFIX + '-play-token-deletion'
ALIAS = f'arn:aws:lambda:{REGION}:{ACCOUNT}:function:{FUNCTION}:live'
GROUP = PREFIX + '-play-lifecycle'
SUBJECT = re.compile(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}')
ERROR = 'Billing cleanup prerequisite rejected; private configuration was not printed.'


def require(condition):
    if not condition:
        raise ValueError(ERROR)


def selected_subjects(plan):
    """Extract the already reviewed billing plan selection, without fallback accounts."""
    variables = {key: entry.get('value') for key, entry in plan['variables'].items()}
    require(variables.get('environment') == 'dev' and
            variables.get('aws_region') == REGION and
            variables.get('project_name') == 'trustcheckradar' and
            variables.get('enabled') is True)
    require('billing_activation' in variables)
    activation = variables['billing_activation']
    if activation is None:
        return []
    require(activation.get('mode') in {'preparation', 'verification', 'ingress', 'background'})
    subjects = activation.get('subjects')
    validate_subjects(subjects, 1)
    return subjects


def validate_subjects(subjects, maximum):
    require(type(subjects) is list and 0 < len(subjects) <= maximum)
    require(all(isinstance(value, str) and SUBJECT.fullmatch(value) for value in subjects))
    require(len(set(subjects)) == len(subjects))


def reviewed_hash():
    path = Path(__file__).resolve().parents[1] / 'docs/evidence/sec332-deletion-packages.json'
    return json.loads(path.read_text())['artifacts']['play_token_deletion']['sha256Base64']


def verify_metadata(subjects, metadata, expected_hash):
    """Validate captured metadata only; never claim that erasure actually ran."""
    validate_subjects(subjects, 1)
    require(metadata['identity'].get('Account') == ACCOUNT)
    function, alias = metadata['function'], metadata['alias']
    require(function.get('FunctionName') == FUNCTION and
            function.get('Role') == f'arn:aws:iam::{ACCOUNT}:role/{FUNCTION}-execution' and
            function.get('Runtime') == 'python3.14' and
            function.get('Handler') == 'app.lambda_handler' and
            function.get('Architectures') == ['arm64'] and
            function.get('Timeout') == 60 and function.get('MemorySize') == 256 and
            function.get('CodeSha256') == expected_hash and
            function.get('State') == 'Active' and function.get('LastUpdateStatus') == 'Successful')
    version = function.get('Version')
    require(isinstance(version, str) and re.fullmatch(r'[1-9][0-9]*', version))
    require(alias.get('Name') == 'live' and alias.get('AliasArn') == ALIAS and
            alias.get('FunctionVersion') == version and
            not alias.get('RoutingConfig', {}).get('AdditionalVersionWeights'))
    require(metadata['concurrency'].get('ReservedConcurrentExecutions') == 1)
    env = function.get('Environment', {}).get('Variables', {})
    expected = {
        'STAGE': 'dev', 'PLAY_TOKEN_CLEANUP_ENABLED': 'true',
        'PLAY_LIFECYCLE_ENABLED': 'false', 'PLAY_CHECKPOINT_POLICY_APPROVED': 'false',
        'PLAY_PREPARATION_ENABLED': 'false', 'AUTHORITY_ENABLED': 'false',
        'PLAY_TOKEN_TABLE_NAME': PREFIX + '-play-tokens',
        'AUTHORITY_TABLE_NAME': PREFIX + '-purchase-entitlements',
        'PURCHASE_OWNERSHIP_TABLE_NAME': PREFIX + '-purchase-entitlements',
        'USERS_TABLE_NAME': PREFIX + '-users', 'DEVICE_BINDINGS_TABLE_NAME': PREFIX + '-device-bindings',
        'DELETION_LEDGER_TABLE_NAME': PREFIX + '-deletion-ledger',
        'AUTHORITY_POLICY_VERSION': 'owner-2026-09-20-v1',
        'DELETION_RECEIPT_RETENTION_SECONDS': '10368000',
    }
    require(all(env.get(key) == value for key, value in expected.items()))
    require(all(env.get(key, 'false') == 'false' for key in
                ('PLAY_HANDOFF_ENABLED', 'PLAY_SCOPED_OWNED_HEAD_ONLY_ENABLED', 'PLAY_SCOPED_LIFECYCLE_WORKER_ENABLED')))
    require('GOOGLE_PLAY_SERVICE_ACCOUNT_SECRET_ARN' not in env and 'PLAY_TOKEN_KMS_KEY_ARN' not in env)
    admitted = json.loads(env.get('DEV_SUBJECT_ALLOWLIST_JSON', 'null'))
    validate_subjects(admitted, 10)
    require(set(subjects) <= set(admitted))
    stream = env.get('DELETION_LEDGER_STREAM_ARN', '')
    require(isinstance(stream, str) and re.fullmatch(
        rf'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{PREFIX}-deletion-ledger/stream/[0-9T:.\-]+', stream))
    schedule = metadata['schedule']
    require(schedule.get('Name') == FUNCTION and schedule.get('GroupName') == GROUP and
            schedule.get('State') == 'ENABLED' and schedule.get('ScheduleExpression') == 'rate(1 minute)' and
            schedule.get('FlexibleTimeWindow', {}).get('Mode') == 'OFF')
    target = schedule.get('Target', {})
    require(target.get('Arn') == ALIAS and
            target.get('RoleArn') == f'arn:aws:iam::{ACCOUNT}:role/{FUNCTION}-schedule' and
            target.get('RetryPolicy') == {'MaximumEventAgeInSeconds': 60, 'MaximumRetryAttempts': 0})
    require(json.loads(target.get('Input', 'null')) == {'schemaVersion': 1, 'operation': 'reconcile-play-token-deletion'})
    mappings = metadata['mappings'].get('EventSourceMappings', [])
    require(len(mappings) == 1)
    mapping = mappings[0]
    require(mapping.get('FunctionArn') == ALIAS and mapping.get('EventSourceArn') == stream and
            mapping.get('State') == 'Enabled' and mapping.get('BatchSize') == 5 and
            mapping.get('MaximumRetryAttempts') == 2 and mapping.get('MaximumRecordAgeInSeconds') == 600 and
            mapping.get('BisectBatchOnFunctionError') is True and
            mapping.get('FunctionResponseTypes') == ['ReportBatchItemFailures'])
    filters = mapping.get('FilterCriteria', {}).get('Filters', [])
    require(len(filters) == 1 and json.loads(filters[0].get('Pattern', 'null')) == {
        'eventName': ['INSERT', 'MODIFY'], 'dynamodb': {'Keys': {'SK': {'S': ['ACCOUNT_DELETION']}}}})
    return {'billingCleanupConfigurationVerified': True, 'billingSubjectCount': len(subjects),
            'cleanupSubjectCount': len(admitted), 'behavioralQualification': False}


def verify(subjects, read=aws):
    """Use only AWS control-plane reads; no records, credentials or invocation."""
    validate_subjects(subjects, 1)
    identity = read('sts', 'get-caller-identity')
    require(identity.get('Account') == ACCOUNT)
    metadata = {
        'identity': identity,
        'function': read('lambda', 'get-function-configuration', '--function-name', FUNCTION, '--qualifier', 'live'),
        'alias': read('lambda', 'get-alias', '--function-name', FUNCTION, '--name', 'live'),
        'concurrency': read('lambda', 'get-function-concurrency', '--function-name', FUNCTION),
        'schedule': read('scheduler', 'get-schedule', '--name', FUNCTION, '--group-name', GROUP),
        'mappings': read('lambda', 'list-event-source-mappings', '--function-name', ALIAS),
    }
    return verify_metadata(subjects, metadata, reviewed_hash())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path, required=True)
    args = parser.parse_args()
    try:
        subjects = selected_subjects(json.loads(args.plan.read_text()))
        result = verify(subjects) if subjects else {
            'billingCleanupConfigurationVerified': False, 'billingSubjectCount': 0,
            'behavioralQualification': False, 'inactiveBilling': True}
        print(json.dumps(result))
    except Exception:
        raise SystemExit(ERROR) from None


if __name__ == '__main__':
    main()
