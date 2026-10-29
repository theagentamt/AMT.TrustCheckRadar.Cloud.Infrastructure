#!/usr/bin/env python3
"""Verify SEC340 access/trial gates only; never change deletion or maintenance."""
import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

import verify_trial_authority_transition as legacy
from verify_governed_history_plan import changed_fields, require
from prepare_governed_history_configuration import validate_access_subjects
import prepare_preserved_deployment as preserved

FUNCTION = 'aws_lambda_function.runtime["entitlements"]'
ALIAS = 'aws_lambda_alias.runtime["entitlements"]'


def review_cohort_addition(plan, revision, baseline):
    """Bind the exact v18 selection change to a full, fresh no-op baseline."""
    require(type(baseline) is dict and baseline.get('complete') is True and not baseline.get('errored')
            and baseline.get('terraform_version') == '1.12.1' and not baseline.get('resource_drift'),
            'Fresh complete drift-free preservation baseline required.')
    require(all(o['actions'] == ['no-op'] and o.get('before') == o.get('after') for o in baseline.get('output_changes', {}).values()),
            'Baseline outputs must be unchanged.')
    variables = {k: v.get('value') for k, v in plan['variables'].items()}
    original = {k: v.get('value') for k, v in baseline['variables'].items()}
    require(variables.get('environment') == 'dev' and variables.get('aws_region') == legacy.REGION
            and variables.get('project_name') == 'trustcheckradar' and variables.get('enabled') is True,
            'Exact enabled Dev root required.')
    require(changed_fields(original, variables) == {'governed_trial_subjects', 'dev_access_snapshot_extra_subjects'}
            and variables['dev_access_snapshot_extra_subjects'] == [], 'Only the exact trial/snapshot selection may change.')
    rows, old = preserved.inventory(plan), preserved.inventory(baseline)
    require(set(rows) == set(old) and len(rows) == 56 and all(r['change']['actions'] == ['no-op'] for r in old.values()),
            'Complete existing 56-resource no-op baseline required.')
    require(all(r['change']['before'] == old[a]['change']['after'] for a, r in rows.items()), 'Candidate must bind every baseline resource.')
    before = rows[FUNCTION]['change']['before']
    preserved.require_entitlements(before)
    previous = preserved.environment(before)
    subjects = variables['governed_trial_subjects']
    require(set(subjects) == set(json.loads(previous['DEV_SUBJECT_ALLOWLIST_JSON'])) | set(json.loads(previous['DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON'])),
            'Preserve the existing member and promote only the verified snapshot tester.')
    require(original.get('governed_trial_subjects') == json.loads(previous['DEV_SUBJECT_ALLOWLIST_JSON'])
            and original.get('dev_access_snapshot_extra_subjects') == json.loads(previous['DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON']),
            'Baseline private inputs must match live v18 selection.')
    changes = [r for r in rows.values() if r['change']['actions'] != ['no-op']]
    require({r['address'] for r in changes} == {FUNCTION, ALIAS} and all(r['change']['actions'] == ['update'] for r in changes),
            'Only entitlements configuration and its bound live alias may update.')
    for address, row in rows.items():
        c = row['change']
        if address not in {FUNCTION, ALIAS}:
            require(c['actions'] == ['no-op'] and c['before'] == c['after'] and not c.get('after_unknown'), 'All other resources must remain exact.')
    c = rows[FUNCTION]['change']
    require(changed_fields(c['before'], c['after']) <= preserved.COMPUTED | {'environment'},
            'Code/artifact, IAM, limits and other function settings must remain exact.')
    expected = dict(previous, DEV_SUBJECT_ALLOWLIST_JSON=json.dumps(sorted(subjects), separators=(',', ':')))
    expected.pop('DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON')
    require(preserved.environment(c['after']) == expected and previous['TRIAL_AUTHORITY_RETENTION_APPROVED'] == 'true',
            'Only the exact allowlist addition and snapshot-key removal are permitted.')
    require(set(c.get('after_unknown', {})) <= preserved.COMPUTED,
            'Only published-version metadata may be unknown.')
    alias = rows[ALIAS]['change']
    require(alias['before']['function_version'] == '18' and alias['before']['name'] == alias['after']['name'] == 'live'
            and alias['before']['function_name'] == alias['after']['function_name'] == before['function_name']
            and not alias['before'].get('routing_config') and not alias['after'].get('routing_config'), 'Exact unweighted v18 live alias required.')
    require(changed_fields(alias['before'], alias['after']) <= {'function_version'}, 'Alias must bind updated function version.')
    require(set(alias.get('after_unknown', {})) <= {'function_version'}, 'No other alias setting may be unknown.')
    version = c['after'].get('version')
    if version is None:
        resources = plan.get('configuration', {}).get('root_module', {}).get('resources', [])
        config = next((r for r in resources if r.get('address') == 'aws_lambda_alias.runtime'), {})
        require(alias['after'].get('function_version') is None and alias.get('after_unknown', {}).get('function_version') is True
                and 'aws_lambda_function.runtime' in config.get('expressions', {}).get('function_version', {}).get('references', []),
                'Unknown alias must bind the updated function version.')
    else:
        require(alias['after'].get('function_version') == version and version != '18', 'Alias must bind the new same-code version.')
    require(set(plan.get('output_changes', {})) == set(baseline.get('output_changes', {})), 'Output inventory must remain exact.')
    for name, output in plan['output_changes'].items():
        old_output = baseline['output_changes'][name]
        require(output.get('before') == old_output.get('after') and not output.get('after_unknown'), 'Output baseline changed or unknown.')
        if name == 'candidate_contract':
            require(changed_fields(output['before'], output['after']) == {'governed_trial_subject_count'}
                    and output['before']['governed_trial_subject_count'] == 1 and output['after']['governed_trial_subject_count'] == 2,
                    'Only the trial subject-count output may change.')
        else:
            require(output['actions'] == ['no-op'] and output['before'] == output['after'], 'Maintenance and other outputs must remain exact.')
    require(all(r['change']['actions'] == ['no-op'] for r in plan['resource_changes'] if r.get('mode') == 'data'), 'No deferred data reads allowed.')
    digest = preserved.digest({'revision': revision, 'baseline': baseline, 'plan': plan})
    return legacy._review_artifacts(variables), digest, len(changes), len(subjects)


def review(plan, revision, mode, baseline=None):
    require(mode in {'inactive', 'trial'} and re.fullmatch(r'[a-f0-9]{40}', revision), 'Exact main revision and access mode required.')
    require(plan.get('complete') is True and not plan.get('errored') and plan.get('terraform_version') == '1.12.1', 'Complete Terraform 1.12.1 plan required.')
    require(not [x for x in plan.get('resource_drift', []) if x.get('mode') == 'managed'], 'Live drift must be reconciled before access qualification.')
    variables = {k: v.get('value') for k, v in plan.get('variables', {}).items()}
    subjects = variables.get('governed_trial_subjects')
    active = mode == 'trial'
    validate_access_subjects(subjects, active)
    require(variables.get('engineering_subjects') == [] and all(legacy._terraform_bool(variables.get(k)) is False for k in ('activate_engineering', 'activate_access_engineering', 'activate_trial_engineering')), 'Other engineering modes must remain disabled.')
    if len(subjects) == 2:
        return review_cohort_addition(plan, revision, baseline)
    # Reuse the established baseline checks without activating its broader trial
    # mode. The original saved plan is still the authority for the narrow diff.
    baseline = copy.deepcopy(plan)
    baseline['resource_changes'] = []
    baseline['output_changes']['candidate_contract']['after'].update({
        'access_enabled': False, 'trial_activation_enabled': False,
        'recovery_enabled': False, 'trial_only_engineering': False,
        'engineering_subject_count': 0,
    })
    artifacts, _, _, _ = legacy.review(baseline, revision, 'inactive')
    managed = [x for x in plan.get('resource_changes', []) if x.get('mode') == 'managed']
    require(all(x.get('provider_name') == 'registry.terraform.io/hashicorp/aws' for x in managed), 'Only the AWS provider may manage this transition.')
    inventory = {x['address']: x for x in managed}
    require(len(inventory) == len(managed), 'Duplicate managed resource address.')
    changes = [x for x in managed if x['change']['actions'] != ['no-op']]
    require({x['address'] for x in changes} <= {FUNCTION, ALIAS} and all(x['change']['actions'] == ['update'] for x in changes), 'Only existing entitlements function and live alias may update.')
    for name in legacy.FUNCTIONS:
        address = f'aws_lambda_function.runtime["{name}"]'
        require(address in inventory, 'Complete runtime inventory required.')
        item = inventory[address]
        before, after = item['change']['before'], item['change']['after']
        require(type(before) is dict and type(after) is dict, 'Existing complete runtime required.')
        if name != 'entitlements':
            require(item['change']['actions'] == ['no-op'] and before == after, 'URL, deletion and recovery must remain unchanged.')
        require(after.get('function_name') == legacy.PREFIX + '-' + {'consumer': 'url-consumer', 'recovery': 'url-lease-recovery', 'deletion': 'v1-authority-deletion', 'entitlements': 'v1-entitlements'}[name], 'Exact Dev function required.')
        require(after.get('role') == f'arn:aws:iam::{legacy.ACCOUNT}:role/' + after['function_name'] + '-execution', 'Exact Dev execution role required.')
        require(after.get('runtime') == 'python3.14' and after.get('architectures') == ['arm64'], 'Existing qualified runtime required.')
        timeout, concurrency, handler = {'consumer': (29, 2, 'app.lambda_handler'), 'recovery': (15, 1, 'app.lambda_handler'), 'deletion': (30, 1, 'v1_authority_deletion.app.lambda_handler'), 'entitlements': (10, 2, 'v1_entitlements.app.lambda_handler')}[name]
        require(after.get('timeout') == timeout and after.get('reserved_concurrent_executions') == concurrency and after.get('handler') == handler and after.get('memory_size') == 256 and after.get('publish') is True, 'Exact existing runtime limits required.')
        artifact = artifacts[name]
        require(all(after.get(field) == artifact[key] for field, key in {'s3_bucket': 'bucket', 's3_key': 'key', 's3_object_version': 'object_version', 'source_code_hash': 'source_hash'}.items()), 'Existing immutable package pins must be preserved.')
        environment = after.get('environment', [{}])[0].get('variables', {})
        secret = environment.get('AUTHORITY_HMAC_SECRET_ARN', '')
        if name != 'recovery':
            require(re.fullmatch(rf'arn:aws:secretsmanager:us-east-1:{legacy.ACCOUNT}:secret:trustcheckradar/dev/v1-authority-hmac-[A-Za-z0-9]{{6}}', secret), 'Existing Dev authority key ring required.')
        expected_vars = dict(variables, engineering_subjects=subjects if name == 'entitlements' else [])
        expected = legacy._expected_environment(name, expected_vars, active and name == 'entitlements', secret)
        require(environment == expected, 'Exact access gates and unchanged unrelated runtime environments required.')
        if name == 'entitlements':
            require(changed_fields(before, after) <= {'environment', 'last_modified', 'qualified_arn', 'qualified_invoke_arn', 'version'}, 'No package, runtime, resource, concurrency or IAM change allowed.')
            previous = before.get('environment', [{}])[0].get('variables', {})
            require(changed_fields(previous, environment) <= {'DEV_SUBJECT_ALLOWLIST_JSON', 'TRIAL_AUTHORITY_RETENTION_APPROVED'}, 'Only subject admission and approved trial gate may change.')
    require(ALIAS in inventory, 'Existing entitlements live alias required.')
    alias = inventory[ALIAS]['change']
    require(alias['before'].get('name') == alias['after'].get('name') == 'live' and alias['after'].get('function_name') == legacy.PREFIX + '-v1-entitlements' and not alias['after'].get('routing_config'), 'Exact unweighted live alias required.')
    require(changed_fields(alias['before'], alias['after']) <= {'function_version'}, 'Alias may move only its function version.')
    require(alias['actions'] == ['no-op'] or inventory[FUNCTION]['change']['actions'] == ['update'], 'Alias cannot move independently of the reviewed function.')
    version = inventory[FUNCTION]['change']['after'].get('version')
    if version is None:
        resources = plan.get('configuration', {}).get('root_module', {}).get('resources', [])
        config = next((x for x in resources if x.get('address') == 'aws_lambda_alias.runtime'), {})
        refs = config.get('expressions', {}).get('function_version', {}).get('references', [])
        require(alias['after'].get('function_version') is None and alias.get('after_unknown', {}).get('function_version') is True and 'aws_lambda_function.runtime' in refs, 'Unknown alias version must bind to the reviewed function version.')
    else:
        require(alias['after'].get('function_version') == version, 'Alias must use the reviewed function version.')
    contract = plan['output_changes']['candidate_contract']['after']
    require(contract.get('access_enabled') is active and contract.get('trial_activation_enabled') is active and contract.get('governed_trial_only_engineering') is active and contract.get('governed_trial_subject_count') == len(subjects), 'Governed trial output mismatch.')
    require(contract.get('recovery_enabled') is False and contract.get('consumer_enabled') is False and contract.get('deletion_enabled') is True and contract.get('general_customer_access') is False, 'Unrelated activation boundaries must be preserved.')
    require(contract.get('trial_only_engineering') is False and contract.get('access_only_engineering') is False and contract.get('engineering_subject_count') == 0, 'Legacy engineering modes must remain inactive.')
    digest = hashlib.sha256(json.dumps({'revision': revision, 'mode': mode, 'plan': {k: plan.get(k) for k in ('terraform_version', 'variables', 'resource_changes', 'resource_drift', 'output_changes', 'checks')}}, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return artifacts, digest, len(changes), len(subjects)


def readback(plan, read=legacy.aws):
    require(read('sts', 'get-caller-identity').get('Account') == legacy.ACCOUNT, 'Only Dev account readback permitted.')
    for item in plan['resource_changes']:
        if item.get('mode') != 'managed' or not item['address'].startswith('aws_lambda_function.runtime['):
            continue
        expected = item['change']['after']
        actual = read('lambda', 'get-function-configuration', '--function-name', expected['function_name'], '--qualifier', 'live')
        require(actual.get('FunctionName') == expected['function_name'] and actual.get('CodeSha256') == expected['source_code_hash'] and actual.get('Environment', {}).get('Variables', {}) == expected['environment'][0]['variables'], 'Runtime package/gate readback mismatch.')
        require(actual.get('Runtime') == expected['runtime'] and actual.get('Architectures') == expected['architectures'] and actual.get('Role') == expected['role'] and actual.get('Handler') == expected['handler'] and actual.get('Timeout') == expected['timeout'] and actual.get('MemorySize') == expected['memory_size'], 'Runtime boundary readback mismatch.')
        require(read('lambda', 'get-function-concurrency', '--function-name', expected['function_name']).get('ReservedConcurrentExecutions') == expected['reserved_concurrent_executions'], 'Concurrency readback mismatch.')
    return {'accessReadbackVerified': True, 'unrelatedRuntimeGatesPreserved': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--mode', choices=['inactive', 'trial'], required=True)
    parser.add_argument('--expected-digest')
    parser.add_argument('--baseline', type=Path, help='Fresh full no-op saved-plan JSON; required for the exact two-tester addition.')
    parser.add_argument('--readback', action='store_true')
    args = parser.parse_args()
    try:
        plan = json.loads(args.plan.read_text())
        artifacts, digest, count, subjects = review(plan, args.revision, args.mode,
                                                  json.loads(args.baseline.read_text()) if args.baseline else None)
        require(args.expected_digest is None or args.expected_digest == digest, 'Exact reviewed plan digest required.')
        legacy.verify_artifacts(artifacts)
        result = {'scope': 'governed-trial-access-only', 'mode': args.mode, 'revision': args.revision, 'reviewedPlanDigest': digest, 'resourceUpdates': count, 'engineeringSubjectCount': subjects}
        if args.readback: result.update(readback(plan))
        print(json.dumps(result))
    except (ValueError, OSError) as error:
        raise SystemExit('Governed access transition rejected: ' + str(error)) from None
