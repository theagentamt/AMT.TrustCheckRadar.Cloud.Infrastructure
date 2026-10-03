import copy
import importlib.util
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_candidate3_rules_plan as v
spec = importlib.util.spec_from_file_location('legacy_transition_fixture', Path(__file__).with_name('test_message_consumer_transition.py'))
f = importlib.util.module_from_spec(spec); spec.loader.exec_module(f)


def fixture(mode='rules-only'):
    active = mode != 'inactive'
    plan = f.fixture('engineering' if active else 'inactive')
    vars = {k: val['value'] for k, val in plan['variables'].items()}
    vars.update(candidate3_rules_only_enabled=active, governed_history_settlement_enabled=mode == 'rules-only-history')
    plan['variables'] = {k: {'value': val} for k, val in vars.items()}
    for item in plan['resource_changes']:
        name = item['address'].split('"')[1]
        after = item['change']['after']
        if item['address'].startswith('aws_lambda_function.'):
            after['version'] = '7'
            env = after['environment'][0]['variables']
            env['MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED'] = str(active).lower()
            if name == 'consumer': env.update(GOVERNED_HISTORY_SETTLEMENT_ENABLED=str(mode == 'rules-only-history').lower(), MESSAGE_PROVIDER_CIRCUIT_OPEN='true')
        else: after['function_version'] = '7'
    import json
    plan['resource_changes'].append({'address': 'aws_iam_role_policy.evaluator[0]', 'mode': 'managed', 'change': {'actions': ['update'], 'before': {}, 'after': {'name': 'private-message-evaluation-only', 'role': 'trustcheckradar-dev-message-evaluator-execution', 'policy': json.dumps(v.evaluator_policy(vars['deployment'], active))}}})
    output = plan['output_changes']['candidate_contract']['after']
    output.update(candidate3_rules_only_enabled=active, governed_history_settlement_enabled=mode == 'rules-only-history', provider_circuit_open=True)
    return sync(plan)


def sync(plan):
    plan['planned_values'] = {'root_module': {'resources': [{'address': item['address'], 'mode': 'managed', 'values': copy.deepcopy(item['change']['after'])} for item in plan['resource_changes']]}}
    return plan


class Candidate3RulesPlanTests(unittest.TestCase):
    def test_exact_inactive_rules_and_history_transitions(self):
        for mode in ('inactive', 'rules-only', 'rules-only-history'):
            self.assertFalse(v.review(fixture(mode), f.REVISION, mode)['providerCallsEnabled'])

    def test_provider_permission_environment_alias_and_foreign_resources_are_rejected(self):
        for mutation in ('provider', 'env', 'alias', 'foreign', 'missing', 'numeric'):
            plan = fixture()
            if mutation == 'provider': plan['resource_changes'][-1]['change']['after']['policy'] = plan['resource_changes'][-1]['change']['after']['policy'].replace('"Deny", "Action": "lambda:InvokeFunction"', '"Allow", "Action": "lambda:InvokeFunction"')
            if mutation == 'env': plan['resource_changes'][0]['change']['after']['environment'][0]['variables']['MESSAGE_AI_ENABLED'] = 'true'
            if mutation == 'alias': next(i for i in plan['resource_changes'] if i['address'].startswith('aws_lambda_alias.'))['change']['after']['function_version'] = '2'
            if mutation == 'foreign': plan['resource_changes'].append({'address': 'aws_lambda_function.export', 'mode': 'managed', 'change': {'actions': ['update'], 'before': {}, 'after': {}}})
            if mutation == 'missing': plan['resource_changes'].pop()
            if mutation == 'numeric': plan['variables']['candidate3_rules_only_enabled']['value'] = 1
            sync(plan)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): v.review(plan, f.REVISION, 'rules-only')

    def test_noop_inventory_and_digest_are_verified(self):
        plan = fixture()
        for item in plan['resource_changes']: item['change']['actions'] = ['no-op']
        result = v.review(plan, f.REVISION, 'rules-only')
        self.assertEqual(result['resourceChanges'], 0)
        self.assertEqual(len(result['reviewedPlanDigest']), 64)
