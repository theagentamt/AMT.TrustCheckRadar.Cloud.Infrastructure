#!/usr/bin/env python3
"""Prepare owner-private inputs for two manual Dev modes; never write AWS state."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re

from verify_governed_history_plan import require
from verify_message_consumer_transition import aws, _review_artifacts, _review_maintenance, verify_artifacts

PREFIX = 'trustcheckradar-dev'
SCOPE_SHA = '7dfa1b8193c7721659824436665ce800edc740fe396b89547725df371aafc09c'
RECOVERY_SHA = 'a5uouU5vy1ZJMuWpjQY4GUQ236d4jpRS23yTmaP5K+Y='
COMPUTED = {'last_modified', 'qualified_arn', 'qualified_invoke_arn', 'version'}


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


def subjects(raw, count=None, sha=None):
    value = json.loads(raw)
    require(type(value) is list and len(value) == len(set(value)) and
            all(type(s) is str and re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', s) for s in value),
            'Canonical private scope required.')
    value = sorted(value)
    require(count is None or len(value) == count, 'Existing scope count changed.')
    require(sha is None or digest(value) == sha, 'Existing private scope changed.')
    return value


def artifact(value):
    return {out: value[src] for out, src in {'bucket': 's3_bucket', 'key': 's3_key',
            'object_version': 's3_object_version', 'source_hash': 'source_code_hash'}.items()}


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
    alarms = read('cloudwatch', 'describe-alarms', '--alarm-names', *alarm_names)['MetricAlarms']
    require(len(alarms) == 2 and {a['AlarmName'] for a in alarms} == set(alarm_names), 'Both existing alarms required.')
    for alarm in alarms:
        require_maintenance_alarm(alarm, active)
    return {'schema_version': 1, 'environment': 'dev',
        'authority_table_arn': 'arn:aws:dynamodb:us-east-1:107827791950:table/' + table,
        'recovery_alias_arn': expected_alias, 'recovery_version': alias['FunctionVersion'],
        'recovery_code_sha256': worker['CodeSha256'], 'worker_enabled': active,
        'schedule_enabled': active, 'heartbeat_enforced': active, 'provider_access_added': False}


def capture(plan, mode, read=aws):
    require(read('sts', 'get-caller-identity').get('Account') == '107827791950', 'Dev account required.')
    rows = inventory(plan)
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
                before['source_code_hash'] == current['CodeSha256'] and
                environment(before) == current.get('Environment', {}).get('Variables'),
                'State/live artifact, version or configuration drift; reconcile before planning.')
        require(all(before[k] == current[v] for k, v in {
            'function_name': 'FunctionName', 'runtime': 'Runtime', 'architectures': 'Architectures',
            'role': 'Role', 'handler': 'Handler', 'timeout': 'Timeout', 'memory_size': 'MemorySize'}.items()),
            'Live runtime identity or limits drifted.')
        result['functions'][name] = {'version': current['Version'], 'codeSha256': current['CodeSha256'],
                                     'environmentSha256': digest(environment(before)),
                                     'concurrency': concurrency['ReservedConcurrentExecutions'], 'lastUpdateStatus': 'Successful'}
    result['maintenance'] = maintenance_readback(read, require_active=mode == 'message-history')
    if mode == 'maintenance':
        require(result['maintenance']['recovery_version'] == result['functions']['recovery']['version'], 'Worker changed during capture.')
    if mode == 'message-history':
        history = read('lambda', 'get-function-configuration', '--function-name', PREFIX + '-governed-history', '--qualifier', 'live')
        history_alias = read('lambda', 'get-alias', '--function-name', PREFIX + '-governed-history', '--name', 'live')
        require(history['Version'] == history_alias['FunctionVersion'] and history['State'] == 'Active' and
                not history_alias.get('RoutingConfig', {}).get('AdditionalVersionWeights') and
                all(history['Environment']['Variables'].get(k) == 'true' for k in (
                    'AUTHORITY_ENABLED', 'GOVERNED_HISTORY_LIST_ENABLED', 'GOVERNED_HISTORY_DETAIL_ENABLED')),
                'Existing active History service must remain qualified.')
        scope = environment(rows['aws_lambda_function.runtime["consumer"]']['change']['before'])['DEV_SUBJECT_ALLOWLIST_JSON']
        require(subjects(scope, 2, SCOPE_SHA) == subjects(history['Environment']['Variables']['DEV_SUBJECT_ALLOWLIST_JSON'], 2, SCOPE_SHA),
                'Message and History scope must remain identical.')
        result['history'] = {'version': history['Version'], 'codeSha256': history['CodeSha256'],
                             'environmentSha256': digest(history['Environment']['Variables'])}
    return result


def build(plan, captured, mode, replacements=None):
    variables = {k: v['value'] for k, v in plan['variables'].items()}
    require(variables.get('environment') == 'dev' and variables.get('aws_region') == 'us-east-1' and
            variables.get('project_name') == 'trustcheckradar' and variables.get('enabled') is True, 'Pinned Dev root required.')
    rows = inventory(plan)
    for name, observed in captured['functions'].items():
        before = rows[f'aws_lambda_function.runtime["{name}"]']['change']['before']
        require(before['version'] == observed['version'] and before['source_code_hash'] == observed['codeSha256'] and
                digest(environment(before)) == observed['environmentSha256'], 'Captured baseline drift.')
    if mode == 'maintenance':
        require(replacements is None, 'Maintenance cannot select replacement code.')
        values = {'activate_authority_maintenance': True,
                  'maintenance_qualification_reference': 'owner-reviewed shared recovery/expiry; exact saved-plan approval required'}
        ent = environment(rows['aws_lambda_function.runtime["entitlements"]']['change']['before'])
        values['governed_trial_subjects'] = subjects(ent['DEV_SUBJECT_ALLOWLIST_JSON'], 1)
        values['dev_access_snapshot_extra_subjects'] = subjects(ent['DEV_ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON'], 1)
        require(not set(values['governed_trial_subjects']) & set(values['dev_access_snapshot_extra_subjects']), 'GET scope must remain separate.')
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
    require(mode == 'message-history', 'Unknown preservation mode.')
    consumer = environment(rows['aws_lambda_function.runtime["consumer"]']['change']['before'])
    require(all(consumer.get(k) == 'true' for k in ('AUTHORITY_ENABLED', 'MESSAGE_CONSUMER_ENABLED',
            'MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED', 'GOVERNED_HISTORY_SETTLEMENT_ENABLED')) and
            consumer.get('MESSAGE_AI_ENABLED') == 'false' and consumer.get('MESSAGE_PROVIDER_CIRCUIT_OPEN') == 'true',
            'Current candidate.3/History gates must be preserved.')
    values = {'activate_rules_engineering': True, 'candidate3_rules_only_enabled': True,
              'governed_history_settlement_enabled': True,
              'engineering_subjects': subjects(consumer['DEV_SUBJECT_ALLOWLIST_JSON'], 2, SCOPE_SHA),
              'authority_maintenance': captured['maintenance']}
    deployment = copy.deepcopy(variables['deployment'])
    deployment['artifacts'] = replacements or {n: artifact(rows[f'aws_lambda_function.runtime["{n}"]']['change']['before']) for n in ('consumer', 'evaluator')}
    _review_artifacts(deployment)
    values['deployment'] = deployment
    _review_maintenance(dict(variables, **values))
    return values


def private_write(path, value):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as out:
        json.dump(value, out, sort_keys=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--mode', choices=('maintenance', 'message-history'), required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--artifact-release')
    args = parser.parse_args()
    plan = json.loads(args.baseline.read_text())
    observed = capture(plan, args.mode)
    replacements = None
    if args.artifact_release:
        require(args.mode == 'message-history' and re.fullmatch('[a-f0-9]{40}', args.artifact_release), 'Exact Message release required.')
        replacements = {}
        for n in ('consumer', 'evaluator'):
            key = f'releases/{args.artifact_release}/message_{n}.zip'
            head = aws('s3api', 'head-object', '--bucket', PREFIX + '-107827791950-artifacts', '--key', key, '--checksum-mode', 'ENABLED')
            replacements[n] = {'bucket': PREFIX + '-107827791950-artifacts', 'key': key,
                               'object_version': head['VersionId'], 'source_hash': head['ChecksumSHA256']}
    values = build(plan, observed, args.mode, replacements)
    if args.mode == 'message-history':
        verify_artifacts(values['deployment']['artifacts'])
    private_write(args.output, values)
    private_write(args.capture, observed)
    print('Private preserved inputs prepared; no activation or permission changed.')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        raise SystemExit('Preserved deployment preparation rejected; private values were not printed.') from None
