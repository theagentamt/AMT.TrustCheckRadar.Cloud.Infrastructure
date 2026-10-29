"""Synthetic unit fixtures only; no AWS or runtime/provider calls."""
import copy
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_ocr_preservation_plan as gate

REV = 'a' * 40


def fixture():
    common = {'MESSAGE_AI_ENABLED': 'false', 'MESSAGE_AI_PRIMARY_ENABLED': 'false', 'MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED': 'true'}
    envs = {'consumer': dict(common, MESSAGE_PROVIDER_CIRCUIT_OPEN='true', COGNITO_ISSUER='synthetic'),
            'evaluator': dict(common, MESSAGE_AI_QUALIFIED='false', MESSAGE_AI_DEV_EXCEPTION_ENABLED='false', MESSAGE_PROPOSER_ENABLED='false')}
    p = {'phase': 'baseline', 'evaluator_live_version': '7', 'artifact': gate.ARTIFACT,
         'recorded_consumer_artifact': gate.CONSUMER_ARTIFACT, 'environments': envs}
    values = {'environment': 'dev', 'aws_region': 'us-east-1', 'project_name': 'trustcheckradar', 'enabled': True,
              'activate_rules_engineering': True, 'candidate3_rules_only_enabled': True,
              'governed_history_settlement_enabled': True, 'message_ai_primary_enabled': False,
              'url_assessment_enabled': False, 'dev_ocr_preservation': p,
              'deployment': {'artifacts': gate.HISTORICAL_ARTIFACTS}}
    rows = []
    for name in ('consumer', 'evaluator'):
        rows.extend([(f'aws_lambda_function.runtime["{name}"]', {'function_name': 'trustcheckradar-dev-message-' + name,
            'version': '8' if name == 'consumer' else '7', 'code_sha256': gate.CONSUMER_ARTIFACT['source_hash'] if name == 'consumer' else gate.OLD_EVALUATOR,
            'environment': [{'variables': envs[name]}], 's3_key': 'inert-reviewed-input', 'role': 'unchanged', 'memory_size': 256}),
            (f'aws_lambda_alias.runtime["{name}"]', {'name': 'live', 'function_name': 'trustcheckradar-dev-message-' + name,
             'function_version': '8' if name == 'consumer' else '7', 'routing_config': []})])
    rows += [(a, {'preserved': 'unchanged'}) for a in sorted(gate.INVENTORY - {a for a, _ in rows})]
    return {'terraform_version': '1.12.1', 'complete': True, 'errored': False,
            'variables': {k: {'value': copy.deepcopy(v)} for k, v in values.items()},
            'resource_changes': [{'address': a, 'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws',
                'change': {'actions': ['no-op'], 'before': copy.deepcopy(v), 'after': copy.deepcopy(v)}} for a, v in rows] + [
                {'address': 'data.aws_caller_identity.current', 'mode': 'data', 'change': {'actions': ['no-op'],
                 'before': {'account_id': '107827791950'}, 'after': {'account_id': '107827791950'}}}],
            'output_changes': {'candidate_contract': {'actions': ['no-op'], 'before': {'ai_enabled': False}, 'after': {'ai_enabled': False}}}}


def live(base, phase='live'):
    plan = copy.deepcopy(base)
    p = plan['variables']['dev_ocr_preservation']['value'];p.update(phase=phase, evaluator_live_version='11' if phase == 'live' else '7')
    for row in plan['resource_changes']:
        for key in ('before', 'after'):
            if row['address'] == gate.F:
                row['change'][key].update(code_sha256=gate.ARTIFACT['source_hash'], version='11')
            if row['address'] == gate.A:
                row['change'][key]['function_version'] = p['evaluator_live_version']
    return plan


class OcrPreservationTests(unittest.TestCase):
    def setUp(self):
        self.base = fixture()
        envs = self.base['variables']['dev_ocr_preservation']['value']['environments']
        # Tests substitute only fixture digests in process memory. Production
        # Terraform/Python constants remain the independently reviewed hashes.
        patcher = patch.object(gate, 'ENV_HASHES', {k: gate.digest(v) for k, v in envs.items()})
        patcher.start();self.addCleanup(patcher.stop)
        self.publication = {'FunctionName': 'trustcheckradar-dev-message-evaluator', 'Version': '11',
                            'CodeSha256': gate.ARTIFACT['source_hash'], 'environmentSha256': gate.ENV_HASHES['evaluator']}

    def test_baseline_live_and_alias_rollback_are_accounted_without_root_apply(self):
        self.assertFalse(gate.review(self.base, REV)['rootApplyAuthorized'])
        self.assertEqual(gate.review(live(self.base), REV, self.base, self.publication)['managedNoOps'], 19)
        self.assertEqual(gate.review(live(self.base, 'staged'), REV, self.base)['phase'], 'staged')

    def test_account_region_modes_and_exact_artifacts_are_not_widened(self):
        for key, value in [('environment', 'prod'), ('aws_region', 'us-west-2'), ('message_ai_primary_enabled', True), ('url_assessment_enabled', True)]:
            p = copy.deepcopy(self.base);p['variables'][key]['value'] = value
            with self.subTest(key=key), self.assertRaises(ValueError): gate.review(p, REV)
        for key in ('artifact', 'recorded_consumer_artifact'):
            p = copy.deepcopy(self.base);p['variables']['dev_ocr_preservation']['value'][key]['object_version'] = 'different'
            with self.subTest(key=key), self.assertRaises(ValueError): gate.review(p, REV)

    def test_changed_environment_or_ai_gate_is_rejected(self):
        p = copy.deepcopy(self.base);p['variables']['dev_ocr_preservation']['value']['environments']['evaluator']['MESSAGE_AI_ENABLED'] = 'true'
        with self.assertRaises(ValueError): gate.review(p, REV)
        p = copy.deepcopy(self.base);p['variables']['dev_ocr_preservation']['value']['environments']['consumer']['COGNITO_ISSUER'] = 'different'
        with self.assertRaises(ValueError): gate.review(p, REV)

    def test_any_resource_change_drift_unknown_or_missing_inventory_rejected(self):
        for mutation in ('update', 'drift', 'unknown', 'missing'):
            p = copy.deepcopy(self.base)
            if mutation == 'update': p['resource_changes'][-1]['change']['actions'] = ['update']
            if mutation == 'drift': p['resource_drift'] = [{'mode': 'managed', 'change': {'actions': ['update']}}]
            if mutation == 'unknown': p['resource_changes'][0]['change']['after_unknown'] = {'environment': [{'variables': {'AUTHORITY_ENABLED': True}}]}
            if mutation == 'missing': p['resource_changes'].pop()
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): gate.review(p, REV)

    def test_future_or_wrong_version_and_consumer_alias_movement_rejected(self):
        p = live(self.base)
        with self.assertRaises(ValueError): gate.review(p, REV, self.base)
        for key, value in [('Version', '12'), ('CodeSha256', 'different')]:
            receipt = dict(self.publication);receipt[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): gate.review(p, REV, self.base, receipt)
        for row in p['resource_changes']:
            if row['address'] == 'aws_lambda_alias.runtime["consumer"]':
                row['change']['before']['function_version'] = row['change']['after']['function_version'] = '9'
        with self.assertRaises(ValueError): gate.review(p, REV, self.base, self.publication)

    def test_unrelated_iam_auth_budget_and_provenance_changes_rejected_after_rollout(self):
        for address, field in [('aws_iam_role_policy.consumer[0]', 'policy'), (gate.F, 'role'), (gate.F, 's3_key')]:
            p = live(self.base)
            for row in p['resource_changes']:
                if row['address'] == address:
                    row['change']['before'][field] = row['change']['after'][field] = 'different'
            with self.subTest(address=address, field=field), self.assertRaises(ValueError): gate.review(p, REV, self.base, self.publication)

    def test_wrong_account_or_substituted_resource_inventory_is_rejected(self):
        p = copy.deepcopy(self.base)
        p['resource_changes'][-1]['change']['before']['account_id'] = '000000000000'
        p['resource_changes'][-1]['change']['after']['account_id'] = '000000000000'
        with self.assertRaises(ValueError): gate.review(p, REV)
        p = copy.deepcopy(self.base)
        p['resource_changes'][0]['address'] = 'aws_iam_role.unrelated'
        with self.assertRaises(ValueError): gate.review(p, REV)


if __name__ == '__main__':
    unittest.main()
