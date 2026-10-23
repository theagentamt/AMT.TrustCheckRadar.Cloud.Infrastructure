"""Pure saved-plan compiler tests; no AWS clients or mock provider are invoked."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import prepare_preserved_deployment as p
import verify_preserved_deployment as v
import test_candidate3_rules_plan as message_fixture
import test_trial_authority_transition as trial_fixture

REVISION = 'b' * 40
SYNTHETIC = [trial_fixture.SUBJECT, '01997e3a-0000-7000-8000-000000000002']


def sync(plan):
    plan['planned_values'] = {'root_module': {'resources': [
        {'address': r['address'], 'mode': 'managed', 'values': copy.deepcopy(r['change']['after'])}
        for r in plan['resource_changes']]}}
    return plan


def capture(plan, maintenance):
    return {'functions': {r['address'].split('"')[1]: {
        'version': r['change']['before']['version'], 'codeSha256': r['change']['before']['code_sha256'],
        'artifactInputsSha256': p.digest(p.artifact(r['change']['before'])),
        'environmentSha256': p.digest(p.environment(r['change']['before']))}
        for r in plan['resource_changes'] if r['address'].startswith('aws_lambda_function.runtime[')},
        'maintenance': maintenance}


def maintenance_contract(active):
    return {'schema_version': 1, 'environment': 'dev',
        'authority_table_arn': 'arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements',
        'recovery_alias_arn': 'arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-lease-recovery:live',
        'recovery_version': '11', 'recovery_code_sha256': p.RECOVERY_SHA,
        'worker_enabled': active, 'schedule_enabled': active, 'heartbeat_enforced': active, 'provider_access_added': False}


def maintenance():
    base = trial_fixture.fixture('inactive')
    variables = {k: r['value'] for k, r in base['variables'].items()}
    variables.update(activate_authority_maintenance=False, maintenance_qualification_reference='',
                     governed_trial_subjects=[], dev_access_snapshot_extra_subjects=[])
    for n in ('consumer', 'entitlements', 'deletion'):
        variables[n + '_artifact_override'] = {'source_sha': 'c' * 40,
            'baseline_source_sha': 'a' * 40, 'baseline_source_hash': trial_fixture.ARTIFACTS[n]['source_hash'],
            'baseline_object_version': 'original', 'provenance_reference': 'docs/evidence/original.json',
            'artifact': copy.deepcopy(trial_fixture.ARTIFACTS[n])}
    base['variables'] = {k: {'value': val} for k, val in variables.items()}
    extra = []
    for row in base['resource_changes']:
        row['provider_name'] = 'registry.terraform.io/hashicorp/aws'
        value = row['change']['after']; n = row['address'].split('"')[1]
        value['version'] = '11' if n == 'recovery' else '7'
        if n == 'deletion': value['handler'] = 'app.lambda_handler'
        if n == 'recovery': value['source_code_hash'] = p.RECOVERY_SHA
        value['code_sha256'] = value['source_code_hash']
        if n == 'entitlements':
            pin = p.ENTITLEMENTS['current']
            value.update({k: pin[k] for k in ('version', 'code_sha256', 'source_code_size', 'last_modified')})
            value.update({{'bucket': 's3_bucket', 'key': 's3_key', 'object_version': 's3_object_version',
                          'source_hash': 'source_code_hash'}[k]: v for k, v in p.ENTITLEMENTS['historicalArtifactInputs'].items()})
            arn = 'arn:aws:lambda:us-east-1:107827791950:function:' + value['function_name'] + ':' + value['version']
            value.update(qualified_arn=arn, qualified_invoke_arn='arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/' + arn + '/invocations')
            env = p.environment(value)
            env.update(DEV_SUBJECT_ALLOWLIST_JSON=json.dumps([SYNTHETIC[0]]),
                       DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON=json.dumps([SYNTHETIC[1]]),
                       AUTHORITY_ENABLED='true', V1_ENTITLEMENTS_ENABLED='true', TRIAL_AUTHORITY_RETENTION_APPROVED='true')
        row['change'] = {'actions': ['no-op'], 'before': copy.deepcopy(value), 'after': value}
        alias = {'name': 'live', 'function_name': value['function_name'], 'function_version': value['version'], 'routing_config': []}
        extra.append({'address': f'aws_lambda_alias.runtime["{n}"]', 'mode': 'managed',
            'provider_name': 'registry.terraform.io/hashicorp/aws',
            'change': {'actions': ['no-op'], 'before': copy.deepcopy(alias), 'after': alias}})
    for address, value in ((v.RULE, {'state': 'DISABLED', 'schedule_expression': 'rate(1 minute)'}),
                           (v.HEARTBEAT, {'actions_enabled': False, 'treat_missing_data': 'notBreaching'}),
                           (v.OVERDUE, {'actions_enabled': False}),
                           ('aws_iam_role_policy.recovery[0]', {'policy': 'unchanged'}),
                           ('aws_apigatewayv2_route.v1["access"]', {'route_key': 'GET /v1/access'})):
        extra.append({'address': address, 'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws',
                      'change': {'actions': ['no-op'], 'before': copy.deepcopy(value), 'after': value}})
    base['resource_changes'] += extra
    base['configuration'] = {'root_module': {'resources': [{'address': 'aws_lambda_alias.runtime',
        'expressions': {'function_version': {'references': ['aws_lambda_function.runtime']}}}]}}
    base['output_changes'] = {'candidate_contract': {'after': {'consumer_enabled': False,
        'recovery_enabled': False, 'general_customer_access': False,
        'governed_trial_subject_count': 1, 'engineering_subject_count': 0}}}
    sync(base)
    # Pure synthetic fixture scope is installed only by this test process.
    observed = capture(base, maintenance_contract(False))
    final = copy.deepcopy(base)
    for k, val in p.build(base, observed, 'maintenance').items(): final['variables'][k] = {'value': val}
    rows = p.inventory(final)
    for a in v.MAINTENANCE: rows[a]['change']['actions'] = ['update']
    rows[v.FUNCTION]['change']['after']['version'] = '12'
    p.environment(rows[v.FUNCTION]['change']['after'])['LEASE_SWEEP_ENABLED'] = 'true'
    rows[v.ALIAS]['change']['after']['function_version'] = '12'
    rows[v.RULE]['change']['after']['state'] = 'ENABLED'
    rows[v.HEARTBEAT]['change']['after'].update(actions_enabled=True, treat_missing_data='breaching')
    rows[v.OVERDUE]['change']['after']['actions_enabled'] = True
    final['output_changes']['candidate_contract']['after']['recovery_enabled'] = True
    return sync(final), base, observed


def message():
    base = message_fixture.fixture('rules-only-history')
    for row in base['resource_changes']:
        row['provider_name'] = 'registry.terraform.io/hashicorp/aws'
        value = row['change']['after']
        if row['address'] == 'aws_lambda_function.runtime["consumer"]':
            p.environment(value)['DEV_SUBJECT_ALLOWLIST_JSON'] = json.dumps(SYNTHETIC, separators=(',', ':'))
        if row['address'].startswith('aws_lambda_function.'):
            value['code_sha256'] = value['source_code_hash']
        row['change'] = {'actions': ['no-op'], 'before': copy.deepcopy(value), 'after': value}
    base['variables']['authority_maintenance']['value'] = maintenance_contract(True)
    base['configuration'] = {'root_module': {'resources': [{'address': 'aws_lambda_alias.runtime',
        'expressions': {'function_version': {'references': ['aws_lambda_function.runtime']}}}]}}
    observed = capture(base, maintenance_contract(True))
    final = copy.deepcopy(base)
    targets = copy.deepcopy(base['variables']['deployment']['value']['artifacts'])
    for name, target in targets.items():
        target.update(key='releases/' + 'c' * 40 + '/message_' + name + '.zip', object_version='new-version')
    for k, val in p.build(base, observed, 'message-history', targets).items(): final['variables'][k] = {'value': val}
    for row in final['resource_changes']:
        if row['address'].startswith('aws_lambda_function.'):
            name = row['address'].split('"')[1]; target = targets[name]
            row['change']['actions'] = ['update']
            row['change']['after'].update(s3_key=target['key'], s3_object_version=target['object_version'], version='8')
        elif row['address'].startswith('aws_lambda_alias.'):
            row['change']['actions'] = ['update']; row['change']['after']['function_version'] = '8'
    final['output_changes']['candidate_contract']['after']['engineering_subject_count'] = 2
    sync(base)
    return sync(final), base, observed, targets


class PreservedDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.original_scope = p.SCOPE_SHA
        self.original_entitlements = copy.deepcopy(p.ENTITLEMENTS)
        p.ENTITLEMENTS['baseTrialSubjectsSha256'] = p.digest([SYNTHETIC[0]])
        p.ENTITLEMENTS['current']['extraSubjectsSha256'] = p.digest([SYNTHETIC[1]])
        p.ENTITLEMENTS['historical']['extraSubjectsSha256'] = p.digest(['01997e3a-0000-7000-8000-000000000003'])
        # Derive only environment hashes from a synthetic fixture, without calling build.
        original_build = p.build
        try:
            p.build = lambda *args, **kwargs: {}
            fixture, _, _ = maintenance()
        finally:
            p.build = original_build
        env = p.environment(p.inventory(fixture)[p.ENT_FUNCTION]['change']['before'])
        p.ENTITLEMENTS['current']['environmentSha256'] = p.digest(env)
        old = dict(env, DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON=json.dumps(['01997e3a-0000-7000-8000-000000000003']))
        p.ENTITLEMENTS['historical']['environmentSha256'] = p.digest(old)
        # Only the pure compiler test process uses a synthetic digest. The CLI,
        # checked-in Terraform and deployed scope remain pinned to the real hash.
        p.SCOPE_SHA = p.digest(SYNTHETIC)

    def tearDown(self):
        p.SCOPE_SHA = self.original_scope
        p.ENTITLEMENTS = self.original_entitlements

    def test_complete_five_resource_transition(self):
        plan, baseline, observed = maintenance()
        result, artifacts = v.review(plan, baseline, observed, REVISION, 'maintenance')
        self.assertEqual(result['resourceUpdates'], 5)
        self.assertEqual(artifacts['recovery']['source_hash'], p.RECOVERY_SHA)
        self.assertFalse(result['providerCallsEnabled'])

    def known_drift(self, plan):
        rows = p.inventory(plan)
        function = copy.deepcopy(rows[p.ENT_FUNCTION])
        before = function['change']['before']
        pin = p.ENTITLEMENTS['historical']
        before.update({k: pin[k] for k in ('version', 'code_sha256', 'source_code_size', 'last_modified')})
        before['qualified_arn'] = before['qualified_arn'].rsplit(':', 1)[0] + ':15'
        before['qualified_invoke_arn'] = before['qualified_invoke_arn'].replace(':18/invocations', ':15/invocations')
        p.environment(before)['DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON'] = json.dumps(['01997e3a-0000-7000-8000-000000000003'])
        function['change'].update(actions=['update'])
        alias = copy.deepcopy(rows[p.ENT_ALIAS])
        alias['change']['before']['function_version'] = '15'
        alias['change']['actions'] = ['update']
        plan['resource_drift'] = [function, alias]
        return plan

    def test_known_refresh_pair_preserves_live18_and_old_input_marker(self):
        plan, baseline, observed = maintenance()
        self.known_drift(plan); self.known_drift(baseline)
        result, _ = v.review(plan, baseline, observed, REVISION, 'maintenance')
        self.assertEqual(set(result['resourceAddresses']), v.MAINTENANCE)
        ent = p.inventory(plan)[p.ENT_FUNCTION]['change']
        self.assertEqual(ent['actions'], ['no-op'])
        self.assertNotEqual(ent['after']['source_code_hash'], ent['after']['code_sha256'])
        self.assertEqual(ent['after']['version'], '18')

    def test_no_drift_still_requires_exact_live18_and_independent_scopes(self):
        for field, replacement in (('version', '15'), ('code_sha256', 'wrong'),
                                   ('source_code_hash', p.ENTITLEMENTS['current']['code_sha256']),
                                   ('s3_object_version', 'invented')):
            plan, baseline, observed = maintenance()
            for source in (plan, baseline):
                for direction in ('before', 'after'):
                    p.inventory(source)[p.ENT_FUNCTION]['change'][direction][field] = replacement
            observed = capture(baseline, maintenance_contract(False)); sync(plan)
            with self.subTest(field=field), self.assertRaises(ValueError):
                v.review(plan, baseline, observed, REVISION, 'maintenance')
        for key in ('DEV_SUBJECT_ALLOWLIST_JSON', 'DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON'):
            plan, baseline, observed = maintenance()
            for source in (plan, baseline):
                for direction in ('before', 'after'):
                    p.environment(p.inventory(source)[p.ENT_FUNCTION]['change'][direction])[key] = json.dumps([SYNTHETIC[0]])
            # The base replacement is identical; specifically swap to the other subject.
            if key == 'DEV_SUBJECT_ALLOWLIST_JSON':
                for source in (plan, baseline):
                    for direction in ('before', 'after'):
                        p.environment(p.inventory(source)[p.ENT_FUNCTION]['change'][direction])[key] = json.dumps([SYNTHETIC[1]])
            observed = capture(baseline, maintenance_contract(False)); sync(plan)
            with self.subTest(key=key), self.assertRaises(ValueError):
                v.review(plan, baseline, observed, REVISION, 'maintenance')

    def test_drift_subset_unrelated_fields_and_real_rollback_rejected(self):
        for mutation in ('partial', 'extra', 'role', 'network', 'marker', 'old-code', 'new-env', 'alias-route', 'binding', 'duplicate'):
            plan, baseline, observed = maintenance(); self.known_drift(plan)
            drift = plan['resource_drift']; before = drift[0]['change']['before']; after = drift[0]['change']['after']
            if mutation == 'partial': drift.pop()
            if mutation == 'extra': drift.append(copy.deepcopy(drift[0])); drift[-1]['address'] = 'aws_iam_role.other'
            if mutation == 'role': before['role'] = 'other'
            if mutation == 'network': before['vpc_config'] = [{}]
            if mutation == 'marker': before['source_code_hash'] = 'other'
            if mutation == 'old-code': before['code_sha256'] = 'other'
            if mutation == 'new-env': p.environment(after)['AUTHORITY_ENABLED'] = 'false'
            if mutation == 'alias-route': drift[1]['change']['after']['routing_config'] = [{'additional_version_weights': {'15': 0.1}}]
            if mutation == 'binding': after['version'] = '19'
            if mutation == 'duplicate': drift.append(copy.deepcopy(drift[0]))
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                v.review(plan, baseline, observed, REVISION, 'maintenance')

    def test_entitlements_update_or_unknown_forbidden_despite_qualified_drift(self):
        for address, field, value in ((p.ENT_FUNCTION, 'version', '15'), (p.ENT_ALIAS, 'function_version', '15'),
                                      (p.ENT_FUNCTION, 'source_code_hash', 'wrong')):
            plan, baseline, observed = maintenance(); self.known_drift(plan); self.known_drift(baseline)
            row = p.inventory(plan)[address]; row['change']['actions'] = ['update']; row['change']['after'][field] = value; sync(plan)
            with self.subTest(address=address, field=field), self.assertRaises(ValueError):
                v.review(plan, baseline, observed, REVISION, 'maintenance')
        plan, baseline, observed = maintenance()
        p.inventory(plan)[p.ENT_FUNCTION]['change']['after_unknown'] = {'version': True}
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')

    def test_captured_artifact_marker_drift_rejected(self):
        plan, baseline, observed = maintenance()
        observed['functions']['entitlements']['artifactInputsSha256'] = 'wrong'
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')

    def test_current_candidate3_history_preserves_two_subjects_and_iam(self):
        plan, baseline, observed, targets = message()
        result, _ = v.review(plan, baseline, observed, REVISION, 'message-history', targets)
        self.assertEqual(result['resourceUpdates'], 4)
        self.assertEqual(plan['variables']['engineering_subjects']['value'], SYNTHETIC)

    def test_message_computed_hash_unknown_requires_reviewed_package_change(self):
        plan, baseline, observed, targets = message()
        row = p.inventory(plan)['aws_lambda_function.runtime["consumer"]']
        row['change']['after']['code_sha256'] = None
        row['change']['after_unknown'] = {'code_sha256': True}
        sync(plan)
        self.assertEqual(v.review(plan, baseline, observed, REVISION, 'message-history', targets)[0]['resourceUpdates'], 4)
        row['change']['after_unknown'] = {}
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'message-history', targets)
        row['change']['after']['code_sha256'] = 'wrong'
        sync(plan)
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'message-history', targets)

    def test_unrelated_iam_route_and_untouched_runtime_drift_rejected(self):
        for address in ('aws_iam_role_policy.recovery[0]', 'aws_apigatewayv2_route.v1["access"]',
                        'aws_lambda_function.runtime["entitlements"]'):
            plan, baseline, observed = maintenance()
            row = p.inventory(plan)[address]; row['change']['actions'] = ['update']; row['change']['after']['unexpected'] = True
            sync(plan)
            with self.subTest(address=address), self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')

    def test_worker_artifact_network_limits_and_alias_replay_rejected(self):
        for field, value in (('source_code_hash', 'wrong'), ('role', 'other'), ('timeout', 30), ('vpc_config', [{}])):
            plan, baseline, observed = maintenance()
            p.inventory(plan)[v.FUNCTION]['change']['after'][field] = value; sync(plan)
            with self.subTest(field=field), self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')
        plan, baseline, observed = maintenance(); p.inventory(plan)[v.ALIAS]['change']['after']['function_version'] = '1'; sync(plan)
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')

    def test_partial_maintenance_and_alarm_destination_changes_rejected(self):
        for address in (v.HEARTBEAT, v.OVERDUE, v.RULE):
            plan, baseline, observed = maintenance(); c = p.inventory(plan)[address]['change']
            c['actions'] = ['no-op']; c['after'] = copy.deepcopy(c['before']); sync(plan)
            with self.subTest(address=address), self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')
        plan, baseline, observed = maintenance(); p.inventory(plan)[v.HEARTBEAT]['change']['after']['alarm_actions'] = ['other']; sync(plan)
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')

    def test_snapshot_and_existing_private_scope_cannot_change(self):
        plan, baseline, observed = maintenance(); plan['variables']['dev_access_snapshot_extra_subjects']['value'] = []
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')
        plan, baseline, observed, targets = message(); plan['variables']['engineering_subjects']['value'] = [SYNTHETIC[0]]
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'message-history', targets)

    def test_ai_enablement_history_loss_and_permission_change_rejected(self):
        for key, value in (('MESSAGE_AI_ENABLED', 'true'), ('GOVERNED_HISTORY_SETTLEMENT_ENABLED', 'false')):
            plan, baseline, observed, targets = message()
            p.environment(p.inventory(plan)['aws_lambda_function.runtime["consumer"]']['change']['after'])[key] = value; sync(plan)
            with self.subTest(key=key), self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'message-history', targets)
        plan, baseline, observed, targets = message(); row = p.inventory(plan)['aws_iam_role_policy.evaluator[0]']
        row['change']['actions'] = ['update']; row['change']['after']['policy'] = '{}'; sync(plan)
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'message-history', targets)

    def test_failed_checks_deleted_inventory_and_replacements_rejected(self):
        for mutation in ('check', 'missing', 'replacement', 'drift', 'inventory'):
            plan, baseline, observed = maintenance()
            if mutation == 'check': plan['checks'] = [{'status': 'unknown'}]
            if mutation == 'missing': plan['resource_changes'].pop()
            if mutation == 'replacement': p.inventory(plan)[v.FUNCTION]['change']['actions'] = ['delete', 'create']
            if mutation == 'drift': plan['resource_drift'] = [{'mode': 'managed', 'change': {'actions': ['update']}}]
            if mutation == 'inventory': plan['planned_values']['root_module']['resources'].pop()
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')

    def test_unknown_published_version_requires_both_masks_and_source_binding(self):
        plan, baseline, observed = maintenance(); rows = p.inventory(plan)
        rows[v.FUNCTION]['change']['after']['version'] = None
        rows[v.FUNCTION]['change']['after_unknown'] = {'version': True}
        rows[v.ALIAS]['change']['after']['function_version'] = None
        rows[v.ALIAS]['change']['after_unknown'] = {'function_version': True}; sync(plan)
        for r in plan['planned_values']['root_module']['resources']:
            if r['address'] == v.FUNCTION: r['values'].pop('version')
            if r['address'] == v.ALIAS: r['values'].pop('function_version')
        self.assertEqual(v.review(plan, baseline, observed, REVISION, 'maintenance')[0]['resourceUpdates'], 5)
        rows[v.FUNCTION]['change']['after_unknown'] = {}
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')

    def test_digest_ignores_only_ephemeral_plan_timestamp(self):
        plan, baseline, observed = maintenance(); one = v.review(plan, baseline, observed, REVISION, 'maintenance')[0]
        plan['timestamp'] = 'later'; baseline['timestamp'] = 'later'
        self.assertEqual(one, v.review(plan, baseline, observed, REVISION, 'maintenance')[0])
        self.assertNotEqual(one['reviewedPlanDigest'], v.review(plan, baseline, observed, 'c' * 40, 'maintenance')[0]['reviewedPlanDigest'])

    def test_numeric_false_and_unknown_nested_values_rejected(self):
        plan, baseline, observed = maintenance(); p.inventory(plan)['aws_iam_role_policy.recovery[0]']['change']['after']['policy'] = 0; sync(plan)
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')
        plan, baseline, observed = maintenance(); p.inventory(plan)[v.FUNCTION]['change']['after_unknown'] = {'environment': [{'variables': True}]}
        with self.assertRaises(ValueError): v.review(plan, baseline, observed, REVISION, 'maintenance')

    def test_private_file_is_0600_exclusive_and_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'inputs.json'; p.private_write(path, {'private': 'synthetic'})
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            with self.assertRaises(FileExistsError): p.private_write(path, {})
            link = Path(temp) / 'link'; os.symlink(path, link)
            with self.assertRaises(FileExistsError): p.private_write(link, {})


class MaintenanceAlarmMetadataTests(unittest.TestCase):
    """Validate service-shaped metadata directly; no AWS clients are simulated."""

    def alarm(self, heartbeat=False, active=False):
        destination = ['arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts']
        return {'AlarmName': p.PREFIX + '-url-lease-recovery-' + ('heartbeat' if heartbeat else 'expiry-overdue'),
                'ActionsEnabled': active, 'AlarmActions': destination, 'OKActions': destination,
                'Namespace': 'AMT/TrustCheckRadar/V1/dev',
                'MetricName': 'url-lease-recovery-' + ('heartbeat' if heartbeat else 'expiry-overdue'),
                'Threshold': 1 if heartbeat else 300, 'EvaluationPeriods': 2 if heartbeat else 1,
                'Period': 300 if heartbeat else 60, 'Statistic': 'Sum' if heartbeat else 'Maximum',
                'ComparisonOperator': 'LessThanThreshold' if heartbeat else 'GreaterThanThreshold',
                'TreatMissingData': 'breaching' if active and heartbeat else 'notBreaching'}

    def test_absent_datapoints_uses_actual_evaluation_periods(self):
        for heartbeat in (False, True):
            for active in (False, True):
                with self.subTest(heartbeat=heartbeat, active=active):
                    p.require_maintenance_alarm(self.alarm(heartbeat, active), active)

    def test_explicit_same_datapoints_is_equivalent(self):
        for heartbeat in (False, True):
            alarm = self.alarm(heartbeat); alarm['DatapointsToAlarm'] = alarm['EvaluationPeriods']
            p.require_maintenance_alarm(alarm, False)

    def test_explicit_incompatible_or_malformed_datapoints_rejected(self):
        for value in (None, False, True, 0, 2, 1.0, '1'):
            alarm = self.alarm(); alarm['DatapointsToAlarm'] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                p.require_maintenance_alarm(alarm, False)
        alarm = self.alarm(True); alarm['DatapointsToAlarm'] = 1
        with self.assertRaises(ValueError): p.require_maintenance_alarm(alarm, False)

    def test_absence_cannot_conceal_wrong_evaluation_periods(self):
        for value in (None, False, True, 0, 2, 1.0, '1'):
            alarm = self.alarm(); alarm['EvaluationPeriods'] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                p.require_maintenance_alarm(alarm, False)

    def test_other_alarm_boundaries_remain_exact(self):
        for field, value in (('Period', 300), ('Statistic', 'Sum'), ('ComparisonOperator', 'LessThanThreshold'),
                             ('Threshold', 1), ('AlarmActions', ['other']), ('ActionsEnabled', True),
                             ('TreatMissingData', 'breaching'), ('Dimensions', [{'Name': 'other', 'Value': 'other'}]),
                             ('Metrics', [{}]), ('ExtendedStatistic', 'p99'), ('InsufficientDataActions', ['other'])):
            alarm = self.alarm(); alarm[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                p.require_maintenance_alarm(alarm, False)


if __name__ == '__main__': unittest.main()
