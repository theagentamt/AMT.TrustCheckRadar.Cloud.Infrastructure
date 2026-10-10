import copy
import hashlib
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import billing_plan_digest as digest
import verify_billing_cleanup_dev_plan as cleanup
import verify_billing_dev_plan as billing
from test_billing_cleanup_dev_plan import timestamp_drift_fixture, REVISION
from test_billing_dev_transition import fixture as billing_fixture, PROVENANCE


def add_caller(plan, session='GitHubActions-123', role='deployment', role_id='AROA' + 'A' * 17):
    identity = {'account_id': digest.ACCOUNT, 'id': digest.ACCOUNT,
                'arn': f'arn:aws:sts::{digest.ACCOUNT}:assumed-role/{role}/{session}',
                'user_id': role_id + ':' + session}
    plan['resource_changes'].append({'address': digest.ADDRESS, 'mode': 'data',
        'type': 'aws_caller_identity', 'name': 'current', 'provider_name': digest.PROVIDER,
        'change': {'actions': ['no-op'], 'before': copy.deepcopy(identity), 'after': identity,
                   'after_unknown': {}, 'before_sensitive': {}, 'after_sensitive': {}}})
    config = plan.setdefault('configuration', {}).setdefault('root_module', {})
    config.setdefault('resources', []).append({'address': digest.ADDRESS, 'mode': 'data',
        'type': 'aws_caller_identity', 'name': 'current', 'provider_config_key': 'aws', 'schema_version': 0})
    config['outputs'] = {'account': {'expression': {'references': [digest.ADDRESS + '.account_id', digest.ADDRESS]}}}
    return plan


def fixture():
    return add_caller({'resource_changes': [], 'terraform_version': '1.12.1'})


def hash_plan(plan):
    return hashlib.sha256(json.dumps(digest.projection(plan), sort_keys=True).encode()).hexdigest()


class BillingPlanDigestTests(unittest.TestCase):
    def rejects(self, plan):
        with self.assertRaisesRegex(ValueError, '^Billing plan caller identity cannot be qualified.$'):
            digest.projection(plan)

    def test_same_role_sessions_normalize_only_two_suffixes_without_mutation(self):
        a, b = fixture(), add_caller({'resource_changes': [], 'terraform_version': '1.12.1'}, session='different-session')
        original = copy.deepcopy(a)
        self.assertEqual(hash_plan(a), hash_plan(b))
        self.assertEqual(a, original)
        projected = digest.projection(a)
        for side in ('before', 'after'):
            row = projected['resource_changes'][0]['change'][side]
            self.assertEqual(row['arn'], f'arn:aws:sts::{digest.ACCOUNT}:assumed-role/deployment/<session>')
            self.assertEqual(row['user_id'], 'AROA' + 'A' * 17 + ':<session>')

    def test_role_and_all_other_projected_values_remain_digest_bound(self):
        baseline = hash_plan(fixture())
        for role, role_id in [('another-role', 'AROA' + 'A' * 17), ('deployment', 'AROA' + 'B' * 17)]:
            self.assertNotEqual(baseline, hash_plan(add_caller({'resource_changes': [], 'terraform_version': '1.12.1'}, role=role, role_id=role_id)))
        for field in digest.FIELDS:
            if field in ('resource_changes', 'configuration', 'resource_drift'): continue
            plan = fixture(); plan[field] = {'changed': 'must remain bound'}
            self.assertNotEqual(baseline, hash_plan(plan), field)
        plan = fixture(); plan['resource_changes'].append({'mode': 'managed', 'before': 'runtime-change'})
        self.assertNotEqual(baseline, hash_plan(plan))
        plan = fixture(); plan['configuration']['root_module']['new'] = 'source change'
        self.assertNotEqual(baseline, hash_plan(plan))
        plan = fixture(); plan['resource_drift'] = [{'mode': 'managed', 'change': {'before': 'bound'}}]
        self.assertNotEqual(baseline, hash_plan(plan))

    def test_both_full_verifiers_stable_across_caller_sessions(self):
        results = []
        for session in ('plan-session', 'apply-session'):
            plan, baseline, captured = timestamp_drift_fixture()
            add_caller(plan, session); add_caller(baseline, session)
            results.append(cleanup.review(plan, baseline, captured, REVISION)['reviewedPlanDigest'])
        self.assertEqual(*results)
        with patch.object(billing, 'load_provenance', return_value=PROVENANCE):
            a = billing.review(add_caller(billing_fixture(), 'plan-session'), REVISION, 'handoff', 'verification')[1]
            b = billing.review(add_caller(billing_fixture(), 'apply-session'), REVISION, 'handoff', 'verification')[1]
        self.assertEqual(a, b)

    def test_absent_caller_allowed_only_without_declarations_or_references(self):
        self.assertEqual(digest.projection({'resource_changes': []})['resource_changes'], [])
        for missing in ('data', 'declaration', 'both-but-reference'):
            plan = fixture()
            if missing != 'declaration': plan['resource_changes'] = []
            if missing != 'data': plan['configuration']['root_module']['resources'] = []
            self.rejects(plan)

    def test_additional_data_or_declarations_rejected(self):
        for place in ('resource_changes', 'configuration'):
            for other in (False, True):
                plan = fixture()
                rows = plan['resource_changes'] if place == 'resource_changes' else plan['configuration']['root_module']['resources']
                extra = copy.deepcopy(rows[0])
                if other: extra.update(address='data.aws_region.current', type='aws_region')
                rows.append(extra)
                self.rejects(plan)
        plan = fixture(); plan['resource_drift'] = [copy.deepcopy(plan['resource_changes'][0])]
        self.rejects(plan)

    def test_consumption_of_session_or_other_caller_attributes_rejected_anywhere(self):
        for reference in (digest.ADDRESS, digest.ADDRESS + '.arn', digest.ADDRESS + '.user_id', digest.ADDRESS + '.id',
                          'data.aws_caller_identity.other.account_id', digest.ADDRESS + '[0].arn'):
            plan = fixture()
            plan['configuration']['root_module']['module_calls'] = {'nested': {'module': {'outputs': {'identity': {'expression': {'references': [reference]}}}}}}
            self.rejects(plan)

    def test_exact_data_provider_address_type_and_actions_required(self):
        for field, value in [('provider_name', 'different'), ('mode', 'managed'), ('type', 'aws_region'),
                             ('name', 'other'), ('address', digest.ADDRESS + '[0]')]:
            plan = fixture(); plan['resource_changes'][0][field] = value; self.rejects(plan)
        for action in (['read'], ['update'], ['create'], ['delete'], ['no-op', 'read']):
            plan = fixture(); plan['resource_changes'][0]['change']['actions'] = action; self.rejects(plan)

    def test_unknown_missing_and_changed_before_after_rejected(self):
        for field, value in [('after_unknown', {'arn': True}), ('before_unknown', True), ('after_unknown', None),
                             ('before_sensitive', True), ('after_sensitive', {'arn': True}), ('after_sensitive', 0),
                             ('after_unknown', {'arn': 0}), ('before', None), ('after', {})]:
            plan = fixture(); plan['resource_changes'][0]['change'][field] = value; self.rejects(plan)
        plan = fixture(); del plan['resource_changes'][0]['change']['after_unknown']; self.rejects(plan)
        plan = fixture(); del plan['resource_changes'][0]['change']['before_sensitive']; self.rejects(plan)
        for field, value in [('account_id', '000000000000'), ('id', '000000000000'), ('arn', 'changed-role'), ('user_id', 'changed-role-id')]:
            plan = fixture(); plan['resource_changes'][0]['change']['after'][field] = value; self.rejects(plan)

    def test_omitted_unchanged_data_uses_exact_prior_state_shape(self):
        def prior_plan(session='plan-session'):
            plan = add_caller({'resource_changes': []}, session)
            row = plan['resource_changes'].pop()
            row['values'] = row.pop('change')['before']
            row.update(schema_version=0, sensitive_values={})
            plan['prior_state'] = {'values': {'root_module': {'resources': [row]}}}
            plan['planned_values'] = {'root_module': {'resources': []}}
            return plan
        a, b = prior_plan(), prior_plan('apply-session')
        original = copy.deepcopy(a)
        self.assertEqual(hash_plan(a), hash_plan(b))
        self.assertEqual(a, original)
        self.assertIn('qualified_caller_identity', digest.projection(a))
        b['prior_state']['values']['root_module']['resources'][0]['values']['arn'] = b['prior_state']['values']['root_module']['resources'][0]['values']['arn'].replace('/deployment/', '/different/')
        self.assertNotEqual(hash_plan(a), hash_plan(b))
        for mutation in ('absent', 'additional', 'other', 'provider', 'schema', 'bool-schema', 'sensitive',
                         'missing-sensitive', 'extra-field', 'unknown', 'planned-data', 'missing-declaration', 'wrong-account'):
            plan = prior_plan(); rows = plan['prior_state']['values']['root_module']['resources']; row = rows[0]
            if mutation == 'absent': rows.clear()
            if mutation == 'additional': rows.append(copy.deepcopy(row))
            if mutation == 'other': row['address'] = 'data.aws_region.current'
            if mutation == 'provider': row['provider_name'] = 'different'
            if mutation == 'schema': row['schema_version'] = 1
            if mutation == 'bool-schema': row['schema_version'] = False
            if mutation == 'sensitive': row['sensitive_values'] = {'arn': True}
            if mutation == 'missing-sensitive': del row['sensitive_values']
            if mutation == 'extra-field': row['extra'] = 'unreviewed'
            if mutation == 'unknown': row['values']['arn'] = None
            if mutation == 'planned-data': plan['planned_values']['root_module']['resources'].append(copy.deepcopy(row))
            if mutation == 'missing-declaration': plan['configuration'] = {}
            if mutation == 'wrong-account': row['values']['account_id'] = '000000000000'
            with self.subTest(mutation=mutation): self.rejects(plan)

    def test_malformed_or_nonrole_identity_rejected_without_echoing_values(self):
        for field, value in [('account_id', '000000000000'), ('id', '000000000000'), ('arn', 'arn:aws:iam::107827791950:user/private'),
                             ('user_id', 'AIDA' + 'A' * 17 + ':GitHubActions-123'), ('user_id', 'AROA' + 'A' * 17 + ':mismatch'),
                             ('arn', None), ('private-extra', 'never print me')]:
            plan = fixture()
            for side in ('before', 'after'): plan['resource_changes'][0]['change'][side][field] = value
            self.rejects(plan)


if __name__ == '__main__':
    unittest.main()
