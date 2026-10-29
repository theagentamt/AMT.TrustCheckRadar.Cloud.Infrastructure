#!/usr/bin/env python3
"""Prepare owner-private inputs for two manual Dev modes; never write AWS state."""
import argparse
import base64
import copy
import hashlib
import json
import os
from pathlib import Path
import re

from nonproduction_alarms import require_absent_readback
from verify_governed_history_plan import require
from verify_message_consumer_transition import aws, _review_artifacts, _review_maintenance, verify_artifacts
import message_ai_configuration as ai

PREFIX = 'trustcheckradar-dev'
SCOPE_SHA = '7dfa1b8193c7721659824436665ce800edc740fe396b89547725df371aafc09c'
RULES_SCOPE_SHA = 'ea905c7184be88586e8a0a5745319bf0fdeef29734b57af80c9c048cd8e353d1'
RECOVERY_SHA = 'a5uouU5vy1ZJMuWpjQY4GUQ236d4jpRS23yTmaP5K+Y='
COMPUTED = {'last_modified', 'qualified_arn', 'qualified_invoke_arn', 'version'}
ENTITLEMENTS = json.loads((Path(__file__).resolve().parents[1] /
                          'docs/evidence/entitlements18-preservation.json').read_text())
ENT_FUNCTION = 'aws_lambda_function.runtime["entitlements"]'
ENT_ALIAS = 'aws_lambda_alias.runtime["entitlements"]'


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def environment(value):
    rows = value.get('environment')
    require(type(rows) is list and len(rows) == 1 and type(rows[0].get('variables')) is dict,
            'One complete environment is required.')
    return rows[0]['variables']


def inventory(plan):
    rows = [r for r in plan['resource_changes'] if r.get('mode') == 'managed']
    result = {r['address']: r for r in rows}
    require(len(rows) == len(result) and all(r.get('provider_name') == 'registry.terraform.io/hashicorp/aws' for r in rows),
            'Unique AWS inventory required.')
    return result


def scope_sha(mode):
    require(mode in ('message-history', 'message-ai'), 'Unknown preservation mode.')
    return RULES_SCOPE_SHA if mode == 'message-history' else SCOPE_SHA


def subjects(raw, count=None, sha=None):
    value = json.loads(raw)
    require(type(value) is list and len(value) == len(set(value)) and
            all(type(s) is str and re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', s) for s in value),
            'Canonical private scope required.')
    value = sorted(value)
    require(count is None or len(value) == count, 'Existing scope count changed.')
    require(sha is None or digest(value) == sha, 'Existing private scope changed.')
    return value


def trial_subject_inputs(env):
    """Keep the historical snapshot profile distinct from the approved addition."""
    from prepare_governed_history_configuration import validate_access_subjects
    selected = subjects(env['DEV_SUBJECT_ALLOWLIST_JSON'])
    validate_access_subjects(selected, True)
    if len(selected) == 1:
        require(digest(selected) == ENTITLEMENTS['baseTrialSubjectsSha256'], 'Existing private scope changed.')
        extra = subjects(env['DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON'], 1, ENTITLEMENTS['current']['extraSubjectsSha256'])
        require(not set(selected) & set(extra), 'GET scope must remain separate.')
    else:
        require('DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON' not in env, 'GET scope must remain separate.')
        extra = []
    return {'governed_trial_subjects': selected, 'dev_access_snapshot_extra_subjects': extra}


def artifact(value):
    return {out: value[src] for out, src in {'bucket': 's3_bucket', 'key': 's3_key',
            'object_version': 's3_object_version', 'source_hash': 'source_code_hash'}.items()}


def published_source_hash(head):
    """Normal publisher records SHA256 in metadata; always hash exact GET bytes later."""
    value = head.get('Metadata', {}).get('sha256')
    require(type(value) is str and re.fullmatch('[a-f0-9]{64}', value), 'Published artifact checksum metadata required.')
    encoded = base64.b64encode(bytes.fromhex(value)).decode()
    require(head.get('ChecksumSHA256') in (None, encoded), 'Published artifact checksum metadata disagrees.')
    return encoded


def require_entitlements(value, generation='current'):
    """Pin observed bytes/config independently of retained provider code inputs."""
    pin = ENTITLEMENTS[generation]
    name = ENTITLEMENTS['functionName']
    arn = 'arn:aws:lambda:us-east-1:107827791950:function:' + name + ':' + pin['version']
    expected = {k: pin[k] for k in ('version', 'code_sha256', 'source_code_size', 'last_modified')}
    expected.update(function_name=name, qualified_arn=arn,
                    qualified_invoke_arn='arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/' + arn + '/invocations')
    require(digest({k: value.get(k) for k in expected}) == digest(expected) and
            artifact(value) == ENTITLEMENTS['historicalArtifactInputs'], 'ENTITLEMENTS_RUNTIME_OR_INPUT_PIN_MISMATCH')
    env = environment(value)
    require(digest(env) == pin['environmentSha256'], 'ENTITLEMENTS_ENVIRONMENT_PIN_MISMATCH')
    subjects(env['DEV_SUBJECT_ALLOWLIST_JSON'], 1, ENTITLEMENTS['baseTrialSubjectsSha256'])
    subjects(env['DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON'], 1, pin['extraSubjectsSha256'])

def require_entitlements_drift(plan, mode):
    """Recognize only the observed read-only v15->v18 refresh, never an apply."""
    drift = [r for r in plan.get('resource_drift', []) if r.get('mode') == 'managed' and
             r.get('change', {}).get('actions') != ['no-op']]
    if not drift:
        return
    require(mode == 'maintenance' and len(drift) == 2 and
            {r.get('address') for r in drift} == {ENT_FUNCTION, ENT_ALIAS},
            'UNREVIEWED_MANAGED_DRIFT')
    rows = {r['address']: r for r in drift}
    refreshed = inventory(plan)
    for address, row in rows.items():
        c = row['change']
        require(row.get('provider_name') == 'registry.terraform.io/hashicorp/aws' and
                c['actions'] == ['update'] and not c.get('after_unknown') and
                digest(c['after']) == digest(refreshed[address]['change']['before']), 'ENTITLEMENTS_DRIFT_BINDING_MISMATCH')
    before, after = (rows[ENT_FUNCTION]['change'][k] for k in ('before', 'after'))
    require_entitlements(before, 'historical')
    require_entitlements(after)
    fields = {'version', 'code_sha256', 'source_code_size', 'last_modified',
              'qualified_arn', 'qualified_invoke_arn', 'environment'}
    require(digest({k: v for k, v in before.items() if k not in fields}) ==
            digest({k: v for k, v in after.items() if k not in fields}), 'ENTITLEMENTS_UNRELATED_DRIFT')
    a, b = (rows[ENT_ALIAS]['change'][k] for k in ('before', 'after'))
    require(a['name'] == b['name'] == 'live' and
            a['function_name'] == b['function_name'] == ENTITLEMENTS['functionName'] and
            not a.get('routing_config') and not b.get('routing_config') and
            a['function_version'] == ENTITLEMENTS['historical']['version'] and
            b['function_version'] == ENTITLEMENTS['current']['version'] and
            digest({k: v for k, v in a.items() if k != 'function_version'}) ==
            digest({k: v for k, v in b.items() if k != 'function_version'}), 'ENTITLEMENTS_ALIAS_DRIFT_MISMATCH')


def require_maintenance_alarm(alarm, active):
    heartbeat = alarm['AlarmName'].endswith('-heartbeat')
    # AWS uses EvaluationPeriods only when DatapointsToAlarm is absent.
    datapoints = alarm.get('DatapointsToAlarm', alarm['EvaluationPeriods'])
    destination = ['arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts']
    require(alarm['ActionsEnabled'] is active and alarm['AlarmActions'] == alarm['OKActions'] == destination and
            alarm['Namespace'] == 'AMT/TrustCheckRadar/V1/dev' and
            alarm['MetricName'] == ('url-lease-recovery-heartbeat' if heartbeat else 'url-lease-recovery-expiry-overdue') and
            alarm['Threshold'] == (1 if heartbeat else 300) and alarm['EvaluationPeriods'] == (2 if heartbeat else 1) and
            alarm['Period'] == (300 if heartbeat else 60) and alarm['Statistic'] == ('Sum' if heartbeat else 'Maximum') and
            alarm['ComparisonOperator'] == ('LessThanThreshold' if heartbeat else 'GreaterThanThreshold') and
            type(alarm['EvaluationPeriods']) is int and type(datapoints) is int and
            datapoints == (2 if heartbeat else 1) and
            not any(alarm.get(k) for k in ('Dimensions', 'Metrics', 'ExtendedStatistic', 'InsufficientDataActions')) and
            alarm['TreatMissingData'] == ('breaching' if active and heartbeat else 'notBreaching'), 'Existing alarm boundary changed.')


def maintenance_readback(read, require_active=False):
    name = PREFIX + '-url-lease-recovery'
    table = PREFIX + '-purchase-entitlements'
    alias = read('lambda', 'get-alias', '--function-name', name, '--name', 'live')
    worker = read('lambda', 'get-function-configuration', '--function-name', name, '--qualifier', alias['FunctionVersion'])
    latest = read('lambda', 'get-function-configuration', '--function-name', name)
    concurrency = read('lambda', 'get-function-concurrency', '--function-name', name)
    expected_alias = 'arn:aws:lambda:us-east-1:107827791950:function:' + name + ':live'
    role_name = name + '-execution'
    require(alias['AliasArn'] == expected_alias and not alias.get('RoutingConfig', {}).get('AdditionalVersionWeights') and
            worker['Version'] == alias['FunctionVersion'] and worker['State'] == 'Active' and
            worker['CodeSha256'] == RECOVERY_SHA and worker['Runtime'] == 'python3.14' and worker['Architectures'] == ['arm64'] and
            worker['Role'] == 'arn:aws:iam::107827791950:role/' + role_name and worker['Handler'] == 'app.lambda_handler' and
            worker['MemorySize'] == 256 and worker['Timeout'] == 15, 'Exact existing worker identity required.')
    require(latest.get('LastUpdateStatus') == 'Successful' and latest.get('CodeSha256') == worker['CodeSha256'] and
            latest.get('Environment') == worker.get('Environment') and concurrency.get('ReservedConcurrentExecutions') == 1,
            'Worker update/concurrency state changed.')
    env = worker['Environment']['Variables']
    active = env.get('LEASE_SWEEP_ENABLED') == 'true'
    require(env == {'STAGE': 'dev', 'AUTHORITY_TABLE_NAME': table, 'LEASE_SWEEP_ENABLED': str(active).lower()} and
            (not require_active or active), 'Actual same-table maintenance is not qualified/active.')
    rule = read('events', 'describe-rule', '--name', name)
    targets = read('events', 'list-targets-by-rule', '--rule', name)['Targets']
    require(rule['Arn'] == 'arn:aws:events:us-east-1:107827791950:rule/' + name and
            rule['State'] == ('ENABLED' if active else 'DISABLED') and rule['ScheduleExpression'] == 'rate(1 minute)' and
            len(targets) == 1 and targets[0]['Arn'] == expected_alias and json.loads(targets[0]['Input']) == {'schemaVersion': 1} and
            targets[0].get('RetryPolicy') == {'MaximumEventAgeInSeconds': 60, 'MaximumRetryAttempts': 0} and
            not targets[0].get('RoleArn') and not targets[0].get('DeadLetterConfig'), 'Exact same-worker schedule/target required.')
    invoke = read('lambda', 'get-function-event-invoke-config', '--function-name', name, '--qualifier', 'live')
    require(invoke['MaximumRetryAttempts'] == 0 and invoke['MaximumEventAgeInSeconds'] == 60 and
            not any(invoke.get('DestinationConfig', {}).values()), 'No retries or invocation destinations permitted.')
    policy = json.loads(read('lambda', 'get-policy', '--function-name', name, '--qualifier', 'live')['Policy'])
    require(policy.get('Statement') == [{'Sid': 'AllowMaintenanceSchedule', 'Effect': 'Allow',
        'Principal': {'Service': 'events.amazonaws.com'}, 'Action': 'lambda:InvokeFunction',
        'Resource': expected_alias, 'Condition': {'StringEquals': {'AWS:SourceAccount': '107827791950'},
        'ArnLike': {'AWS:SourceArn': rule['Arn']}}}], 'Invocation resource policy changed.')
    names = read('iam', 'list-role-policies', '--role-name', role_name)['PolicyNames']
    require(names == ['expired-lease-cleanup-only'] and
            read('iam', 'list-attached-role-policies', '--role-name', role_name)['AttachedPolicies'] == [], 'Recovery role policies changed.')
    role = read('iam', 'get-role', '--role-name', role_name)['Role']
    require(role['AssumeRolePolicyDocument'] == {'Version': '2012-10-17', 'Statement': [
        {'Effect': 'Allow', 'Action': 'sts:AssumeRole', 'Principal': {'Service': 'lambda.amazonaws.com'}}]} and
        not role.get('PermissionsBoundary'), 'Recovery role trust changed.')
    role_policy = read('iam', 'get-role-policy', '--role-name', role_name, '--policy-name', names[0])['PolicyDocument']
    require(digest(role_policy) == 'f556674acec46576caf4e2e1afb102984a42b67457c5d27a3bcbd9daa1918f77', 'Recovery permission baseline changed.')
    alarm_names = [name + '-heartbeat', name + '-expiry-overdue']
    require_absent_readback(read('cloudwatch', 'describe-alarms', '--alarm-types', 'MetricAlarm',
                                 'CompositeAlarm', '--alarm-names', *alarm_names))
    return {'schema_version': 2, 'alarm_policy': 'dev-uat-disabled-v1', 'environment': 'dev',
        'authority_table_arn': 'arn:aws:dynamodb:us-east-1:107827791950:table/' + table,
        'recovery_alias_arn': expected_alias, 'recovery_version': alias['FunctionVersion'],
        'recovery_code_sha256': worker['CodeSha256'], 'worker_enabled': active,
        'schedule_enabled': active, 'heartbeat_enforced': False, 'provider_access_added': False}


def capture(plan, mode, read=aws):
    require(read('sts', 'get-caller-identity').get('Account') == '107827791950', 'Dev account required.')
    rows = inventory(plan)
    require_entitlements_drift(plan, mode)
    if mode == 'maintenance':
        require_entitlements(rows[ENT_FUNCTION]['change']['before'])
    names = ('consumer', 'entitlements', 'recovery', 'deletion') if mode == 'maintenance' else ('consumer', 'evaluator')
    result = {'functions': {}}
    for name in names:
        before = rows[f'aws_lambda_function.runtime["{name}"]']['change']['before']
        fn = before['function_name']
        alias = read('lambda', 'get-alias', '--function-name', fn, '--name', 'live')
        current = read('lambda', 'get-function-configuration', '--function-name', fn,
                       '--qualifier', alias['FunctionVersion'])
        latest = read('lambda', 'get-function-configuration', '--function-name', fn)
        concurrency = read('lambda', 'get-function-concurrency', '--function-name', fn)
        require(current.get('State') == 'Active' and not alias.get('RoutingConfig', {}).get('AdditionalVersionWeights'),
                'Existing active unweighted alias required.')
        require(latest.get('LastUpdateStatus') == 'Successful' and latest.get('CodeSha256') == current['CodeSha256'] and
                latest.get('Environment') == current.get('Environment') and
                concurrency.get('ReservedConcurrentExecutions') == before['reserved_concurrent_executions'],
                'No pending configuration update or concurrency drift permitted.')
        require(before['version'] == alias['FunctionVersion'] == current['Version'] and
                before['code_sha256'] == current['CodeSha256'] and
                environment(before) == current.get('Environment', {}).get('Variables'),
                'State/live artifact, version or configuration drift; reconcile before planning.')
        require(all(before[k] == current[v] for k, v in {
            'function_name': 'FunctionName', 'runtime': 'Runtime', 'architectures': 'Architectures',
            'role': 'Role', 'handler': 'Handler', 'timeout': 'Timeout', 'memory_size': 'MemorySize'}.items()),
            'Live runtime identity or limits drifted.')
        result['functions'][name] = {'version': current['Version'], 'codeSha256': current['CodeSha256'],
                                     'environmentSha256': digest(environment(before)),
                                     'artifactInputsSha256': digest(artifact(before)),
                                     'concurrency': concurrency['ReservedConcurrentExecutions'], 'lastUpdateStatus': 'Successful'}
    result['maintenance'] = maintenance_readback(read, require_active=mode in ('message-history', 'message-ai'))
    if mode == 'maintenance':
        require(result['maintenance']['recovery_version'] == result['functions']['recovery']['version'], 'Worker changed during capture.')
    if mode in ('message-history', 'message-ai'):
        history = read('lambda', 'get-function-configuration', '--function-name', PREFIX + '-governed-history', '--qualifier', 'live')
        history_alias = read('lambda', 'get-alias', '--function-name', PREFIX + '-governed-history', '--name', 'live')
        require(history['Version'] == history_alias['FunctionVersion'] and history['State'] == 'Active' and
                not history_alias.get('RoutingConfig', {}).get('AdditionalVersionWeights') and
                all(history['Environment']['Variables'].get(k) == 'true' for k in (
                    'AUTHORITY_ENABLED', 'GOVERNED_HISTORY_LIST_ENABLED', 'GOVERNED_HISTORY_DETAIL_ENABLED')),
                'Existing active History service must remain qualified.')
        scope = environment(rows['aws_lambda_function.runtime["consumer"]']['change']['before'])['DEV_SUBJECT_ALLOWLIST_JSON']
        require(subjects(scope, 2, scope_sha(mode)) == subjects(history['Environment']['Variables']['DEV_SUBJECT_ALLOWLIST_JSON'], 2, scope_sha(mode)),
                'Message and History scope must remain identical.')
        result['history'] = {'version': history['Version'], 'codeSha256': history['CodeSha256'],
                             'environmentSha256': digest(history['Environment']['Variables'])}
    if mode == 'message-ai':
        result['policies'] = message_policy_readback(rows, read)
        result['monitoring'] = message_monitoring_readback(rows, read)
    return result


def message_policy_readback(rows, read=aws, side='before'):
    result = {}
    for name in ('consumer', 'evaluator'):
        value = rows[f'aws_iam_role_policy.{name}[0]']['change'][side]
        role = PREFIX + '-message-' + name + '-execution'
        expected_name = {'consumer': 'fenced-message-authority-and-private-evaluator',
                         'evaluator': 'private-message-evaluation-only'}[name]
        require(value['role'] == role and value['name'] == expected_name, 'AI_POLICY_IDENTITY')
        require(read('iam', 'list-role-policies', '--role-name', role)['PolicyNames'] == [expected_name]
                and read('iam', 'list-attached-role-policies', '--role-name', role)['AttachedPolicies'] == [], 'AI_POLICY_INVENTORY')
        actual = read('iam', 'get-role-policy', '--role-name', role, '--policy-name', expected_name)['PolicyDocument']
        require(digest(actual) == digest(json.loads(value['policy'])), 'AI_POLICY_READBACK')
        trust = read('iam', 'get-role', '--role-name', role)['Role']
        require(trust['AssumeRolePolicyDocument'] == {'Version': '2012-10-17', 'Statement': [
            {'Effect': 'Allow', 'Action': 'sts:AssumeRole', 'Principal': {'Service': 'lambda.amazonaws.com'}}]}
            and not trust.get('PermissionsBoundary'), 'AI_ROLE_TRUST')
        result[name] = digest(actual)
    return result


def message_monitoring(rows, side='before'):
    """Preserve content-free runtime logs while Dev alarm resources are absent."""
    require(not any(address.startswith('aws_cloudwatch_metric_alarm.') or
                    address.startswith('aws_cloudwatch_composite_alarm.') for address in rows),
            'NONPRODUCTION_ALARM_MIGRATION_REQUIRED')
    result = {'alarm_policy': {'policy': 'dev-uat-disabled-v1'}}
    for name in ('consumer', 'evaluator'):
        value = rows.get(f'aws_cloudwatch_log_group.runtime["{name}"]', {}).get('change', {}).get(side) or {}
        expected_name = '/aws/lambda/' + PREFIX + '-message-' + name
        require(value.get('name') == expected_name and type(value.get('retention_in_days')) is int
                and value['retention_in_days'] > 0, 'AI_ESSENTIAL_MONITORING')
        result[name] = {key: value.get(key) for key in ('name', 'retention_in_days', 'kms_key_id')}
    return result


def message_monitoring_readback(rows, read=aws, side='before'):
    expected = message_monitoring(rows, side)
    names = [PREFIX + '-message-' + name + '-' + metric
             for name in ('consumer', 'evaluator') for metric in ('errors', 'throttles', 'duration')]
    require_absent_readback(read('cloudwatch', 'describe-alarms', '--alarm-types', 'MetricAlarm',
                                 'CompositeAlarm', '--alarm-names', *names))
    for name in ('consumer', 'evaluator'):
        value = expected[name]
        response = read('logs', 'describe-log-groups', '--log-group-name-prefix', value['name'])
        groups = [g for g in response.get('logGroups', []) if g.get('logGroupName') == value['name']]
        require(len(groups) == 1 and groups[0].get('retentionInDays') == value['retention_in_days']
                and groups[0].get('kmsKeyId') == value['kms_key_id'], 'AI_ESSENTIAL_MONITORING')
    return {name: digest(value) for name, value in expected.items()}


def build(plan, captured, mode, replacements=None, configuration=None):
    variables = {k: v['value'] for k, v in plan['variables'].items()}
    require(variables.get('environment') == 'dev' and variables.get('aws_region') == 'us-east-1' and
            variables.get('project_name') == 'trustcheckradar' and variables.get('enabled') is True, 'Pinned Dev root required.')
    rows = inventory(plan)
    require_entitlements_drift(plan, mode)
    if mode == 'maintenance':
        require_entitlements(rows[ENT_FUNCTION]['change']['before'])
    for name, observed in captured['functions'].items():
        before = rows[f'aws_lambda_function.runtime["{name}"]']['change']['before']
        require(before['version'] == observed['version'] and before['code_sha256'] == observed['codeSha256'] and
                digest(artifact(before)) == observed['artifactInputsSha256'] and
                digest(environment(before)) == observed['environmentSha256'], 'Captured baseline drift.')
    if mode == 'maintenance':
        require(replacements is None, 'Maintenance cannot select replacement code.')
        values = {'activate_authority_maintenance': True,
                  'maintenance_qualification_reference': 'owner-reviewed shared recovery/expiry; exact saved-plan approval required'}
        ent = environment(rows['aws_lambda_function.runtime["entitlements"]']['change']['before'])
        values.update(trial_subject_inputs(ent))
        for name in ('consumer', 'entitlements', 'deletion'):
            key = name + '_artifact_override'
            value = copy.deepcopy(variables[key])
            value['artifact'] = artifact(rows[f'aws_lambda_function.runtime["{name}"]']['change']['before'])
            value['source_sha'] = value['artifact']['key'].split('/')[1]
            value['provenance_reference'] = 'docs/evidence/preserved-deployment-boundary.json'
            values[key] = value
        deletion = copy.deepcopy(variables['deletion_activation'])
        deletion['subjects'] = subjects(environment(rows['aws_lambda_function.runtime["deletion"]']['change']['before'])['DEV_SUBJECT_ALLOWLIST_JSON'])
        values['deletion_activation'] = deletion
        return values
    require(mode in ('message-history', 'message-ai'), 'Unknown preservation mode.')
    consumer = environment(rows['aws_lambda_function.runtime["consumer"]']['change']['before'])
    require(all(consumer.get(k) == 'true' for k in ('AUTHORITY_ENABLED', 'MESSAGE_CONSUMER_ENABLED',
            'GOVERNED_HISTORY_SETTLEMENT_ENABLED')), 'Current candidate.3/History gates must be preserved.')
    if mode == 'message-history':
        require(configuration is None and consumer.get('MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED') == 'true' and
                consumer.get('MESSAGE_AI_ENABLED') == 'false' and consumer.get('MESSAGE_PROVIDER_CIRCUIT_OPEN') == 'true',
                'Current candidate.3/History gates must be preserved.')
    else:
        ai.validate(configuration)
        evaluator = environment(rows['aws_lambda_function.runtime["evaluator"]']['change']['before'])
        require(consumer.get('MESSAGE_AI_ENABLED') in ('true', 'false') and
                evaluator.get('MESSAGE_AI_ENABLED') == evaluator.get('MESSAGE_AI_QUALIFIED') == consumer['MESSAGE_AI_ENABLED'] and
                consumer.get('MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED') in ('true', 'false') and
                evaluator.get('MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED') == consumer['MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED'] and
                consumer.get('MESSAGE_PROVIDER_CIRCUIT_OPEN') in ('true', 'false') and evaluator.get('MESSAGE_PROPOSER_ENABLED') == 'false',
                'AI_PROFILE_BASELINE')
        if consumer['MESSAGE_AI_ENABLED'] == 'true':
            require(consumer.get('MESSAGE_AI_PRIMARY_ENABLED') == evaluator.get('MESSAGE_AI_PRIMARY_ENABLED') == 'true'
                    and consumer['MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED'] == 'false'
                    and consumer['MESSAGE_PROVIDER_CIRCUIT_OPEN'] == 'false'
                    and json.loads(consumer['MESSAGE_AI_COST_POLICY']) == json.loads(evaluator['MESSAGE_AI_COST_POLICY']), 'AI_PROFILE_BASELINE')
        for name in ('consumer', 'evaluator'):
            require(captured['policies'][name] == digest(json.loads(rows[f'aws_iam_role_policy.{name}[0]']['change']['before']['policy'])),
                    'AI_POLICY_READBACK')
    values = {'activate_rules_engineering': True, 'candidate3_rules_only_enabled': consumer['MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED'] == 'true',
              'governed_history_settlement_enabled': True,
              'engineering_subjects': subjects(consumer['DEV_SUBJECT_ALLOWLIST_JSON'], 2, scope_sha(mode)),
              'authority_maintenance': captured['maintenance']}
    if mode == 'message-history':
        # Membership is checked above; preserve order/spacing independently.
        values['preserved_engineering_subjects_json'] = consumer['DEV_SUBJECT_ALLOWLIST_JSON']
    deployment = copy.deepcopy(variables['deployment'])
    deployment['artifacts'] = replacements or {n: artifact(rows[f'aws_lambda_function.runtime["{n}"]']['change']['before']) for n in ('consumer', 'evaluator')}
    _review_artifacts(deployment)
    values['deployment'] = deployment
    if mode == 'message-ai':
        active = configuration['message_ai_primary_enabled']
        rules = configuration['candidate3_rules_only_enabled']
        values.update(message_ai_primary_enabled=active, ai_configuration=configuration['ai_configuration'], url_assessment_enabled=False)
        if rules is not None:
            values['candidate3_rules_only_enabled'] = rules
        values['provider_budget'] = configuration['provider_budget'] if active else {
            k: int(consumer[v]) for k, v in {'window_seconds': 'MESSAGE_PROVIDER_WINDOW_SECONDS',
            'max_attempts_per_window': 'MESSAGE_PROVIDER_ATTEMPTS_PER_WINDOW',
            'max_failures_per_window': 'MESSAGE_PROVIDER_FAILURES_PER_WINDOW'}.items()}
    _review_maintenance(dict(variables, **values))
    return values


def private_write(path, value):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as out:
        json.dump(value, out, sort_keys=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--mode', choices=('maintenance', 'message-history', 'message-ai'), required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--artifact-release')
    parser.add_argument('--ai-configuration', type=Path)
    args = parser.parse_args()
    plan = json.loads(args.baseline.read_text())
    observed = capture(plan, args.mode)
    replacements = None
    if args.artifact_release:
        require(args.mode in ('message-history', 'message-ai') and re.fullmatch('[a-f0-9]{40}', args.artifact_release), 'Exact Message release required.')
        replacements = {}
        for n in ('consumer', 'evaluator'):
            key = f'releases/{args.artifact_release}/message_{n}.zip'
            head = aws('s3api', 'head-object', '--bucket', PREFIX + '-107827791950-artifacts', '--key', key, '--checksum-mode', 'ENABLED')
            replacements[n] = {'bucket': PREFIX + '-107827791950-artifacts', 'key': key,
                               'object_version': head['VersionId'], 'source_hash': published_source_hash(head)}
    require((args.ai_configuration is not None) == (args.mode == 'message-ai'), 'AI_CONFIGURATION_SHAPE')
    configuration = json.loads(args.ai_configuration.read_text(), object_pairs_hook=ai.unique_pairs) if args.ai_configuration else None
    values = build(plan, observed, args.mode, replacements, configuration)
    if args.mode in ('message-history', 'message-ai'):
        verify_artifacts(values['deployment']['artifacts'], review_archive=(
            lambda name, path: ai.archive(name, path, configuration)) if args.mode == 'message-ai' else None)
    private_write(args.output, values)
    private_write(args.capture, observed)
    print('Private preserved inputs prepared; no activation or permission changed.')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        raise SystemExit('Preserved deployment preparation rejected; private values were not printed.') from None
