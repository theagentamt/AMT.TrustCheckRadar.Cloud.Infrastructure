#!/usr/bin/env python3
"""Read configuration only; never read accounts, receipts or secret values."""
import argparse
import json
from pathlib import Path
from verify_message_consumer_transition import aws
from verify_governed_history_plan import ACCOUNT, AUTHORITY, PREFIX, PROJECTION, require, reader_environment, reader_policy


def verify_reader_role_exclusivity(*, allow_missing=False):
    import subprocess
    name = PREFIX + '-governed-history-execution'
    try:
        role = aws('iam', 'get-role', '--role-name', name)['Role']
    except subprocess.CalledProcessError as error:
        if allow_missing and 'NoSuchEntity' in (error.stderr or ''):
            return {'readerRolePresent': False, 'firstInactiveProvisioning': True}
        raise ValueError('Reader role preflight failed; no activation is permitted.') from None
    require(role.get('Arn') == f'arn:aws:iam::{ACCOUNT}:role/{name}', 'Wrong reader role identity.')
    require(not aws('iam', 'list-attached-role-policies', '--role-name', name).get('AttachedPolicies') and aws('iam', 'list-role-policies', '--role-name', name).get('PolicyNames') == ['fenced-governed-history-read-only'], 'Unexpected additional reader role grants; reconcile them before activation.')
    return {'readerRolePresent': True, 'exclusivePolicyNamesVerified': True}


def reader_invoke_statements():
    alias = f'arn:aws:lambda:us-east-1:{ACCOUNT}:function:{PREFIX}-governed-history:live'
    return [{
        'Sid': 'AllowMessage-' + kind, 'Effect': 'Allow',
        'Principal': {'Service': 'apigateway.amazonaws.com'},
        'Action': 'lambda:InvokeFunction', 'Resource': alias,
        'Condition': {'StringEquals': {'AWS:SourceAccount': ACCOUNT},
                      'ArnLike': {'AWS:SourceArn': f'arn:aws:execute-api:us-east-1:{ACCOUNT}:icuak34th9/*/GET/v1/users/analysis-history' + ('/*' if kind == 'detail' else '')}}
    } for kind in ('list', 'detail')]


def verify_reader_invoke_boundary(*, allow_missing=False):
    import subprocess
    def policy(qualifier=None):
        args = ['lambda', 'get-policy', '--function-name', PREFIX + '-governed-history']
        if qualifier: args += ['--qualifier', qualifier]
        try:
            return json.loads(aws(*args)['Policy'])
        except subprocess.CalledProcessError as error:
            if 'ResourceNotFoundException' in (error.stderr or ''):
                return None
            raise ValueError('Reader invocation boundary could not be verified.') from None
    unqualified = policy()
    require(unqualified is None or unqualified.get('Statement') == [], 'Unexpected unqualified reader invocation grants; reconcile before activation.')
    qualified = policy('live')
    if qualified is None and allow_missing:
        return {'readerAliasPolicyPresent': False, 'inactiveProvisioning': True}
    require(isinstance(qualified, dict) and qualified.get('Version') == '2012-10-17', 'The exact reader alias invocation policy is required.')
    actual = qualified.get('Statement')
    require(isinstance(actual, list) and len(actual) == 2 and sorted(actual, key=lambda v: v.get('Sid', '')) == sorted(reader_invoke_statements(), key=lambda v: v['Sid']), 'Reader alias must permit only the two exact JWT API Gateway route sources.')
    return {'readerAliasPolicyPresent': True, 'exclusiveRouteInvokePolicyVerified': True}


def verify_reader_preflight(*, allow_missing=False):
    return {**verify_reader_role_exclusivity(allow_missing=allow_missing),
            **verify_reader_invoke_boundary(allow_missing=allow_missing)}


def verify_index():
    require(aws('sts', 'get-caller-identity').get('Account') == ACCOUNT, 'Wrong AWS account.')
    table = aws('dynamodb', 'describe-table', '--table-name', PREFIX + '-purchase-entitlements')['Table']
    indexes = [v for v in table.get('GlobalSecondaryIndexes', []) if v['IndexName'] == 'GSI2']
    require(table.get('TableArn') == AUTHORITY and table.get('TableStatus') == 'ACTIVE' and len(indexes) == 1, 'Active authority History index is required.')
    index = indexes[0]
    require(index.get('IndexStatus') == 'ACTIVE' and index.get('KeySchema') == [{'AttributeName': 'GSI2PK', 'KeyType': 'HASH'}, {'AttributeName': 'GSI2SK', 'KeyType': 'RANGE'}] and index.get('Projection', {}).get('ProjectionType') == 'INCLUDE' and set(index['Projection'].get('NonKeyAttributes') or []) == PROJECTION, 'History index schema/projection is not qualified.')
    ttl = aws('dynamodb', 'describe-time-to-live', '--table-name', PREFIX + '-purchase-entitlements')['TimeToLiveDescription']
    require(ttl.get('TimeToLiveStatus') == 'ENABLED' and ttl.get('AttributeName') == 'expiresAt', 'Receipt TTL must remain enabled.')
    backups = aws('dynamodb', 'describe-continuous-backups', '--table-name', PREFIX + '-purchase-entitlements')['ContinuousBackupsDescription']
    require(backups.get('PointInTimeRecoveryDescription', {}).get('PointInTimeRecoveryStatus') == 'ENABLED', 'Existing authority backup posture must remain enabled.')
    return {'indexStatus': 'ACTIVE', 'projectionVerified': True, 'ttlEnabled': True, 'pitrEnabled': True}


def verify(plan, scope, mode):
    require(aws('sts', 'get-caller-identity').get('Account') == ACCOUNT, 'Wrong AWS account.')
    variables = {k: v.get('value') for k, v in plan.get('variables', {}).items()}
    if scope == 'index':
        if mode == 'active': return verify_index()
        table = aws('dynamodb', 'describe-table', '--table-name', PREFIX + '-purchase-entitlements')['Table']
        require(table.get('TableArn') == AUTHORITY and not any(v['IndexName'] == 'GSI2' for v in table.get('GlobalSecondaryIndexes', [])), 'Inactive index readback mismatch.')
        return {'indexPresent': False}
    if scope == 'reader' and mode != 'inactive' or scope == 'message' and mode == 'rules-only-history':
        verify_index()
    from verify_message_consumer_transition import _expected_environment
    names = ['governed-history'] if scope == 'reader' else ['message-consumer', 'message-evaluator']
    configs = {}
    for suffix in names:
        name = PREFIX + '-' + suffix
        alias = aws('lambda', 'get-alias', '--function-name', name, '--name', 'live')
        require(not alias.get('RoutingConfig', {}).get('AdditionalVersionWeights'), 'Weighted alias routing is forbidden.')
        function = aws('lambda', 'get-function-configuration', '--function-name', name, '--qualifier', alias['FunctionVersion'])
        artifact_name = 'reader' if scope == 'reader' else suffix.split('-')[1]
        artifact = variables['deployment']['artifacts'][artifact_name]
        require(function.get('CodeSha256') == artifact['source_hash'] and function.get('Runtime') == 'python3.14' and function.get('Architectures') == ['arm64'] and function.get('State') == 'Active' and function.get('LastUpdateStatus') == 'Successful' and function.get('Role') == f'arn:aws:iam::{ACCOUNT}:role/{name}-execution', 'Runtime readback differs from reviewed source/runtime/role.')
        timeout = 23 if scope == 'reader' else (29 if artifact_name == 'consumer' else 23)
        handler = 'governed_history.app.lambda_handler' if scope == 'reader' else f'message_{artifact_name}.app.lambda_handler'
        require(function.get('Timeout') == timeout and function.get('MemorySize') == 256 and function.get('Handler') == handler, 'Runtime handler/timeout/memory differ from the qualified limits.')
        actual = function.get('Environment', {}).get('Variables') or {}
        if scope == 'reader': expected = reader_environment(variables)
        else:
            active = mode != 'inactive'
            expected = _expected_environment(artifact_name, variables, active)
            expected['MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED'] = str(active).lower()
            if artifact_name == 'consumer': expected.update(GOVERNED_HISTORY_SETTLEMENT_ENABLED=str(mode == 'rules-only-history').lower(), MESSAGE_PROVIDER_CIRCUIT_OPEN='true')
        require(actual == expected, 'Runtime gates do not match the reviewed independent contract.')
        concurrency = aws('lambda', 'get-function-concurrency', '--function-name', name)
        require(concurrency.get('ReservedConcurrentExecutions') == 2, 'Runtime concurrency must remain bounded.')
        if scope == 'reader':
            require(not aws('iam', 'list-attached-role-policies', '--role-name', name + '-execution').get('AttachedPolicies') and aws('iam', 'list-role-policies', '--role-name', name + '-execution').get('PolicyNames') == ['fenced-governed-history-read-only'], 'Unexpected additional reader role grants.')
            actual_policy = aws('iam', 'get-role-policy', '--role-name', name + '-execution', '--policy-name', 'fenced-governed-history-read-only')['PolicyDocument']
            require(actual_policy == reader_policy(variables['deployment'], variables['engineering_subjects'], variables['authority_partitions']), 'Reader least-privilege policy did not land.')
        elif artifact_name == 'evaluator':
            from verify_candidate3_rules_plan import evaluator_policy
            actual_policy = aws('iam', 'get-role-policy', '--role-name', name + '-execution', '--policy-name', 'private-message-evaluation-only')['PolicyDocument']
            require(actual_policy == evaluator_policy(variables['deployment'], mode != 'inactive'), 'Evaluator provider-denial policy did not land.')
        configs[suffix] = {'version': alias['FunctionVersion'], 'codeHashVerified': True, 'environmentVerified': True, 'concurrency': 2}
    if scope == 'reader':
        verify_reader_invoke_boundary()
        routes = aws('apigatewayv2', 'get-routes', '--api-id', 'icuak34th9').get('Items', [])
        wanted = {'GET /v1/users/analysis-history', 'GET /v1/users/analysis-history/{resultId}'}
        found = [v for v in routes if v.get('RouteKey') in wanted]
        require(len(found) == 2 and {v['RouteKey'] for v in found} == wanted, 'Both governed History routes are required.')
        for route in found:
            require(route.get('AuthorizationType') == 'JWT' and route.get('AuthorizerId') == 'itms4b' and route.get('AuthorizationScopes') == ['aws.cognito.signin.user.admin'], 'Route JWT mismatch.')
            target = route.get('Target', '')
            require(target.startswith('integrations/'), 'Invalid route target.')
            integration = aws('apigatewayv2', 'get-integration', '--api-id', 'icuak34th9', '--integration-id', target.split('/')[1])
            alias_arn = f'arn:aws:lambda:us-east-1:{ACCOUNT}:function:{PREFIX}-governed-history:live'
            allowed_uri = {alias_arn, f'arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/{alias_arn}/invocations'}
            require(integration.get('IntegrationUri') in allowed_uri and integration.get('IntegrationMethod') == 'POST', 'Route backend readback mismatch.')
    return {'scope': scope, 'mode': mode, 'runtimes': configs, 'configurationOnly': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path, nargs='?'); parser.add_argument('--preflight', action='store_true'); parser.add_argument('--scope', required=True); parser.add_argument('--mode', required=True)
    args = parser.parse_args()
    try:
        if args.preflight:
            require(args.scope == 'reader', 'Role preflight applies only to reader scope.')
            require(aws('sts', 'get-caller-identity').get('Account') == ACCOUNT, 'Wrong AWS account.')
            print(json.dumps(verify_reader_preflight(allow_missing=args.mode == 'inactive')))
        else:
            require(args.plan is not None, 'Reviewed plan is required for readback.')
            print(json.dumps(verify(json.loads(args.plan.read_text()), args.scope, args.mode)))
    except (ValueError, KeyError, TypeError, OSError) as exc: raise SystemExit(f'Governed History readback rejected: {exc}')
