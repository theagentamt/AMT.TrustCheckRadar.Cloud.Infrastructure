import copy
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_governed_history_readback as v
spec = importlib.util.spec_from_file_location('plan_fixture', Path(__file__).with_name('test_governed_history_plan.py'))
f = importlib.util.module_from_spec(spec); spec.loader.exec_module(f)
spec2 = importlib.util.spec_from_file_location('message_fixture', Path(__file__).with_name('test_candidate3_rules_plan.py'))
m = importlib.util.module_from_spec(spec2); spec2.loader.exec_module(m)


class ReadbackTests(unittest.TestCase):
    def fake_aws(self, plan, scope, mode, *, bad_policy=False, no_index=False):
        variables = {k: val['value'] for k, val in plan['variables'].items()}
        def read(service, action, *args):
            if (service, action) == ('sts', 'get-caller-identity'): return {'Account': v.ACCOUNT}
            if action == 'describe-table': return {'Table': {'TableArn': v.AUTHORITY, 'TableStatus': 'ACTIVE', 'GlobalSecondaryIndexes': [] if no_index else [{'IndexName': 'GSI2', 'IndexStatus': 'ACTIVE', 'KeySchema': [{'AttributeName': 'GSI2PK', 'KeyType': 'HASH'}, {'AttributeName': 'GSI2SK', 'KeyType': 'RANGE'}], 'Projection': {'ProjectionType': 'INCLUDE', 'NonKeyAttributes': sorted(v.PROJECTION)}}]}}
            if action == 'describe-time-to-live': return {'TimeToLiveDescription': {'TimeToLiveStatus': 'ENABLED', 'AttributeName': 'expiresAt'}}
            if action == 'describe-continuous-backups': return {'ContinuousBackupsDescription': {'PointInTimeRecoveryDescription': {'PointInTimeRecoveryStatus': 'ENABLED'}}}
            if action == 'get-policy':
                if '--qualifier' not in args:
                    from subprocess import CalledProcessError
                    raise CalledProcessError(255, ['aws'], stderr='ResourceNotFoundException')
                return {'Policy': __import__('json').dumps({'Version': '2012-10-17', 'Statement': v.reader_invoke_statements()})}
            if action == 'get-alias': return {'FunctionVersion': '7'}
            if action == 'get-function-configuration':
                name = args[args.index('--function-name') + 1]
                if scope == 'reader': env = v.reader_environment(variables)
                else:
                    from verify_message_consumer_transition import _expected_environment
                    kind = name.split('-')[-1]
                    env = _expected_environment(kind, variables, mode != 'inactive'); env['MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED'] = str(mode != 'inactive').lower()
                    if kind == 'consumer': env.update(GOVERNED_HISTORY_SETTLEMENT_ENABLED=str(mode == 'rules-only-history').lower(), MESSAGE_PROVIDER_CIRCUIT_OPEN='true')
                return {'Timeout': 23 if scope == 'reader' else (29 if name.endswith('consumer') else 23), 'MemorySize': 256, 'Handler': 'governed_history.app.lambda_handler' if scope == 'reader' else ('message_consumer.app.lambda_handler' if name.endswith('consumer') else 'message_evaluator.app.lambda_handler'), 'CodeSha256': 'A' * 43 + '=', 'Runtime': 'python3.14', 'Architectures': ['arm64'], 'State': 'Active', 'LastUpdateStatus': 'Successful', 'Role': f'arn:aws:iam::{v.ACCOUNT}:role/{name}-execution', 'Environment': {'Variables': env}}
            if action == 'get-function-concurrency': return {'ReservedConcurrentExecutions': 2}
            if action == 'list-attached-role-policies': return {'AttachedPolicies': []}
            if action == 'list-role-policies': return {'PolicyNames': ['fenced-governed-history-read-only']}
            if action == 'get-role-policy':
                if scope == 'reader': policy = v.reader_policy(variables['deployment'], variables['engineering_subjects'], variables['authority_partitions'])
                else:
                    from verify_candidate3_rules_plan import evaluator_policy
                    policy = evaluator_policy(variables['deployment'], mode != 'inactive')
                if bad_policy: policy['Statement'][1]['Effect'] = 'Allow' if scope == 'message' else 'Deny'
                return {'PolicyDocument': policy}
            if action == 'get-routes': return {'Items': [{'RouteKey': 'GET /v1/users/analysis-history' + ('/{resultId}' if kind == 'detail' else ''), 'AuthorizationType': 'JWT', 'AuthorizerId': 'itms4b', 'AuthorizationScopes': ['aws.cognito.signin.user.admin'], 'Target': 'integrations/id'} for kind in ('list', 'detail')]}
            if action == 'get-integration': return {'IntegrationUri': f'arn:aws:lambda:us-east-1:{v.ACCOUNT}:function:{v.PREFIX}-governed-history:live', 'IntegrationMethod': 'POST'}
            raise AssertionError((service, action))
        return read

    def test_active_reader_and_message_recheck_index_and_exact_iam(self):
        for scope, mode, plan in [('reader', 'both', f.fixture('reader', 'both')), ('message', 'rules-only-history', m.fixture('rules-only-history'))]:
            # Shared legacy fixture artifact hash differs; runtime fixture uses one explicit hash.
            for a in plan['variables']['deployment']['value']['artifacts'].values(): a['source_hash'] = 'A' * 43 + '='
            with self.subTest(scope=scope), patch.object(v, 'aws', side_effect=self.fake_aws(plan, scope, mode)) as calls:
                self.assertTrue(v.verify(plan, scope, mode)['configurationOnly'])
                self.assertTrue(any(call.args[1] == 'describe-table' for call in calls.call_args_list))
                self.assertTrue(any(call.args[1] == 'get-role-policy' for call in calls.call_args_list))
                self.assertFalse(any(call.args[1] in ('get-item', 'query', 'get-secret-value') for call in calls.call_args_list))

    def test_policy_mismatch_or_missing_index_is_rejected_after_apply(self):
        for scope, mode, plan in [('reader', 'both', f.fixture('reader', 'both')), ('message', 'rules-only-history', m.fixture('rules-only-history'))]:
            for a in plan['variables']['deployment']['value']['artifacts'].values(): a['source_hash'] = 'A' * 43 + '='
            for kwargs in ({'bad_policy': True}, {'no_index': True}):
                with self.subTest(scope=scope, kwargs=kwargs), patch.object(v, 'aws', side_effect=self.fake_aws(plan, scope, mode, **kwargs)), self.assertRaises(ValueError): v.verify(plan, scope, mode)

    def test_role_preflight_blocks_extra_grants_or_missing_active_role(self):
        from subprocess import CalledProcessError
        role = {'Role': {'Arn': f'arn:aws:iam::{v.ACCOUNT}:role/{v.PREFIX}-governed-history-execution'}}
        with patch.object(v, 'aws', side_effect=[role, {'AttachedPolicies': []}, {'PolicyNames': ['fenced-governed-history-read-only']}]):
            self.assertTrue(v.verify_reader_role_exclusivity()['exclusivePolicyNamesVerified'])
        with patch.object(v, 'aws', side_effect=[role, {'AttachedPolicies': [{'PolicyArn': 'admin'}]}]), self.assertRaises(ValueError):
            v.verify_reader_role_exclusivity()
        missing = CalledProcessError(255, ['aws'], stderr='NoSuchEntity')
        with patch.object(v, 'aws', side_effect=missing):
            self.assertFalse(v.verify_reader_role_exclusivity(allow_missing=True)['readerRolePresent'])
        with patch.object(v, 'aws', side_effect=missing), self.assertRaises(ValueError):
            v.verify_reader_role_exclusivity()


    def test_invoke_boundary_rejects_direct_extra_wrong_route_and_missing_active_policy(self):
        import json
        from subprocess import CalledProcessError
        absent = CalledProcessError(255, ['aws'], stderr='ResourceNotFoundException')
        good = {'Version': '2012-10-17', 'Statement': v.reader_invoke_statements()}
        with patch.object(v, 'aws', side_effect=[absent, {'Policy': json.dumps(good)}]):
            self.assertTrue(v.verify_reader_invoke_boundary()['exclusiveRouteInvokePolicyVerified'])
        for altered in ('extra', 'source', 'account', 'principal'):
            bad = copy.deepcopy(good)
            if altered == 'extra': bad['Statement'].append(copy.deepcopy(bad['Statement'][0]))
            if altered == 'source': bad['Statement'][0]['Condition']['ArnLike']['AWS:SourceArn'] = '*'
            if altered == 'account': bad['Statement'][0]['Condition']['StringEquals']['AWS:SourceAccount'] = 'other'
            if altered == 'principal': bad['Statement'][0]['Principal'] = '*'
            with self.subTest(altered=altered), patch.object(v, 'aws', side_effect=[absent, {'Policy': json.dumps(bad)}]), self.assertRaises(ValueError):
                v.verify_reader_invoke_boundary()
        with patch.object(v, 'aws', return_value={'Policy': json.dumps(good)}), self.assertRaises(ValueError):
            v.verify_reader_invoke_boundary(allow_missing=True)
        with patch.object(v, 'aws', side_effect=absent):
            self.assertFalse(v.verify_reader_invoke_boundary(allow_missing=True)['readerAliasPolicyPresent'])
        with patch.object(v, 'aws', side_effect=absent), self.assertRaises(ValueError):
            v.verify_reader_invoke_boundary()
