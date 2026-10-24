#!/usr/bin/env python3
"""Fence saved Dev plans to maintenance-only or existing candidate.3/History."""
import argparse
import json
from pathlib import Path
import re
import subprocess

import prepare_preserved_deployment as prepare
from verify_governed_history_plan import changed_fields
from verify_message_consumer_transition import _expected_environment, verify_artifacts
from billing_plan_digest import projection
import message_ai_configuration as ai

FUNCTION = 'aws_lambda_function.runtime["recovery"]'
ALIAS = 'aws_lambda_alias.runtime["recovery"]'
RULE = 'aws_cloudwatch_event_rule.maintenance["recovery"]'
HEARTBEAT = 'aws_cloudwatch_metric_alarm.worker_heartbeat["recovery"]'
OVERDUE = 'aws_cloudwatch_metric_alarm.expiry_overdue[0]'
MAINTENANCE = {FUNCTION, ALIAS, RULE, HEARTBEAT, OVERDUE}
PACKAGE = {'s3_bucket', 's3_key', 's3_object_version', 'source_code_hash'}



# Only fixed code/category labels enter rejection output. Never render exception
# text, resource addresses, unknown paths, plan values or AWS stderr/targets.
PREDICATES = {
    'Complete passing Terraform 1.12.1 plan required.': ('PLAN_STATUS', 'PLAN'),
    'Complete planned inventory required.': ('PLAN_INVENTORY', 'PLAN'),
    'Exact unweighted alias required.': ('ALIAS_IDENTITY', 'ALIAS'),
    'Alias baseline drift.': ('ALIAS_BASELINE', 'ALIAS'),
    'Exact main revision required.': ('REVISION_PIN', 'INPUT'),
    'Baseline inventory changed.': ('BASELINE_INVENTORY', 'PLAN'),
    'Private preservation inputs changed.': ('PRESERVED_INPUTS', 'INPUT'),
    'Unexpected output.': ('PLAN_OUTPUTS', 'PLAN'),
    'Nested unknown values are forbidden.': ('NESTED_UNKNOWNS', 'PLAN'),
    'Unreviewed computed field.': ('UNREVIEWED_COMPUTED_FIELD', 'PLAN'),
    'Post-plan inventory mismatch.': ('PLANNED_VALUE_MISMATCH', 'PLAN'),
    'New alias version must bind the published reviewed function.': ('ALIAS_PUBLISHED_BINDING', 'ALIAS'),
    'Alias version mismatch.': ('ALIAS_VERSION', 'ALIAS'),
    'State changed after capture.': ('CAPTURED_BEFORE_CHANGED', 'PLAN'),
    'No create, deletion or replacement permitted.': ('RESOURCE_ACTION', 'PLAN'),
    'Captured function binding mismatch.': ('CAPTURED_FUNCTION', 'FUNCTION'),
    'Pinned runtime identity required.': ('RUNTIME_IDENTITY', 'FUNCTION'),
    'Protected entitlements alias changed.': ('ENTITLEMENTS_ALIAS', 'ENTITLEMENTS_ALIAS'),
    'Maintenance transition must be complete or an exact no-op.': ('MAINTENANCE_CHANGE_SET', 'RECOVERY_CONTROLS'),
    'Only existing worker11 bytes are allowed.': ('RECOVERY_CODE_PIN', 'RECOVERY_FUNCTION'),
    'Worker artifact/role/runtime/limits must not change.': ('RECOVERY_PROTECTED_FIELDS', 'RECOVERY_FUNCTION'),
    'Only worker gate may change.': ('RECOVERY_GATE', 'RECOVERY_FUNCTION'),
    'Unknown mode.': ('MODE', 'INPUT'),
    'Preserved URL/access/trial boundaries required.': ('MAINTENANCE_OUTPUT_BOUNDARY', 'PLAN'),
    'Candidate.3/History output mismatch.': ('MESSAGE_OUTPUT_BOUNDARY', 'PLAN'),
    'Deployed alias is not qualified.': ('DEPLOYED_ALIAS', 'FUNCTION'),
    'Protected or known published version changed.': ('DEPLOYED_VERSION', 'FUNCTION'),
    'Deployed limits/update state mismatch.': ('DEPLOYED_LIMITS', 'FUNCTION'),
    'Deployed configuration mismatch.': ('DEPLOYED_CONFIGURATION', 'FUNCTION'),
    'Protected maintenance metadata changed.': ('DEPLOYED_MAINTENANCE', 'RECOVERY_CONTROLS'),
    'Protected History version/configuration changed.': ('DEPLOYED_HISTORY', 'HISTORY'),
    'Exact reviewed plan digest is required before apply.': ('APPLY_DIGEST_REQUIRED', 'INPUT'),
    'Fresh live pre-apply readback changed.': ('APPLY_FRESH_CAPTURE', 'PLAN'),
    'Unrelated resource update; IAM/routes/admission must remain unchanged.': ('UNRELATED_RESOURCE_UPDATE', 'OTHER_MANAGED'),
    'No-op inventory is not identical.': ('NOOP_NOT_IDENTICAL', 'PLAN'),
    'Protected runtime must remain unchanged.': ('PROTECTED_RUNTIME_UPDATE', 'FUNCTION'),
    'Entitlements must be a complete no-op.': ('ENTITLEMENTS_NOT_NOOP', 'ENTITLEMENTS_FUNCTION'),
    'Maintenance control exceeds scope.': ('RECOVERY_CONTROL_FIELDS', 'RECOVERY_CONTROLS'),
    'Message environment/role/runtime/limits/permissions must remain exact.': ('MESSAGE_PROTECTED_FIELDS', 'FUNCTION'),
    'Candidate.3/History/AI-off configuration must remain exact.': ('MESSAGE_ENVIRONMENT', 'FUNCTION'),
    'Artifact selection mismatch.': ('MESSAGE_ARTIFACT_SELECTION', 'ARTIFACT'),
    'Reviewed Message runtime hash must bind its package.': ('MESSAGE_RUNTIME_HASH', 'ARTIFACT'),
    'Plan digest mismatch.': ('PLAN_DIGEST', 'INPUT'),
}
RESOURCE_CATEGORIES = {
    FUNCTION: 'RECOVERY_FUNCTION', ALIAS: 'RECOVERY_ALIAS', RULE: 'RECOVERY_SCHEDULE',
    HEARTBEAT: 'RECOVERY_HEARTBEAT', OVERDUE: 'RECOVERY_OVERDUE',
    prepare.ENT_FUNCTION: 'ENTITLEMENTS_FUNCTION', prepare.ENT_ALIAS: 'ENTITLEMENTS_ALIAS',
    **{f'{kind}.runtime["{name}"]': name.upper() + '_' + suffix
       for kind, suffix in (('aws_lambda_function', 'FUNCTION'), ('aws_lambda_alias', 'ALIAS'))
       for name in ('consumer', 'evaluator', 'deletion')},
}
RESOURCE_CATEGORIES.update({f'aws_iam_role_policy.{n}[0]': 'MESSAGE_IAM' for n in ('consumer', 'evaluator')})
FIELD_CATEGORIES = frozenset({'code_sha256', 'source_code_size', 'version', 'last_modified',
    'qualified_arn', 'qualified_invoke_arn', 'function_version', 'environment',
    's3_bucket', 's3_key', 's3_object_version', 'source_code_hash', 'role', 'runtime',
    'handler', 'timeout', 'memory_size', 'architectures', 'reserved_concurrent_executions',
    'vpc_config', 'state', 'actions_enabled', 'treat_missing_data', 'before', 'after',
    'after_unknown', 'resource_changes', 'planned_values', 'root_module', 'resources',
    'variables', 'value', 'configuration', 'output_changes', 'candidate_contract',
    'function_name', 'publish', 'name', 'artifact', 'source_hash', 'bucket', 'key',
    'object_version', 'codeSha256', 'environmentSha256', 'artifactInputsSha256'})
PHASES = frozenset({'INITIALIZE', 'INPUT_LOAD', 'PLAN_REVIEW', 'APPLY_BOUNDARY',
                   'ARTIFACT_VERIFY', 'DEPLOYED_READBACK'})
DEPENDENCIES = {code: (code, 'ENTITLEMENTS_FUNCTION') for code in (
    'ENTITLEMENTS_RUNTIME_OR_INPUT_PIN_MISMATCH', 'ENTITLEMENTS_ENVIRONMENT_PIN_MISMATCH',
    'UNREVIEWED_MANAGED_DRIFT', 'ENTITLEMENTS_DRIFT_BINDING_MISMATCH',
    'ENTITLEMENTS_UNRELATED_DRIFT', 'ENTITLEMENTS_ALIAS_DRIFT_MISMATCH')}
DEPENDENCIES.update({
    'One complete environment is required.': ('BASELINE_ENVIRONMENT_SHAPE', 'FUNCTION'),
    'Unique AWS inventory required.': ('AWS_INVENTORY', 'PLAN'),
    'Canonical private scope required.': ('PRIVATE_SCOPE_SHAPE', 'INPUT'),
    'Existing scope count changed.': ('PRIVATE_SCOPE_COUNT', 'INPUT'),
    'Existing private scope changed.': ('PRIVATE_SCOPE_PIN', 'INPUT'),
    'Pinned Dev root required.': ('DEV_ROOT_PIN', 'INPUT'),
    'Captured baseline drift.': ('CAPTURED_BASELINE', 'PLAN'),
    'Maintenance cannot select replacement code.': ('MAINTENANCE_REPLACEMENT', 'ARTIFACT'),
    'GET scope must remain separate.': ('GET_SCOPE_ISOLATION', 'INPUT'),
    'Billing plan caller identity cannot be qualified.': ('CALLER_IDENTITY_PROJECTION', 'PLAN'),
    'Published artifact checksum metadata required.': ('PUBLISHED_CHECKSUM_METADATA', 'ARTIFACT'),
    'Published artifact checksum metadata disagrees.': ('PUBLISHED_CHECKSUM_DISAGREEMENT', 'ARTIFACT'),
})
DEPENDENCIES.update({code: (code, 'MESSAGE_CONFIGURATION') for code in (
    'AI_CONFIGURATION_SHAPE', 'AI_INACTIVE_CONFIGURATION', 'AI_PROFILE_CONFLICT', 'AI_COST_CONFIGURATION', 'AI_COMPONENT',
    'AI_PROVIDER_CONFIGURATION', 'AI_BUDGET_CONFIGURATION', 'AI_LEGACY_PROPOSER_NOT_DISABLED',
    'AI_BUDGET_POLICY_BASELINE', 'AI_URL_POLICY_BASELINE', 'AI_EVALUATOR_POLICY_BASELINE',
    'AI_PACKAGE_STRUCTURE', 'AI_QUALIFICATION_BINDING', 'AI_POLICY_IDENTITY', 'AI_POLICY_INVENTORY',
    'AI_POLICY_READBACK', 'AI_ROLE_TRUST', 'AI_PROFILE_BASELINE', 'AI_OPERATIONAL_REPORTING_NOT_READY')})
EXTRA_CODES = frozenset({'INPUT_INVALID', 'PLAN_STRUCTURE', 'VERIFIER_UNCLASSIFIED',
    'ARTIFACT_STS_READ_FAILED', 'ARTIFACT_S3_READ_FAILED', 'ARTIFACT_READ_FAILED',
    'ARTIFACT_ACCOUNT', 'ARTIFACT_HASH', 'ARTIFACT_VERSION', 'ARTIFACT_UNCLASSIFIED'})
CODES = frozenset(code for code, _ in PREDICATES.values()) | {code for code, _ in DEPENDENCIES.values()} | EXTRA_CODES
CATEGORIES = frozenset(RESOURCE_CATEGORIES.values()) | {category for _, category in PREDICATES.values()} | {'OTHER_MANAGED','MESSAGE_CONFIGURATION'}


def resource_category(address):
    return RESOURCE_CATEGORIES.get(address, 'OTHER_MANAGED')


class Rejection(ValueError):
    def __init__(self, code, category, fields=()):
        self.code = code if code in CODES else 'VERIFIER_UNCLASSIFIED'
        self.category = category if category in CATEGORIES else 'OTHER_MANAGED'
        self.fields = sorted({f if f in FIELD_CATEGORIES else 'OTHER_FIELD' for f in fields})
        super().__init__(self.code)


class PrivateArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        raise Rejection('INPUT_INVALID', 'INPUT')


def require(condition, message, *, resource=None, fields=()):
    if not condition:
        code, category = PREDICATES[message]
        raise Rejection(code, resource or category, fields)


def rejection_record(error, phase):
    phase = phase if phase in PHASES else 'INITIALIZE'
    if isinstance(error, Rejection):
        rejection = error
    elif type(error) is ValueError and str(error) in DEPENDENCIES:
        rejection = Rejection(*DEPENDENCIES[str(error)])
    elif phase == 'ARTIFACT_VERIFY':
        code = 'ARTIFACT_UNCLASSIFIED'
        if type(error) is subprocess.CalledProcessError:
            operation = tuple(error.cmd[:3]) if type(error.cmd) is list else ()
            code = {('aws', 'sts', 'get-caller-identity'): 'ARTIFACT_STS_READ_FAILED',
                    ('aws', 's3api', 'get-object'): 'ARTIFACT_S3_READ_FAILED'}.get(operation, 'ARTIFACT_READ_FAILED')
        elif type(error) is ValueError:
            fixed = {'Unexpected AWS account; no artifact read performed.': 'ARTIFACT_ACCOUNT'}
            for name in ('recovery', 'consumer', 'evaluator'):
                fixed[f'Downloaded {name} artifact SHA256 does not match.'] = 'ARTIFACT_HASH'
                fixed[f'Downloaded {name} artifact version does not match.'] = 'ARTIFACT_VERSION'
            code = fixed.get(str(error), code)
        rejection = Rejection(code, 'ARTIFACT')
    elif phase == 'INPUT_LOAD':
        rejection = Rejection('INPUT_INVALID', 'INPUT')
    elif type(error) in (KeyError, TypeError, IndexError, AttributeError):
        fields = error.args[:1] if type(error) is KeyError else ()
        rejection = Rejection('PLAN_STRUCTURE', 'PLAN', fields)
    else:
        rejection = Rejection('VERIFIER_UNCLASSIFIED', 'PLAN')
    return {'status': 'REJECTED', 'phase': phase, 'code': rejection.code,
            'resourceCategory': rejection.category, 'fieldCategories': rejection.fields}


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
            allowed = prepare.COMPUTED | ({'code_sha256', 'source_code_size'} if mode in ('message-history','message-ai') else set())
        elif address.startswith('aws_lambda_alias.runtime['):
            allowed = {'function_version'}
        require(paths <= {(k,) for k in allowed}, 'Unreviewed computed field.', resource=resource_category(address), fields=(path[0] for path in paths if path))
        require(same(known(change['after'], paths), known(planned[address], paths)), 'Post-plan inventory mismatch.', resource=resource_category(address), fields=changed_fields(known(change['after'], paths), known(planned[address], paths)))
    return rows


def alias_binding(row, function, plan):
    change = row['change']
    before, after = change['before'], change['after']
    require(before['name'] == after['name'] == 'live' and before['function_name'] == after['function_name'] == function['before']['function_name'] and
            not before.get('routing_config') and not after.get('routing_config'), 'Exact unweighted alias required.', resource=resource_category(row['address']))
    require(before['function_version'] == function['before']['version'] and changed_fields(before, after) <= {'function_version'}, 'Alias baseline drift.', resource=resource_category(row['address']))
    if after.get('function_version') is None or function['after'].get('version') is None:
        config = next((r for r in plan['configuration']['root_module']['resources'] if r['address'] == 'aws_lambda_alias.runtime'), {})
        refs = config.get('expressions', {}).get('function_version', {}).get('references', [])
        require(change.get('after_unknown', {}).get('function_version') is True and
                function.get('after_unknown', {}).get('version') is True and 'aws_lambda_function.runtime' in refs,
                'New alias version must bind the published reviewed function.', resource=resource_category(row['address']))
    else:
        require(re.fullmatch('[1-9][0-9]*', after['function_version']) and after['function_version'] == function['after']['version'], 'Alias version mismatch.', resource=resource_category(row['address']))


def review(plan, baseline, captured, revision, mode, replacements=None, configuration=None):
    require(re.fullmatch('[a-f0-9]{40}', revision or ''), 'Exact main revision required.')
    rows, old = validate_plan(plan, mode), prepare.inventory(baseline)
    prepare.require_entitlements_drift(baseline, mode)
    require(set(rows) == set(old), 'Baseline inventory changed.')
    expected = {k: v['value'] for k, v in baseline['variables'].items()}
    expected.update(prepare.build(baseline, captured, mode, replacements, configuration))
    require(same({k: v['value'] for k, v in plan['variables'].items()}, expected), 'Private preservation inputs changed.')
    allowed = MAINTENANCE if mode == 'maintenance' else {f'{kind}.runtime["{n}"]' for kind in ('aws_lambda_function', 'aws_lambda_alias') for n in ('consumer', 'evaluator')}
    if mode == 'message-ai':
        allowed |= {f'aws_iam_role_policy.{n}[0]' for n in ('consumer','evaluator')}
    changed = []
    for address, row in rows.items():
        c = row['change']
        require(same(c['before'], old[address]['change']['before']), 'State changed after capture.', resource=resource_category(address), fields=changed_fields(c['before'], old[address]['change']['before']))
        require(c['actions'] in (['no-op'], ['update']), 'No create, deletion or replacement permitted.', resource=resource_category(address))
        if c['actions'] == ['update']:
            require(address in allowed, 'Unrelated resource update; IAM/routes/admission must remain unchanged.', resource=resource_category(address), fields=changed_fields(c['before'], c['after']))
            changed.append(address)
        else:
            require(same(c['before'], c['after']) and not unknowns(c.get('after_unknown', {})), 'No-op inventory is not identical.', resource=resource_category(address), fields=changed_fields(c['before'], c['after']))
    for n in captured['functions']:
        address = f'aws_lambda_function.runtime["{n}"]'
        before, after = (rows[address]['change'][k] for k in ('before', 'after'))
        require(before['version'] == captured['functions'][n]['version'] and before['code_sha256'] == captured['functions'][n]['codeSha256'] and
                prepare.digest(prepare.artifact(before)) == captured['functions'][n]['artifactInputsSha256'] and
                prepare.digest(prepare.environment(before)) == captured['functions'][n]['environmentSha256'], 'Captured function binding mismatch.', resource=resource_category(address))
        suffix = 'message-' + n if mode in ('message-history','message-ai') else {'consumer': 'url-consumer', 'entitlements': 'v1-entitlements', 'recovery': 'url-lease-recovery', 'deletion': 'v1-authority-deletion'}[n]
        handlers = {'consumer': 'app.lambda_handler', 'recovery': 'app.lambda_handler',
                    'entitlements': 'v1_entitlements.app.lambda_handler',
                    'deletion': 'v1_authority_deletion.app.lambda_handler'}
        handler = ('message_' + n + '.app.lambda_handler') if mode in ('message-history','message-ai') else handlers[n]
        timeout = (29 if n == 'consumer' else 23) if mode in ('message-history','message-ai') else {'consumer': 29, 'entitlements': 10, 'recovery': 15, 'deletion': 30}[n]
        require(all(before.get(k) == v for k, v in {
            'function_name': prepare.PREFIX + '-' + suffix, 'runtime': 'python3.14', 'architectures': ['arm64'],
            'handler': handler, 'memory_size': 256, 'publish': True, 'timeout': timeout,
            'reserved_concurrent_executions': 1 if mode == 'maintenance' and n in ('recovery', 'deletion') else 2,
            'role': 'arn:aws:iam::107827791950:role/' + prepare.PREFIX + '-' + suffix + '-execution'}.items()),
            'Pinned runtime identity required.', resource=resource_category(address))
        if mode == 'maintenance' and n != 'recovery':
            require(rows[address]['change']['actions'] == ['no-op'], 'Protected runtime must remain unchanged.', resource=resource_category(address))
    if mode == 'maintenance':
        for address in (prepare.ENT_FUNCTION, prepare.ENT_ALIAS):
            require(rows[address]['change']['actions'] == ['no-op'], 'Entitlements must be a complete no-op.', resource=resource_category(address))
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
        require(changed_fields(before, after) <= prepare.COMPUTED | {'environment'}, 'Worker artifact/role/runtime/limits must not change.', fields=changed_fields(before, after))
        require(prepare.environment(after) == dict(prepare.environment(before), LEASE_SWEEP_ENABLED='true') and
                prepare.environment(before).get('LEASE_SWEEP_ENABLED') in ('false', 'true'), 'Only worker gate may change.')
        alias_binding(rows[ALIAS], c, plan)
        for address, fields, values in (
            (RULE, {'state'}, {'state': 'ENABLED'}),
            (HEARTBEAT, {'actions_enabled', 'treat_missing_data'}, {'actions_enabled': True, 'treat_missing_data': 'breaching'}),
            (OVERDUE, {'actions_enabled'}, {'actions_enabled': True}),
        ):
            a, b = (rows[address]['change'][k] for k in ('before', 'after'))
            require(changed_fields(a, b) <= fields and all(b.get(k) == v for k, v in values.items()), 'Maintenance control exceeds scope.', resource=resource_category(address), fields=changed_fields(a, b))
        artifacts = {'recovery': prepare.artifact(after)}
    else:
        require(mode in ('message-history','message-ai'), 'Unknown mode.')
        for name in ('consumer', 'evaluator'):
            c = rows[f'aws_lambda_function.runtime["{name}"]']['change']
            before, after = c['before'], c['after']
            require(changed_fields(before, after) <= prepare.COMPUTED | PACKAGE | {'code_sha256', 'source_code_size'} | ({'environment'} if mode == 'message-ai' else set()),
                    'Message environment/role/runtime/limits/permissions must remain exact.', resource=resource_category(f'aws_lambda_function.runtime["{name}"]'), fields=changed_fields(before, after))
            if mode == 'message-ai':
                environment = ai.environment(prepare.environment(before), name, configuration)
                require(prepare.environment(after) == environment, 'Candidate.3/History/AI-off configuration must remain exact.', resource=resource_category(f'aws_lambda_function.runtime["{name}"]'))
            else:
                environment = _expected_environment(name, expected, True)
                environment['MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED'] = 'true'
                if name == 'consumer':
                    environment.update(GOVERNED_HISTORY_SETTLEMENT_ENABLED='true', MESSAGE_PROVIDER_CIRCUIT_OPEN='true')
                require(prepare.environment(before) == prepare.environment(after) == environment, 'Candidate.3/History/AI-off configuration must remain exact.', resource=resource_category(f'aws_lambda_function.runtime["{name}"]'))
            require(prepare.artifact(after) == expected['deployment']['artifacts'][name], 'Artifact selection mismatch.', resource=resource_category(f'aws_lambda_function.runtime["{name}"]'))
            require(after.get('code_sha256') == after['source_code_hash'] or
                    (after.get('code_sha256') is None and c.get('after_unknown', {}).get('code_sha256') is True and
                     bool(changed_fields(before, after) & PACKAGE)), 'Reviewed Message runtime hash must bind its package.', resource=resource_category(f'aws_lambda_function.runtime["{name}"]'))
            alias_binding(rows[f'aws_lambda_alias.runtime["{name}"]'], c, plan)
        artifacts = expected['deployment']['artifacts']
        if mode == 'message-ai':
            before_policies = [json.loads(rows[f'aws_iam_role_policy.{n}[0]']['change']['before']['policy']) for n in ('consumer','evaluator')]
            desired = ai.policies(*before_policies, expected['deployment']['authority_table_arn'],
                expected['deployment']['assessment_alias_arn'], configuration['message_ai_primary_enabled'],
                configuration['ai_configuration']['secret_arn'] if configuration['message_ai_primary_enabled'] else None)
            for name, policy in zip(('consumer','evaluator'), desired):
                c = rows[f'aws_iam_role_policy.{name}[0]']['change']
                require(changed_fields(c['before'], c['after']) <= {'policy'} and same(json.loads(c['after']['policy']), policy),
                        'Unrelated resource update; IAM/routes/admission must remain unchanged.', resource='MESSAGE_IAM')
    require(set(plan.get('output_changes', {})) <= {'candidate_contract', 'authority_maintenance'}, 'Unexpected output.')
    contract = plan['output_changes']['candidate_contract']['after']
    if mode == 'maintenance':
        require(contract['consumer_enabled'] is False and contract['recovery_enabled'] is True and contract['general_customer_access'] is False and
                contract['governed_trial_subject_count'] == 1 and contract['engineering_subject_count'] == 0, 'Preserved URL/access/trial boundaries required.')
    elif mode == 'message-history':
        require(all(contract[k] is True for k in ('candidate3_rules_only_enabled', 'governed_history_settlement_enabled', 'consumer_enabled', 'evaluator_enabled', 'provider_circuit_open')) and
                all(contract[k] is False for k in ('ai_enabled', 'ai_qualified', 'model_enabled')) and contract['engineering_subject_count'] == 2,
                'Candidate.3/History output mismatch.')
    else:
        active = configuration['message_ai_primary_enabled']
        require(all(contract[k] is True for k in ('governed_history_settlement_enabled','consumer_enabled','evaluator_enabled')) and
                all(contract[k] is active for k in ('ai_enabled','ai_qualified','ai_primary_enabled','model_enabled')) and
                contract['candidate3_rules_only_enabled'] is expected['candidate3_rules_only_enabled'] and
                contract['provider_circuit_open'] is expected['candidate3_rules_only_enabled'] and
                contract['url_assessment_enabled'] is False and contract['engineering_subject_count'] == 2,
                'Candidate.3/History output mismatch.')
        prepare.require(not active or contract.get('daily_reporting_ready') is True, 'AI_OPERATIONAL_REPORTING_NOT_READY')
    material = {'plan': projection(plan), 'baseline': projection(baseline), 'capture': captured,
                'revision': revision, 'mode': mode}
    return {'reviewedPlanDigest': prepare.digest(material), 'mode': mode, 'revision': revision,
            'resourceUpdates': len(changed), 'resourceAddresses': sorted(changed),
            'providerCallsEnabled': mode == 'message-ai' and configuration['message_ai_primary_enabled']}, artifacts


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
        expected_hash = desired['source_code_hash'] if mode in ('message-history','message-ai') else desired['code_sha256']
        require(current['CodeSha256'] == expected_hash and
                all(current[v] == desired[k] for k, v in {'function_name': 'FunctionName',
                'runtime': 'Runtime', 'architectures': 'Architectures', 'handler': 'Handler', 'role': 'Role',
                'timeout': 'Timeout', 'memory_size': 'MemorySize'}.items()) and
                current['Environment']['Variables'] == prepare.environment(desired), 'Deployed configuration mismatch.')
    maintenance = prepare.maintenance_readback(read, require_active=True)
    if mode in ('message-history','message-ai'):
        require(maintenance == captured['maintenance'], 'Protected maintenance metadata changed.')
        history = read('lambda', 'get-function-configuration', '--function-name', prepare.PREFIX + '-governed-history', '--qualifier', 'live')
        prepare.subjects(history['Environment']['Variables']['DEV_SUBJECT_ALLOWLIST_JSON'], 2, prepare.SCOPE_SHA)
        history_alias = read('lambda', 'get-alias', '--function-name', prepare.PREFIX + '-governed-history', '--name', 'live')
        require(history['State'] == 'Active' and history['Version'] == history_alias['FunctionVersion'] and
                not history_alias.get('RoutingConfig', {}).get('AdditionalVersionWeights') and captured['history'] == {
                    'version': history['Version'], 'codeSha256': history['CodeSha256'],
                    'environmentSha256': prepare.digest(history['Environment']['Variables'])}, 'Protected History version/configuration changed.')
    if mode == 'message-ai':
        prepare.message_policy_readback(rows, read, side='after')


def main():
    p = PrivateArgumentParser(description=__doc__)
    p.add_argument('plan', type=Path); p.add_argument('--baseline', type=Path, required=True)
    p.add_argument('--capture', type=Path, required=True); p.add_argument('--revision', required=True)
    p.add_argument('--mode', choices=('maintenance', 'message-history','message-ai'), required=True)
    p.add_argument('--ai-configuration', type=Path)
    p.add_argument('--expected-digest'); p.add_argument('--apply', action='store_true')
    p.add_argument('--deployed', action='store_true')
    args = p.parse_args()
    phase = 'INPUT_LOAD'
    try:
        plan, baseline, captured = (json.loads(path.read_text()) for path in (args.plan, args.baseline, args.capture))
        replacements = None
        if args.mode in ('message-history','message-ai'):
            replacements = plan['variables']['deployment']['value']['artifacts']
        prepare.require((args.ai_configuration is not None) == (args.mode == 'message-ai'), 'AI_CONFIGURATION_SHAPE')
        configuration = json.loads(args.ai_configuration.read_text(), object_pairs_hook=ai.unique_pairs) if args.ai_configuration else None
        phase = 'PLAN_REVIEW'
        result, artifacts = review(plan, baseline, captured, args.revision, args.mode, replacements, configuration)
        phase = 'APPLY_BOUNDARY'
        if args.apply:
            require(re.fullmatch('[a-f0-9]{64}', args.expected_digest or '') and result['reviewedPlanDigest'] == args.expected_digest,
                    'Exact reviewed plan digest is required before apply.')
            require(prepare.capture(baseline, args.mode) == captured, 'Fresh live pre-apply readback changed.')
        elif args.expected_digest is not None:
            require(result['reviewedPlanDigest'] == args.expected_digest, 'Plan digest mismatch.')
        phase = 'ARTIFACT_VERIFY'
        verify_artifacts(artifacts, review_archive=(lambda name,path: ai.archive(name,path,configuration)) if args.mode == 'message-ai' else None)
        if args.deployed:
            phase = 'DEPLOYED_READBACK'
            verify_deployed(plan, baseline, captured, args.mode)
            result['actualDeployedConfigurationReadback'] = True
        print(json.dumps(result))
    except Exception as error:
        raise SystemExit(json.dumps(rejection_record(error, phase), sort_keys=True)) from None


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit(json.dumps(rejection_record(error, 'INITIALIZE'), sort_keys=True)) from None
