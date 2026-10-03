#!/usr/bin/env python3
"""Reject unreviewed changes in a scoped Dev governed-History plan; never apply."""
import argparse
import base64
import hashlib
import json
import re
from pathlib import Path

ACCOUNT = '107827791950'
PREFIX = 'trustcheckradar-dev'
AUTHORITY = f'arn:aws:dynamodb:us-east-1:{ACCOUNT}:table/{PREFIX}-purchase-entitlements'
HISTORY_ROUTES = {'GET /v1/users/analysis-history', 'GET /v1/users/analysis-history/{resultId}'}
PROJECTION = {'recordType', 'state', 'governedHistory', 'expiresAt'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def flag(variables, name):
    value = variables.get(name, False)
    require(type(value) is bool, f'{name} must be a typed Terraform boolean.')
    return value


def changed_fields(before, after):
    return {key for key in set(before) | set(after) if before.get(key) != after.get(key)}


def _index(plan, variables, mode):
    require(mode in {'inactive', 'active'}, 'Unknown index mode.')
    active = mode == 'active'
    require(flag(variables, 'governed_history_index_enabled') is active, 'Index selection mismatch.')
    for item in plan:
        require(item['address'] == 'aws_dynamodb_table.purchase_entitlements', 'Only the authority table index can change.')
        change = item['change']
        require(change['actions'] in (['update'], ['no-op']), 'Authority table replacement/deletion is forbidden.')
        before, after = change['before'], change['after']
        require(after.get('name') == f'{PREFIX}-purchase-entitlements' and after.get('arn') == AUTHORITY, 'Wrong authority table.')
        require(after.get('billing_mode') == 'PAY_PER_REQUEST' and after.get('ttl') == [{'enabled': True, 'attribute_name': 'expiresAt'}] and len(after.get('point_in_time_recovery') or []) == 1 and after['point_in_time_recovery'][0].get('enabled') is True, 'Authority TTL and backup posture must remain enabled.')
        require(changed_fields(before, after) <= {'attribute', 'global_secondary_index'}, 'Index change cannot alter retention, backups or other table settings.')
        old = {v['name']: v for v in before.get('global_secondary_index', [])}
        new = {v['name']: v for v in after.get('global_secondary_index', [])}
        require({k: v for k, v in old.items() if k != 'GSI2'} == {k: v for k, v in new.items() if k != 'GSI2'}, 'Existing indexes must remain unchanged.')
        require(set(new) == set(old) | {'GSI2'} if active else set(new) == set(old) - {'GSI2'}, 'Unexpected index set.')
        attrs_before = {v['name']: v for v in before.get('attribute', [])}
        attrs_after = {v['name']: v for v in after.get('attribute', [])}
        require({k: v for k, v in attrs_before.items() if k not in {'GSI2PK', 'GSI2SK'}} == {k: v for k, v in attrs_after.items() if k not in {'GSI2PK', 'GSI2SK'}}, 'Existing key attributes must remain unchanged.')
        if active:
            index = new['GSI2']
            require(index.get('hash_key') == 'GSI2PK' and index.get('range_key') == 'GSI2SK' and index.get('projection_type') == 'INCLUDE' and set(index.get('non_key_attributes') or []) == PROJECTION, 'History projection exceeds its content-free contract.')
            require(all(attrs_after.get(k) == {'name': k, 'type': 'S'} for k in ('GSI2PK', 'GSI2SK')), 'History keys must be strings.')
        else:
            require(not {'GSI2PK', 'GSI2SK'} & set(attrs_after), 'Inactive index cannot retain its indexed attributes.')


def _reader(changes, variables, mode, configuration):
    require(mode in {'inactive', 'list', 'detail', 'both'}, 'Unknown reader mode.')
    listed, detailed = mode in {'list', 'both'}, mode in {'detail', 'both'}
    require(flag(variables, 'enabled'), 'Reader must be pinned and provisioned.')
    require(flag(variables, 'list_enabled') is listed and flag(variables, 'detail_enabled') is detailed, 'Independent reader gate mismatch.')
    partitions = variables.get('authority_partitions', [])
    require(type(partitions) is list and len(partitions) <= 4 and len(set(partitions)) == len(partitions) and all(isinstance(v, str) and re.fullmatch(r'V1#[A-Za-z0-9]{1,8}#[a-f0-9]{64}', v) for v in partitions), 'Private exact account HMAC partitions required.')
    require(bool(partitions) if listed or detailed else not partitions, 'Inactive reader cannot retain scoped account access.')
    subjects = variables.get('engineering_subjects')
    require(isinstance(subjects, list), 'Subject list is required.')
    require((len(subjects) == 1 and re.fullmatch(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', subjects[0]) and flag(variables, 'index_ready')) if listed or detailed else not subjects, 'Active reader requires one exact subject and a qualified index; inactive mode requires no subjects.')
    dep = variables.get('deployment') or {}
    artifact = (dep.get('artifacts') or {}).get('reader') or {}
    require(set(dep.get('artifacts') or {}) == {'reader'}, 'Exactly one reader artifact is required.')
    require(artifact.get('bucket') == f'{PREFIX}-{ACCOUNT}-artifacts' and re.fullmatch(r'releases/[0-9a-f]{40}/governed_history\.zip', artifact.get('key', '')) and isinstance(artifact.get('object_version'), str) and artifact['object_version'] not in {'', 'null'}, 'Immutable artifact coordinates required.')
    try:
        require(len(base64.b64decode(artifact.get('source_hash'), validate=True)) == 32, 'Invalid artifact hash.')
    except (TypeError, ValueError):
        raise ValueError('Invalid artifact hash.') from None
    for field, suffix in {'users_table_arn': 'users', 'devices_table_arn': 'device-bindings', 'deletion_table_arn': 'deletion-ledger', 'authority_table_arn': 'purchase-entitlements'}.items():
        require(dep.get(field) == f'arn:aws:dynamodb:us-east-1:{ACCOUNT}:table/{PREFIX}-{suffix}', 'Wrong reader dependency.')
    require(re.fullmatch(rf'arn:aws:secretsmanager:us-east-1:{ACCOUNT}:secret:trustcheckradar/dev/v1-authority-hmac-[A-Za-z0-9]{{6}}', dep.get('authority_hmac_secret_arn', '')), 'Wrong HMAC secret reference.')
    require(dep.get('cognito_issuer') == 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ' and dep.get('cognito_app_client_id') == '5kvl9a8jo4fr1qqnci27tdabk4', 'Wrong Cognito authority.')
    require(variables.get('api_gateway') == {'api_id': 'icuak34th9', 'execution_arn': f'arn:aws:execute-api:us-east-1:{ACCOUNT}:icuak34th9', 'authorizer_id': 'itms4b'}, 'Wrong API/JWT authorizer.')
    allowed = {'aws_cloudwatch_log_group.runtime["reader"]', 'aws_iam_role.runtime["reader"]', 'aws_iam_role_policy.reader[0]', 'aws_lambda_function.runtime["reader"]', 'aws_lambda_alias.runtime["reader"]', 'aws_lambda_function_event_invoke_config.no_async_retries["reader"]', 'aws_apigatewayv2_integration.history[0]'} | {f'{kind}.history["{name}"]' for kind in ('aws_apigatewayv2_route', 'aws_lambda_permission') for name in ('list', 'detail')}
    require({v['address'] for v in changes} == allowed, 'Complete reader post-plan inventory is required.')
    inventory = {v['address']: v['change']['after'] for v in changes}
    require({inventory[f'aws_apigatewayv2_route.history["{name}"]'].get('route_key') for name in ('list', 'detail')} == HISTORY_ROUTES, 'Both distinct governed History routes are required.')
    for item in changes:
        address, change = item['address'], item['change']
        require(address in allowed and change['actions'] in (['create'], ['update'], ['no-op']), 'Unexpected reader resource or destructive change.')
        value = change['after']
        config_address = re.sub(r'\[.*$', '', address)
        expressions = configuration.get(config_address, {}).get('expressions', {})
        def bound(field, expected, reference):
            actual = value.get(field)
            if actual is not None and expected is not None:
                require(actual == expected, f'{address} {field} binding mismatch.')
            else:
                refs = expressions.get(field, {}).get('references') or []
                require(change.get('after_unknown', {}).get(field) is True and any(v == reference or v.startswith(reference + '.') or v.startswith(reference + '[') for v in refs), f'{address} {field} must bind the reviewed resource.')
        if address.startswith('aws_lambda_function.'):
            expected = {'function_name': f'{PREFIX}-governed-history', 'handler': 'governed_history.app.lambda_handler', 'runtime': 'python3.14', 'architectures': ['arm64'], 'timeout': 23, 'memory_size': 256, 'reserved_concurrent_executions': 2, 'publish': True, 's3_bucket': artifact['bucket'], 's3_key': artifact['key'], 's3_object_version': artifact['object_version'], 'source_code_hash': artifact['source_hash']}
            require(all(value.get(k) == v for k, v in expected.items()), 'Reader runtime exceeds pinned limits.')
            bound('role', f'arn:aws:iam::{ACCOUNT}:role/{PREFIX}-governed-history-execution', 'aws_iam_role.runtime')
            env = value.get('environment', [{}])[0].get('variables') or {}
            expected_env = reader_environment(variables)
            require(env == expected_env, 'Reader environment must match the exact independent contract.')
            require(not any(value.get(k) for k in ('layers', 'vpc_config', 'dead_letter_config', 'file_system_config', 'image_uri')), 'Unexpected reader runtime attachment.')
        elif address.startswith('aws_iam_role_policy.'):
            bound('role', inventory['aws_iam_role.runtime["reader"]'].get('id'), 'aws_iam_role.runtime')
            require(value.get('name') == 'fenced-governed-history-read-only', 'Unexpected reader inline policy name.')
            require(json.loads(value.get('policy', '{}')) == reader_policy(dep, subjects, partitions), 'Reader IAM policy differs from the least-privilege contract.')
        elif address.startswith('aws_iam_role.'):
            require(value.get('name') == f'{PREFIX}-governed-history-execution' and json.loads(value.get('assume_role_policy', '{}')) == {'Version': '2012-10-17', 'Statement': [{'Effect': 'Allow', 'Action': 'sts:AssumeRole', 'Principal': {'Service': 'lambda.amazonaws.com'}}]}, 'Reader role trust mismatch.')
        elif address.startswith('aws_apigatewayv2_route.'):
            integration = inventory['aws_apigatewayv2_integration.history[0]'].get('id')
            bound('target', 'integrations/' + integration if integration else None, 'aws_apigatewayv2_integration.history')
            expected_key = 'GET /v1/users/analysis-history' + ('/{resultId}' if address.endswith('["detail"]') else '')
            require(value.get('api_id') == 'icuak34th9' and value.get('route_key') == expected_key and value.get('authorization_type') == 'JWT' and value.get('authorizer_id') == 'itms4b' and value.get('authorization_scopes') == ['aws.cognito.signin.user.admin'], 'Unexpected route or authentication.')
        elif address.startswith('aws_apigatewayv2_integration.'):
            bound('integration_uri', inventory['aws_lambda_alias.runtime["reader"]'].get('invoke_arn'), 'aws_lambda_alias.runtime')
            require(value.get('integration_method') == 'POST', 'Reader integration must invoke Lambda by POST.')
            require(value.get('api_id') == 'icuak34th9' and value.get('integration_type') == 'AWS_PROXY' and value.get('payload_format_version') == '2.0' and value.get('timeout_milliseconds') == 29000, 'Unexpected HTTP integration.')
        elif address.startswith('aws_lambda_permission.'):
            name = address.split('"')[1]
            path = 'GET/v1/users/analysis-history' + ('/*' if name == 'detail' else '')
            require(value.get('action') == 'lambda:InvokeFunction' and value.get('principal') == 'apigateway.amazonaws.com' and value.get('function_name') == f'{PREFIX}-governed-history' and value.get('qualifier') == 'live' and value.get('source_account') == ACCOUNT and value.get('source_arn') == f'arn:aws:execute-api:us-east-1:{ACCOUNT}:icuak34th9/*/{path}', 'Reader invocation permission exceeds its routes.')
        elif address.startswith('aws_lambda_alias.'):
            bound('function_version', inventory['aws_lambda_function.runtime["reader"]'].get('version'), 'aws_lambda_function.runtime')
            require(value.get('name') == 'live' and value.get('function_name') == f'{PREFIX}-governed-history' and not value.get('routing_config'), 'Reader alias mismatch.')
        elif address.startswith('aws_cloudwatch_log_group.'):
            require(value.get('name') == f'/aws/lambda/{PREFIX}-governed-history' and value.get('retention_in_days') == 14, 'Reader logs must be bounded.')
        elif address.startswith('aws_lambda_function_event_invoke_config.'):
            require(not value.get('destination_config'), 'Reader cannot configure async destinations.')
            require(value.get('maximum_retry_attempts') == 0 and value.get('maximum_event_age_in_seconds') == 60 and value.get('qualifier') == 'live' and value.get('function_name') == f'{PREFIX}-governed-history', 'Reader async retry settings mismatch.')


def reader_environment(v):
    d = v['deployment']
    return {'GOVERNED_HISTORY_INDEX_NAME': 'GSI2', 'GOVERNED_HISTORY_CURSOR_TTL_SECONDS': '900', 'GOVERNED_HISTORY_RETENTION_SECONDS': '604800', 'GOVERNED_HISTORY_DEFAULT_PAGE_SIZE': '20', 'GOVERNED_HISTORY_MAX_PAGE_SIZE': '50', 'GOVERNED_HISTORY_MAX_RESPONSE_BYTES': '262144', 'OPERATION_VALIDITY_SECONDS': '300', 'WORKER_SETTLEMENT_SECONDS': '60', 'RECONCILIATION_SECONDS': '3600', 'RECEIPT_RETENTION_SECONDS': '604800', 'COUNTER_RETENTION_SECONDS': '604800', 'ATTEMPT_WINDOW_SECONDS': '60', 'ATTEMPTS_PER_WINDOW': '20', 'MAX_INFLIGHT': '2', 'STAGE': 'dev', 'AUTHORITY_ENABLED': str(v['list_enabled'] or v['detail_enabled']).lower(), 'AUTHORITY_POLICY_VERSION': 'owner-2026-09-20-v1', 'GOVERNED_HISTORY_LIST_ENABLED': str(v['list_enabled']).lower(), 'GOVERNED_HISTORY_DETAIL_ENABLED': str(v['detail_enabled']).lower(), 'DEV_SUBJECT_ALLOWLIST_JSON': json.dumps(sorted(v['engineering_subjects']), separators=(',', ':')), 'AUTHORITY_TABLE_NAME': f'{PREFIX}-purchase-entitlements', 'USERS_TABLE_NAME': f'{PREFIX}-users', 'DEVICE_BINDINGS_TABLE_NAME': f'{PREFIX}-device-bindings', 'DELETION_LEDGER_TABLE_NAME': f'{PREFIX}-deletion-ledger', 'COGNITO_ISSUER': d['cognito_issuer'], 'COGNITO_APP_CLIENT_ID': d['cognito_app_client_id'], 'COGNITO_REQUIRED_SCOPE': 'aws.cognito.signin.user.admin', 'AUTHORITY_HMAC_SECRET_ARN': d['authority_hmac_secret_arn']}


def reader_policy(d, subjects, partitions):
    def fence(sid, resource, leading, attributes):
        return {'Sid': sid, 'Effect': 'Allow', 'Action': 'dynamodb:GetItem', 'Resource': resource, 'Condition': {'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': leading, 'dynamodb:Attributes': attributes}, 'Null': {'dynamodb:Attributes': 'false', 'dynamodb:LeadingKeys': 'false'}}}
    subject_keys = ['USER#' + v for v in sorted(subjects)] or ['DENIED#NO-SUBJECT']
    deletion_keys = ['ACCOUNT#' + v for v in sorted(subjects)] or ['DENIED#NO-SUBJECT']
    policy = {'Version': '2012-10-17', 'Statement': [
        {'Sid': 'OwnLogs', 'Effect': 'Allow', 'Action': ['logs:CreateLogStream', 'logs:PutLogEvents'], 'Resource': f'arn:aws:logs:us-east-1:{ACCOUNT}:log-group:/aws/lambda/{PREFIX}-governed-history:*'},
        fence('ReadProfileFence', d['users_table_arn'], subject_keys, ['PK', 'SK', 'sub', 'status', 'ageVerified']),
        fence('ReadDeviceFence', d['devices_table_arn'], subject_keys, ['PK', 'SK', 'recordType', 'bindingFingerprint', 'stateVersion', 'accountId', 'status']),
        fence('ReadDeletionFence', d['deletion_table_arn'], deletion_keys, ['PK', 'SK']),
        fence('ReadCanonicalReceiptAndInventory', AUTHORITY, ['V1#CONTROL'] + sorted(partitions), ['PK', 'SK', 'recordType', 'state', 'governedHistory', 'governedHistoryDigest', 'expiresAt', 'retentionDeadlineEpoch', 'GSI2PK', 'GSI2SK', 'schemaVersion', 'revision', 'coverage', 'issuedKeys']),
        {'Sid': 'QuerySparseHistoryIndex', 'Effect': 'Allow', 'Action': 'dynamodb:Query', 'Resource': AUTHORITY + '/index/GSI2', 'Condition': {'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': sorted(partitions) or ['DENIED#NO-SUBJECT'], 'dynamodb:Attributes': ['PK', 'SK', 'GSI2PK', 'GSI2SK', 'recordType', 'state', 'governedHistory', 'expiresAt']}, 'StringEquals': {'dynamodb:Select': 'SPECIFIC_ATTRIBUTES'}, 'Null': {'dynamodb:Attributes': 'false', 'dynamodb:LeadingKeys': 'false'}}},
        {'Sid': 'ExistingHmacKeyRing', 'Effect': 'Allow', 'Action': 'secretsmanager:GetSecretValue', 'Resource': d['authority_hmac_secret_arn'], 'Condition': {'StringEquals': {'secretsmanager:VersionStage': 'AWSCURRENT'}}},
        {'Sid': 'NoWritesScanProviderOrObjectStorage', 'Effect': 'Deny', 'Action': ['dynamodb:PutItem', 'dynamodb:UpdateItem', 'dynamodb:DeleteItem', 'dynamodb:BatchWriteItem', 'dynamodb:TransactWriteItems', 'dynamodb:Scan', 'lambda:InvokeFunction', 's3:*', 'ssm:*', 'sts:AssumeRole'], 'Resource': '*'},
    ]}

    if not subjects or not partitions:
        policy['Statement'] = [policy['Statement'][0], policy['Statement'][-1]]
    return policy


def review(plan, revision, scope, mode):
    require(re.fullmatch('[0-9a-f]{40}', revision or ''), 'Full reviewed main revision required.')
    require(plan.get('complete') is True and not plan.get('errored') and plan.get('terraform_version') == '1.12.1', 'Successful pinned Terraform plan required.')
    variables = {k: v.get('value') for k, v in plan.get('variables', {}).items()}
    require(variables.get('environment') == 'dev' and variables.get('aws_region') == 'us-east-1' and variables.get('project_name') == 'trustcheckradar', 'Only TrustCheckRadar Dev is allowed.')
    require(not any(item.get('mode') == 'managed' and item.get('change', {}).get('actions') != ['no-op'] for item in plan.get('resource_drift', [])), 'Unreviewed live drift must be reconciled first.')
    changes = [v for v in plan.get('resource_changes', []) if v.get('mode') == 'managed' and v.get('change', {}).get('actions') != ['no-op']]
    all_managed = [v for v in plan.get('resource_changes', []) if v.get('mode') == 'managed']
    planned = {v['address']: v for v in plan.get('planned_values', {}).get('root_module', {}).get('resources', []) if v.get('mode') == 'managed'}
    require(planned and set(planned) == {v['address'] for v in all_managed}, 'Complete consistent post-plan inventory is required.')
    require(all(planned[v['address']].get('values') == v['change'].get('after') for v in all_managed), 'Post-plan inventory differs from reviewed resources.')
    if scope == 'index':
        require(all(v['address'] == 'aws_dynamodb_table.purchase_entitlements' for v in changes), 'Only the authority index may change.')
        table = [v for v in all_managed if v['address'] == 'aws_dynamodb_table.purchase_entitlements']
        require(len(table) == 1, 'Canonical authority table post-plan inventory required.')
        _index(table, variables, mode)
    elif scope == 'reader':
        configuration = {v['address']: v for v in plan.get('configuration', {}).get('root_module', {}).get('resources', [])}
        _reader(all_managed, variables, mode, configuration)
    else:
        raise ValueError('Unknown governed History scope.')
    material = {k: plan.get(k) for k in ('terraform_version', 'variables', 'output_changes', 'checks')}
    material.update(revision=revision, scope=scope, mode=mode, resource_changes=all_managed, resource_drift=plan.get('resource_drift', []))
    digest = hashlib.sha256(json.dumps(material, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'reviewedPlanDigest': digest, 'revision': revision, 'scope': scope, 'mode': mode, 'resourceChanges': len(changes), 'environment': 'dev'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--scope', choices=('index', 'reader'), required=True)
    parser.add_argument('--mode', required=True)
    parser.add_argument('--expected-digest')
    args = parser.parse_args()
    result = review(json.loads(args.plan.read_text()), args.revision, args.scope, args.mode)
    if args.expected_digest is not None:
        require(args.expected_digest == result['reviewedPlanDigest'], 'Plan digest differs from the approved plan.')
    print(json.dumps(result))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError) as exc:
        raise SystemExit(f'Governed History plan rejected: {exc}')
