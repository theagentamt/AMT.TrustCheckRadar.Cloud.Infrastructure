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

FUNCTION = 'aws_lambda_function.runtime["entitlements"]'
ALIAS = 'aws_lambda_alias.runtime["entitlements"]'


def review(plan, revision, mode):
    require(mode in {'inactive', 'trial'} and re.fullmatch(r'[a-f0-9]{40}', revision), 'Exact main revision and access mode required.')
    require(plan.get('complete') is True and not plan.get('errored') and plan.get('terraform_version') == '1.12.1', 'Complete Terraform 1.12.1 plan required.')
    require(not [x for x in plan.get('resource_drift', []) if x.get('mode') == 'managed'], 'Live drift must be reconciled before access qualification.')
    variables = {k: v.get('value') for k, v in plan.get('variables', {}).items()}
    subjects = variables.get('governed_trial_subjects')
    active = mode == 'trial'
    require(type(subjects) is list and len(subjects) == int(active) and all(legacy._canonical_uuid(x) for x in subjects), 'Exactly one synthetic subject when active; no subjects when inactive.')
    require(variables.get('engineering_subjects') == [] and all(legacy._terraform_bool(variables.get(k)) is False for k in ('activate_engineering', 'activate_access_engineering', 'activate_trial_engineering')), 'Other engineering modes must remain disabled.')
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
    parser.add_argument('--readback', action='store_true')
    args = parser.parse_args()
    try:
        plan = json.loads(args.plan.read_text())
        artifacts, digest, count, subjects = review(plan, args.revision, args.mode)
        require(args.expected_digest is None or args.expected_digest == digest, 'Exact reviewed plan digest required.')
        legacy.verify_artifacts(artifacts)
        result = {'scope': 'governed-trial-access-only', 'mode': args.mode, 'revision': args.revision, 'reviewedPlanDigest': digest, 'resourceUpdates': count, 'engineeringSubjectCount': subjects}
        if args.readback: result.update(readback(plan))
        print(json.dumps(result))
    except (ValueError, OSError) as error:
        raise SystemExit('Governed access transition rejected: ' + str(error)) from None
