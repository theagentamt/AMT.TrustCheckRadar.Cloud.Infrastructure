import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_governed_trial_plan as gate
from test_trial_authority_transition import fixture as legacy_fixture, SUBJECT, REVISION


def fixture(mode='trial'):
    plan = legacy_fixture('inactive')
    variables = {k: v['value'] for k, v in plan['variables'].items()}
    subjects = [SUBJECT] if mode == 'trial' else []
    variables['governed_trial_subjects'] = subjects
    plan['variables']['governed_trial_subjects'] = {'value': subjects}
    for item in plan['resource_changes']:
        item['provider_name'] = 'registry.terraform.io/hashicorp/aws'
        value = item['change']['after']
        value['environment'][0]['variables']['AUTHORITY_HMAC_SECRET_ARN'] = 'arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123' if item['address'] != 'aws_lambda_function.runtime["recovery"]' else None
        if value['environment'][0]['variables']['AUTHORITY_HMAC_SECRET_ARN'] is None:
            value['environment'][0]['variables'].pop('AUTHORITY_HMAC_SECRET_ARN')
        value['version'] = '13'
        item['change']['before'] = copy.deepcopy(value)
        item['change']['actions'] = ['no-op']
        if item['address'] == gate.FUNCTION and subjects:
            value['environment'][0]['variables']['DEV_SUBJECT_ALLOWLIST_JSON'] = json.dumps(subjects, separators=(',', ':'))
            value['environment'][0]['variables']['TRIAL_AUTHORITY_RETENTION_APPROVED'] = 'true'
            value['version'] = None
            item['change']['actions'] = ['update']
            item['change']['after_unknown'] = {'version': True}
    alias = {'name': 'live', 'function_name': 'trustcheckradar-dev-v1-entitlements', 'function_version': '13', 'routing_config': []}
    plan['resource_changes'].append({'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws', 'address': gate.ALIAS, 'change': {'actions': ['update'] if subjects else ['no-op'], 'before': alias, 'after': dict(alias, function_version=None) if subjects else copy.deepcopy(alias), 'after_unknown': {'function_version': True} if subjects else {}}})
    plan['configuration'] = {'root_module': {'resources': [{'address': 'aws_lambda_alias.runtime', 'expressions': {'function_version': {'references': ['aws_lambda_function.runtime', 'each.key']}}}]}}
    plan['output_changes']['candidate_contract']['after'].update({'access_enabled': bool(subjects), 'trial_activation_enabled': bool(subjects), 'governed_trial_only_engineering': bool(subjects), 'governed_trial_subject_count': len(subjects)})
    return plan


class GovernedTrialTests(unittest.TestCase):
    def test_active_and_inactive_preserve_unrelated_capabilities(self):
        self.assertEqual(gate.review(fixture(), REVISION, 'trial')[2:], (2, 1))
        self.assertEqual(gate.review(fixture('inactive'), REVISION, 'inactive')[2:], (0, 0))

    def test_admission_cannot_expand_to_other_accounts_or_modes(self):
        for key, value in [('governed_trial_subjects', [SUBJECT, '00000000-0000-4000-8000-000000000001']), ('governed_trial_subjects', ['*']), ('engineering_subjects', [SUBJECT]), ('activate_trial_engineering', True), ('activate_engineering', True), ('environment', 'prod')]:
            plan = fixture()
            plan['variables'][key]['value'] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                gate.review(plan, REVISION, 'trial')

    def test_unrelated_resources_and_hidden_config_changes_rejected(self):
        for address in ('aws_lambda_function.runtime["deletion"]', 'aws_lambda_function.runtime["recovery"]', 'aws_lambda_function.runtime["consumer"]', gate.FUNCTION):
            plan = fixture()
            item = next(x for x in plan['resource_changes'] if x['address'] == address)
            item['change']['after']['timeout'] += 1
            item['change']['actions'] = ['update']
            with self.subTest(address=address), self.assertRaises(ValueError):
                gate.review(plan, REVISION, 'trial')
        for kind in ('aws_iam_role_policy.extra', 'aws_apigatewayv2_route.extra', 'aws_cloudwatch_event_rule.extra'):
            plan = fixture()
            plan['resource_changes'].append({'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws', 'address': kind, 'change': {'actions': ['create'], 'before': None, 'after': {}}})
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                gate.review(plan, REVISION, 'trial')

    def test_provider_package_and_function_identity_cannot_change(self):
        for field, value in [('s3_key', 'releases/' + 'f' * 40 + '/v1_entitlements.zip'), ('function_name', 'trustcheckradar-prod-v1-entitlements'), ('handler', 'other.handler'), ('reserved_concurrent_executions', 100)]:
            plan = fixture()
            item = next(x for x in plan['resource_changes'] if x['address'] == gate.FUNCTION)
            item['change']['after'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                gate.review(plan, REVISION, 'trial')
        plan = fixture()
        plan['resource_changes'][0]['provider_name'] = 'untrusted/aws'
        with self.assertRaises(ValueError): gate.review(plan, REVISION, 'trial')

    def test_drift_and_incomplete_runtime_inventory_rejected(self):
        plan = fixture()
        plan['resource_drift'] = [{'mode': 'managed'}]
        with self.assertRaises(ValueError): gate.review(plan, REVISION, 'trial')

    def test_alias_cannot_select_an_unreviewed_version(self):
        for value in ('1', '13'):
            plan = fixture()
            next(x for x in plan['resource_changes'] if x['address'] == gate.ALIAS)['change']['after']['function_version'] = value
            with self.subTest(value=value), self.assertRaises(ValueError): gate.review(plan, REVISION, 'trial')
        plan = fixture()
        plan['configuration']['root_module']['resources'][0]['expressions']['function_version']['references'] = ['var.unreviewed_version']
        with self.assertRaises(ValueError): gate.review(plan, REVISION, 'trial')
        plan = fixture()
        plan['resource_changes'] = [x for x in plan['resource_changes'] if x['address'] != 'aws_lambda_function.runtime["deletion"]']
        with self.assertRaises(ValueError): gate.review(plan, REVISION, 'trial')

    def test_digest_changes_with_subject_and_mode(self):
        plan = fixture()
        original = gate.review(plan, REVISION, 'trial')[1]
        self.assertNotEqual(original, gate.review(plan, 'c' * 40, 'trial')[1])
        self.assertNotEqual(original, gate.review(fixture('inactive'), REVISION, 'inactive')[1])

    def test_readback_refuses_changed_unrelated_runtime(self):
        plan = fixture()
        def read(service, operation, *args):
            if service == 'sts': return {'Account': '107827791950'}
            name = args[args.index('--function-name') + 1]
            value = next(x['change']['after'] for x in plan['resource_changes'] if x['address'].startswith('aws_lambda_function.') and x['change']['after']['function_name'] == name)
            if operation == 'get-function-concurrency': return {'ReservedConcurrentExecutions': value['reserved_concurrent_executions']}
            result = {public: value[tf] for public, tf in {'FunctionName': 'function_name', 'CodeSha256': 'source_code_hash', 'Runtime': 'runtime', 'Architectures': 'architectures', 'Role': 'role', 'Handler': 'handler', 'Timeout': 'timeout', 'MemorySize': 'memory_size'}.items()}
            result['Environment'] = {'Variables': copy.deepcopy(value['environment'][0]['variables'])}
            return result
        self.assertTrue(gate.readback(plan, read)['accessReadbackVerified'])
        def wrong(*args):
            result = read(*args)
            if result.get('FunctionName') == 'trustcheckradar-dev-v1-authority-deletion': result['Environment']['Variables']['DEV_SUBJECT_ALLOWLIST_JSON'] = '["*"]'
            return result
        with self.assertRaises(ValueError): gate.readback(plan, wrong)
