import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('governed_history_plan', Path(__file__).resolve().parents[1] / 'verify_governed_history_plan.py')
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)
REVISION = 'b' * 40


def fixture(scope='reader', mode='inactive'):
    variables = {'environment': 'dev', 'aws_region': 'us-east-1', 'project_name': 'trustcheckradar'}
    resources = []
    if scope == 'index':
        variables['governed_history_index_enabled'] = mode == 'active'
        before = {'billing_mode': 'PAY_PER_REQUEST', 'arn': v.AUTHORITY, 'name': v.PREFIX + '-purchase-entitlements', 'attribute': [{'name': 'PK', 'type': 'S'}, {'name': 'SK', 'type': 'S'}], 'global_secondary_index': [], 'ttl': [{'enabled': True, 'attribute_name': 'expiresAt'}], 'point_in_time_recovery': [{'enabled': True}]}
        after = copy.deepcopy(before)
        if mode == 'active':
            after['attribute'] += [{'name': k, 'type': 'S'} for k in ('GSI2PK', 'GSI2SK')]
            after['global_secondary_index'] = [{'name': 'GSI2', 'hash_key': 'GSI2PK', 'range_key': 'GSI2SK', 'projection_type': 'INCLUDE', 'non_key_attributes': sorted(v.PROJECTION)}]
        resources.append({'address': 'aws_dynamodb_table.purchase_entitlements', 'mode': 'managed', 'change': {'actions': ['update'] if mode == 'active' else ['no-op'], 'before': before, 'after': after}})
    else:
        dep = {field: f'arn:aws:dynamodb:us-east-1:{v.ACCOUNT}:table/{v.PREFIX}-{suffix}' for field, suffix in {'users_table_arn': 'users', 'devices_table_arn': 'device-bindings', 'deletion_table_arn': 'deletion-ledger', 'authority_table_arn': 'purchase-entitlements'}.items()}
        dep.update(authority_hmac_secret_arn=f'arn:aws:secretsmanager:us-east-1:{v.ACCOUNT}:secret:trustcheckradar/dev/v1-authority-hmac-ABC123', cognito_issuer='https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ', cognito_app_client_id='5kvl9a8jo4fr1qqnci27tdabk4', artifacts={'reader': {'bucket': f'{v.PREFIX}-{v.ACCOUNT}-artifacts', 'key': 'releases/' + 'a' * 40 + '/governed_history.zip', 'object_version': 'version1', 'source_hash': 'A' * 43 + '='}})
        variables.update(authority_partitions=[] if mode == 'inactive' else ['V1#test#' + 'a' * 64], enabled=True, list_enabled=mode in ('list', 'both'), detail_enabled=mode in ('detail', 'both'), index_ready=mode != 'inactive', engineering_subjects=[] if mode == 'inactive' else ['11111111-1111-4111-8111-111111111111'], deployment=dep, api_gateway={'api_id': 'icuak34th9', 'execution_arn': f'arn:aws:execute-api:us-east-1:{v.ACCOUNT}:icuak34th9', 'authorizer_id': 'itms4b'})
        role = f'arn:aws:iam::{v.ACCOUNT}:role/{v.PREFIX}-governed-history-execution'
        values = {
            'aws_cloudwatch_log_group.runtime["reader"]': {'name': '/aws/lambda/' + v.PREFIX + '-governed-history', 'retention_in_days': 14},
            'aws_iam_role.runtime["reader"]': {'name': v.PREFIX + '-governed-history-execution', 'id': 'execution-role-id', 'arn': role, 'assume_role_policy': json.dumps({'Version': '2012-10-17', 'Statement': [{'Effect': 'Allow', 'Action': 'sts:AssumeRole', 'Principal': {'Service': 'lambda.amazonaws.com'}}]})},
            'aws_iam_role_policy.reader[0]': {'name': 'fenced-governed-history-read-only', 'role': 'execution-role-id', 'policy': json.dumps(v.reader_policy(dep, variables['engineering_subjects'], variables['authority_partitions']))},
            'aws_lambda_function.runtime["reader"]': {'function_name': v.PREFIX + '-governed-history', 'handler': 'governed_history.app.lambda_handler', 'runtime': 'python3.14', 'architectures': ['arm64'], 'timeout': 23, 'memory_size': 256, 'reserved_concurrent_executions': 2, 'publish': True, 'role': role, 'version': '7', 's3_bucket': dep['artifacts']['reader']['bucket'], 's3_key': dep['artifacts']['reader']['key'], 's3_object_version': 'version1', 'source_code_hash': 'A' * 43 + '=', 'environment': [{'variables': v.reader_environment(variables)}]},
            'aws_lambda_alias.runtime["reader"]': {'name': 'live', 'function_name': v.PREFIX + '-governed-history', 'function_version': '7', 'invoke_arn': 'reviewed-reader-alias'},
            'aws_lambda_function_event_invoke_config.no_async_retries["reader"]': {'function_name': v.PREFIX + '-governed-history', 'qualifier': 'live', 'maximum_retry_attempts': 0, 'maximum_event_age_in_seconds': 60},
            'aws_apigatewayv2_integration.history[0]': {'id': 'integration1', 'api_id': 'icuak34th9', 'integration_type': 'AWS_PROXY', 'integration_uri': 'reviewed-reader-alias', 'integration_method': 'POST', 'payload_format_version': '2.0', 'timeout_milliseconds': 29000},
        }
        for name in ('list', 'detail'):
            values[f'aws_apigatewayv2_route.history["{name}"]'] = {'api_id': 'icuak34th9', 'route_key': 'GET /v1/users/analysis-history' + ('/{resultId}' if name == 'detail' else ''), 'target': 'integrations/integration1', 'authorization_type': 'JWT', 'authorizer_id': 'itms4b', 'authorization_scopes': ['aws.cognito.signin.user.admin']}
            values[f'aws_lambda_permission.history["{name}"]'] = {'action': 'lambda:InvokeFunction', 'principal': 'apigateway.amazonaws.com', 'function_name': v.PREFIX + '-governed-history', 'qualifier': 'live', 'source_account': v.ACCOUNT, 'source_arn': f'arn:aws:execute-api:us-east-1:{v.ACCOUNT}:icuak34th9/*/GET/v1/users/analysis-history' + ('/*' if name == 'detail' else '')}
        resources = [{'address': k, 'mode': 'managed', 'change': {'actions': ['create'], 'before': None, 'after': value}} for k, value in values.items()]
    return sync({'complete': True, 'errored': False, 'terraform_version': '1.12.1', 'variables': {k: {'value': value} for k, value in variables.items()}, 'resource_changes': resources})


def sync(plan):
    plan['planned_values'] = {'root_module': {'resources': [{'address': item['address'], 'mode': 'managed', 'values': copy.deepcopy(item['change']['after'])} for item in plan['resource_changes']]}}
    return plan


def resource(plan, prefix):
    return next(v for v in plan['resource_changes'] if v['address'].startswith(prefix))['change']['after']


class GovernedHistoryPlanTests(unittest.TestCase):
    def test_approved_reader_modes_and_sparse_index(self):
        for scope, modes in [('reader', ('inactive', 'list', 'detail', 'both')), ('index', ('inactive', 'active'))]:
            for mode in modes:
                with self.subTest(scope=scope, mode=mode):
                    result = v.review(fixture(scope, mode), REVISION, scope, mode)
                    self.assertEqual(len(result['reviewedPlanDigest']), 64)

    def test_wrong_environment_incomplete_inventory_and_drift(self):
        for mutation in ('env', 'empty', 'partial', 'drift', 'snapshot'):
            plan = fixture()
            if mutation == 'env': plan['variables']['environment']['value'] = 'uat'
            if mutation == 'empty': plan['resource_changes'] = []; sync(plan)
            if mutation == 'partial': plan['resource_changes'].pop(); sync(plan)
            if mutation == 'drift': plan['resource_drift'] = [{'mode': 'managed', 'change': {'actions': ['update']}}]
            if mutation == 'snapshot': plan['planned_values']['root_module']['resources'][0]['values']['retention_in_days'] = 365
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): v.review(plan, REVISION, 'reader', 'inactive')

    def test_route_backend_role_alias_and_async_destination_cannot_escape(self):
        for prefix, field, value in [('aws_apigatewayv2_route.', 'target', 'integrations/other'), ('aws_apigatewayv2_integration.', 'integration_uri', 'unrelated-alias'), ('aws_apigatewayv2_integration.', 'integration_method', 'GET'), ('aws_lambda_function.', 'role', 'arn:aws:iam::107827791950:role/admin'), ('aws_lambda_alias.', 'function_version', '2'), ('aws_lambda_function_event_invoke_config.', 'destination_config', [{'on_failure': [{'destination': 'arn:unreviewed'}]}])]:
            plan = fixture(); resource(plan, prefix)[field] = value; sync(plan)
            with self.subTest(field=field), self.assertRaises(ValueError): v.review(plan, REVISION, 'reader', 'inactive')

    def test_policy_expansion_or_unrelated_activation_is_rejected(self):
        plan = fixture(); policy = json.loads(resource(plan, 'aws_iam_role_policy.')['policy']); policy['Statement'].append({'Effect': 'Allow', 'Action': '*', 'Resource': '*'})
        resource(plan, 'aws_iam_role_policy.')['policy'] = json.dumps(policy); sync(plan)
        with self.assertRaises(ValueError): v.review(plan, REVISION, 'reader', 'inactive')
        plan = fixture('reader', 'both'); resource(plan, 'aws_lambda_function.')['environment'][0]['variables']['HISTORY_READS_ENABLED'] = 'true'; sync(plan)
        with self.assertRaises(ValueError): v.review(plan, REVISION, 'reader', 'both')

    def test_retention_backup_and_sensitive_projection_changes_are_rejected(self):
        for field, value in [('ttl', [{'enabled': False}]), ('point_in_time_recovery', [{'enabled': False}]), ('global_secondary_index', [{'name': 'GSI2', 'hash_key': 'GSI2PK', 'range_key': 'GSI2SK', 'projection_type': 'ALL'}])]:
            plan = fixture('index', 'active'); resource(plan, 'aws_dynamodb_table.')[field] = value; sync(plan)
            with self.subTest(field=field), self.assertRaises(ValueError): v.review(plan, REVISION, 'index', 'active')

    def test_malformed_flags_and_empty_active_subjects_are_rejected(self):
        for value in ('true', 1, None):
            plan = fixture('reader', 'both'); plan['variables']['list_enabled']['value'] = value
            with self.subTest(value=value), self.assertRaises(ValueError): v.review(plan, REVISION, 'reader', 'both')
        plan = fixture('reader', 'both'); plan['variables']['engineering_subjects']['value'] = []
        with self.assertRaises(ValueError): v.review(plan, REVISION, 'reader', 'both')

    def test_noop_inventory_is_still_verified(self):
        plan = fixture('reader', 'both')
        for item in plan['resource_changes']: item['change']['actions'] = ['no-op']; item['change']['before'] = copy.deepcopy(item['change']['after'])
        self.assertEqual(v.review(plan, REVISION, 'reader', 'both')['resourceChanges'], 0)
        resource(plan, 'aws_lambda_alias.')['function_version'] = '1'; sync(plan)
        with self.assertRaises(ValueError): v.review(plan, REVISION, 'reader', 'both')
