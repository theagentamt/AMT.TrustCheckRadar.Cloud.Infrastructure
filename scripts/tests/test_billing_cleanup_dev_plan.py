import copy
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import prepare_billing_cleanup_dev as prepare
import verify_billing_cleanup_dev_plan as guard
from test_billing_cleanup_prerequisite import fixture as metadata_fixture, BILLING, PRESERVED

REVISION = 'a' * 40


def fixture():
    metadata = metadata_fixture()
    metadata['function']['CodeSha256'] = prepare.artifact()['source_hash']
    metadata['function']['Environment']['Variables']['DEV_SUBJECT_ALLOWLIST_JSON'] = json.dumps([PRESERVED], separators=(',', ':'))
    activation = {'source_sha': prepare.SOURCE, 'subjects': [PRESERVED],
                  **{key: 'synthetic boundary test; no approval' for key in ('inventory_reference', 'runtime_reference', 'permissions_reference')}}
    values = {'environment': 'dev', 'aws_region': 'us-east-1', 'project_name': 'trustcheckradar', 'enabled': True,
              'deletion_activation': activation,
              'deletion_artifact_override': {'source_sha': prepare.SOURCE, 'artifact': prepare.artifact()},
              'billing_activation': None, 'billing_artifact_overrides': {}}
    live = metadata['function']
    before = {field: live[key] for field, key in {
        'function_name': 'FunctionName', 'role': 'Role', 'runtime': 'Runtime', 'handler': 'Handler',
        'architectures': 'Architectures', 'timeout': 'Timeout', 'memory_size': 'MemorySize', 'version': 'Version'}.items()}
    before.update({key: prepare.artifact()[value] for key, value in guard.PACKAGE_FIELDS.items()})
    before.update(environment=[{'variables': copy.deepcopy(live['Environment']['Variables'])}],
                  publish=True, reserved_concurrent_executions=1)
    alias = {'function_name': prepare.prerequisite.FUNCTION, 'name': 'live', 'function_version': live['Version'], 'routing_config': []}
    def row(address, value):
        return {'address': address, 'type': address.split('.')[0], 'mode': 'managed',
                'provider_name': 'registry.terraform.io/hashicorp/aws',
                'change': {'actions': ['no-op'], 'before': copy.deepcopy(value), 'after': copy.deepcopy(value), 'after_unknown': {}}}
    rows = [row(guard.FUNCTION_ADDRESS, before), row(guard.ALIAS_ADDRESS, alias),
            row('aws_iam_role_policy.runtime["deletion"]', {'policy': 'unchanged private policy'}),
            row('aws_scheduler_schedule.lifecycle["deletion"]', {'state': 'ENABLED', 'schedule_expression': 'rate(1 minute)'}),
            row('aws_lambda_event_source_mapping.deletion[0]', {'enabled': True}),
            row('aws_lambda_function.runtime["worker"]', {'environment': [{'variables': {'PLAY_LIFECYCLE_ENABLED': 'false'}}]})]
    baseline = {'complete': True, 'errored': False, 'terraform_version': '1.12.1',
                'variables': {key: {'value': value} for key, value in values.items()}, 'resource_changes': rows,
                'resource_drift': [], 'checks': [{'status': 'pass'}],
                'output_changes': {'candidate_contract': {'actions': ['no-op'], 'before': {'lifecycle_active': False}, 'after': {'lifecycle_active': False}, 'after_unknown': False}},
                'configuration': {'root_module': {'resources': [{'address': 'aws_lambda_alias.runtime', 'expressions': {'function_version': {'references': ['aws_lambda_function.runtime']}}}]}}}
    captured = {'selected': [BILLING], 'metadata': metadata}
    plan = copy.deepcopy(baseline)
    plan['variables']['deletion_activation']['value']['subjects'] = sorted([PRESERVED, BILLING])
    function, alias = [row['change'] for row in plan['resource_changes'][:2]]
    function.update(actions=['update'], after_unknown={'version': True})
    function['after']['environment'][0]['variables']['DEV_SUBJECT_ALLOWLIST_JSON'] = json.dumps(sorted([PRESERVED, BILLING]), separators=(',', ':'))
    function['after']['version'] = None
    alias.update(actions=['update'], after_unknown={'function_version': True})
    alias['after']['function_version'] = None
    return plan, baseline, captured


class CleanupPlanTests(unittest.TestCase):
    def review(self, values):
        return guard.review(*values, REVISION)

    def test_only_union_and_published_alias_changes_are_accepted(self):
        data = fixture(); before = copy.deepcopy(data)
        result = self.review(data)
        self.assertEqual(data, before)
        self.assertEqual(result['resourceUpdates'], 2)
        self.assertEqual(result['preservedSubjectCount'], 1)
        self.assertEqual(result['cleanupSubjectCount'], 2)
        self.assertTrue(result['planOnly'])
        self.assertFalse(result['behavioralQualification'])
        self.assertNotIn(BILLING, json.dumps(result))
        self.assertNotIn(PRESERVED, json.dumps(result))

    def test_already_covered_selection_is_an_honest_noop(self):
        _, baseline, captured = fixture()
        captured['selected'] = [PRESERVED]
        self.assertEqual(self.review((copy.deepcopy(baseline), baseline, captured))['resourceUpdates'], 0)

    def test_union_preserves_actual_live_selection_instead_of_stale_source(self):
        _, baseline, captured = fixture()
        baseline['variables']['deletion_activation']['value']['subjects'] = ['00000000-0000-4000-8000-000000000098']
        result = prepare.build(baseline, [BILLING], captured['metadata'])
        self.assertEqual(result['deletion_activation']['subjects'], sorted([PRESERVED, BILLING]))

    def test_reject_lost_previous_or_extra_unapproved_subject(self):
        for subjects in ([BILLING], [PRESERVED], [PRESERVED, BILLING, '00000000-0000-4000-8000-000000000098']):
            data = fixture(); data[0]['variables']['deletion_activation']['value']['subjects'] = subjects
            with self.subTest(subjects=subjects), self.assertRaises(ValueError): self.review(data)

    def test_capacity_and_missing_selection_fail_before_any_read(self):
        _, baseline, captured = fixture()
        for selected in ([], None, ['invalid'], [BILLING, PRESERVED]):
            with self.subTest(selected=selected), self.assertRaises(ValueError): prepare.build(baseline, selected, captured['metadata'])
        captured['metadata']['function']['Environment']['Variables']['DEV_SUBJECT_ALLOWLIST_JSON'] = json.dumps([
            f'00000000-0000-4000-8000-{number:012d}' for number in range(10, 20)])
        with self.assertRaises(ValueError): prepare.build(baseline, [BILLING], captured['metadata'])

    def test_no_credentials_or_identity_fallback_on_missing_secret(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(sys, 'argv', ['prepare', '--baseline-plan', '/unused']), \
             patch.object(prepare, 'capture', side_effect=AssertionError('Must reject before AWS')):
            with self.assertRaises(SystemExit) as error: prepare.main()
        self.assertEqual(str(error.exception), 'selection_shape')

    def test_unrelated_iam_schedule_stream_or_worker_change_rejected(self):
        for index in range(2, 6):
            data = fixture(); change = data[0]['resource_changes'][index]['change']
            change['actions'] = ['update']; change['after']['unrelated'] = True
            with self.subTest(index=index), self.assertRaises(ValueError): self.review(data)

    def test_replacement_drift_unknown_and_missing_inventory_rejected(self):
        for mutation in ('replacement', 'drift', 'unknown', 'missing', 'duplicate', 'failed-check'):
            data = fixture(); plan = data[0]
            if mutation == 'replacement': plan['resource_changes'][0]['change']['actions'] = ['delete', 'create']
            if mutation == 'drift': plan['resource_drift'] = [{'mode': 'managed'}]
            if mutation == 'unknown': plan['resource_changes'][0]['change']['after_unknown']['environment'] = True
            if mutation == 'missing': plan['resource_changes'].pop()
            if mutation == 'duplicate': plan['resource_changes'].append(copy.deepcopy(plan['resource_changes'][0]))
            if mutation == 'failed-check': plan['checks'] = [{'status': 'unknown'}]
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): self.review(data)

    def test_package_runtime_and_non_subject_environment_are_fixed(self):
        for field in ('s3_key', 's3_object_version', 'source_code_hash', 'role', 'runtime', 'handler', 'timeout', 'reserved_concurrent_executions'):
            data = fixture(); data[0]['resource_changes'][0]['change']['after'][field] = 'other'
            with self.subTest(field=field), self.assertRaises(ValueError): self.review(data)
        for key in ('PLAY_LIFECYCLE_ENABLED', 'PLAY_TOKEN_CLEANUP_ENABLED', 'AUTHORITY_POLICY_VERSION', 'DELETION_RECEIPT_RETENTION_SECONDS'):
            data = fixture(); data[0]['resource_changes'][0]['change']['after']['environment'][0]['variables'][key] = 'other'
            with self.subTest(key=key), self.assertRaises(ValueError): self.review(data)

    def test_live_snapshot_and_alias_must_match_plan_and_published_dependency(self):
        for mutation in ('live-version', 'weighted', 'version', 'reference'):
            data = fixture(); plan, _, captured = data
            if mutation == 'live-version': captured['metadata']['function']['Version'] = '99'
            if mutation == 'weighted': plan['resource_changes'][1]['change']['after']['routing_config'] = [{'additional_version_weights': {'99': 0.5}}]
            if mutation == 'version': plan['resource_changes'][1]['change']['after']['function_version'] = '99'
            if mutation == 'reference': plan['configuration']['root_module']['resources'][0]['expressions']['function_version']['references'] = ['unrelated.function']
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): self.review(data)

    def test_digest_changes_with_reviewed_source(self):
        data = fixture()
        self.assertNotEqual(self.review(data)['reviewedPlanDigest'], guard.review(*data, 'b' * 40)['reviewedPlanDigest'])

    def test_cannot_move_alias_to_preexisting_known_version(self):
        data = fixture()
        for index, field in ((0, 'version'), (1, 'function_version')):
            data[0]['resource_changes'][index]['change']['after'][field] = '99'
            data[0]['resource_changes'][index]['change']['after_unknown'] = {}
        with self.assertRaises(ValueError): self.review(data)

    def test_private_output_cannot_follow_symlink_or_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'target'
            prepare.write_private(target, {'private': BILLING})
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            with self.assertRaises(FileExistsError): prepare.write_private(target, {})
            link = Path(directory) / 'link'; link.symlink_to(target)
            with self.assertRaises(FileExistsError): prepare.write_private(link, {})


class CleanupRejectionDiagnosticTests(unittest.TestCase):
    def rejection(self, selected, baseline=None, capture_error=None, load_error=None):
        if baseline is None:
            _, baseline, _ = fixture()
        artifact = prepare.artifact()
        env = {} if selected is None else {'BILLING_ENGINEERING_SUBJECTS_JSON': selected}
        with patch.dict(os.environ, env, clear=True), \
             patch.object(sys, 'argv', ['prepare', '--baseline-plan', '/unused-private-plan']), \
             patch.object(prepare, 'load', return_value=baseline, side_effect=load_error), \
             patch.object(prepare, 'artifact', return_value=artifact), \
             patch.object(prepare, 'capture', side_effect=capture_error or AssertionError('AWS must not be reached')) as capture, \
             redirect_stdout(StringIO()) as stdout, redirect_stderr(StringIO()) as stderr:
            with self.assertRaises(SystemExit) as error:
                prepare.main()
        self.assertEqual(stdout.getvalue(), '')
        self.assertEqual(stderr.getvalue(), '')
        code = str(error.exception)
        self.assertIn(code, prepare.CODES)
        self.assertNotIn(BILLING, code)
        self.assertNotIn(PRESERVED, code)
        return code, capture.call_count

    def test_missing_malformed_or_noncanonical_selection_has_fixed_category(self):
        cases = [(None, 'selection_shape'), ('', 'selection_shape'), ('[', 'selection_json'),
                 (json.dumps({'private': BILLING}), 'selection_shape'),
                 (json.dumps(['NONCANONICAL-' + BILLING]), 'selection_shape'),
                 (json.dumps([BILLING, PRESERVED]), 'selection_shape'),
                 ('{"private":"' + BILLING + '","private":"' + PRESERVED + '"}', 'selection_json')]
        for selected, expected in cases:
            with self.subTest(expected=expected, selected=selected):
                self.assertEqual(self.rejection(selected), (expected, 0))

    def test_plan_drift_and_check_rejections_are_distinct_without_resource_values(self):
        for key, value, expected in [
            ('resource_drift', [{'address': 'private-resource-' + BILLING}], 'plan_drift'),
            ('checks', [{'status': 'unknown', 'private': BILLING}], 'plan_checks'),
            ('checks', [{'status': 'fail', 'private': PRESERVED}], 'plan_checks'),
            ('complete', False, 'plan_complete'), ('errored', True, 'plan_complete'),
            ('terraform_version', 'private-version-' + BILLING, 'plan_version'),
        ]:
            _, baseline, _ = fixture(); baseline[key] = value
            with self.subTest(key=key):
                self.assertEqual(self.rejection(json.dumps([BILLING]), baseline), (expected, 0))

    def test_unexpected_parse_or_capture_exception_never_appears_in_output(self):
        private = 'credential-like-sentinel-' + BILLING
        self.assertEqual(self.rejection(json.dumps([BILLING]), load_error=RuntimeError(private)), ('baseline_json', 0))
        self.assertEqual(self.rejection(json.dumps([BILLING]), capture_error=RuntimeError(private)), ('metadata_capture', 1))

    def test_exception_codes_are_allowlisted_at_creation_and_emission(self):
        with self.assertRaises(prepare.PlanningRejected) as error:
            prepare.require(False, BILLING)
        self.assertEqual(error.exception.code, 'internal')
        self.assertEqual(str(error.exception), prepare.ERROR)
        unsafe = prepare.PlanningRejected('metadata_account')
        unsafe.code = BILLING
        self.assertEqual(self.rejection(json.dumps([BILLING]), capture_error=unsafe), ('internal', 1))
        self.assertEqual(prepare.public_code({'private': BILLING}), 'internal')


def timestamp_drift_fixture():
    plan, baseline, captured = fixture()
    identifier = '22222222-2222-4222-8222-222222222222'
    mapping = captured['metadata']['mappings']['EventSourceMappings'][0]
    mapping.update(UUID=identifier, EventSourceMappingArn=f'arn:aws:lambda:us-east-1:{prepare.prerequisite.ACCOUNT}:event-source-mapping:{identifier}',
                   LastModified='2026-09-30T17:23:00-05:00', MaximumBatchingWindowInSeconds=0,
                   ParallelizationFactor=1, TumblingWindowInSeconds=0, StartingPosition='TRIM_HORIZON')
    after = {'id': identifier, 'uuid': identifier, 'arn': mapping['EventSourceMappingArn'],
             'function_arn': mapping['FunctionArn'], 'function_name': mapping['FunctionArn'],
             'event_source_arn': mapping['EventSourceArn'], 'enabled': True, 'state': 'Enabled',
             'last_modified': '2026-09-30T22:23:00Z', 'starting_position': 'TRIM_HORIZON',
             'kms_key_arn': '', 'starting_position_timestamp': '',
             'batch_size': 5, 'maximum_batching_window_in_seconds': 0, 'parallelization_factor': 1,
             'maximum_retry_attempts': 2, 'maximum_record_age_in_seconds': 600,
             'bisect_batch_on_function_error': True, 'tumbling_window_in_seconds': 0,
             'function_response_types': ['ReportBatchItemFailures'],
             'filter_criteria': [{'filter': [{'pattern': mapping['FilterCriteria']['Filters'][0]['Pattern']}]}]}
    before = dict(after, last_modified='2026-09-29T22:23:00Z')
    row = {'address': prepare.MAPPING_ADDRESS, 'mode': 'managed', 'type': 'aws_lambda_event_source_mapping',
           'provider_name': prepare.MAPPING_PROVIDER,
           'change': {'actions': ['update'], 'before': before, 'after': after, 'after_unknown': {}}}
    config = {'address': 'aws_lambda_event_source_mapping.deletion', 'expressions': {
        'event_source_arn': {'references': ['var.deployment.deletion_stream_arn', 'var.deployment']},
        'function_name': {'references': ['aws_lambda_alias.runtime["deletion"].arn',
                                       'aws_lambda_alias.runtime["deletion"]', 'aws_lambda_alias.runtime']}}}
    for target in (plan, baseline):
        target['variables']['deployment'] = {'value': {'deletion_stream_arn': mapping['EventSourceArn']}}
        target['resource_drift'] = [copy.deepcopy(row)]
        counterpart = next(entry for entry in target['resource_changes'] if entry['address'] == prepare.MAPPING_ADDRESS)
        counterpart['change'] = {'actions': ['no-op'], 'before': copy.deepcopy(after), 'after': copy.deepcopy(after), 'after_unknown': {}}
        target['configuration']['root_module']['resources'].append(copy.deepcopy(config))
    return plan, baseline, captured


class MappingTimestampDriftTests(unittest.TestCase):
    def rejects(self, plan, metadata):
        with self.assertRaises(prepare.PlanningRejected) as error:
            prepare.variables(plan, metadata)
        self.assertEqual(error.exception.code, 'plan_drift')

    def test_exact_timestamp_refresh_requires_timezone_equivalent_live_proof(self):
        plan, baseline, captured = timestamp_drift_fixture()
        metadata = captured['metadata']
        self.assertEqual(prepare.variables(plan, metadata)['environment'], 'dev')
        self.assertEqual(prepare.build(baseline, captured['selected'], metadata)['deletion_activation']['subjects'], sorted([BILLING, PRESERVED]))
        self.assertEqual(guard.review(plan, baseline, captured, REVISION)['resourceUpdates'], 2)
        self.rejects(plan, None)
        metadata['mappings']['EventSourceMappings'][0]['LastModified'] = '2026-09-30T22:23:00+00:00'
        self.assertEqual(prepare.variables(plan, metadata)['environment'], 'dev')

    def test_other_resource_provider_action_or_additional_drift_rejected(self):
        mutations = [('address', 'aws_lambda_function.runtime["deletion"]'), ('mode', 'data'),
                     ('type', 'aws_lambda_function'), ('provider_name', 'registry.terraform.io/other/aws')]
        for field, value in mutations:
            plan, _, captured = timestamp_drift_fixture(); plan['resource_drift'][0][field] = value
            with self.subTest(field=field): self.rejects(plan, captured['metadata'])
        for action in (['no-op'], ['delete', 'create'], ['create']):
            plan, _, captured = timestamp_drift_fixture(); plan['resource_drift'][0]['change']['actions'] = action
            with self.subTest(action=action): self.rejects(plan, captured['metadata'])
        for extra in ({'mode': 'data'}, {'mode': 'managed'}):
            plan, _, captured = timestamp_drift_fixture(); plan['resource_drift'].append(extra)
            with self.subTest(extra=extra): self.rejects(plan, captured['metadata'])

    def test_other_changed_fields_unknowns_and_changed_counterpart_rejected(self):
        for mutation in ('other-field', 'before-unknown', 'after-unknown', 'counterpart-after', 'counterpart-actions', 'counterpart-unknown', 'duplicate'):
            plan, _, captured = timestamp_drift_fixture()
            drift = plan['resource_drift'][0]['change']
            counterpart = next(row for row in plan['resource_changes'] if row['address'] == prepare.MAPPING_ADDRESS)
            if mutation == 'other-field': drift['before']['batch_size'] = 99
            if mutation == 'before-unknown': drift['before_unknown'] = {'last_modified': True}
            if mutation == 'after-unknown': drift['after_unknown'] = {'last_modified': True}
            if mutation == 'counterpart-after': counterpart['change']['after']['batch_size'] = 99
            if mutation == 'counterpart-actions': counterpart['change']['actions'] = ['update']
            if mutation == 'counterpart-unknown': counterpart['change']['after_unknown'] = {'filter_criteria': [{'filter': True}]}
            if mutation == 'duplicate': plan['resource_changes'].append(copy.deepcopy(counterpart))
            with self.subTest(mutation=mutation): self.rejects(plan, captured['metadata'])

    def test_timestamp_malformed_naive_equal_or_fresh_mismatch_rejected(self):
        for value in ('2026-09-30T22:23:00', 'not-a-timestamp', '2026-99-30T22:23:00Z', '2026-09-30T22:23:01Z'):
            plan, _, captured = timestamp_drift_fixture()
            captured['metadata']['mappings']['EventSourceMappings'][0]['LastModified'] = value
            with self.subTest(value=value): self.rejects(plan, captured['metadata'])
        plan, _, captured = timestamp_drift_fixture()
        plan['resource_drift'][0]['change']['before']['last_modified'] = '2026-09-30T17:23:00-05:00'
        self.rejects(plan, captured['metadata'])

    def test_wrong_live_identity_or_configuration_rejected(self):
        for field, value in [('UUID', 'not-a-uuid'), ('EventSourceMappingArn', 'other'), ('FunctionArn', 'other'),
                             ('EventSourceArn', 'other'), ('State', 'Disabled'), ('BatchSize', 99),
                             ('MaximumRetryAttempts', -1), ('MaximumBatchingWindowInSeconds', 10),
                             ('StartingPosition', 'LATEST'), ('DestinationConfig', {'OnFailure': {'Destination': 'other'}}),
                             ('FilterCriteria', {'Filters': [{'Pattern': '{}'}]})]:
            plan, _, captured = timestamp_drift_fixture()
            captured['metadata']['mappings']['EventSourceMappings'][0][field] = value
            with self.subTest(field=field): self.rejects(plan, captured['metadata'])

    def test_only_two_absent_provider_strings_are_normalized_and_live_start_required(self):
        for field, live_field in [('kms_key_arn', 'KMSKeyArn'), ('starting_position_timestamp', 'StartingPositionTimestamp')]:
            plan, _, captured = timestamp_drift_fixture()
            for side in ('before', 'after'): plan['resource_drift'][0]['change'][side][field] = 'nonempty'
            counterpart = next(row for row in plan['resource_changes'] if row['address'] == prepare.MAPPING_ADDRESS)
            for side in ('before', 'after'): counterpart['change'][side][field] = 'nonempty'
            with self.subTest(field=field): self.rejects(plan, captured['metadata'])
            plan, _, captured = timestamp_drift_fixture()
            captured['metadata']['mappings']['EventSourceMappings'][0][live_field] = None
            with self.subTest(live_field=live_field): self.rejects(plan, captured['metadata'])
        plan, _, captured = timestamp_drift_fixture()
        del captured['metadata']['mappings']['EventSourceMappings'][0]['StartingPosition']
        self.rejects(plan, captured['metadata'])
        for field in ('id', 'uuid', 'arn', 'function_arn', 'function_name', 'event_source_arn'):
            plan, _, captured = timestamp_drift_fixture()
            for side in ('before', 'after'): plan['resource_drift'][0]['change'][side][field] = 'other'
            counterpart = next(row for row in plan['resource_changes'] if row['address'] == prepare.MAPPING_ADDRESS)
            for side in ('before', 'after'): counterpart['change'][side][field] = 'other'
            with self.subTest(field=field): self.rejects(plan, captured['metadata'])

    def test_source_timestamp_assignment_or_wrong_binding_rejected(self):
        for mutation in ('timestamp', 'function-ref', 'source-ref', 'literal', 'declared-stream'):
            plan, _, captured = timestamp_drift_fixture()
            expr = plan['configuration']['root_module']['resources'][-1]['expressions']
            if mutation == 'timestamp': expr['last_modified'] = {'constant_value': '2026-09-30T22:23:00Z'}
            if mutation == 'function-ref': expr['function_name']['references'] = ['aws_lambda_alias.runtime["worker"].arn']
            if mutation == 'source-ref': expr['event_source_arn']['references'] = ['var.other_stream']
            if mutation == 'literal': expr['function_name'] = {'constant_value': prepare.prerequisite.ALIAS}
            if mutation == 'declared-stream': plan['variables']['deployment']['value']['deletion_stream_arn'] = 'other'
            with self.subTest(mutation=mutation): self.rejects(plan, captured['metadata'])

    def test_preparation_checks_static_gates_then_captures_metadata_once(self):
        _, baseline, captured = timestamp_drift_fixture()
        artifact = prepare.artifact()
        with tempfile.TemporaryDirectory() as directory, \
             patch.dict(os.environ, {'BILLING_ENGINEERING_SUBJECTS_JSON': json.dumps([BILLING]), 'RUNNER_TEMP': directory}, clear=True), \
             patch.object(sys, 'argv', ['prepare', '--baseline-plan', '/unused-private-plan']), \
             patch.object(prepare, 'load', return_value=baseline), patch.object(prepare, 'artifact', return_value=artifact), \
             patch.object(prepare, 'capture', return_value=captured['metadata']) as capture, redirect_stdout(StringIO()):
            prepare.main()
            self.assertEqual(capture.call_count, 1)
        for field, value, code in [('complete', False, 'plan_complete'), ('terraform_version', 'other', 'plan_version'),
                                   ('checks', [{'status': 'unknown'}], 'plan_checks')]:
            _, baseline, _ = timestamp_drift_fixture(); baseline[field] = value
            with self.subTest(field=field), patch.dict(os.environ, {'BILLING_ENGINEERING_SUBJECTS_JSON': json.dumps([BILLING])}, clear=True), \
                 patch.object(sys, 'argv', ['prepare', '--baseline-plan', '/unused-private-plan']), \
                 patch.object(prepare, 'load', return_value=baseline), patch.object(prepare, 'artifact', return_value=artifact), \
                 patch.object(prepare, 'capture', side_effect=AssertionError('Static gates must run first')) as capture:
                with self.assertRaises(SystemExit) as error: prepare.main()
                self.assertEqual(str(error.exception), code)
                self.assertEqual(capture.call_count, 0)


if __name__ == '__main__': unittest.main()
