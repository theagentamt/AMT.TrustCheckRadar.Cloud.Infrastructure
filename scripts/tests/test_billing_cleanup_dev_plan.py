import copy
import json
import os
import sys
import tempfile
import unittest
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
        self.assertEqual(str(error.exception), prepare.ERROR)

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


if __name__ == '__main__': unittest.main()
