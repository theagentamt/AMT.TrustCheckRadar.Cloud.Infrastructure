#!/usr/bin/env python3
"""Read-only cleanup configuration and protected runtime checks after reviewed apply."""
import argparse
import json
import os
import re
from pathlib import Path

import prepare_billing_cleanup_dev as prepare
import verify_billing_cleanup_dev_plan as guard
import verify_billing_cleanup_prerequisite as prerequisite
from verify_billing_dev_readback import snapshot
from verify_message_consumer_transition import aws

ERROR = 'Billing cleanup readback rejected; private configuration was not printed.'


def require(condition):
    if not condition:
        raise ValueError(ERROR)


def mapping_configuration(metadata):
    return [{key: value for key, value in row.items() if key != 'LastProcessingResult'}
            for row in metadata['mappings']['EventSourceMappings']]


def verify(plan, captured, protected, read=aws):
    """Check metadata only; the approved full plan/digest guard must run before apply."""
    prior = captured['metadata']
    variables = prepare.variables(plan, prior)
    selected = captured['selected']
    prerequisite.validate_subjects(selected, 1)
    subjects = sorted(set(prepare.admitted(prior)) | set(selected))
    require(variables['deletion_activation']['subjects'] == subjects)
    require(type(protected) is dict and bool(protected) and prerequisite.FUNCTION not in protected and
            all(type(name) is str and name.startswith('trustcheckradar-dev-') and
                type(value) is str and re.fullmatch(r'[a-f0-9]{64}', value) for name, value in protected.items()))
    rows = guard.inventory(plan)
    function = rows[guard.FUNCTION_ADDRESS]['change']
    alias = rows[guard.ALIAS_ADDRESS]['change']
    expected = function['after']
    require(function['actions'] in (['no-op'], ['update']) and alias['actions'] in (['no-op'], ['update']))
    require(expected.get('publish') is True and
            all(expected.get(key) == prepare.artifact()[field] for key, field in guard.PACKAGE_FIELDS.items()))
    require(alias['after'].get('function_name') == prerequisite.FUNCTION and
            alias['after'].get('name') == 'live' and not alias['after'].get('routing_config'))
    desired_env = dict(prior['function']['Environment']['Variables'],
                       DEV_SUBJECT_ALLOWLIST_JSON=json.dumps(subjects, separators=(',', ':')))
    require(expected.get('environment') == [{'variables': desired_env}])
    require(function['before'].get('version') == alias['before'].get('function_version') == prior['function']['Version'])
    fresh = prepare.capture(read=read)
    result = prerequisite.verify_metadata(selected, fresh, prepare.artifact()['source_hash'])
    actual = fresh['function']
    fields = {'FunctionName': 'function_name', 'Role': 'role', 'Runtime': 'runtime',
              'Handler': 'handler', 'Architectures': 'architectures', 'Timeout': 'timeout',
              'MemorySize': 'memory_size', 'CodeSha256': 'source_code_hash'}
    require(all(actual.get(key) == expected.get(field) for key, field in fields.items()))
    require(actual.get('Environment', {}).get('Variables') == desired_env and
            fresh['concurrency'].get('ReservedConcurrentExecutions') == expected.get('reserved_concurrent_executions'))
    version = actual['Version']  # prerequisite verification requires a published numeric version.
    if expected.get('version') is None:
        require(function.get('after_unknown', {}).get('version') is True and
                alias['after'].get('function_version') is None and
                alias.get('after_unknown', {}).get('function_version') is True and
                int(version) > int(prior['function']['Version']))
    else:
        require(version == expected['version'] == alias['after'].get('function_version'))
    require(fresh['schedule'] == prior['schedule'])
    require(mapping_configuration(fresh) == mapping_configuration(prior))
    current = snapshot('cleanup', read=read)
    require(current == protected)
    return dict(result, protectedRuntimeCount=len(current))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path)
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--snapshot', type=Path, required=True)
    args = parser.parse_args()
    try:
        require((args.plan is None) == (args.baseline is None))
        if args.plan is None:
            current = snapshot('cleanup')
            descriptor = os.open(args.snapshot, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(descriptor, 'w') as stream:
                os.fchmod(stream.fileno(), 0o600)
                json.dump(current, stream)
            print(json.dumps({'protectedRuntimeCount': len(current)}))
            return
        result = verify(prepare.load(args.plan), prepare.load(args.baseline), prepare.load(args.snapshot))
        print(json.dumps(result))
    except Exception:
        raise SystemExit(ERROR) from None


if __name__ == '__main__':
    main()
