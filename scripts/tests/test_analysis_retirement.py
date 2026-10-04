import ast
import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location('retirement', Path(__file__).resolve().parents[1] / 'verify_analysis_retirement.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
REVISION = '1' * 40
RELEASE = 'd98ffd65b42d54953ad83e980e58846b6fc02c5d'
VERSION = 'K6SXSdTc6rYObyN4qxbRVGTbsNvxAuU1'
SHA = 'vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4='
NAME = 'trustcheckradar-dev-conversation-analysis'


def fixture():
    env = {'APP_ENVIRONMENT': 'dev', 'COGNITO_REQUIRED_SCOPE': 'aws.cognito.signin.user.admin',
           'COGNITO_ISSUER': 'synthetic-issuer', 'COGNITO_APP_CLIENT_ID': 'synthetic-client',
           'USERS_TABLE_NAME': 'trustcheckradar-dev-users', 'DEVICE_BINDINGS_TABLE_NAME': 'trustcheckradar-dev-device-bindings',
           'ANALYSIS_ABUSE_TABLE_NAME': 'trustcheckradar-dev-analysis-abuse-control', 'DELETION_LEDGER_TABLE_NAME': 'trustcheckradar-dev-deletion-ledger',
           'HISTORY_MAX_SUMMARY_BYTES': '4096', 'HISTORY_MAX_LIST_ITEMS': '20', 'HISTORY_MAX_TEXT_FIELD_BYTES': '1024',
           'HISTORY_CONTENT_TABLE_NAME': 'trustcheckradar-dev-history-content', 'HISTORY_CONTROL_TABLE_NAME': 'trustcheckradar-dev-history-control',
           'HISTORY_MAX_RESPONSE_BYTES': '262144', 'HISTORY_WRITES_ENABLED': 'false', 'HISTORY_DURABLE_REPLAY_ENABLED': 'false', 'RECOGNITION_ENABLED': 'false'}
    fn = {'function_name': NAME, 'role': 'synthetic-role', 's3_bucket': 'trustcheckradar-dev-107827791950-artifacts',
          's3_key': 'releases/'+RELEASE+'/conversation_analysis.zip', 's3_object_version': VERSION, 'source_code_hash': SHA,
          'publish': True, 'runtime': 'python3.14', 'architectures': ['arm64'], 'handler': 'app.lambda_handler',
          'reserved_concurrent_executions': 5, 'timeout': 29, 'memory_size': 256, 'environment': [{'variables': env}]}
    old = copy.deepcopy(fn)
    old['publish'] = False
    old['environment'][0]['variables']['OPENAI_SECRET_ARN'] = 'synthetic-old-unused-secret-reference'
    def row(address, actions, before, after):
        return {'address': address, 'mode': 'managed', 'change': {'actions': actions, 'before': before, 'after': after, 'after_unknown': {}}}
    permission = {'function_name': NAME, 'qualifier': 'retired', 'source_account': '107827791950', 'principal': 'apigateway.amazonaws.com',
                  'action': 'lambda:InvokeFunction', 'statement_id': 'AllowExecutionFromApiGatewayAnalysis',
                  'source_arn': 'arn:aws:execute-api:us-east-1:107827791950:example1234/$default/POST/analysis'}
    old_permission = dict(permission, qualifier=None, source_arn='arn:aws:execute-api:us-east-1:107827791950:example1234/*/*')
    return {'complete': True, 'errored': False, 'terraform_version': '1.12.1',
      'variables': {key: {'value': value} for key, value in {
         'environment': 'dev', 'aws_region': 'us-east-1', 'project_name': 'trustcheckradar', 'analysis_legacy_path_enabled': False,
         'analysis_retirement_deployment': {'release_id': RELEASE, 'object_version': VERSION, 'source_hash': SHA}}.items()},
      'resource_changes': [row('aws_lambda_function.analysis', ['update'], old, fn),
         row('aws_iam_policy.analysis_runtime', ['update'], {'policy': '{}'}, {'policy': MODULE.runtime_policy()}),
         row('aws_lambda_alias.analysis_retired[0]', ['create'], None, {'name': 'retired', 'function_name': NAME, 'function_version': None, 'routing_config': []}),
         row('aws_apigatewayv2_integration.analysis_lambda', ['update'], {'integration_uri': 'unqualified', 'integration_method': 'POST'}, {'integration_uri': None, 'integration_method': 'POST'}),
         row('aws_lambda_permission.allow_api_gateway_invoke_analysis[0]', ['delete', 'create'], old_permission, permission)],
      'configuration': {'root_module': {'resources': [
         {'address': 'aws_lambda_alias.analysis_retired', 'expressions': {'function_version': {'references': ['aws_lambda_function.analysis.version']}}},
         {'address': 'aws_apigatewayv2_integration.analysis_lambda', 'expressions': {'integration_uri': {'references': ['aws_lambda_alias.analysis_retired[0].invoke_arn']}}}]}},
      'resource_drift': [], 'checks': []}


class RetirementTests(unittest.TestCase):
    def rejected(self, mutate):
        plan = fixture()
        mutate(plan)
        with self.assertRaises(ValueError):
            MODULE.review(plan, REVISION, bounded=True)

    def test_diagnostics_use_only_static_check_labels(self):
        tree = ast.parse(Path(MODULE.__file__).read_text())
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == 'require':
                self.assertIsInstance(node.args[1], ast.Constant)
                self.assertIsInstance(node.args[1].value, str)
        with self.assertRaises(MODULE.ReviewRejected) as caught:
            MODULE.require(False, 'Managed drift requires review')
        self.assertIn('Managed drift requires review', MODULE.safe_failure_message(caught.exception))
        for error in [ValueError('private-plan-value'), RuntimeError('private-sdk-value')]:
            self.assertNotIn('private', MODULE.safe_failure_message(error))

    def test_drift_diagnostics_redact_all_plan_values_and_unknown_labels(self):
        plan = fixture()
        plan['resource_drift'] = [
            {'mode': 'managed', 'address': 'aws_iam_role.analysis', 'change': {
                'before': {'inline_policy': 'private-old'}, 'after': {'inline_policy': 'private-new'}}},
            {'mode': 'managed', 'address': 'private-resource', 'change': {
                'before': {'private-field': 'private-old'}, 'after': {'private-field': 'private-new'}}},
        ]
        report = MODULE.safe_drift_summary(plan)
        self.assertEqual(report, {'managedDrift': [
            {'resource': 'analysis role', 'fields': ['inline_policy'], 'otherFieldCount': 0},
            {'resource': 'other managed resource', 'fields': [], 'otherFieldCount': 1}]})
        self.assertNotIn('private', json.dumps(report))
        with self.assertRaises(MODULE.ReviewRejected):
            MODULE.review(plan, REVISION, bounded=True)

    def test_bounded_transition_and_digest(self):
        report = MODULE.review(fixture(), REVISION, bounded=True)
        self.assertEqual(len(report['changes']), 5)
        MODULE.authorize(report, report['reviewedPlanDigest'], True)
        with self.assertRaises(ValueError):
            MODULE.authorize(report, 'wrong', True)
        with self.assertRaises(ValueError):
            MODULE.authorize(report, None, True)

    def test_version_and_hash_are_exact(self):
        for key, value in [('object_version', 'other'), ('source_hash', 'A'*43+'='), ('release_id', '2'*40)]:
            with self.subTest(key=key):
                self.rejected(lambda p: p['variables']['analysis_retirement_deployment']['value'].__setitem__(key, value))

    def test_dev_catalog_cannot_be_used_elsewhere(self):
        for env in ['uat', 'prod']:
            with self.subTest(env=env):
                self.rejected(lambda p: p['variables']['environment'].__setitem__('value', env))

    def test_other_capability_or_drift_rejected(self):
        self.rejected(lambda p: p['resource_changes'].append({'address': 'aws_lambda_function.account_data[0]', 'mode': 'managed', 'change': {'actions': ['update'], 'before': {}, 'after': {}}}))
        self.rejected(lambda p: p['resource_drift'].append({'address': 'aws_lambda_function.analysis', 'mode': 'managed'}))

    def test_omitted_or_noop_transition_is_not_acceptance(self):
        self.rejected(lambda p: p['resource_changes'].pop(1))
        self.rejected(lambda p: p['resource_changes'][1]['change'].__setitem__('actions', ['no-op']))

    def test_function_role_and_unknown_network_changes_rejected(self):
        self.rejected(lambda p: p['resource_changes'][0]['change']['after'].__setitem__('role', 'changed-role'))
        self.rejected(lambda p: p['resource_changes'][0]['change']['after_unknown'].__setitem__('vpc_config', True))

    def test_env_cannot_reactivate_provider_or_work(self):
        for key in ['OPENAI_SECRET_ARN', 'FREE_MONTHLY_SCAN_LIMIT', 'CAMPAIGN_PERIOD_WORK_ENABLED']:
            with self.subTest(key=key):
                self.rejected(lambda p: p['resource_changes'][0]['change']['after']['environment'][0]['variables'].__setitem__(key, 'true'))

    def test_runtime_policy_cannot_broaden(self):
        self.rejected(lambda p: p['resource_changes'][1]['change']['after'].__setitem__('policy', json.dumps({'Version': '2012-10-17', 'Statement': [{'Effect': 'Allow', 'Action': '*', 'Resource': '*'}]})))

    def test_alias_cannot_use_latest_weighted_or_wrong_reference(self):
        self.rejected(lambda p: p['resource_changes'][2]['change']['after'].__setitem__('function_version', '$LATEST'))
        self.rejected(lambda p: p['resource_changes'][2]['change']['after'].__setitem__('routing_config', [{'additional_version_weights': {'3': 0.1}}]))
        self.rejected(lambda p: p['configuration']['root_module']['resources'][0]['expressions']['function_version'].__setitem__('references', ['var.unsafe_version']))

    def test_integration_cannot_point_to_latest(self):
        self.rejected(lambda p: p['resource_changes'][3]['change']['after'].__setitem__('integration_uri', 'unqualified'))

    def test_permission_cannot_broaden_or_activate_legacy(self):
        for key, value in [('qualifier', None), ('source_account', '999999999999'), ('source_arn', 'arn:aws:execute-api:us-east-1:107827791950:example1234/*/*')]:
            with self.subTest(key=key):
                self.rejected(lambda p: p['resource_changes'][4]['change']['after'].__setitem__(key, value))
        self.rejected(lambda p: p['variables']['analysis_legacy_path_enabled'].__setitem__('value', True))

    def test_ordinary_deploy_cannot_bypass_reviewed_transition(self):
        plan = fixture()
        with self.assertRaises(ValueError):
            MODULE.ordinary_guard(plan)
        for row in plan['resource_changes']:
            row['change']['actions'] = ['no-op']
        MODULE.ordinary_guard(plan)

    def test_old_unqualified_permission_must_be_removed(self):
        self.rejected(lambda p: p['resource_changes'][4]['change'].update(actions=['create'], before=None))

    def test_post_apply_checks_active_shapes_even_when_noop(self):
        plan = fixture()
        for row in plan['resource_changes']:
            row['change']['actions'] = ['no-op']
            row['change']['before'] = copy.deepcopy(row['change']['after'])
        plan['resource_changes'][0]['change']['after']['code_sha256'] = SHA
        plan['resource_changes'][0]['change']['before']['code_sha256'] = SHA
        plan['resource_changes'][2]['change']['after']['function_version'] = '4'
        plan['resource_changes'][2]['change']['before']['function_version'] = '4'
        MODULE.review(plan, REVISION, bounded=True, post_apply=True)
        for mutate in [
            lambda p: p['resource_changes'][1]['change']['after'].__setitem__('policy', '{}'),
            lambda p: p['resource_changes'][2]['change']['after'].__setitem__('routing_config', [{'additional_version_weights': {'2': .1}}]),
            lambda p: p['resource_changes'][3]['change']['after'].__setitem__('integration_uri', 'unqualified'),
            lambda p: p['resource_changes'][4]['change']['after'].__setitem__('qualifier', None),
            lambda p: p['resource_changes'][0]['change']['after'].__setitem__('code_sha256', 'wrong'),
        ]:
            with self.subTest(mutate=mutate):
                bad = copy.deepcopy(plan)
                mutate(bad)
                # Simulate refreshed no-op state, so changed-fields cannot alone catch it.
                for row in bad['resource_changes']:
                    row['change']['before'] = copy.deepcopy(row['change']['after'])
                with self.assertRaises((ValueError, KeyError)):
                    MODULE.review(bad, REVISION, bounded=True, post_apply=True)

    def test_archive_bytes_and_version_verified(self):
        data = b'synthetic-qualified-archive'
        artifact = {'bucket': 'synthetic', 'key': 'synthetic', 'version': 'v1', 'source_hash': base64.b64encode(hashlib.sha256(data).digest()).decode()}
        def download(value, path):
            path.write_bytes(data)
            return {'VersionId': 'v1'}
        MODULE.verify_archive(artifact, download)
        with self.assertRaises(ValueError):
            MODULE.verify_archive(dict(artifact, source_hash='A'*43+'='), download)
        with self.assertRaises(ValueError):
            MODULE.verify_archive(dict(artifact, version='v2'), download)


if __name__ == '__main__':
    unittest.main()
