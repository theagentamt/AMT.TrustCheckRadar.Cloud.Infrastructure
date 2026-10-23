#!/usr/bin/env python3
"""Fence saved Dev plans to maintenance-only or existing candidate.3/History."""
import argparse
import json
from pathlib import Path
import re

import prepare_preserved_deployment as prepare
from verify_governed_history_plan import changed_fields, require
from verify_message_consumer_transition import _expected_environment, verify_artifacts
from billing_plan_digest import projection

FUNCTION = 'aws_lambda_function.runtime["recovery"]'
ALIAS = 'aws_lambda_alias.runtime["recovery"]'
RULE = 'aws_cloudwatch_event_rule.maintenance["recovery"]'
HEARTBEAT = 'aws_cloudwatch_metric_alarm.worker_heartbeat["recovery"]'
OVERDUE = 'aws_cloudwatch_metric_alarm.expiry_overdue[0]'
MAINTENANCE = {FUNCTION, ALIAS, RULE, HEARTBEAT, OVERDUE}
PACKAGE = {'s3_bucket', 's3_key', 's3_object_version', 'source_code_hash'}


def same(left, right):
    return prepare.digest(left) == prepare.digest(right)


def unknowns(value, path=()):
    if value is True:
        return {path}
    if isinstance(value, dict):
        return set().union(*(unknowns(v, path + (k,)) for k, v in value.items())) if value else set()
    if isinstance(value, list):
        return set().union(*(unknowns(v, path + (i,)) for i, v in enumerate(value))) if value else set()
    return set()


def known(value, paths):
    result = dict(value)
    for path in paths:
        require(len(path) == 1, 'Nested unknown values are forbidden.')
        result.pop(path[0], None)
    return result


def validate_plan(plan, mode):
    require(plan.get('terraform_version') == '1.12.1' and plan.get('complete') is True and
            plan.get('errored') is False and all(c.get('status') == 'pass' for c in plan.get('checks', [])),
            'Complete passing Terraform 1.12.1 plan required.')
    prepare.require_entitlements_drift(plan, mode)
    rows = prepare.inventory(plan)
    values = [r for r in plan.get('planned_values', {}).get('root_module', {}).get('resources', []) if r.get('mode') == 'managed']
    planned = {r['address']: r['values'] for r in values}
    require(len(planned) == len(values) and set(planned) == set(rows), 'Complete planned inventory required.')
    for address, row in rows.items():
        change = row['change']
        paths = unknowns(change.get('after_unknown', {}))
        allowed = set()
        if address.startswith('aws_lambda_function.runtime['):
            allowed = prepare.COMPUTED | ({'code_sha256', 'source_code_size'} if mode == 'message-history' else set())
        elif address.startswith('aws_lambda_alias.runtime['):
            allowed = {'function_version'}
        require(paths <= {(k,) for k in allowed}, 'Unreviewed computed field.')
        require(same(known(change['after'], paths), known(planned[address], paths)), 'Post-plan inventory mismatch.')
    return rows


def alias_binding(row, function, plan):
    change = row['change']
    before, after = change['before'], change['after']
    require(before['name'] == after['name'] == 'live' and before['function_name'] == after['function_name'] == function['before']['function_name'] and
            not before.get('routing_config') and not after.get('routing_config'), 'Exact unweighted alias required.')
    require(before['function_version'] == function['before']['version'] and changed_fields(before, after) <= {'function_version'}, 'Alias baseline drift.')
    if after.get('function_version') is None or function['after'].get('version') is None:
        config = next((r for r in plan['configuration']['root_module']['resources'] if r['address'] == 'aws_lambda_alias.runtime'), {})
        refs = config.get('expressions', {}).get('function_version', {}).get('references', [])
        require(change.get('after_unknown', {}).get('function_version') is True and
                function.get('after_unknown', {}).get('version') is True and 'aws_lambda_function.runtime' in refs,
                'New alias version must bind the published reviewed function.')
    else:
        require(re.fullmatch('[1-9][0-9]*', after['function_version']) and after['function_version'] == function['after']['version'], 'Alias version mismatch.')


def review(plan, baseline, captured, revision, mode, replacements=None):
    require(re.fullmatch('[a-f0-9]{40}', revision or ''), 'Exact main revision required.')
    rows, old = validate_plan(plan, mode), prepare.inventory(baseline)
    prepare.require_entitlements_drift(baseline, mode)
    require(set(rows) == set(old), 'Baseline inventory changed.')
    expected = {k: v['value'] for k, v in baseline['variables'].items()}
    expected.update(prepare.build(baseline, captured, mode, replacements))
    require(same({k: v['value'] for k, v in plan['variables'].items()}, expected), 'Private preservation inputs changed.')
    allowed = MAINTENANCE if mode == 'maintenance' else {f'{kind}.runtime["{n}"]' for kind in ('aws_lambda_function', 'aws_lambda_alias') for n in ('consumer', 'evaluator')}
    changed = []
    for address, row in rows.items():
        c = row['change']
        require(same(c['before'], old[address]['change']['before']), 'State changed after capture.')
        require(c['actions'] in (['no-op'], ['update']), 'No create, deletion or replacement permitted.')
        if c['actions'] == ['update']:
            require(address in allowed, 'Unrelated resource update; IAM/routes/admission must remain unchanged.')
            changed.append(address)
        else:
            require(same(c['before'], c['after']) and not unknowns(c.get('after_unknown', {})), 'No-op inventory is not identical.')
    for n in captured['functions']:
        address = f'aws_lambda_function.runtime["{n}"]'
        before, after = (rows[address]['change'][k] for k in ('before', 'after'))
        require(before['version'] == captured['functions'][n]['version'] and before['code_sha256'] == captured['functions'][n]['codeSha256'] and
                prepare.digest(prepare.artifact(before)) == captured['functions'][n]['artifactInputsSha256'] and
                prepare.digest(prepare.environment(before)) == captured['functions'][n]['environmentSha256'], 'Captured function binding mismatch.')
        suffix = 'message-' + n if mode == 'message-history' else {'consumer': 'url-consumer', 'entitlements': 'v1-entitlements', 'recovery': 'url-lease-recovery', 'deletion': 'v1-authority-deletion'}[n]
        handler = ('message_' + n + '.app.lambda_handler') if mode == 'message-history' else 'v1_entitlements.app.lambda_handler' if n == 'entitlements' else 'app.lambda_handler'
        timeout = (29 if n == 'consumer' else 23) if mode == 'message-history' else {'consumer': 29, 'entitlements': 10, 'recovery': 15, 'deletion': 30}[n]
        require(all(before.get(k) == v for k, v in {
            'function_name': prepare.PREFIX + '-' + suffix, 'runtime': 'python3.14', 'architectures': ['arm64'],
            'handler': handler, 'memory_size': 256, 'publish': True, 'timeout': timeout,
            'reserved_concurrent_executions': 1 if mode == 'maintenance' and n in ('recovery', 'deletion') else 2,
            'role': 'arn:aws:iam::107827791950:role/' + prepare.PREFIX + '-' + suffix + '-execution'}.items()),
            'Pinned runtime identity required.')
        if mode == 'maintenance' and n != 'recovery':
            require(rows[address]['change']['actions'] == ['no-op'], 'Protected runtime must remain unchanged.')
    if mode == 'maintenance':
        for address in (prepare.ENT_FUNCTION, prepare.ENT_ALIAS):
            require(rows[address]['change']['actions'] == ['no-op'], 'Entitlements must be a complete no-op.')
        prepare.require_entitlements(rows[prepare.ENT_FUNCTION]['change']['after'])
        ent_alias = rows[prepare.ENT_ALIAS]['change']['after']
        require(ent_alias['name'] == 'live' and ent_alias['function_name'] == prepare.ENTITLEMENTS['functionName'] and
                ent_alias['function_version'] == prepare.ENTITLEMENTS['current']['version'] and
                not ent_alias.get('routing_config'), 'Protected entitlements alias changed.')
        require(set(changed) in (set(), MAINTENANCE), 'Maintenance transition must be complete or an exact no-op.')
        c = rows[FUNCTION]['change']; before, after = c['before'], c['after']
        require(before['function_name'] == after['function_name'] == prepare.PREFIX + '-url-lease-recovery' and
                before['source_code_hash'] == after['source_code_hash'] ==
                before['code_sha256'] == after['code_sha256'] == prepare.RECOVERY_SHA,
                'Only existing worker11 bytes are allowed.')
        require(changed_fields(before, after) <= prepare.COMPUTED | {'environment'}, 'Worker artifact/role/runtime/limits must not change.')
        require(prepare.environment(after) == dict(prepare.environment(before), LEASE_SWEEP_ENABLED='true') and
                prepare.environment(before).get('LEASE_SWEEP_ENABLED') in ('false', 'true'), 'Only worker gate may change.')
        alias_binding(rows[ALIAS], c, plan)
        for address, fields, values in (
            (RULE, {'state'}, {'state': 'ENABLED'}),
            (HEARTBEAT, {'actions_enabled', 'treat_missing_data'}, {'actions_enabled': True, 'treat_missing_data': 'breaching'}),
            (OVERDUE, {'actions_enabled'}, {'actions_enabled': True}),
        ):
            a, b = (rows[address]['change'][k] for k in ('before', 'after'))
            require(changed_fields(a, b) <= fields and all(b.get(k) == v for k, v in values.items()), 'Maintenance control exceeds scope.')
        artifacts = {'recovery': prepare.artifact(after)}
    else:
        require(mode == 'message-history', 'Unknown mode.')
        for name in ('consumer', 'evaluator'):
            c = rows[f'aws_lambda_function.runtime["{name}"]']['change']
            before, after = c['before'], c['after']
            require(changed_fields(before, after) <= prepare.COMPUTED | PACKAGE | {'code_sha256', 'source_code_size'},
                    'Message environment/role/runtime/limits/permissions must remain exact.')
            environment = _expected_environment(name, expected, True)
            environment['MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED'] = 'true'
            if name == 'consumer':
                environment.update(GOVERNED_HISTORY_SETTLEMENT_ENABLED='true', MESSAGE_PROVIDER_CIRCUIT_OPEN='true')
            require(prepare.environment(before) == prepare.environment(after) == environment, 'Candidate.3/History/AI-off configuration must remain exact.')
            require(prepare.artifact(after) == expected['deployment']['artifacts'][name], 'Artifact selection mismatch.')
            require(after.get('code_sha256') == after['source_code_hash'] or
                    (after.get('code_sha256') is None and c.get('after_unknown', {}).get('code_sha256') is True and
                     bool(changed_fields(before, after) & PACKAGE)), 'Reviewed Message runtime hash must bind its package.')
            alias_binding(rows[f'aws_lambda_alias.runtime["{name}"]'], c, plan)
        artifacts = expected['deployment']['artifacts']
    require(set(plan.get('output_changes', {})) <= {'candidate_contract', 'authority_maintenance'}, 'Unexpected output.')
    contract = plan['output_changes']['candidate_contract']['after']
    if mode == 'maintenance':
        require(contract['consumer_enabled'] is False and contract['recovery_enabled'] is True and contract['general_customer_access'] is False and
                contract['governed_trial_subject_count'] == 1 and contract['engineering_subject_count'] == 0, 'Preserved URL/access/trial boundaries required.')
    else:
        require(all(contract[k] is True for k in ('candidate3_rules_only_enabled', 'governed_history_settlement_enabled', 'consumer_enabled', 'evaluator_enabled', 'provider_circuit_open')) and
                all(contract[k] is False for k in ('ai_enabled', 'ai_qualified', 'model_enabled')) and contract['engineering_subject_count'] == 2,
                'Candidate.3/History output mismatch.')
    material = {'plan': projection(plan), 'baseline': projection(baseline), 'capture': captured,
                'revision': revision, 'mode': mode}
    return {'reviewedPlanDigest': prepare.digest(material), 'mode': mode, 'revision': revision,
            'resourceUpdates': len(changed), 'resourceAddresses': sorted(changed), 'providerCallsEnabled': False}, artifacts


def verify_deployed(plan, baseline, captured, mode, read=prepare.aws):
    rows = prepare.inventory(plan)
    names = tuple(captured['functions'])
    for name in names:
        desired = rows[f'aws_lambda_function.runtime["{name}"]']['change']['after']
        alias = read('lambda', 'get-alias', '--function-name', desired['function_name'], '--name', 'live')
        current = read('lambda', 'get-function-configuration', '--function-name', desired['function_name'], '--qualifier', alias['FunctionVersion'])
        latest = read('lambda', 'get-function-configuration', '--function-name', desired['function_name'])
        concurrency = read('lambda', 'get-function-concurrency', '--function-name', desired['function_name'])
        require(current.get('State') == 'Active' and current['Version'] == alias['FunctionVersion'] and
                not alias.get('RoutingConfig', {}).get('AdditionalVersionWeights'), 'Deployed alias is not qualified.')
        require(desired.get('version') is None or desired['version'] == current['Version'], 'Protected or known published version changed.')
        require(latest.get('LastUpdateStatus') == 'Successful' and latest.get('CodeSha256') == current['CodeSha256'] and
                latest.get('Environment') == current.get('Environment') and
                concurrency.get('ReservedConcurrentExecutions') == desired['reserved_concurrent_executions'], 'Deployed limits/update state mismatch.')
        expected_hash = desired['source_code_hash'] if mode == 'message-history' else desired['code_sha256']
        require(current['CodeSha256'] == expected_hash and
                all(current[v] == desired[k] for k, v in {'function_name': 'FunctionName',
                'runtime': 'Runtime', 'architectures': 'Architectures', 'handler': 'Handler', 'role': 'Role',
                'timeout': 'Timeout', 'memory_size': 'MemorySize'}.items()) and
                current['Environment']['Variables'] == prepare.environment(desired), 'Deployed configuration mismatch.')
    maintenance = prepare.maintenance_readback(read, require_active=True)
    if mode == 'message-history':
        require(maintenance == captured['maintenance'], 'Protected maintenance metadata changed.')
        history = read('lambda', 'get-function-configuration', '--function-name', prepare.PREFIX + '-governed-history', '--qualifier', 'live')
        prepare.subjects(history['Environment']['Variables']['DEV_SUBJECT_ALLOWLIST_JSON'], 2, prepare.SCOPE_SHA)
        history_alias = read('lambda', 'get-alias', '--function-name', prepare.PREFIX + '-governed-history', '--name', 'live')
        require(history['State'] == 'Active' and history['Version'] == history_alias['FunctionVersion'] and
                not history_alias.get('RoutingConfig', {}).get('AdditionalVersionWeights') and captured['history'] == {
                    'version': history['Version'], 'codeSha256': history['CodeSha256'],
                    'environmentSha256': prepare.digest(history['Environment']['Variables'])}, 'Protected History version/configuration changed.')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('plan', type=Path); p.add_argument('--baseline', type=Path, required=True)
    p.add_argument('--capture', type=Path, required=True); p.add_argument('--revision', required=True)
    p.add_argument('--mode', choices=('maintenance', 'message-history'), required=True)
    p.add_argument('--expected-digest'); p.add_argument('--apply', action='store_true')
    p.add_argument('--deployed', action='store_true')
    args = p.parse_args()
    plan, baseline, captured = (json.loads(path.read_text()) for path in (args.plan, args.baseline, args.capture))
    replacements = None
    if args.mode == 'message-history':
        replacements = plan['variables']['deployment']['value']['artifacts']
    result, artifacts = review(plan, baseline, captured, args.revision, args.mode, replacements)
    if args.apply:
        require(re.fullmatch('[a-f0-9]{64}', args.expected_digest or '') and result['reviewedPlanDigest'] == args.expected_digest,
                'Exact reviewed plan digest is required before apply.')
        require(prepare.capture(baseline, args.mode) == captured, 'Fresh live pre-apply readback changed.')
    elif args.expected_digest is not None:
        require(result['reviewedPlanDigest'] == args.expected_digest, 'Plan digest mismatch.')
    verify_artifacts(artifacts)
    if args.deployed:
        verify_deployed(plan, baseline, captured, args.mode)
        result['actualDeployedConfigurationReadback'] = True
    print(json.dumps(result))


if __name__ == '__main__':
    try:
        main()
    except Exception:
        raise SystemExit('Preserved deployment plan rejected; private plan values were not printed.') from None
