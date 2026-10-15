#!/usr/bin/env python3
"""Verify replay-only archive bytes and a bounded Dev retirement plan; never deploy."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'terraform/api/analysis-retirement-catalog.json'
ALLOWED = {
    'aws_iam_policy.analysis_runtime', 'aws_iam_role_policy.history_analysis[0]',
    'aws_lambda_function.analysis', 'aws_lambda_alias.analysis_retired[0]',
    'aws_apigatewayv2_integration.analysis_lambda',
    'aws_lambda_permission.allow_api_gateway_invoke_analysis',
    'aws_lambda_permission.allow_api_gateway_invoke_analysis[0]',
    'aws_lambda_permission.allow_api_gateway_invoke_analysis_legacy[0]',
    'aws_iam_role_policy_attachment.period_work["analysis"]',
    'aws_iam_policy.period_work["analysis"]',
}


COMPUTED = {'last_modified', 'version', 'qualified_arn', 'qualified_invoke_arn', 'code_sha256', 'source_code_size'}


def unknown(value):
    if isinstance(value, dict):
        return any(unknown(item) for item in value.values())
    if isinstance(value, list):
        return any(unknown(item) for item in value)
    return value is True


def changed_fields(change):
    before, after = change.get('before') or {}, change.get('after') or {}
    return {key for key in before.keys() | after.keys() if before.get(key) != after.get(key)} | {
        key for key, value in (change.get('after_unknown') or {}).items() if unknown(value)}


def policy_shape(text):
    doc = json.loads(text)
    require(doc.get('Version') == '2012-10-17' and set(doc) == {'Version', 'Statement'}, 'Unknown policy format')
    def normalize(row):
        require(set(row) <= {'Sid', 'Effect', 'Action', 'Resource', 'Condition'}, 'Unknown policy grant')
        row = dict(row)
        for key in ('Action', 'Resource'):
            value = row[key]
            row[key] = sorted([value] if isinstance(value, str) else value)
        conditions = row.get('Condition', {})
        row['Condition'] = {test: {key: sorted([value] if isinstance(value, str) else value)
                                  for key, value in values.items()} for test, values in conditions.items()}
        return row
    return sorted([normalize(row) for row in doc['Statement']], key=lambda row: row.get('Sid', ''))


def runtime_policy():
    table = 'arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-'
    rows = []
    for label, suffix, keys in [('Profile', 'users', ['USER#*']), ('Deletion', 'deletion-ledger', ['ACCOUNT#*']),
                                ('Device', 'device-bindings', ['USER#*']), ('Evidence', 'analysis-abuse-control', ['ANALYSIS#REQUEST#*', 'ANALYSIS#CONSUMPTION#*'])]:
        rows.append({'Sid': 'ReadReplay'+label, 'Effect': 'Allow', 'Action': ['dynamodb:GetItem'], 'Resource': [table+suffix],
                     'Condition': {'ForAllValues:StringLike': {'dynamodb:LeadingKeys': keys}}})
    rows += [
      {'Sid': 'DenyProviderCredentialsAndDispatch', 'Effect': 'Deny', 'Resource': ['*'], 'Action': [
        'secretsmanager:GetSecretValue', 'ssm:GetParameter', 'ssm:GetParameters', 'ssm:GetParametersByPath', 'lambda:InvokeFunction',
        'bedrock:InvokeModel', 'bedrock:InvokeModelWithResponseStream', 'bedrock:StartAsyncInvoke']},
      {'Sid': 'DenyApplicationKmsUse', 'Effect': 'Deny', 'Resource': ['*'], 'Action': ['kms:Decrypt', 'kms:GenerateDataKey*'],
       'Condition': {'Null': {'lambda:SourceFunctionArn': ['false']}}},
      {'Sid': 'DenyNonReplayDatabaseAccess', 'Effect': 'Deny', 'Resource': ['*'], 'Action': [
        'dynamodb:PutItem', 'dynamodb:UpdateItem', 'dynamodb:DeleteItem', 'dynamodb:BatchWriteItem', 'dynamodb:ConditionCheckItem', 'dynamodb:Query', 'dynamodb:Scan', 'dynamodb:BatchGetItem', 'dynamodb:PartiQLSelect',
        'dynamodb:PartiQLInsert', 'dynamodb:PartiQLUpdate', 'dynamodb:PartiQLDelete']},
    ]
    return json.dumps({'Version': '2012-10-17', 'Statement': rows})


def runtime_before_kms_fix():
    doc = json.loads(runtime_policy())
    doc['Statement'] = [row for row in doc['Statement'] if row['Sid'] != 'DenyApplicationKmsUse']
    next(row for row in doc['Statement'] if row['Sid'] == 'DenyProviderCredentialsAndDispatch')['Action'] += ['kms:Decrypt', 'kms:GenerateDataKey*']
    return json.dumps(doc)


DRIFT_FIELDS = COMPUTED | {'inline_policy', 'estimated_number_of_users', 'environment', 'publish',
    'policy', 'role', 'assume_role_policy', 'tags', 'tags_all', 'name', 'arn', 'id', 'unique_id',
    'integration_uri', 'function_version', 'routing_config', 'source_arn', 'qualifier'}
DRIFT_LABELS = {address: address for address in ALLOWED} | {
    'aws_iam_role.analysis': 'analysis role',
    'aws_iam_role.history_api[0]': 'legacy History role',
    'aws_iam_role.account_data[0]': 'account data role',
    'aws_iam_role.account_export[0]': 'account export role',
    'aws_iam_role.support_account_deletion[0]': 'support deletion role',
    'aws_iam_role.demographic_research[0]': 'demographic research role',
    'aws_iam_role.campaign_participation': 'campaign participation role',
    'aws_cognito_user_pool.main': 'Cognito pool',
}


def safe_drift_summary(plan):
    """Only source-catalog labels, known field names and aggregate counts."""
    catalog = json.loads((ROOT / 'scripts/analysis-retirement-diagnostic-catalog.json').read_text())
    fields_catalog = DRIFT_FIELDS | set(catalog['fields'])
    labels_catalog = set(catalog['resources'])
    rows = []
    for row in plan.get('resource_drift', []):
        if row.get('mode') != 'managed':
            continue
        fields = changed_fields(row.get('change') or {})
        address = row.get('address') or ''
        base = address.split('[', 1)[0]
        label = DRIFT_LABELS.get(address, base if base in labels_catalog else 'other managed resource')
        rows.append({'resource': label,
                     'fields': sorted(fields & fields_catalog), 'otherFieldCount': len(fields - fields_catalog)})
    return {'managedDrift': rows}


def automatic_stage_readback(plan, row):
    """Only the service-managed deployment pointer of the unchanged Dev stage."""
    try:
        address = 'aws_apigatewayv2_stage.age_attestation'
        require(row.get('address') == address and row.get('provider_name') == 'registry.terraform.io/hashicorp/aws', 'Unknown stage readback')
        change = row['change']
        before, after = change['before'], change['after']
        require(change['actions'] == ['update'] and type(before) is dict and type(after) is dict and
                changed_fields(change) == {'deployment_id'} and not unknown(change.get('after_unknown') or {}), 'Only deployment pointer readback permitted')
        configs = {item['address']: item for item in plan.get('configuration', {}).get('root_module', {}).get('resources', [])}
        expressions = configs.get(address, {}).get('expressions', {})
        require(expressions.get('auto_deploy', {}).get('constant_value') is True and 'deployment_id' not in expressions and
                'aws_apigatewayv2_api.age_attestation.id' in expressions.get('api_id', {}).get('references', []), 'Automatic stage source binding required')
        require(all(isinstance(value.get('deployment_id'), str) and re.fullmatch('[a-z0-9]+', value['deployment_id'])
                    for value in (before, after)), 'Known deployment pointers required')
        counterparts = [item for item in plan['resource_changes'] if item.get('mode') == 'managed' and item.get('address') == address]
        require(len(counterparts) == 1 and counterparts[0]['change']['actions'] == ['no-op'] and
                counterparts[0]['change']['before'] == after and counterparts[0]['change']['after'] == after and
                not unknown(counterparts[0]['change'].get('after_unknown') or {}), 'Stage must be an exact no-op readback')
        apis = [item for item in plan['resource_changes'] if item.get('mode') == 'managed' and item.get('address') == 'aws_apigatewayv2_api.age_attestation']
        require(len(apis) == 1 and apis[0].get('provider_name') == 'registry.terraform.io/hashicorp/aws', 'Exact API counterpart required')
        api_change = apis[0]['change']
        api = api_change['after']
        require(api_change['actions'] == ['no-op'] and api_change['before'] == api and
                not unknown(api_change.get('after_unknown') or {}) and
                api['name'] == 'trustcheckradar-dev-age-attestation-api' and api['protocol_type'] == 'HTTP' and
                re.fullmatch('[a-z0-9]+', api['id']) and after['api_id'] == api['id'], 'Unchanged Dev API required')
        require(after['auto_deploy'] is True and after['name'] == '$default' and
                api['arn'] == 'arn:aws:apigateway:us-east-1::/apis/' + api['id'] and
                after['arn'] == api['arn'] + '/stages/$default', 'Automatic Dev stage identity required')
        return True
    except (KeyError, TypeError, ValueError):
        return False


def migration_boundary_policy():
    return json.dumps({'Version': '2012-10-17', 'Statement': [
        {'Sid': 'DenyProviderCredentialsAndDispatch', 'Effect': 'Deny', 'Action': [
            'secretsmanager:GetSecretValue', 'ssm:GetParameter', 'ssm:GetParameters', 'ssm:GetParametersByPath', 'lambda:InvokeFunction'], 'Resource': ['*']},
        {'Sid': 'DenyLegacySettlementAndWrites', 'Effect': 'Deny', 'Action': [
            'dynamodb:PutItem', 'dynamodb:UpdateItem', 'dynamodb:DeleteItem', 'dynamodb:BatchWriteItem',
            'dynamodb:PartiQLInsert', 'dynamodb:PartiQLUpdate', 'dynamodb:PartiQLDelete'], 'Resource': ['*']},
        {'Sid': 'ReadReplayAccountDeletionFence', 'Effect': 'Allow', 'Action': ['dynamodb:GetItem'],
            'Resource': ['arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger'],
            'Condition': {'ForAllValues:StringLike': {'dynamodb:LeadingKeys': ['ACCOUNT#*']}}},
    ]})


def policy_digest(text):
    return hashlib.sha256(json.dumps(policy_shape(text), sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def post_role_readback(plan, row, *, runtime_repair=False):
    """Reconcile only the exact stale policy view after the approved transition."""
    try:
        address = 'aws_iam_role.analysis'
        provider = 'registry.terraform.io/hashicorp/aws'
        role = 'trustcheckradar-dev-conversation-analysis-role'
        require(row.get('address') == address and row.get('provider_name') == provider, 'Unknown role readback')
        change = row['change']; before, after = change['before'], change['after']
        require(change['actions'] == ['update'] and type(before) is dict and type(after) is dict and
                changed_fields(change) == {'inline_policy', 'managed_policy_arns'} and not unknown(change.get('after_unknown') or {}), 'Only owned policy views may differ')
        configs = {item['address']: item for item in plan.get('configuration', {}).get('root_module', {}).get('resources', [])}
        expressions = configs.get(address, {}).get('expressions', {})
        require('inline_policy' not in expressions and 'managed_policy_arns' not in expressions and
                'data.aws_iam_policy_document.age_attestation_assume_role.json' in expressions.get('assume_role_policy', {}).get('references', []), 'Separately managed role source required')
        resources = [item for item in plan['resource_changes'] if item.get('mode') == 'managed']
        def current(target):
            matches = [item for item in resources if item.get('address') == target]
            require(len(matches) == 1 and matches[0].get('provider_name') == provider, 'Exact managed policy counterpart required')
            value = matches[0]['change']
            repair = runtime_repair and target == 'aws_iam_policy.analysis_runtime'
            require((value['actions'] == ['no-op'] and value['before'] == value['after'] or
                    repair and value['actions'] == ['update'] and changed_fields(value) == {'policy'} and
                    policy_shape(value['before']['policy']) == policy_shape(runtime_before_kms_fix())) and
                    not unknown(value.get('after_unknown') or {}), 'Managed policy counterpart must be no-op or exact KMS repair')
            return value['after']
        require(current(address) == after and after['name'] == role and after['arn'] == 'arn:aws:iam::107827791950:role/' + role,
                'Exact current role identity required')
        require(current('aws_lambda_function.analysis')['role'] == after['arn'] and
                'aws_iam_role.analysis.arn' in configs.get('aws_lambda_function.analysis', {}).get('expressions', {}).get('role', {}).get('references', []), 'Analysis must use the verified role')
        trust = {'Version': '2012-10-17', 'Statement': [{'Sid': 'LambdaAssumeRole', 'Effect': 'Allow',
            'Action': 'sts:AssumeRole', 'Principal': {'Service': 'lambda.amazonaws.com'}}]}
        require(json.loads(after['assume_role_policy']) == trust, 'Exact Lambda role trust required')
        runtime = current('aws_iam_policy.analysis_runtime')
        runtime_arn = 'arn:aws:iam::107827791950:policy/trustcheckradar-dev-conversation-analysis-runtime'
        basic_arn = 'arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
        period_arn = 'arn:aws:iam::107827791950:policy/trustcheckradar-dev-analysis-period-work'
        require(runtime['arn'] == runtime_arn and policy_shape(runtime['policy']) == policy_shape(runtime_policy()), 'Exact replay runtime policy required')
        for target, arn in [('aws_iam_role_policy_attachment.analysis_runtime', runtime_arn),
                            ('aws_iam_role_policy_attachment.analysis_basic_execution', basic_arn)]:
            attachment = current(target)
            require(attachment['role'] == role and attachment['policy_arn'] == arn, 'Exact replay attachment required')
        require(type(before['managed_policy_arns']) is list and type(after['managed_policy_arns']) is list and
                len(before['managed_policy_arns']) == 3 and set(before['managed_policy_arns']) == {runtime_arn, basic_arn, period_arn} and
                len(after['managed_policy_arns']) == 2 and set(after['managed_policy_arns']) == {runtime_arn, basic_arn}, 'Exact retired attachment readback required')
        history = current('aws_iam_role_policy.history_analysis[0]')
        boundary = current('aws_iam_role_policy.research_migration_boundary["analysis"]')
        require(history['name'] == 'history-analysis-runtime' and history['role'] == role and
                boundary['name'] == 'trustcheckradar-dev-research-migration-analysis' and boundary['role'] == role and
                policy_shape(boundary['policy']) == policy_shape(migration_boundary_policy()), 'Exact inline policy binding required')
        def inline(values):
            require(type(values) is list and len(values) == 2 and all(type(item) is dict and set(item) == {'name', 'policy'} for item in values), 'Exact inline policy view required')
            result = {item['name']: item['policy'] for item in values}
            require(len(result) == 2 and set(result) == {history['name'], boundary['name']}, 'Unknown or duplicate inline policy')
            return result
        old, new = inline(before['inline_policy']), inline(after['inline_policy'])
        require(all(policy_shape(new[item['name']]) == policy_shape(item['policy']) for item in (history, boundary)), 'Current inline view differs from managed inventory')
        require(policy_shape(old[boundary['name']]) == policy_shape(boundary['policy']) and
                policy_digest(old[history['name']]) == '95a70a4cb727366daa2f93f60e90402e40b4813551ebc594ddbb7731431c3ab0', 'Historical inline view differs from bound pre-apply inventory')
        return True
    except (KeyError, TypeError, ValueError):
        return False


def bounded_shapes(plan, managed, function, *, post_apply=False, runtime_repair=False):
    drift = safe_drift_summary(plan)
    if drift['managedDrift']:
        print(json.dumps(drift), file=sys.stderr)
    managed_drift = [row for row in plan.get('resource_drift', []) if row.get('mode') == 'managed']
    drift_addresses = [row.get('address') for row in managed_drift]
    require(len(managed_drift) <= (2 if post_apply or runtime_repair else 1) and len(drift_addresses) == len(set(drift_addresses)) and
                all(automatic_stage_readback(plan, row) or (post_apply or runtime_repair) and post_role_readback(plan, row, runtime_repair=runtime_repair)
                    for row in managed_drift), 'Managed drift requires review')
    configs = {row['address']: row for row in plan.get('configuration', {}).get('root_module', {}).get('resources', [])}
    function_change = function['change']
    require(function_change['actions'] in (['update'], ['no-op']) and
            changed_fields(function_change) <= COMPUTED | {'environment', 'publish'}, 'Unexpected function change')
    before = function_change.get('before') or {}
    after = function_change.get('after') or {}
    name = 'trustcheckradar-dev-conversation-analysis'
    require(before.get('publish') in (False, True) and after.get('publish') is True, 'Publish transition required')
    expected_env = {
        'APP_ENVIRONMENT': 'dev', 'COGNITO_REQUIRED_SCOPE': 'aws.cognito.signin.user.admin',
        'USERS_TABLE_NAME': 'trustcheckradar-dev-users', 'DEVICE_BINDINGS_TABLE_NAME': 'trustcheckradar-dev-device-bindings',
        'ANALYSIS_ABUSE_TABLE_NAME': 'trustcheckradar-dev-analysis-abuse-control', 'DELETION_LEDGER_TABLE_NAME': 'trustcheckradar-dev-deletion-ledger',
        'HISTORY_MAX_SUMMARY_BYTES': '4096', 'HISTORY_MAX_LIST_ITEMS': '20', 'HISTORY_MAX_TEXT_FIELD_BYTES': '1024',
        'HISTORY_MAX_RESPONSE_BYTES': '262144', 'HISTORY_WRITES_ENABLED': 'false', 'HISTORY_DURABLE_REPLAY_ENABLED': 'false',
        'RECOGNITION_ENABLED': 'false',
    }
    old_env = before.get('environment', [{}])[0].get('variables', {})
    env = after.get('environment', [{}])[0].get('variables', {})
    for key in ('COGNITO_ISSUER', 'COGNITO_APP_CLIENT_ID'):
        require(isinstance(old_env.get(key), str) and old_env[key], 'Existing protected auth required')
        expected_env[key] = old_env[key]
    for key in ('HISTORY_CONTENT_TABLE_NAME', 'HISTORY_CONTROL_TABLE_NAME'):
        require(isinstance(old_env.get(key), str) and old_env[key], 'Existing paired History tables required')
        expected_env[key] = old_env[key]
    for key, value in old_env.items():
        if key.startswith('CAMPAIGN_PERIOD_'):
            expected_env[key] = value
    require(all(value != 'true' for key, value in expected_env.items() if key.startswith('CAMPAIGN_PERIOD_') and key.endswith('_ENABLED')), 'Campaign work stays disabled')
    require(env == expected_env and not unknown((function_change.get('after_unknown') or {}).get('environment')), 'Unexpected replay environment')
    for row in managed:
        address, change = row['address'], row['change']
        actions = change['actions']
        if actions == ['no-op'] and address not in ALLOWED:
            continue
        new, old = change.get('after') or {}, change.get('before') or {}
        fields = changed_fields(change)
        if address == 'aws_lambda_function.analysis':
            continue
        if address == 'aws_iam_policy.analysis_runtime':
            require(actions in (['update'], ['no-op']) and fields <= {'policy'} and policy_shape(new['policy']) == policy_shape(runtime_policy()), 'Unexpected runtime policy')
        elif address == 'aws_iam_role_policy.history_analysis[0]':
            table = 'arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-'
            expected = json.dumps({'Version': '2012-10-17', 'Statement': [{
                'Sid': 'ReadHistoryReplayAndState', 'Effect': 'Allow', 'Action': ['dynamodb:GetItem'],
                'Resource': [table+'content', table+'control'], 'Condition': {'ForAllValues:StringLike': {'dynamodb:LeadingKeys': ['USER#*']}}}]})
            require(actions in (['update'], ['no-op']) and fields <= {'policy'} and policy_shape(new['policy']) == policy_shape(expected), 'Unexpected History replay policy')
        elif address in {'aws_iam_role_policy_attachment.period_work["analysis"]', 'aws_iam_policy.period_work["analysis"]'}:
            require(actions == ['delete'], 'Retired period-work access may only be removed')
        elif address == 'aws_lambda_alias.analysis_retired[0]':
            require(actions in (['create'], ['no-op']) and new.get('name') == 'retired' and new.get('function_name') == name and not new.get('routing_config'), 'Unexpected alias')
            expr = configs.get('aws_lambda_alias.analysis_retired', {}).get('expressions', {}).get('function_version', {})
            require('aws_lambda_function.analysis.version' in expr.get('references', []), 'Alias must select published version')
            require(new.get('function_version') is None or re.fullmatch('[1-9][0-9]*', new['function_version']), 'Latest alias forbidden')
        elif address == 'aws_apigatewayv2_integration.analysis_lambda':
            require(actions in (['update'], ['no-op']) and fields <= {'integration_uri'} and new.get('integration_method') == 'POST', 'Unexpected integration update')
            expr = configs.get(address, {}).get('expressions', {}).get('integration_uri', {})
            require('aws_lambda_alias.analysis_retired[0].invoke_arn' in expr.get('references', []), 'Qualified integration required')
            expected_uri = 'arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:107827791950:function:'+name+':retired/invocations'
            require(new.get('integration_uri') is None or new['integration_uri'] == expected_uri, 'Unqualified integration forbidden')
        elif address.startswith('aws_lambda_permission.allow_api_gateway_invoke_analysis'):
            require('legacy' not in address, 'No legacy-route activation in this correction')
            if actions == ['delete']:
                require(not old.get('qualifier') and old.get('function_name') == name and old.get('principal') == 'apigateway.amazonaws.com', 'Only old unqualified permission may be removed')
            else:
                require(actions in (['create'], ['delete', 'create'], ['create', 'delete'], ['no-op']) and new.get('function_name') == name and
                        new.get('qualifier') == 'retired' and new.get('source_account') == '107827791950' and
                        new.get('principal') == 'apigateway.amazonaws.com' and new.get('action') == 'lambda:InvokeFunction' and
                        new.get('statement_id') == 'AllowExecutionFromApiGatewayAnalysis' and
                        re.fullmatch(r'arn:aws:execute-api:us-east-1:107827791950:[a-z0-9]+/\$default/POST/analysis', new.get('source_arn') or ''), 'Unexpected invoke permission')
                if actions not in (['create'], ['no-op']):
                    require(not old.get('qualifier') and old.get('function_name') == name, 'Only old permission replacement allowed')
        else:
            require(False, 'Unexpected retirement action')


class ReviewRejected(ValueError):
    """A static source-defined check label, never a plan or SDK value."""


def require(ok, message):
    if not ok:
        raise ReviewRejected(message)


def safe_failure_message(error):
    prefix = 'Analysis retirement verification rejected'
    if isinstance(error, ReviewRejected):
        return prefix + ': ' + str(error) + '. Inspect protected evidence locally.'
    return prefix + '; inspect protected evidence locally.'


def review(plan, revision, *, bounded=False, post_apply=False, runtime_repair=False, catalog=None):
    catalog = json.loads(CATALOG.read_text()) if catalog is None else catalog
    require(re.fullmatch('[0-9a-f]{40}', revision or ''), 'Exact revision required')
    require(not runtime_repair or bounded and not post_apply, 'KMS repair requires bounded initial mode')
    require(plan.get('complete') is True and not plan.get('errored'), 'Incomplete plan')
    variables = {key: row.get('value') for key, row in plan.get('variables', {}).items()}
    selected = variables.get('analysis_retirement_deployment')
    migration = variables.get('research_consent_migration_deployment')
    if selected is None and isinstance(migration, dict):
        selected = {'release_id': migration.get('release_id'), **migration.get('artifacts', {}).get('analysis', {})}
    require(isinstance(selected, dict), 'Missing retirement selection')
    release, sha, version = (selected.get(key) for key in ('release_id', 'source_hash', 'object_version'))
    require(re.fullmatch('[0-9a-f]{40}', release or '') and catalog.get(variables.get("environment"), {}).get(release) == {"object_version": version, "source_hash": sha}, 'Unqualified archive')
    require(isinstance(version, str) and version.strip() and version != 'null', 'Mutable archive')
    managed = [row for row in plan.get('resource_changes', []) if row.get('mode') == 'managed']
    addresses = [row.get('address') for row in managed]
    require(len(addresses) == len(set(addresses)), 'Duplicate resource')
    function = next((row for row in managed if row['address'] == 'aws_lambda_function.analysis'), None)
    require(function is not None, 'Missing analysis function')
    after = function['change'].get('after') or {}
    require(after.get('s3_key') == f'releases/{release}/conversation_analysis.zip' and
            after.get('s3_object_version') == version and after.get('source_code_hash') == sha and
            after.get('publish') is True and after.get('runtime') == 'python3.14' and
            after.get('architectures') == ['arm64'] and after.get('handler') == 'app.lambda_handler', 'Unqualified function code')
    bucket = after.get('s3_bucket')
    require(isinstance(bucket, str) and bucket, 'Unknown bucket')
    if bounded:
        require(variables.get('analysis_legacy_path_enabled') is False, 'Legacy route must remain disabled')
        require(not any('allow_api_gateway_invoke_analysis_legacy' in row['address'] and row['change'].get('after') is not None for row in managed), 'Legacy invoke must remain absent')
        required = {'aws_iam_policy.analysis_runtime', 'aws_lambda_function.analysis', 'aws_lambda_alias.analysis_retired[0]',
                    'aws_apigatewayv2_integration.analysis_lambda', 'aws_lambda_permission.allow_api_gateway_invoke_analysis[0]'}
        require(required <= set(addresses), 'Missing retirement resources')
        changed = {row['address'] for row in managed if row['change'].get('actions') != ['no-op']}
        if post_apply:
            require(not changed, 'Post-apply plan must be no-op')
        elif runtime_repair:
            require(changed == {'aws_iam_policy.analysis_runtime'}, 'KMS repair may change only runtime policy')
            runtime = next(row for row in managed if row['address'] == 'aws_iam_policy.analysis_runtime')['change']
            require(runtime['actions'] == ['update'] and changed_fields(runtime) == {'policy'} and
                    not unknown(runtime.get('after_unknown') or {}) and
                    policy_shape(runtime['before']['policy']) == policy_shape(runtime_before_kms_fix()), 'Exact pre-repair runtime policy required')
            require(all(row['change']['actions'] == ['no-op'] and row['change']['before'] == row['change']['after'] and
                        not unknown(row['change'].get('after_unknown') or {})
                        for row in managed if row['address'] != 'aws_iam_policy.analysis_runtime'), 'KMS repair must preserve every other resource')
        else:
            if 'aws_iam_role_policy.history_analysis[0]' in addresses:
                require('aws_iam_role_policy.history_analysis[0]' in changed, 'History policy correction required')
            require(required <= changed, 'Incomplete retirement transition')
            require(any(row['address'].startswith('aws_lambda_permission.allow_api_gateway_invoke_analysis') and
                        row['change'].get('before') and not row['change']['before'].get('qualifier') and
                        'delete' in row['change'].get('actions', []) for row in managed), 'Old unqualified invoke permission must be removed')
    changes = []
    for row in managed:
        actions = row['change'].get('actions')
        if actions != ['no-op']:
            if bounded:
                require(row['address'] in ALLOWED and actions in (['create'], ['update'], ['delete'], ['delete', 'create'], ['create', 'delete']), 'Out-of-scope action')
            changes.append({'address': row['address'], 'actions': actions})
    require(not any(row.get('status') == 'fail' for row in plan.get('checks', [])), 'Failed plan check')
    if bounded:
        require(tuple(variables.get(key) for key in ('environment', 'aws_region', 'project_name')) == ('dev', 'us-east-1', 'trustcheckradar'), 'Dev only')
        require(bucket == 'trustcheckradar-dev-107827791950-artifacts' and after.get('function_name') == 'trustcheckradar-dev-conversation-analysis', 'Wrong Dev target')
        bounded_shapes(plan, managed, function, post_apply=post_apply, runtime_repair=runtime_repair)
        if post_apply or runtime_repair:
            require(after.get('code_sha256') == sha, 'Applied Lambda bytes differ from the qualified archive')
        # Do not change code or activate unrelated services in this IAM/routing correction.
        before = function['change'].get('before') or {}
        for key in ('s3_bucket', 's3_key', 's3_object_version', 'source_code_hash', 'reserved_concurrent_executions', 'timeout', 'memory_size', 'architectures', 'handler', 'runtime'):
            require(before.get(key) == after.get(key), 'Unexpected runtime/code activation')
        env = after.get('environment', [{}])[0].get('variables', {})
        require(env.get('HISTORY_WRITES_ENABLED') == 'false' and env.get('HISTORY_DURABLE_REPLAY_ENABLED') == 'false' and env.get('RECOGNITION_ENABLED') == 'false', 'Replay gates required')
        require(not any(key.startswith(('OPENAI_', 'FREE_', 'PRO_', 'PARTICIPATING_FREE_', 'ENTITLEMENT', 'CAMPAIGN_OUTBOX_')) for key in env), 'Legacy dispatch configuration')
    stable = {'revision': revision, 'runtimeKmsRepair': runtime_repair, 'terraform_version': plan.get('terraform_version'), 'variables': plan.get('variables'),
              'managed': sorted(managed, key=lambda row: row['address']), 'configuration': plan.get('configuration'),
              'managedDrift': sorted((row for row in plan.get('resource_drift', []) if row.get('mode') == 'managed'), key=lambda row: row['address'])}
    digest = hashlib.sha256(json.dumps(stable, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'revision': revision, 'reviewedPlanDigest': digest, 'changes': sorted(changes, key=lambda row: row['address']),
            'verifiedAutomaticStageReadbacks': sum(automatic_stage_readback(plan, row) for row in plan.get('resource_drift', []) if row.get('mode') == 'managed'),
            'verifiedPostApplyRoleReadbacks': sum(post_role_readback(plan, row, runtime_repair=runtime_repair) for row in plan.get('resource_drift', []) if (post_apply or runtime_repair) and row.get('mode') == 'managed'),
            'runtimeKmsRepair': runtime_repair,
            'artifact': {'bucket': bucket, 'key': after['s3_key'], 'version': version, 'source_hash': sha}}


def verify_archive(artifact, download=None):
    with tempfile.TemporaryDirectory(prefix='analysis-retirement-') as directory:
        target = Path(directory) / 'archive.zip'
        if download is None:
            result = subprocess.run(['aws', 's3api', 'get-object', '--bucket', artifact['bucket'], '--key', artifact['key'],
                '--version-id', artifact['version'], str(target), '--output', 'json'], capture_output=True, check=True, text=True)
            metadata = json.loads(result.stdout)
        else:
            metadata = download(artifact, target)
        require(metadata.get('VersionId') == artifact['version'], 'Downloaded version differs')
        sha = base64.b64encode(hashlib.sha256(target.read_bytes()).digest()).decode()
        require(sha == artifact['source_hash'], 'Downloaded archive differs from qualified bytes')


def authorize(report, expected, apply):
    require(not apply or expected == report['reviewedPlanDigest'], 'Exact reviewed digest required before apply')
    if expected:
        require(expected == report['reviewedPlanDigest'], 'Reviewed digest differs')


def ordinary_guard(plan):
    require(not any(row.get('mode') == 'managed' and row.get('address') in ALLOWED and
                    row.get('change', {}).get('actions') != ['no-op'] for row in plan.get('resource_changes', [])),
            'Retirement changes require the isolated reviewed Dev workflow')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--bounded-dev', action='store_true')
    parser.add_argument('--expected-digest')
    parser.add_argument('--post-apply', action='store_true')
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--runtime-kms-repair', action='store_true')
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text())
    if not args.bounded_dev:
        ordinary_guard(plan)
    report = review(plan, args.revision, bounded=args.bounded_dev, post_apply=args.post_apply, runtime_repair=args.runtime_kms_repair)
    require(not args.post_apply or args.bounded_dev, 'Post-apply verification requires bounded Dev mode')
    authorize(report, args.expected_digest, args.apply)
    verify_archive(report.pop('artifact'))
    report['archiveVerified'] = True
    report['postApplyVerified'] = args.post_apply
    # Only aggregate changes/digest; never print environment, state or account data.
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit(safe_failure_message(error)) from None
