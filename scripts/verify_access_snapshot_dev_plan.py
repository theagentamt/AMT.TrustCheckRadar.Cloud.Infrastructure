#!/usr/bin/env python3
"""Reject every change outside one Dev GET-only entitlement function and alias."""
import argparse
import hashlib
import json
import re
from pathlib import Path

from prepare_access_snapshot_dev import (ACCOUNT, FUNCTION_NAME, EXTRA_GATE, PROVENANCE_REFERENCE,
    load_provenance, provenance_artifact, previous_artifact, selection, require)
from verify_governed_history_plan import changed_fields
from verify_message_consumer_transition import verify_artifacts

FUNCTION = 'aws_lambda_function.runtime["entitlements"]'
ALIAS = 'aws_lambda_alias.runtime["entitlements"]'
PACKAGE_FIELDS = {'s3_bucket': 'bucket', 's3_key': 'key', 's3_object_version': 'object_version', 'source_code_hash': 'source_hash'}
COMPUTED = {'last_modified', 'qualified_arn', 'qualified_invoke_arn', 'version'}


def environment(value):
    rows = value.get('environment')
    require(type(rows) is list and len(rows) == 1 and type(rows[0].get('variables')) is dict, 'Complete runtime environment required.')
    return rows[0]['variables']


def review(plan, revision, provenance=None):
    provenance = provenance if provenance is not None else load_provenance()
    artifact = provenance_artifact(provenance)
    require(isinstance(revision, str) and re.fullmatch('[a-f0-9]{40}', revision), 'Exact infrastructure revision required.')
    require(plan.get('complete') is True and plan.get('errored') is False and plan.get('terraform_version') == '1.12.1', 'Complete Terraform 1.12.1 plan required.')
    require(not [r for r in plan.get('resource_drift', []) if r.get('mode') == 'managed'], 'Reconcile managed drift before activation.')
    require(all(c.get('status') == 'pass' for c in plan.get('checks', [])), 'All Terraform checks must pass.')
    variables = {k: v.get('value') for k, v in plan.get('variables', {}).items()}
    require(variables.get('enabled') is True and variables.get('environment') == 'dev' and variables.get('aws_region') == 'us-east-1' and variables.get('project_name') == 'trustcheckradar', 'Dev-only transition required.')
    require(variables.get('engineering_subjects') == [] and all(variables.get(k) is False for k in ('activate_engineering', 'activate_access_engineering', 'activate_trial_engineering')), 'Broader engineering modes must stay disabled.')
    preserved = selection(variables.get('governed_trial_subjects'))
    extra = selection(variables.get('dev_access_snapshot_extra_subjects'))
    require(preserved != extra, 'Snapshot subject must differ from preserved trial subject.')
    pin = variables.get('entitlements_artifact_override') or {}
    baseline = provenance['terraform_baseline']
    require(pin == {'source_sha': provenance['source_sha'], 'baseline_source_sha': baseline['source_sha'],
        'baseline_source_hash': baseline['source_hash'], 'baseline_object_version': baseline['object_version'],
        'provenance_reference': PROVENANCE_REFERENCE, 'artifact': artifact}, 'Exact reviewed override required.')
    require(variables.get('deployment', {}).get('artifacts', {}).get('entitlements') == {
        'bucket': artifact['bucket'], 'key': f'releases/{baseline["source_sha"]}/v1_entitlements.zip',
        'object_version': baseline['object_version'], 'source_hash': baseline['source_hash']}, 'Exact Terraform baseline required.')
    managed = [r for r in plan.get('resource_changes', []) if r.get('mode') == 'managed']
    require(all(r.get('provider_name') == 'registry.terraform.io/hashicorp/aws' for r in managed), 'Only AWS resources may participate.')
    inventory = {r['address']: r for r in managed}
    require(len(inventory) == len(managed), 'Duplicate managed address.')
    changes = [r for r in managed if r['change']['actions'] != ['no-op']]
    require(len(changes) == 2 and {r['address'] for r in changes} == {FUNCTION, ALIAS} and all(r['change']['actions'] == ['update'] for r in changes), 'Only two existing function/alias updates permitted.')
    for row in managed:
        if row['address'] not in {FUNCTION, ALIAS}:
            require(row['change']['before'] == row['change']['after'], 'Every unrelated managed resource must remain unchanged.')
    for name in ('consumer', 'recovery', 'deletion'):
        require(f'aws_lambda_function.runtime["{name}"]' in inventory, 'Complete protected runtime inventory required.')
    before, after = (inventory[FUNCTION]['change'][k] for k in ('before', 'after'))
    require(type(before) is dict and type(after) is dict, 'Existing entitlement function required.')
    expected = {'function_name': FUNCTION_NAME, 'role': f'arn:aws:iam::{ACCOUNT}:role/{FUNCTION_NAME}-execution',
        'handler': 'v1_entitlements.app.lambda_handler', 'runtime': 'python3.14', 'architectures': ['arm64'],
        'timeout': 10, 'memory_size': 256, 'reserved_concurrent_executions': 2, 'publish': True}
    require(all(before.get(k) == after.get(k) == v for k,v in expected.items()), 'Exact runtime identity and limits required.')
    require(changed_fields(before, after) <= COMPUTED | set(PACKAGE_FIELDS) | {'environment'}, 'No networking, IAM, limits or other function changes allowed.')
    old_pin = previous_artifact()
    require(all(before.get(k) == old_pin[v] and after.get(k) == artifact[v] for k,v in PACKAGE_FIELDS.items()), 'Exact previous and new immutable entitlement packages required.')
    old_env, new_env = environment(before), environment(after)
    require(old_env.get(EXTRA_GATE) in (None, '[]'), 'Preexisting extra admission needs its own review.')
    expected_env = dict(old_env, **{EXTRA_GATE: json.dumps(extra, separators=(',', ':'))})
    require(new_env == expected_env, 'Only the extra GET-specific gate may change; original trial selection/policy must remain exact.')
    require(old_env.get('DEV_SUBJECT_ALLOWLIST_JSON') == json.dumps(preserved, separators=(',', ':')) and old_env.get('STAGE') == 'dev', 'Preserved selection must match the previous live function.')
    require(all(old_env.get(k) == 'true' for k in ('AUTHORITY_ENABLED', 'V1_ENTITLEMENTS_ENABLED', 'TRIAL_AUTHORITY_RETENTION_APPROVED')) and old_env.get('CONSUMER_ENABLED') == 'false', 'Existing access/trial policy must stay active without consumers.')
    alias = inventory[ALIAS]['change']
    require(all(alias[k].get('name') == 'live' and alias[k].get('function_name') == FUNCTION_NAME and not alias[k].get('routing_config') for k in ('before','after')), 'Existing unweighted live alias required.')
    require(alias['before'].get('function_version') == before.get('version'), 'Previous alias/function baseline mismatch.')
    require(changed_fields(alias['before'], alias['after']) == {'function_version'}, 'Alias may change only version.')
    if after.get('version') is None:
        config = next((r for r in plan.get('configuration',{}).get('root_module',{}).get('resources',[]) if r.get('address') == 'aws_lambda_alias.runtime'), {})
        refs = config.get('expressions',{}).get('function_version',{}).get('references',[])
        require(inventory[FUNCTION]['change'].get('after_unknown',{}).get('version') is True and alias['after'].get('function_version') is None and alias.get('after_unknown',{}).get('function_version') is True and 'aws_lambda_function.runtime' in refs, 'Unknown alias must bind to the reviewed published function.')
    else:
        require(alias['after'].get('function_version') == after['version'], 'Alias must use reviewed version.')
    outputs = plan.get('output_changes', {})
    require('candidate_contract' in outputs and all(v.get('before') == v.get('after') and not v.get('after_unknown') for v in outputs.values()), 'Existing output boundaries must remain unchanged.')
    contract = outputs['candidate_contract']['after']
    require(contract.get('general_customer_access') is False and contract.get('consumer_enabled') is False and contract.get('recovery_enabled') is False and contract.get('trial_activation_enabled') is True and contract.get('governed_trial_subject_count') == 1, 'Preserved access/trial and disabled unrelated modes required.')
    projected = {k: plan.get(k) for k in ('terraform_version','variables','resource_changes','resource_drift','output_changes','checks','configuration')}
    digest = hashlib.sha256(json.dumps({'revision':revision, 'scope':'access-snapshot', 'plan':projected, 'provenance':provenance},sort_keys=True,separators=(',',':')).encode()).hexdigest()
    return {'entitlements':artifact}, digest


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan',type=Path);parser.add_argument('--revision',required=True);parser.add_argument('--expected-digest')
    args=parser.parse_args()
    try:
        artifacts,digest=review(json.loads(args.plan.read_text()),args.revision)
        require(args.expected_digest is None or args.expected_digest == digest, 'Exact approved digest required.')
        verify_artifacts(artifacts)
        print(json.dumps({'scope':'dev-access-snapshot-only','revision':args.revision,'reviewedPlanDigest':digest,
            'resourceUpdates':2,'extraSnapshotSubjects':1,'preservedTrialSubjects':1,'publicContractChanged':False}))
    except Exception:
        raise SystemExit('Snapshot plan rejected; private plan values were not printed.') from None


if __name__=='__main__':main()
