#!/usr/bin/env python3
"""Fence a saved Dev plan to cleanup subject union and its published live version."""
import argparse
import hashlib
import json
import re
from pathlib import Path

import prepare_billing_cleanup_dev as prepare
import verify_billing_cleanup_prerequisite as prerequisite
from verify_governed_history_plan import changed_fields

FUNCTION_ADDRESS = 'aws_lambda_function.runtime["deletion"]'
ALIAS_ADDRESS = 'aws_lambda_alias.runtime["deletion"]'
COMPUTED = {'last_modified', 'qualified_arn', 'qualified_invoke_arn', 'version'}
PACKAGE_FIELDS = {'s3_bucket': 'bucket', 's3_key': 'key', 's3_object_version': 'object_version', 'source_code_hash': 'source_hash'}


def require(condition):
    prepare.require(condition)


def unknown(value):
    if isinstance(value, dict):
        return any(unknown(child) for child in value.values())
    if isinstance(value, list):
        return any(unknown(child) for child in value)
    return value is True


def inventory(plan):
    rows = [row for row in plan['resource_changes'] if row.get('mode') == 'managed']
    require(all(row.get('provider_name') == 'registry.terraform.io/hashicorp/aws' for row in rows))
    result = {row['address']: row for row in rows}
    require(len(result) == len(rows) and FUNCTION_ADDRESS in result and ALIAS_ADDRESS in result)
    return result


def review(plan, baseline_plan, captured, revision):
    require(isinstance(revision, str) and re.fullmatch(r'[a-f0-9]{40}', revision))
    current, base = prepare.variables(plan), prepare.variables(baseline_plan)
    expected = prepare.build(baseline_plan, captured['selected'], captured['metadata'])
    require(current == dict(base, **expected))
    rows, baseline = inventory(plan), inventory(baseline_plan)
    require(set(rows) == set(baseline))
    changed = []
    for address, row in rows.items():
        prior, change = baseline[address], row['change']
        require(row.get('type') == prior.get('type') and change['before'] == prior['change']['before'])
        require(change['actions'] in (['no-op'], ['update']))
        if change['actions'] == ['no-op']:
            require(change['before'] == change['after'] and not unknown(change.get('after_unknown', {})))
        else:
            require(address in {FUNCTION_ADDRESS, ALIAS_ADDRESS})
            changed.append(address)
        if address not in {FUNCTION_ADDRESS, ALIAS_ADDRESS}:
            require(change['before'] == change['after'])
    function = rows[FUNCTION_ADDRESS]['change']
    before, after = function['before'], function['after']
    require(type(before) is dict and type(after) is dict)
    metadata = captured['metadata']; live = metadata['function']
    fields = {'function_name': 'FunctionName', 'role': 'Role', 'runtime': 'Runtime', 'handler': 'Handler',
              'architectures': 'Architectures', 'timeout': 'Timeout', 'memory_size': 'MemorySize',
              'source_code_hash': 'CodeSha256', 'version': 'Version'}
    require(all(before.get(key) == live.get(value) for key, value in fields.items()))
    require(before.get('reserved_concurrent_executions') == metadata['concurrency']['ReservedConcurrentExecutions'])
    require(before.get('publish') is True and after.get('publish') is True)
    for side in (before, after):
        require(all(side.get(key) == prepare.artifact()[value] for key, value in PACKAGE_FIELDS.items()))
    env = live['Environment']['Variables']
    require(before.get('environment') == [{'variables': env}])
    desired_env = dict(env, DEV_SUBJECT_ALLOWLIST_JSON=json.dumps(expected['deletion_activation']['subjects'], separators=(',', ':')))
    require(after.get('environment') == [{'variables': desired_env}])
    require(changed_fields(before, after) <= COMPUTED | {'environment'})
    require(all(key in COMPUTED or not unknown(value) for key, value in function.get('after_unknown', {}).items()))
    alias = rows[ALIAS_ADDRESS]['change']
    require(alias['before'].get('function_name') == alias['after'].get('function_name') == prerequisite.FUNCTION)
    require(alias['before'].get('name') == alias['after'].get('name') == 'live')
    require(alias['before'].get('function_version') == live['Version'])
    require(not alias['before'].get('routing_config') and not alias['after'].get('routing_config'))
    require(changed_fields(alias['before'], alias['after']) <= {'function_version'})
    require(all(key == 'function_version' or not unknown(value) for key, value in alias.get('after_unknown', {}).items()))
    if after.get('version') is None:
        require(function.get('after_unknown', {}).get('version') is True and
                alias['after'].get('function_version') is None and alias.get('after_unknown', {}).get('function_version') is True)
        configs = plan.get('configuration', {}).get('root_module', {}).get('resources', [])
        config = next((row for row in configs if row.get('address') == 'aws_lambda_alias.runtime'), {})
        refs = config.get('expressions', {}).get('function_version', {}).get('references', [])
        require('aws_lambda_function.runtime' in refs)
    else:
        require(after['version'] == before['version'] and before['environment'] == after['environment'] and
                alias['after'].get('function_version') == after['version'])
    if before['environment'] != after['environment']:
        require(set(changed) == {FUNCTION_ADDRESS, ALIAS_ADDRESS})
    for output in plan.get('output_changes', {}).values():
        require(output.get('actions') == ['no-op'] and output.get('before') == output.get('after') and not unknown(output.get('after_unknown', {})))
    projected = {key: plan.get(key) for key in ('terraform_version', 'variables', 'resource_changes', 'resource_drift', 'output_changes', 'checks', 'configuration')}
    digest = hashlib.sha256(json.dumps({'revision': revision, 'plan': projected, 'selected': captured['selected'],
        'preservedSubjects': prepare.admitted(metadata), 'deletionArtifact': prepare.artifact()}, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'revision': revision, 'cleanupSource': prepare.SOURCE, 'reviewedPlanDigest': digest,
            'resourceUpdates': len(changed), 'preservedSubjectCount': len(prepare.admitted(metadata)),
            'cleanupSubjectCount': len(expected['deletion_activation']['subjects']), 'billingSubjectCount': 1,
            'planOnly': True, 'behavioralQualification': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--baseline-plan', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--revision', required=True)
    args = parser.parse_args()
    try:
        captured = prepare.load(args.baseline)
        result = review(prepare.load(args.plan), prepare.load(args.baseline_plan), captured, args.revision)
        fresh = prepare.capture()
        # Ignore caller-session metadata and scheduler modification timestamps.
        for key in ('function', 'alias', 'concurrency'):
            require(fresh[key] == captured['metadata'][key])
        # Stream processing can update its result without changing configuration.
        def mapping_configuration(data):
            return [{key: value for key, value in row.items() if key != 'LastProcessingResult'}
                    for row in data['mappings'].get('EventSourceMappings', [])]
        require(mapping_configuration(fresh) == mapping_configuration(captured['metadata']))
        schedule_keys = ('Name', 'GroupName', 'State', 'ScheduleExpression', 'FlexibleTimeWindow', 'Target')
        require(all(fresh['schedule'].get(key) == captured['metadata']['schedule'].get(key) for key in schedule_keys))
        print(json.dumps(result))
    except Exception:
        raise SystemExit(prepare.ERROR) from None


if __name__ == '__main__':
    main()
