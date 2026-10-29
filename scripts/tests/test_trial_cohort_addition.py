"""Isolated saved-plan/unit regressions; synthetic identities, no AWS calls."""
import copy
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import prepare_governed_history_configuration as configuration
import prepare_preserved_deployment as preserved
import verify_governed_trial_plan as gate
from test_preserved_deployment import PreservedDeploymentTests, maintenance, SYNTHETIC

REVISION = 'b' * 40


class TrialCohortAdditionTests(unittest.TestCase):
    def setUp(self):
        boundary = PreservedDeploymentTests(methodName='runTest')
        boundary.setUp()
        self.addCleanup(boundary.tearDown)
        self.addCleanup(patch.stopall)
        patch.object(configuration, 'TRIAL_COHORT_SHA256', preserved.digest(SYNTHETIC)).start()
        _, self.baseline, _ = maintenance()
        self.baseline['variables']['governed_trial_subjects']['value'] = SYNTHETIC[:1]
        self.baseline['variables']['dev_access_snapshot_extra_subjects']['value'] = SYNTHETIC[1:]
        for output in self.baseline['output_changes'].values():
            output.update(actions=['no-op'], before=copy.deepcopy(output['after']))
        while len(self.baseline['resource_changes']) < 56:
            value = {'policy': 'unchanged'}
            self.baseline['resource_changes'].append({'address': 'aws_iam_role_policy.preserved[' + str(len(self.baseline['resource_changes'])) + ']',
                'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws',
                'change': {'actions': ['no-op'], 'before': copy.deepcopy(value), 'after': value}})
        self.plan = copy.deepcopy(self.baseline)
        self.plan['variables']['governed_trial_subjects']['value'] = SYNTHETIC
        self.plan['variables']['dev_access_snapshot_extra_subjects']['value'] = []
        rows = preserved.inventory(self.plan)
        c = rows[gate.FUNCTION]['change']
        env = preserved.environment(c['after'])
        env['DEV_SUBJECT_ALLOWLIST_JSON'] = json.dumps(sorted(SYNTHETIC), separators=(',', ':'))
        env.pop('DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON')
        c['actions'] = ['update']
        c['after']['version'] = None
        c['after_unknown'] = {'version': True}
        alias = rows[gate.ALIAS]['change']
        alias.update(actions=['update'], after_unknown={'function_version': True})
        alias['after']['function_version'] = None
        self.plan['output_changes']['candidate_contract']['actions'] = ['update']
        self.plan['output_changes']['candidate_contract']['after']['governed_trial_subject_count'] = 2

    def test_exact_addition_preserves_member_and_only_removes_snapshot_selection(self):
        self.assertEqual(gate.review(self.plan, REVISION, 'trial', self.baseline)[2:], (2, 2))
        self.assertEqual(configuration.build('access', 'trial', {}, list(reversed(SYNTHETIC)), False),
                         {'governed_trial_subjects': list(reversed(SYNTHETIC)), 'dev_access_snapshot_extra_subjects': []})
        env = preserved.environment(preserved.inventory(self.plan)[gate.FUNCTION]['change']['after'])
        self.assertEqual(preserved.trial_subject_inputs(env), {'governed_trial_subjects': sorted(SYNTHETIC), 'dev_access_snapshot_extra_subjects': []})
        # A projected new profile is never silently accepted as historical v18.
        with self.assertRaises(ValueError): preserved.require_entitlements(preserved.inventory(self.plan)[gate.FUNCTION]['change']['after'])

    def test_unknown_different_duplicate_and_third_subjects_are_rejected(self):
        other = '00000000-0000-4000-8000-000000000099'
        for selected in ([SYNTHETIC[0], other], SYNTHETIC + [other], [SYNTHETIC[0]] * 2):
            candidate = copy.deepcopy(self.plan)
            candidate['variables']['governed_trial_subjects']['value'] = selected
            with self.subTest(count=len(selected)), self.assertRaises(ValueError): gate.review(candidate, REVISION, 'trial', self.baseline)
            with self.assertRaises(ValueError): configuration.build('access', 'trial', {}, selected, False)

    def test_baseline_drift_missing_or_substituted_profile_is_rejected(self):
        with self.assertRaises(ValueError): gate.review(self.plan, REVISION, 'trial')
        baseline = copy.deepcopy(self.baseline)
        baseline['resource_drift'] = [{'mode': 'managed', 'address': 'aws_lambda_event_source_mapping.v1_deletion[0]', 'change': {'actions': ['update']}}]
        with self.assertRaises(ValueError): gate.review(self.plan, REVISION, 'trial', baseline)
        baseline = copy.deepcopy(self.baseline)
        preserved.inventory(baseline)[gate.FUNCTION]['change']['after']['version'] = '19'
        with self.assertRaises(ValueError): gate.review(self.plan, REVISION, 'trial', baseline)

    def test_wrong_environment_region_and_engineering_mode_are_rejected(self):
        for key, value in [('environment', 'prod'), ('aws_region', 'us-west-2'), ('project_name', 'other'), ('activate_engineering', True), ('activate_trial_engineering', True)]:
            candidate = copy.deepcopy(self.plan)
            candidate['variables'][key]['value'] = value
            with self.subTest(key=key), self.assertRaises(ValueError): gate.review(candidate, REVISION, 'trial', self.baseline)

    def test_code_auth_retention_and_snapshot_key_changes_are_rejected(self):
        for field, value in [('COGNITO_REQUIRED_SCOPE', '*'), ('TRIAL_AUTHORITY_RETENTION_APPROVED', 'false'), ('DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON', '[]')]:
            candidate = copy.deepcopy(self.plan)
            preserved.environment(preserved.inventory(candidate)[gate.FUNCTION]['change']['after'])[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError): gate.review(candidate, REVISION, 'trial', self.baseline)
        for field in ('s3_key', 'source_code_hash', 'code_sha256', 'role', 'timeout'):
            candidate = copy.deepcopy(self.plan)
            preserved.inventory(candidate)[gate.FUNCTION]['change']['after'][field] = 'changed'
            with self.subTest(field=field), self.assertRaises(ValueError): gate.review(candidate, REVISION, 'trial', self.baseline)

    def test_other_resource_output_or_alias_change_is_rejected(self):
        for address in ('aws_lambda_function.runtime["recovery"]', 'aws_iam_role_policy.preserved[55]'):
            candidate = copy.deepcopy(self.plan)
            c = preserved.inventory(candidate)[address]['change']
            c['actions'] = ['update']; c['after']['unexpected'] = True
            with self.subTest(address=address), self.assertRaises(ValueError): gate.review(candidate, REVISION, 'trial', self.baseline)
        candidate = copy.deepcopy(self.plan)
        candidate['output_changes']['candidate_contract']['after']['recovery_enabled'] = True
        with self.assertRaises(ValueError): gate.review(candidate, REVISION, 'trial', self.baseline)
        candidate = copy.deepcopy(self.plan)
        preserved.inventory(candidate)[gate.ALIAS]['change']['after']['function_version'] = '18'
        with self.assertRaises(ValueError): gate.review(candidate, REVISION, 'trial', self.baseline)

    def test_unknown_environment_alias_or_output_is_rejected(self):
        for address, unknown in [(gate.FUNCTION, {'environment': True}), (gate.ALIAS, {'routing_config': True})]:
            candidate = copy.deepcopy(self.plan)
            preserved.inventory(candidate)[address]['change']['after_unknown'].update(unknown)
            with self.subTest(address=address), self.assertRaises(ValueError): gate.review(candidate, REVISION, 'trial', self.baseline)
        candidate = copy.deepcopy(self.plan)
        candidate['output_changes']['candidate_contract']['after_unknown'] = {'general_customer_access': True}
        with self.assertRaises(ValueError): gate.review(candidate, REVISION, 'trial', self.baseline)
