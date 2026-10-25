#!/usr/bin/env python3
"""Review a saved, complete alarm-only Dev/UAT plan; never plan/apply or call AWS."""

import argparse
import hashlib
import json
from pathlib import Path
import re

from nonproduction_alarms import POLICY, is_alarm, resources

ACCOUNT = '107827791950'
REGION = 'us-east-1'
MANIFEST = json.loads(Path(__file__).with_name('nonproduction-alarm-resources.json').read_text())


def require(condition, code):
    if not condition:
        raise ValueError(code)


def has_unknown(value):
    if isinstance(value, dict):
        return any(has_unknown(item) for item in value.values())
    if isinstance(value, list):
        return any(has_unknown(item) for item in value)
    return bool(value)


def review(plan, revision, environment, stack):
    require(environment in ('dev', 'uat') and stack in MANIFEST, 'ALARM_SCOPE')
    require(re.fullmatch('[a-f0-9]{40}', revision or ''), 'ALARM_REVISION')
    require(plan.get('complete') is True and plan.get('errored') is False and
            plan.get('terraform_version') == '1.12.1' and
            all(item.get('status') == 'pass' for item in plan.get('checks', [])), 'ALARM_PLAN_STATUS')
    variables = {key: value.get('value') for key, value in plan.get('variables', {}).items()}
    require(variables.get('environment') == environment and variables.get('aws_region') == REGION and
            variables.get('project_name') == 'trustcheckradar', 'ALARM_ENVIRONMENT')
    require(not any(row.get('mode') == 'managed' and row.get('change', {}).get('actions') != ['no-op']
                    for row in plan.get('resource_drift', [])), 'ALARM_DRIFT')
    rows = [row for row in plan.get('resource_changes', []) if row.get('mode') == 'managed']
    inventory = {row['address']: row for row in rows}
    planned_rows = [row for row in resources(plan.get('planned_values', {}).get('root_module', {}))
                    if row.get('mode') == 'managed']
    planned = {row['address']: row.get('values') for row in planned_rows}
    require(rows and len(rows) == len(inventory) and len(planned_rows) == len(planned), 'ALARM_INVENTORY')
    require(not any(is_alarm(row) for row in planned_rows), 'ALARM_RECREATION')
    deleted = []
    for address, row in inventory.items():
        change = row['change']
        require(not has_unknown(change.get('after_unknown')), 'ALARM_UNKNOWN')
        if is_alarm(row):
            require(row.get('provider_name') == 'registry.terraform.io/hashicorp/aws', 'ALARM_PROVIDER')
            require(address.split('[', 1)[0] in MANIFEST[stack], 'ALARM_ADDRESS')
            before = change.get('before') or {}
            name = before.get('alarm_name', '')
            require(change.get('actions') == ['delete'] and change.get('after') is None and
                    address not in planned, 'ALARM_DELETE_ONLY')
            require(name.startswith('trustcheckradar-' + environment + '-') and
                    before.get('arn') == f'arn:aws:cloudwatch:{REGION}:{ACCOUNT}:alarm:{name}' and
                    before.get('id') == name, 'ALARM_IDENTITY')
            deleted.append(address)
        else:
            require(change.get('actions') == ['no-op'] and change.get('before') == change.get('after') and
                    address in planned and planned[address] == change.get('after'), 'ALARM_UNRELATED_CHANGE')
    require(set(planned) == set(inventory) - set(deleted), 'ALARM_POST_PLAN_INVENTORY')
    material = {'revision': revision, 'environment': environment, 'stack': stack, 'plan': plan}
    digest = hashlib.sha256(json.dumps(material, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'policy': POLICY, 'revision': revision, 'environment': environment, 'stack': stack,
            'account': ACCOUNT, 'region': REGION, 'alarmDeletes': len(deleted),
            'resourceAddresses': sorted(deleted), 'reviewedPlanDigest': digest,
            'deploymentAuthorized': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--environment', choices=('dev', 'uat'), required=True)
    parser.add_argument('--stack', choices=sorted(MANIFEST), required=True)
    args = parser.parse_args()
    print(json.dumps(review(json.loads(args.plan.read_text()), args.revision, args.environment, args.stack)))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError):
        # Saved plans may contain private runtime configuration. Do not echo them.
        raise SystemExit('Alarm-only plan rejected; inspect the saved plan privately.')
