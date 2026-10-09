#!/usr/bin/env python3
"""Read-only billing runtime readback and preservation of other Dev live aliases."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path

from prepare_billing_dev_configuration import ACCOUNT, require, verify_manifest
from verify_message_consumer_transition import aws


def snapshot(scope, read=aws):
    require(read('sts', 'get-caller-identity').get('Account') == ACCOUNT, 'Only Dev readback permitted.')
    require(scope in {'handoff', 'lifecycle', 'access-snapshot'}, 'Unknown protected runtime scope.')
    selected = {'handoff': {'trustcheckradar-dev-v1-play-handoff'}, 'lifecycle': {'trustcheckradar-dev-play-lifecycle-ingress', 'trustcheckradar-dev-play-lifecycle-worker'}, 'access-snapshot': {'trustcheckradar-dev-v1-entitlements'}}[scope]
    # AWS CLI paginates this inventory automatically. No account/token items read.
    rows = read('lambda', 'list-functions').get('Functions', [])
    results = {}
    for row in rows:
        name = row['FunctionName']
        if not name.startswith('trustcheckradar-dev-') or name in selected:
            continue
        aliases = read('lambda', 'list-aliases', '--function-name', name).get('Aliases', [])
        live = next((alias for alias in aliases if alias.get('Name') == 'live'), None)
        if live is None:
            continue
        function = read('lambda', 'get-function-configuration', '--function-name', name, '--qualifier', 'live')
        data = {key: function.get(key) for key in ('CodeSha256', 'Version', 'Role', 'Handler', 'Runtime', 'Architectures', 'MemorySize', 'Timeout', 'Environment', 'VpcConfig')}
        data['concurrency'] = read('lambda', 'get-function-concurrency', '--function-name', name).get('ReservedConcurrentExecutions')
        data['routing'] = live.get('RoutingConfig', {})
        results[name] = hashlib.sha256(json.dumps(data, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    require(bool(results), 'Protected Dev runtime inventory must not be empty.')
    return results


def readback(plan, read=aws):
    require(read('sts', 'get-caller-identity').get('Account') == ACCOUNT, 'Only Dev readback permitted.')
    for item in plan['resource_changes']:
        if item.get('mode') != 'managed':
            continue
        expected = item['change']['after']
        if item.get('type') == 'aws_lambda_function':
            actual = read('lambda', 'get-function-configuration', '--function-name', expected['function_name'], '--qualifier', 'live')
            fields = {'FunctionName': 'function_name', 'CodeSha256': 'source_code_hash', 'Role': 'role', 'Handler': 'handler', 'Runtime': 'runtime', 'Architectures': 'architectures', 'Timeout': 'timeout', 'MemorySize': 'memory_size'}
            require(all(actual.get(k) == expected[v] for k, v in fields.items()) and actual.get('Environment', {}).get('Variables', {}) == expected['environment'][0]['variables'], 'Billing function readback mismatch.')
            alias = read('lambda', 'get-alias', '--function-name', expected['function_name'], '--name', 'live')
            require(alias.get('FunctionVersion') == actual.get('Version') and not alias.get('RoutingConfig', {}).get('AdditionalVersionWeights'), 'Billing alias must have one qualified version, without weighted routing.')
            require(read('lambda', 'get-function-concurrency', '--function-name', expected['function_name']).get('ReservedConcurrentExecutions') == expected['reserved_concurrent_executions'], 'Billing concurrency mismatch.')
        elif item.get('type') == 'aws_scheduler_schedule':
            actual = read('scheduler', 'get-schedule', '--name', expected['name'], '--group-name', expected['group_name'])
            require(actual.get('State') == expected['state'] and actual.get('ScheduleExpression') == expected['schedule_expression'] and actual.get('Target', {}).get('Arn') == expected['target'][0]['arn'], 'Billing schedule readback mismatch.')
        elif item.get('type') == 'aws_iam_role_policy':
            actual = read('iam', 'get-role-policy', '--role-name', expected['role'], '--policy-name', expected['name'])
            require(actual.get('PolicyDocument') == json.loads(expected['policy']), 'Billing IAM policy readback mismatch.')
    return {'billingConfigurationVerified': True, 'behavioralQualification': False}


def handoff_prerequisite(plan, manifest, read=aws):
    require(read('sts', 'get-caller-identity').get('Account') == ACCOUNT, 'Only Dev foreground prerequisite readback permitted.')
    activation = plan['variables'].get('billing_activation', {}).get('value')
    if activation is None:
        return
    require(manifest.get('source_sha') == activation['source_sha'], 'Handoff/source prerequisite mismatch.')
    verify_manifest(activation['source_sha'], manifest)
    digest = manifest.get('v1_play_handoff', '')
    require(isinstance(digest, str) and len(digest) == 64, 'Reviewed handoff hash required.')
    function = 'trustcheckradar-dev-v1-play-handoff'
    actual = read('lambda', 'get-function-configuration', '--function-name', function, '--qualifier', 'live')
    require(actual.get('CodeSha256') == base64.b64encode(bytes.fromhex(digest)).decode(), 'Lifecycle cannot activate against an older foreground handoff package.')
    env = actual.get('Environment', {}).get('Variables', {})
    require(all(env.get(k) == 'true' for k in ('PLAY_HANDOFF_ENABLED', 'PLAY_PREPARATION_ENABLED', 'PLAY_LIFECYCLE_ENABLED', 'AUTHORITY_ENABLED', 'PLAY_CATALOG_P1M_VERIFIED', 'PLAY_REQUIRE_TEST_PURCHASES')), 'Foreground test-purchase/token-retention gates must be qualified first.')
    require(env.get('STAGE') == 'dev' and env.get('DEV_SUBJECT_ALLOWLIST_JSON') == json.dumps(activation['subjects'], separators=(',', ':')), 'Foreground handoff must use the same exact subject.')
    alias = read('lambda', 'get-alias', '--function-name', function, '--name', 'live')
    require(alias.get('FunctionVersion') == actual.get('Version') and not alias.get('RoutingConfig', {}).get('AdditionalVersionWeights'), 'Foreground handoff must use one qualified live version.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=['handoff', 'lifecycle'], required=True)
    parser.add_argument('--snapshot', type=Path, required=True)
    parser.add_argument('--plan', type=Path)
    parser.add_argument('--handoff-prerequisite', action='store_true')
    args = parser.parse_args()
    try:
        if args.handoff_prerequisite:
            require(args.scope == 'lifecycle' and args.plan is not None, 'Lifecycle plan required for foreground prerequisite.')
            handoff_prerequisite(json.loads(args.plan.read_text()), json.loads(os.environ.get('BILLING_PACKAGE_HASHES_JSON') or '{}'))
            print('Matching foreground handoff package and one-account gates verified.')
            return
        current = snapshot(args.scope)
        if args.plan is None:
            descriptor = os.open(args.snapshot, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(descriptor, 'w') as stream:
                json.dump(current, stream)
            print('Protected Dev runtime baseline captured without reading customer records.')
        else:
            if args.scope == 'lifecycle':
                handoff_prerequisite(json.loads(args.plan.read_text()), json.loads(os.environ.get('BILLING_PACKAGE_HASHES_JSON') or '{}'))
            require(current == json.loads(args.snapshot.read_text()), 'Unrelated Dev live runtime changed during billing apply.')
            result = readback(json.loads(args.plan.read_text()))
            result['protectedRuntimeCount'] = len(current)
            print(json.dumps(result))
    except Exception:
        raise SystemExit('Billing readback rejected; private configuration was not printed.') from None


if __name__ == '__main__':
    main()
