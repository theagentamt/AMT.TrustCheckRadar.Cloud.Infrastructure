"""Keep initial AWS collection/policy readback distinct from substantive drift."""
import copy
import json
import unittest
import test_governed_history_plan as r
import test_candidate3_rules_plan as m
import verify_governed_history_plan as v
import verify_candidate3_rules_plan as c

PROVIDER = 'registry.terraform.io/hashicorp/aws'


def reader_plan():
    p = r.fixture('reader', 'both')
    variables = {k: val['value'] for k, val in p['variables'].items()}
    inactive = copy.deepcopy(variables)
    inactive.update(list_enabled=False, detail_enabled=False, engineering_subjects=[], authority_partitions=[], index_ready=False)
    policy_address = 'aws_iam_role_policy.reader[0]'
    by_address = {x['address']: x for x in p['resource_changes']}
    current_policy = copy.deepcopy(by_address[policy_address]['change']['after'])
    current_policy['policy'] = json.dumps(v.reader_policy(variables['deployment'], [], []))
    drifts = []
    fields = {
        'aws_apigatewayv2_integration.history[0]': {'request_parameters': {}, 'request_templates': {}},
        'aws_apigatewayv2_route.history["list"]': {'request_models': {}},
        'aws_apigatewayv2_route.history["detail"]': {'request_models': {}},
        'aws_cloudwatch_log_group.runtime["reader"]': {'tags': {}},
        'aws_iam_role.runtime["reader"]': {'tags': {}, 'inline_policy': [{'name': current_policy['name'], 'policy': current_policy['policy']}]},
        'aws_lambda_function.runtime["reader"]': {'layers': [], 'tags': {}},
    }
    for address, entry in by_address.items():
        change = entry['change']
        change['actions'] = ['no-op']
        change['before'] = copy.deepcopy(change['after'])
        if address == policy_address:
            change.update(actions=['update'], before=current_policy)
        if address not in fields:
            continue
        current = copy.deepcopy(change['after'])
        current.update(fields[address])
        if address.startswith('aws_lambda_function.'):
            current['environment'] = [{'variables': v.reader_environment(inactive)}]
            change.update(actions=['update'], before=current)
            change['after'].update(fields[address])
        else:
            change.update(before=current, after=current)
        previous = copy.deepcopy(current)
        for field in fields[address]:
            previous[field] = [] if field == 'inline_policy' else None
        drifts.append({'address': address, 'mode': 'managed', 'provider_name': PROVIDER,
                       'change': {'actions': ['update'], 'before': previous, 'after': current}})
    p['resource_drift'] = drifts
    return r.sync(p)


def message_plan(mode):
    p = m.fixture(mode)
    dep = p['variables']['deployment']['value']
    policy_entry = next(x for x in p['resource_changes'] if x['address'] == 'aws_iam_role_policy.evaluator[0]')
    current_policy = copy.deepcopy(policy_entry['change']['after'])
    current_policy['policy'] = json.dumps(c.evaluator_policy(dep, mode == 'inactive'))
    policy_entry['change']['before'] = current_policy
    role = {'name': c.PREFIX + '-message-evaluator-execution',
            'arn': f'arn:aws:iam::{c.ACCOUNT}:role/{c.PREFIX}-message-evaluator-execution',
            'assume_role_policy': json.dumps({'Version': '2012-10-17', 'Statement': [{'Effect': 'Allow', 'Action': 'sts:AssumeRole', 'Principal': {'Service': 'lambda.amazonaws.com'}}]}),
            'inline_policy': [{'name': current_policy['name'], 'policy': current_policy['policy']}]}
    previous = copy.deepcopy(role)
    previous['inline_policy'][0]['policy'] = policy_entry['change']['after']['policy']
    address = 'aws_iam_role.runtime["evaluator"]'
    p['resource_changes'].append({'address': address, 'mode': 'managed',
                                 'change': {'actions': ['no-op'], 'before': role, 'after': role}})
    p['resource_drift'] = [{'address': address, 'mode': 'managed', 'provider_name': PROVIDER,
                          'change': {'actions': ['update'], 'before': previous, 'after': role}}]
    return m.sync(p)


class ComputedReadbackTests(unittest.TestCase):
    def test_observed_reader_first_read_and_activation_pass(self):
        p = reader_plan()
        self.assertEqual(v.review(p, r.REVISION, 'reader', 'both')['resourceChanges'], 2)

    def test_normalized_drift_stays_in_digest(self):
        p = reader_plan()
        digest = v.review(p, r.REVISION, 'reader', 'both')['reviewedPlanDigest']
        p['resource_drift'] = []
        self.assertNotEqual(digest, v.review(p, r.REVISION, 'reader', 'both')['reviewedPlanDigest'])

    def test_reader_nonempty_reverse_substantive_or_foreign_drift_rejected(self):
        for mutation in ('nonempty', 'reverse', 'retention', 'provider', 'foreign', 'counterpart', 'extra_grant', 'old_extra_grant', 'wrong_target', 'update_role'):
            p = reader_plan()
            drift = p['resource_drift'][0]
            if mutation == 'nonempty': drift['change']['after']['request_parameters'] = {'unsafe': 'mapping'}
            if mutation == 'reverse': drift['change']['before']['request_parameters'] = {}; drift['change']['after']['request_parameters'] = None
            if mutation == 'retention': drift['change']['after']['timeout_milliseconds'] = 30000
            if mutation == 'provider': drift['provider_name'] = 'foreign'
            if mutation == 'foreign': drift['address'] = 'aws_apigatewayv2_integration.export[0]'
            if mutation == 'counterpart': drift['change']['after']['id'] = 'unrelated'
            if mutation in ('extra_grant', 'old_extra_grant', 'update_role'):
                drift = next(x for x in p['resource_drift'] if x['address'].startswith('aws_iam_role.'))
                if mutation == 'extra_grant': drift['change']['after']['inline_policy'].append({'name': 'admin', 'policy': '{}'})
                if mutation == 'old_extra_grant': drift['change']['before']['inline_policy'] = [{'name': 'admin', 'policy': '{}'}]
                if mutation == 'update_role': next(x for x in p['resource_changes'] if x['address'] == drift['address'])['change']['actions'] = ['update']
            if mutation == 'wrong_target': next(x for x in p['resource_changes'] if x['address'].startswith('aws_lambda_function.'))['change']['after']['environment'][0]['variables']['MESSAGE_AI_ENABLED'] = 'true'
            r.sync(p)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): v.review(p, r.REVISION, 'reader', 'both')

    def test_owned_evaluator_policy_views_in_both_directions(self):
        for mode in ('inactive', 'rules-only-history'):
            self.assertFalse(c.review(message_plan(mode), m.f.REVISION, mode)['providerCallsEnabled'])

    def test_evaluator_extra_grants_rename_trust_or_other_drift_rejected(self):
        for mutation in ('extra', 'old_extra', 'rename', 'trust', 'provider', 'foreign', 'role_update', 'broken_link'):
            p = message_plan('inactive'); d = p['resource_drift'][0]
            if mutation == 'extra': d['change']['after']['inline_policy'].append({'name': 'admin', 'policy': '{}'})
            if mutation == 'old_extra': d['change']['before']['inline_policy'].append({'name': 'admin', 'policy': '{}'})
            if mutation == 'rename': next(x for x in p['resource_changes'] if x['address'].startswith('aws_iam_role_policy.'))['change']['after']['name'] = 'renamed'
            if mutation == 'trust': d['change']['after']['assume_role_policy'] = '{}'
            if mutation == 'provider': d['provider_name'] = 'foreign'
            if mutation == 'foreign': d['address'] = 'aws_iam_role.runtime["consumer"]'
            if mutation == 'role_update': p['resource_changes'][-1]['change']['actions'] = ['update']
            if mutation == 'broken_link': next(x for x in p['resource_changes'] if x['address'].startswith('aws_iam_role_policy.'))['change']['before']['policy'] = '{}'
            m.sync(p)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): c.review(p, m.f.REVISION, 'inactive')


if __name__ == '__main__':
    unittest.main()
