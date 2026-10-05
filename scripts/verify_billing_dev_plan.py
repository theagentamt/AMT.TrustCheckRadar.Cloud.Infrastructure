#!/usr/bin/env python3
"""Review only existing Dev billing runtime updates; reject unrelated changes."""
import argparse
import hashlib
import json
import re
from pathlib import Path

from prepare_billing_dev_configuration import MODES, PACKAGES, ACCOUNT, BUCKET, require, load_provenance
from verify_governed_history_plan import changed_fields
from verify_message_consumer_transition import aws, verify_artifacts

COMPUTED = {'last_modified', 'qualified_arn', 'qualified_invoke_arn', 'version'}
PACKAGE_FIELDS = {'s3_bucket': 'bucket', 's3_key': 'key', 's3_object_version': 'object_version', 'source_code_hash': 'source_hash'}
GATES = {'PLAY_HANDOFF_ENABLED', 'PLAY_PREPARATION_ENABLED', 'PLAY_LIFECYCLE_ENABLED', 'AUTHORITY_ENABLED', 'DEV_SUBJECT_ALLOWLIST_JSON', 'PLAY_SCOPED_OWNED_HEAD_ONLY_ENABLED', 'PLAY_SCOPED_LIFECYCLE_WORKER_ENABLED'}


def review(plan, revision, scope, mode):
    require(scope in MODES and mode in MODES[scope] and re.fullmatch(r'[a-f0-9]{40}', revision or ''), 'Reviewed main source and valid billing selection required.')
    require(plan.get('complete') is True and not plan.get('errored') and plan.get('terraform_version') == '1.12.1', 'Complete Terraform 1.12.1 plan required.')
    require(not [x for x in plan.get('resource_drift', []) if x.get('mode') == 'managed'], 'Reconcile drift before billing activation.')
    require(all(c.get('status') == 'pass' for c in plan.get('checks', [])), 'Every Terraform check must pass.')
    variables = {k: v.get('value') for k, v in plan.get('variables', {}).items()}
    require(variables.get('environment') == 'dev' and variables.get('aws_region') == 'us-east-1' and variables.get('project_name') == 'trustcheckradar' and variables.get('enabled') is True, 'Only existing Dev billing may transition.')
    activation = variables.get('billing_activation')
    active = mode != 'inactive'
    require((activation is not None) is active, 'Activation mode mismatch.')
    subjects = activation.get('subjects') if active else []
    require(type(subjects) is list and len(subjects) == int(active) and all(re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', s) for s in subjects), 'Exact single subject required.')
    if active:
        require(activation.get('mode') == mode and all(isinstance(activation.get(k), str) and activation[k].strip() for k in ('inventory_reference', 'runtime_reference', 'permissions_reference')), 'Activation evidence/mode mismatch.')
    names = ['handoff'] if scope == 'handoff' else ['ingress', 'worker']
    pins = {'handoff': variables.get('billing_artifact_override')} if scope == 'handoff' else variables.get('billing_artifact_overrides', {})
    require(type(pins) is dict and set(pins) == set(names), 'Only selected billing artifact overrides permitted.')
    artifacts = {}
    provenance = load_provenance()
    for name, pin in pins.items():
        require(type(pin) is dict and re.fullmatch(r'[a-f0-9]{40}', pin.get('source_sha', '')), 'Reviewed immutable Lambda source required.')
        require(pin['source_sha'] == provenance.get('source_sha'), 'Package source must match checked-in reviewed provenance.')
        require(not active or pin['source_sha'] == activation.get('source_sha'), 'Activation/package source mismatch.')
        artifact = pin.get('artifact', {})
        require(artifact.get('bucket') == BUCKET and artifact.get('key') == f'releases/{pin["source_sha"]}/{PACKAGES[name]}.zip' and artifact.get('object_version') not in {None, '', 'null'}, 'Exact versioned Dev package required.')
        import base64
        require(artifact.get('source_hash') == base64.b64encode(bytes.fromhex(provenance[PACKAGES[name]])).decode(), 'Package hash must match checked-in reviewed provenance.')
        artifacts[name] = artifact
    managed = [x for x in plan.get('resource_changes', []) if x.get('mode') == 'managed']
    require(all(x.get('provider_name') == 'registry.terraform.io/hashicorp/aws' for x in managed), 'Only AWS resources may participate.')
    inventory = {x['address']: x for x in managed}
    require(len(inventory) == len(managed), 'Duplicate managed address.')
    targets = {name: 'runtime[0]' if name == 'handoff' else f'runtime["{name}"]' for name in names}
    allowed = {f'{kind}.{suffix}' for suffix in targets.values() for kind in ('aws_lambda_function', 'aws_lambda_alias')}
    if scope == 'lifecycle':
        allowed |= {'aws_scheduler_schedule.lifecycle["worker"]', 'aws_cloudwatch_metric_alarm.operational["worker-heartbeat"]', 'aws_iam_role_policy.runtime["worker"]'}
    changed = [x for x in managed if x['change']['actions'] != ['no-op']]
    require(all(x['address'] in allowed and x['change']['actions'] == ['update'] for x in changed), 'Only selected existing billing functions/aliases and scoped-worker schedule/heartbeat may update.')
    for name, suffix in targets.items():
        address = 'aws_lambda_function.' + suffix
        require(address in inventory, 'Complete selected function inventory required.')
        change = inventory[address]['change']; before, after = change['before'], change['after']
        require(type(before) is dict and type(after) is dict, 'Existing function required.')
        function = 'trustcheckradar-dev-' + {'handoff': 'v1-play-handoff', 'ingress': 'play-lifecycle-ingress', 'worker': 'play-lifecycle-worker'}[name]
        require(after.get('function_name') == function and after.get('role') == f'arn:aws:iam::{ACCOUNT}:role/{function}-execution', 'Exact billing runtime/role required.')
        require(after.get('runtime') == 'python3.14' and after.get('architectures') == ['arm64'] and after.get('publish') is True, 'Qualified Python/architecture required.')
        require(after.get('timeout') == (60 if name == 'worker' else 29) and after.get('memory_size') == 256 and after.get('reserved_concurrent_executions') == (1 if name == 'worker' else 2), 'Runtime work limits must remain fixed.')
        require(changed_fields(before, after) <= COMPUTED | set(PACKAGE_FIELDS) | {'environment'}, 'Runtime identity, networking, retention or concurrency may not change.')
        require(all(after.get(field) == artifacts[name][key] for field, key in PACKAGE_FIELDS.items()), 'Package pins mismatch.')
        previous = before.get('environment', [{}])[0].get('variables', {}); env = after.get('environment', [{}])[0].get('variables', {})
        require(changed_fields(previous, env) <= GATES, 'Unrelated runtime configuration must remain unchanged.')
        require(env.get('STAGE') == 'dev' and env.get('PLAY_REQUIRE_TEST_PURCHASES') == 'true' and env.get('PLAY_CATALOG_P1M_VERIFIED') == 'true', 'Dev test purchases and verified monthly catalog required.')
        require(env.get('DEV_SUBJECT_ALLOWLIST_JSON') == json.dumps(subjects if name != 'worker' or mode == 'background' else [], separators=(',', ':')), 'Runtime must admit exactly the selected account.')
        selected_active = active and (name != 'worker' or mode == 'background')
        expected = {'AUTHORITY_ENABLED': selected_active, 'PLAY_LIFECYCLE_ENABLED': selected_active and (name != 'handoff' or mode == 'verification')}
        if name == 'handoff':
            expected |= {'PLAY_HANDOFF_ENABLED': mode == 'verification', 'PLAY_PREPARATION_ENABLED': active}
        else:
            expected |= {'PLAY_PREPARATION_ENABLED': False, 'PLAY_TOKEN_CLEANUP_ENABLED': False, 'PLAY_CHECKPOINT_POLICY_APPROVED': False}
            require(env.get('PLAY_SCOPED_OWNED_HEAD_ONLY_ENABLED', 'false') == str(selected_active).lower(), 'Owned-head-only scope required.')
            if name == 'worker':
                require(env.get('PLAY_SCOPED_LIFECYCLE_WORKER_ENABLED', 'false') == str(mode == 'background').lower(), 'Direct-head worker required; global traversal prohibited.')
        require(all(env.get(k) == str(v).lower() for k, v in expected.items()), 'Billing runtime gates mismatch.')
        alias_address = 'aws_lambda_alias.' + suffix
        require(alias_address in inventory, 'Selected live alias required.')
        alias = inventory[alias_address]['change']
        require(alias['before'].get('name') == alias['after'].get('name') == 'live' and alias['after'].get('function_name') == function and not alias['after'].get('routing_config'), 'Unweighted existing live alias required.')
        require(changed_fields(alias['before'], alias['after']) <= {'function_version'}, 'Only alias version may change.')
        if after.get('version') is None:
            configs = plan.get('configuration', {}).get('root_module', {}).get('resources', [])
            config = next((c for c in configs if c.get('address') == 'aws_lambda_alias.runtime'), {})
            refs = config.get('expressions', {}).get('function_version', {}).get('references', [])
            require(alias['after'].get('function_version') is None and alias.get('after_unknown', {}).get('function_version') is True and 'aws_lambda_function.runtime' in refs, 'Unknown alias target must bind to reviewed runtime.')
        else:
            require(alias['after'].get('function_version') == after['version'], 'Alias version mismatch.')
    if scope == 'lifecycle':
        policy = inventory['aws_iam_role_policy.runtime["worker"]']['change']
        require(changed_fields(policy['before'], policy['after']) <= {'policy'}, 'Worker IAM identity may not change.')
        before_policy, after_policy = (json.loads(policy[side]['policy']) for side in ('before', 'after'))
        require(before_policy.get('Version') == after_policy.get('Version') == '2012-10-17', 'Worker IAM version mismatch.')
        before_statements = {s['Sid']: s for s in before_policy['Statement']}
        after_statements = {s['Sid']: s for s in after_policy['Statement']}
        require(len(after_statements) == len(after_policy['Statement']), 'Duplicate worker IAM statement.')
        removed = {'DueTokenKeys', 'LifecycleCheckpointRead', 'LifecycleCheckpointWrite'}
        added = {'NoScopedTokenEnumeration', 'NoScopedCheckpointAccess'}
        require(set(after_statements) == (set(before_statements) - removed) | added, 'Only global worker grants may be removed and scoped denies added.')
        require(all(s == before_statements.get(sid) for sid, s in after_statements.items() if sid not in added | {'TokenReads'}), 'Other worker permissions must be preserved.')
        require(after_statements['TokenReads'] == dict(before_statements['TokenReads'], Action=['dynamodb:GetItem', 'dynamodb:ConditionCheckItem']), 'Scoped token reads must exclude Query/Scan.')
        table = f'arn:aws:dynamodb:us-east-1:{ACCOUNT}:table/trustcheckradar-dev-play-tokens'
        require(after_statements['NoScopedTokenEnumeration'] == {'Sid': 'NoScopedTokenEnumeration', 'Effect': 'Deny', 'Action': ['dynamodb:Query', 'dynamodb:Scan'], 'Resource': [table, table + '/index/*']}, 'Exact token enumeration deny required.')
        require(after_statements['NoScopedCheckpointAccess'] == {'Sid': 'NoScopedCheckpointAccess', 'Effect': 'Deny', 'Action': ['dynamodb:GetItem', 'dynamodb:ConditionCheckItem', 'dynamodb:PutItem', 'dynamodb:UpdateItem', 'dynamodb:DeleteItem'], 'Resource': table, 'Condition': {'ForAnyValue:StringEquals': {'dynamodb:LeadingKeys': ['PLAY#CONTROL']}}}, 'Exact global checkpoint deny required.')
        schedule = inventory['aws_scheduler_schedule.lifecycle["worker"]']['change']
        require(schedule['after'].get('state') == ('ENABLED' if mode == 'background' else 'DISABLED') and changed_fields(schedule['before'], schedule['after']) <= {'state'}, 'Only existing worker schedule admission may change.')
        heartbeat = inventory['aws_cloudwatch_metric_alarm.operational["worker-heartbeat"]']['change']
        require(heartbeat['after'].get('actions_enabled') is (mode == 'background') and changed_fields(heartbeat['before'], heartbeat['after']) <= {'actions_enabled'}, 'Only existing worker heartbeat admission may change.')
    contract = plan.get('output_changes', {}).get('candidate_contract', {}).get('after', {})
    require(contract.get('billing_subject_count') == len(subjects), 'Output subject count mismatch.')
    if scope == 'handoff':
        require(contract.get('general_customer_access') is False and contract.get('play_handoff_enabled') is (mode == 'verification') and contract.get('preparation_enabled') is active, 'Handoff output mismatch.')
    else:
        require(contract.get('lifecycle_active') is active and contract.get('scheduled_worker_active') is (mode == 'background') and contract.get('google_transport_provisioned') is False, 'Lifecycle output mismatch.')
    projected = {key: plan.get(key) for key in ('terraform_version', 'variables', 'resource_changes', 'resource_drift', 'output_changes', 'checks', 'configuration')}
    digest = hashlib.sha256(json.dumps(dict(revision=revision, scope=scope, mode=mode, plan=projected, packageProvenance=provenance), sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return artifacts, digest, len(changed), len(subjects)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path); parser.add_argument('--revision', required=True)
    parser.add_argument('--scope', choices=MODES, required=True); parser.add_argument('--mode', required=True)
    parser.add_argument('--expected-digest'); args = parser.parse_args()
    try:
        artifacts, digest, count, subjects = review(json.loads(args.plan.read_text()), args.revision, args.scope, args.mode)
        require(args.expected_digest is None or args.expected_digest == digest, 'Exact reviewed digest required.')
        verify_artifacts(artifacts)
        print(json.dumps({'revision': args.revision, 'scope': args.scope, 'mode': args.mode, 'reviewedPlanDigest': digest, 'resourceUpdates': count, 'billingSubjectCount': subjects}))
    except Exception:
        raise SystemExit('Billing plan rejected; private plan values were not printed.') from None


if __name__ == '__main__':
    main()
