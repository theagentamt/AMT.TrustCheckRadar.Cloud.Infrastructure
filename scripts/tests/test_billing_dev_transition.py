import copy
from contextlib import redirect_stdout
from io import StringIO
from types import SimpleNamespace
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import prepare_billing_dev_configuration as prepare
import verify_billing_dev_plan as guard
import verify_billing_dev_readback as readback
import billing_inventory_access as inventory_access

SOURCE = 'a' * 40
REVISION = 'b' * 40
SUBJECT = '00000000-0000-4000-8000-000000000001'
EVIDENCE = {k: 'synthetic qualification' for k in ('inventory_reference', 'runtime_reference', 'permissions_reference')}
PROVENANCE = dict(source_sha=SOURCE, **{name: '0' * 64 for name in prepare.PACKAGES.values()})


class ProvenanceCase(unittest.TestCase):
    def setUp(self):
        for module in (prepare, guard):
            binding = patch.object(module, 'load_provenance', return_value=PROVENANCE)
            binding.start()
            self.addCleanup(binding.stop)


def fixture(scope='handoff', mode='verification'):
    names = ['handoff'] if scope == 'handoff' else ['ingress', 'worker']
    pins = {name: {'source_sha': SOURCE, 'provenance_reference': 'synthetic package qualification', 'artifact': {'bucket': prepare.BUCKET, 'key': f'releases/{SOURCE}/{prepare.PACKAGES[name]}.zip', 'object_version': 'synthetic', 'source_hash': 'A' * 43 + '='}} for name in names}
    active = mode != 'inactive'
    selected_subjects = [SUBJECT] if active else []
    variables = {'enabled': True, 'environment': 'dev', 'project_name': 'trustcheckradar', 'aws_region': 'us-east-1', 'billing_activation': dict(mode=mode, source_sha=SOURCE, subjects=selected_subjects, **EVIDENCE) if active else None}
    if scope == 'handoff': variables['billing_artifact_override'] = pins['handoff']
    else: variables['billing_artifact_overrides'] = pins
    changes = []
    for name in names:
        suffix = 'runtime[0]' if name == 'handoff' else f'runtime["{name}"]'
        function = 'trustcheckradar-dev-' + {'handoff': 'v1-play-handoff', 'ingress': 'play-lifecycle-ingress', 'worker': 'play-lifecycle-worker'}[name]
        selected_active = active and (name != 'worker' or mode == 'background')
        env = {'STAGE': 'dev', 'PLAY_REQUIRE_TEST_PURCHASES': 'true', 'PLAY_CATALOG_P1M_VERIFIED': 'true', 'AUTHORITY_ENABLED': str(selected_active).lower(), 'PLAY_LIFECYCLE_ENABLED': str(selected_active and (name != 'handoff' or mode == 'verification')).lower(), 'DEV_SUBJECT_ALLOWLIST_JSON': json.dumps(selected_subjects if selected_active else [], separators=(',', ':'))}
        if name == 'handoff': env.update(PLAY_HANDOFF_ENABLED=str(mode == 'verification').lower(), PLAY_PREPARATION_ENABLED=str(active).lower())
        else:
            env.update(PLAY_PREPARATION_ENABLED='false', PLAY_TOKEN_CLEANUP_ENABLED='false', PLAY_CHECKPOINT_POLICY_APPROVED='false', PLAY_SCOPED_OWNED_HEAD_ONLY_ENABLED=str(selected_active).lower())
            if name == 'worker': env['PLAY_SCOPED_LIFECYCLE_WORKER_ENABLED'] = str(mode == 'background').lower()
        after = {'function_name': function, 'role': f'arn:aws:iam::{prepare.ACCOUNT}:role/{function}-execution', 'runtime': 'python3.14', 'architectures': ['arm64'], 'publish': True, 'timeout': 60 if name == 'worker' else 29, 'memory_size': 256, 'reserved_concurrent_executions': 1 if name == 'worker' else 2, 'version': '2', 'environment': [{'variables': env}], **{field: pins[name]['artifact'][key] for field, key in guard.PACKAGE_FIELDS.items()}}
        before = copy.deepcopy(after); before['version'] = '1'; before['environment'][0]['variables']['AUTHORITY_ENABLED'] = 'false'
        changes.append({'address': 'aws_lambda_function.' + suffix, 'type': 'aws_lambda_function', 'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws', 'change': {'actions': ['update'], 'before': before, 'after': after}})
        alias_after = {'name': 'live', 'function_name': function, 'function_version': '2', 'routing_config': []}
        changes.append({'address': 'aws_lambda_alias.' + suffix, 'type': 'aws_lambda_alias', 'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws', 'change': {'actions': ['update'], 'before': dict(alias_after, function_version='1'), 'after': alias_after}})
    if scope == 'lifecycle':
        for address, after, field, old in [('aws_scheduler_schedule.lifecycle["worker"]', {'state': 'ENABLED' if mode == 'background' else 'DISABLED'}, 'state', 'DISABLED'), ('aws_cloudwatch_metric_alarm.operational["worker-heartbeat"]', {'actions_enabled': mode == 'background'}, 'actions_enabled', False)]:
            changes.append({'address': address, 'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws', 'change': {'actions': ['update'] if mode == 'background' else ['no-op'], 'before': dict(after, **{field: old}), 'after': after}})
    if scope == 'lifecycle':
        table = f'arn:aws:dynamodb:us-east-1:{prepare.ACCOUNT}:table/trustcheckradar-dev-play-tokens'
        before_statements = [
            {'Sid': 'TokenReads', 'Effect': 'Allow', 'Action': ['dynamodb:GetItem', 'dynamodb:ConditionCheckItem', 'dynamodb:Query'], 'Resource': table},
            {'Sid': 'DueTokenKeys', 'Effect': 'Allow', 'Action': 'dynamodb:Query', 'Resource': table + '/index/GSI1'},
            {'Sid': 'LifecycleCheckpointRead', 'Effect': 'Allow', 'Action': ['dynamodb:GetItem'], 'Resource': table},
            {'Sid': 'LifecycleCheckpointWrite', 'Effect': 'Allow', 'Action': ['dynamodb:PutItem'], 'Resource': table},
            {'Sid': 'ExactOtherPermission', 'Effect': 'Allow', 'Action': 'secretsmanager:GetSecretValue', 'Resource': 'synthetic-secret-reference'},
        ]
        after_statements = [dict(before_statements[0], Action=['dynamodb:GetItem', 'dynamodb:ConditionCheckItem']), before_statements[-1],
            {'Sid': 'NoScopedTokenEnumeration', 'Effect': 'Deny', 'Action': ['dynamodb:Query', 'dynamodb:Scan'], 'Resource': [table, table + '/index/*']},
            {'Sid': 'NoScopedCheckpointAccess', 'Effect': 'Deny', 'Action': ['dynamodb:GetItem', 'dynamodb:ConditionCheckItem', 'dynamodb:PutItem', 'dynamodb:UpdateItem', 'dynamodb:DeleteItem'], 'Resource': table, 'Condition': {'ForAnyValue:StringEquals': {'dynamodb:LeadingKeys': ['PLAY#CONTROL']}}},
        ]
        changes.append({'address': 'aws_iam_role_policy.runtime["worker"]', 'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws', 'change': {'actions': ['update'], 'before': {'role': 'worker-execution', 'policy': json.dumps({'Version': '2012-10-17', 'Statement': before_statements})}, 'after': {'role': 'worker-execution', 'policy': json.dumps({'Version': '2012-10-17', 'Statement': after_statements})}}})
    contract = {'billing_subject_count': len(selected_subjects)}
    if scope == 'handoff': contract.update(general_customer_access=False, play_handoff_enabled=mode == 'verification', preparation_enabled=active)
    else: contract.update(lifecycle_active=active, scheduled_worker_active=mode == 'background', google_transport_provisioned=False)
    return {'complete': True, 'terraform_version': '1.12.1', 'variables': {k: {'value': v} for k, v in variables.items()}, 'resource_changes': changes, 'resource_drift': [], 'checks': [{'status': 'pass'}], 'output_changes': {'candidate_contract': {'after': contract}}}


def stale_role_mirror_fixture():
    plan = fixture('handoff', 'preparation')
    role = 'trustcheckradar-dev-v1-play-handoff-execution'
    policies = [
        ('lifecycle', 'prepare-binding-and-retain-verified-token',
         {'Version': '2012-10-17', 'Statement': [{'Sid': 'NewTokenEnvelopeKeyOnly', 'Effect': 'Allow', 'Action': 'kms:GenerateDataKey', 'Resource': 'synthetic-key', 'Condition': {'StringEquals': {'kms:EncryptionAlgorithm': 'SYMMETRIC_DEFAULT'}}}]}),
        ('runtime', 'verified-play-ownership-and-authority',
         {'Version': '2012-10-17', 'Statement': [{'Sid': 'OwnLogs', 'Effect': 'Allow', 'Action': 'logs:PutLogEvents', 'Resource': 'synthetic-log'}]}),
    ]
    mirror = []
    for suffix, name, document in policies:
        definition = {'name': name, 'role': role, 'policy': json.dumps(document)}
        plan['resource_changes'].append({'address': f'aws_iam_role_policy.{suffix}[0]', 'type': 'aws_iam_role_policy', 'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws', 'change': {'actions': ['no-op'], 'before': copy.deepcopy(definition), 'after': definition}})
        mirror.append({'name': name, 'policy': json.dumps(document)})
    current = {'name': role, 'id': role, 'arn': f'arn:aws:iam::{prepare.ACCOUNT}:role/{role}', 'assume_role_policy': 'synthetic unchanged trust', 'permissions_boundary': '', 'inline_policy': mirror}
    stale = copy.deepcopy(current)
    old_policy = json.loads(stale['inline_policy'][0]['policy'])
    old_policy['Statement'][0]['Condition'] = {'StringEquals': {'kms:DataKeySpec': 'AES_256'}}
    stale['inline_policy'][0]['policy'] = json.dumps(old_policy)
    plan['resource_drift'] = [{'address': 'aws_iam_role.runtime[0]', 'type': 'aws_iam_role', 'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws', 'change': {'actions': ['update'], 'before': stale, 'after': copy.deepcopy(current)}}]
    plan['resource_changes'].append({'address': 'aws_iam_role.runtime[0]', 'type': 'aws_iam_role', 'mode': 'managed', 'provider_name': 'registry.terraform.io/hashicorp/aws', 'change': {'actions': ['no-op'], 'before': copy.deepcopy(current), 'after': current}})
    return plan


class PlanTests(ProvenanceCase):
    def test_stale_role_mirror_matches_unchanged_declared_policies_and_binds_digest(self):
        plan = stale_role_mirror_fixture()
        _, digest, updates, _ = guard.review(plan, REVISION, 'handoff', 'preparation')
        self.assertEqual(updates, 2)
        without_mirror = copy.deepcopy(plan); without_mirror['resource_drift'] = []
        self.assertNotEqual(digest, guard.review(without_mirror, REVISION, 'handoff', 'preparation')[1])

    def test_stale_mirror_cannot_hide_policy_or_role_changes(self):
        for case in ('extra_policy', 'missing_policy', 'duplicate_policy', 'modified_policy', 'trust', 'boundary', 'role', 'address', 'provider', 'replacement', 'policy_write', 'missing_declaration', 'extra_drift', 'mirror_schema'):
            plan = stale_role_mirror_fixture(); drift = plan['resource_drift'][0]; after = drift['change']['after']
            if case == 'extra_policy': after['inline_policy'].append({'name': 'extra', 'policy': '{"Statement": []}'})
            elif case == 'missing_policy': after['inline_policy'].pop()
            elif case == 'duplicate_policy': after['inline_policy'][1] = copy.deepcopy(after['inline_policy'][0])
            elif case == 'modified_policy': after['inline_policy'][0]['policy'] = '{"Statement": []}'
            elif case == 'trust': after['assume_role_policy'] = 'modified trust'
            elif case == 'boundary': after['permissions_boundary'] = 'modified boundary'
            elif case == 'role': after['arn'] = 'arn:aws:iam::999999999999:role/other'
            elif case == 'address': drift['address'] = 'aws_iam_role.other'
            elif case == 'provider': drift['provider_name'] = 'registry.terraform.io/other/aws'
            elif case == 'replacement': drift['change']['actions'] = ['delete', 'create']
            elif case == 'policy_write': plan['resource_changes'][2]['change']['actions'] = ['update']
            elif case == 'missing_declaration': plan['resource_changes'].pop(2)
            elif case == 'extra_drift': plan['resource_drift'].append(copy.deepcopy(drift))
            else: after['inline_policy'][0]['unexpected'] = 'value'
            with self.subTest(case=case), self.assertRaises(ValueError):
                guard.review(plan, REVISION, 'handoff', 'preparation')

    def test_role_mirror_exception_does_not_allow_lifecycle_drift(self):
        plan = stale_role_mirror_fixture()
        self.assertFalse(guard.declared_handoff_policy_mirror(plan, 'lifecycle'))

    def test_foreground_ingress_and_direct_head_worker(self):
        for scope, mode in [('handoff', 'verification'), ('lifecycle', 'ingress'), ('lifecycle', 'background')]:
            with self.subTest(scope=scope, mode=mode):
                artifacts, digest, updates, subjects = guard.review(fixture(scope, mode), REVISION, scope, mode)
                self.assertEqual(subjects, 1)
                self.assertEqual(len(digest), 64)
                self.assertEqual(updates, 7 if mode == 'background' else 5 if scope == 'lifecycle' else 2)

    def test_reject_unrelated_writes_deletes_and_replacements(self):
        for address, actions in [('aws_iam_role_policy.writer', ['update']), ('aws_lambda_function.export', ['update']), ('aws_lambda_function.runtime[0]', ['delete', 'create'])]:
            plan = fixture(); row = copy.deepcopy(plan['resource_changes'][0]); row['address'] = address; row['change']['actions'] = actions
            if address == 'aws_lambda_function.runtime[0]': plan['resource_changes'][0] = row
            else: plan['resource_changes'].append(row)
            with self.subTest(address=address), self.assertRaises(ValueError): guard.review(plan, REVISION, 'handoff', 'verification')

    def test_reject_cross_account_or_other_capability(self):
        for field, value in [('role', 'arn:aws:iam::999999999999:role/other'), ('reserved_concurrent_executions', 20), ('runtime', 'python3.13')]:
            plan = fixture(); plan['resource_changes'][0]['change']['after'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError): guard.review(plan, REVISION, 'handoff', 'verification')
        plan = fixture(); plan['resource_changes'][0]['change']['after']['environment'][0]['variables']['DELETION_ENABLED'] = 'true'
        with self.assertRaises(ValueError): guard.review(plan, REVISION, 'handoff', 'verification')

    def test_global_scan_and_unowned_discovery_stay_closed(self):
        for field, value in [('PLAY_TOKEN_CLEANUP_ENABLED', 'true'), ('PLAY_CHECKPOINT_POLICY_APPROVED', 'true'), ('PLAY_SCOPED_LIFECYCLE_WORKER_ENABLED', 'false'), ('PLAY_SCOPED_OWNED_HEAD_ONLY_ENABLED', 'false')]:
            plan = fixture('lifecycle', 'background'); plan['resource_changes'][2]['change']['after']['environment'][0]['variables'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError): guard.review(plan, REVISION, 'lifecycle', 'background')

    def test_worker_iam_cannot_keep_global_grants_or_broaden_secret_access(self):
        for sid in ('TokenReads', 'ExactOtherPermission', 'NoScopedTokenEnumeration'):
            plan = fixture('lifecycle', 'background')
            policy = json.loads(plan['resource_changes'][-1]['change']['after']['policy'])
            statement = next(x for x in policy['Statement'] if x['Sid'] == sid)
            if sid == 'TokenReads': statement['Action'].append('dynamodb:Query')
            elif sid == 'ExactOtherPermission': statement['Resource'] = '*'
            else: statement['Effect'] = 'Allow'
            plan['resource_changes'][-1]['change']['after']['policy'] = json.dumps(policy)
            with self.subTest(sid=sid), self.assertRaises(ValueError): guard.review(plan, REVISION, 'lifecycle', 'background')

    def test_subject_runtime_cannot_differ_from_approved_input(self):
        plan = fixture(); plan['resource_changes'][0]['change']['after']['environment'][0]['variables']['DEV_SUBJECT_ALLOWLIST_JSON'] = '[]'
        with self.assertRaises(ValueError): guard.review(plan, REVISION, 'handoff', 'verification')

    def test_background_to_ingress_and_inactive_close_worker_without_widening_iam(self):
        previous = fixture('lifecycle', 'background')
        before = {r['address']: r['change']['after'] for r in previous['resource_changes']}
        for mode in ('ingress', 'inactive'):
            plan = fixture('lifecycle', mode)
            for row in plan['resource_changes']:
                row['change']['before'] = copy.deepcopy(before[row['address']])
                row['change']['actions'] = ['no-op'] if row['change']['before'] == row['change']['after'] else ['update']
            _, _, _, subjects = guard.review(plan, REVISION, 'lifecycle', mode)
            self.assertEqual(subjects, int(mode != 'inactive'))
            worker = plan['resource_changes'][2]['change']['after']['environment'][0]['variables']
            self.assertEqual(worker['PLAY_SCOPED_LIFECYCLE_WORKER_ENABLED'], 'false')
            self.assertEqual(worker['PLAY_CHECKPOINT_POLICY_APPROVED'], 'false')

    def test_exact_digest_changes_on_source_subject_or_package(self):
        plan = fixture(); original = guard.review(plan, REVISION, 'handoff', 'verification')[1]
        self.assertNotEqual(original, guard.review(plan, 'c' * 40, 'handoff', 'verification')[1])
        plan['variables']['billing_artifact_override']['value']['artifact']['object_version'] = 'another-version'
        plan['resource_changes'][0]['change']['after']['s3_object_version'] = 'another-version'
        self.assertNotEqual(original, guard.review(plan, REVISION, 'handoff', 'verification')[1])

    def test_lifecycle_digest_binds_handoff_provenance_outside_tfvars(self):
        plan = fixture('lifecycle', 'background')
        before = guard.review(plan, REVISION, 'lifecycle', 'background')[1]
        changed = dict(PROVENANCE, v1_play_handoff='f' * 64)
        with patch.object(guard, 'load_provenance', return_value=changed):
            after = guard.review(plan, REVISION, 'lifecycle', 'background')[1]
        self.assertNotEqual(before, after)

    def test_incomplete_drift_or_unknown_checks_rejected(self):
        for key, value in [('complete', False), ('resource_drift', [{'mode': 'managed'}]), ('checks', [{'status': 'unknown'}])]:
            plan = fixture(); plan[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): guard.review(plan, REVISION, 'handoff', 'verification')

    def test_alias_cannot_target_unreviewed_version(self):
        plan = fixture(); plan['resource_changes'][1]['change']['after']['function_version'] = '99'
        with self.assertRaises(ValueError): guard.review(plan, REVISION, 'handoff', 'verification')


class ConfigurationTests(ProvenanceCase):
    def read(self, service, operation, *args):
        if service == 'sts': return {'Account': prepare.ACCOUNT}
        if service == 's3api' and operation == 'head-object': return {'VersionId': 'synthetic-version'}
        raise AssertionError('Unexpected API')

    @patch.object(prepare, 'verify_artifacts')
    def test_preparation_and_background_need_exact_packages(self, verify):
        for scope, mode, packages in [('handoff', 'preparation', ['v1_play_handoff']), ('lifecycle', 'background', ['v1_play_handoff', 'play_lifecycle_ingress', 'play_lifecycle_worker'])]:
            result = prepare.build(scope, mode, SOURCE, [SUBJECT], dict(PROVENANCE), EVIDENCE, read=self.read)
            self.assertEqual(result['billing_activation']['subjects'], [SUBJECT])
            self.assertEqual(result['billing_activation']['mode'], mode)
        self.assertEqual(verify.call_count, 2)

    def test_mutable_handoff_hash_cannot_change_without_source_review(self):
        manifest = dict(PROVENANCE, v1_play_handoff='f' * 64)
        def unexpected(*args): raise AssertionError('AWS must not be called for an unreviewed manifest')
        with self.assertRaises(ValueError):
            prepare.build('lifecycle', 'background', SOURCE, [SUBJECT], manifest, EVIDENCE, read=unexpected)

    def test_bad_selection_rejected_before_any_aws_call(self):
        def unexpected(*args): raise AssertionError('AWS must not be used')
        for subjects in ([], [SUBJECT, SUBJECT], ['invalid']):
            with self.subTest(subjects=subjects), self.assertRaises(ValueError):
                prepare.build('handoff', 'verification', SOURCE, subjects, {}, EVIDENCE, read=unexpected)

    def test_source_manifest_or_account_mismatch(self):
        with self.assertRaises(ValueError): prepare.build('handoff', 'verification', SOURCE, [SUBJECT], {'source_sha': 'b' * 40}, EVIDENCE, read=self.read)
        with self.assertRaises(ValueError): prepare.build('handoff', 'verification', SOURCE, [SUBJECT], {'source_sha': SOURCE}, EVIDENCE, read=lambda *args: {'Account': '999999999999'})


if __name__ == '__main__': unittest.main()


class ReadbackTests(ProvenanceCase):
    def handoff_read(self, service, operation, *args):
        if operation == 'get-caller-identity': return {'Account': prepare.ACCOUNT}
        if operation == 'get-function-configuration':
            env = {k: 'true' for k in ('PLAY_HANDOFF_ENABLED', 'PLAY_PREPARATION_ENABLED', 'PLAY_LIFECYCLE_ENABLED', 'AUTHORITY_ENABLED', 'PLAY_CATALOG_P1M_VERIFIED', 'PLAY_REQUIRE_TEST_PURCHASES')}
            env.update(STAGE='dev', DEV_SUBJECT_ALLOWLIST_JSON=json.dumps([SUBJECT], separators=(',', ':')))
            return {'CodeSha256': 'A' * 43 + '=', 'Version': '2', 'Environment': {'Variables': env}}
        if operation == 'get-alias': return {'FunctionVersion': '2'}
        raise AssertionError('Unexpected API')

    def test_lifecycle_rejects_stale_handoff_wrong_subject_and_weighted_alias(self):
        plan = fixture('lifecycle', 'background')
        manifest = dict(PROVENANCE)
        readback.handoff_prerequisite(plan, manifest, read=self.handoff_read)
        for mutation in ('hash', 'subject', 'routing'):
            def changed(service, operation, *args):
                data = self.handoff_read(service, operation, *args)
                if operation == 'get-function-configuration':
                    if mutation == 'hash': data['CodeSha256'] = 'B' * 43 + '='
                    if mutation == 'subject': data['Environment']['Variables']['DEV_SUBJECT_ALLOWLIST_JSON'] = '[]'
                if operation == 'get-alias' and mutation == 'routing': data['RoutingConfig'] = {'AdditionalVersionWeights': {'99': .5}}
                return data
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): readback.handoff_prerequisite(plan, manifest, read=changed)

    def test_protected_snapshot_reads_metadata_only_and_detects_changes(self):
        def metadata(service, operation, *args):
            if operation == 'get-caller-identity': return {'Account': prepare.ACCOUNT}
            if operation == 'list-functions': return {'Functions': [{'FunctionName': 'trustcheckradar-dev-message-consumer'}, {'FunctionName': 'trustcheckradar-dev-v1-play-handoff'}]}
            if operation == 'list-aliases': return {'Aliases': [{'Name': 'live'}]}
            if operation == 'get-function-configuration': return {'CodeSha256': 'synthetic', 'Version': '14', 'Environment': {'Variables': {'AUTHORITY_ENABLED': 'true'}}}
            if operation == 'get-function-concurrency': return {'ReservedConcurrentExecutions': 2}
            raise AssertionError('No customer record API permitted')
        before = readback.snapshot('handoff', read=metadata)
        self.assertEqual(set(before), {'trustcheckradar-dev-message-consumer'})
        def changed(service, operation, *args):
            result = metadata(service, operation, *args)
            if operation == 'get-function-configuration': result['Version'] = '15'
            return result
        self.assertNotEqual(before, readback.snapshot('handoff', read=changed))

    def test_schedule_and_iam_readback_mismatches_rejected(self):
        schedule = {'mode': 'managed', 'type': 'aws_scheduler_schedule', 'change': {'after': {'name': 'synthetic', 'group_name': 'synthetic', 'state': 'ENABLED', 'schedule_expression': 'rate(1 minute)', 'target': [{'arn': 'synthetic-live-alias'}]}}}
        policy = {'mode': 'managed', 'type': 'aws_iam_role_policy', 'change': {'after': {'role': 'synthetic', 'name': 'synthetic', 'policy': json.dumps({'Version': '2012-10-17', 'Statement': []})}}}
        def metadata(service, operation, *args):
            if operation == 'get-caller-identity': return {'Account': prepare.ACCOUNT}
            if operation == 'get-schedule': return {'State': 'ENABLED', 'ScheduleExpression': 'rate(1 minute)', 'Target': {'Arn': 'synthetic-live-alias'}}
            if operation == 'get-role-policy': return {'PolicyDocument': {'Version': '2012-10-17', 'Statement': []}}
            raise AssertionError('Unexpected API')
        plan = {'resource_changes': [schedule, policy]}
        self.assertTrue(readback.readback(plan, read=metadata)['billingConfigurationVerified'])
        for operation in ('get-schedule', 'get-role-policy'):
            def changed(service, method, *args):
                if method == operation: return {}
                return metadata(service, method, *args)
            with self.subTest(operation=operation), self.assertRaises(ValueError): readback.readback(plan, read=changed)


class InventoryPolicyTests(unittest.TestCase):
    def test_inventory_policy_contains_only_required_metadata_actions(self):
        policy = inventory_access.document()
        actions = []
        for row in policy['Statement']:
            actions.extend(row['Action'] if type(row['Action']) is list else [row['Action']])
        self.assertEqual(set(actions), {'backup:ListRecoveryPointsByResource', 'backup:ListBackupPlans', 'backup:ListBackupSelections', 'backup:GetBackupSelection', 'iam:ListRoles'})
        self.assertEqual(policy['Statement'][0]['Condition'], {'StringEquals': {'aws:RequestedRegion': 'us-east-1'}})
        self.assertNotEqual(inventory_access.digest(REVISION), inventory_access.digest(SOURCE))


class InventoryCommandTests(unittest.TestCase):
    def test_plan_never_writes_policy_and_apply_verifies_exact_document(self):
        for mode in ('plan', 'apply'):
            calls = []
            def read(service, operation, *args):
                calls.append(operation)
                if operation == 'get-caller-identity': return {'Account': prepare.ACCOUNT}
                if operation == 'get-role-policy': return {'PolicyDocument': inventory_access.document()}
                raise AssertionError('Unexpected AWS API')
            argv = ['test', '--revision', REVISION, '--mode', mode]
            if mode == 'apply': argv += ['--expected-digest', inventory_access.digest(REVISION)]
            with patch.object(sys, 'argv', argv), patch.object(inventory_access, 'aws', read), patch.object(inventory_access.subprocess, 'run', return_value=SimpleNamespace(stdout=REVISION + '\n')) as command, redirect_stdout(StringIO()):
                inventory_access.main()
                self.assertEqual(command.call_count, 1 if mode == 'plan' else 2)
                if mode == 'apply':
                    self.assertEqual(command.call_args.args[0][:4], ['aws', 'iam', 'put-role-policy', '--role-name'])
            self.assertEqual(calls, ['get-caller-identity'] if mode == 'plan' else ['get-caller-identity', 'get-role-policy'])

    def test_wrong_policy_digest_stops_before_write(self):
        argv = ['test', '--revision', REVISION, '--mode', 'apply', '--expected-digest', 'f' * 64]
        with patch.object(sys, 'argv', argv), patch.object(inventory_access, 'aws', return_value={'Account': prepare.ACCOUNT}), patch.object(inventory_access.subprocess, 'run', return_value=SimpleNamespace(stdout=REVISION + '\n')) as command:
            with self.assertRaises(SystemExit): inventory_access.main()
            self.assertEqual(command.call_count, 1)
