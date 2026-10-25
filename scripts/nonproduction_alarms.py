"""ATCR-184 Dev/UAT alarm policy; no cloud calls or mutation entry points."""

import re

ALARM_TYPES = frozenset({'aws_cloudwatch_metric_alarm', 'aws_cloudwatch_composite_alarm'})
POLICY = 'dev-uat-disabled-v1'


def resources(module):
    yield from module.get('resources', [])
    for child in module.get('child_modules', []):
        yield from resources(child)


def is_alarm(row):
    return (row.get('type') in ALARM_TYPES or
            re.search(r'(?:^|\.)aws_cloudwatch_(?:metric|composite)_alarm\.',
                      row.get('address', '')) is not None)


def require_alarm_free_plan(plan):
    """Runtime verifiers require the separate alarm-only migration first."""
    rows = list(plan.get('resource_changes', []))
    rows += list(resources(plan.get('planned_values', {}).get('root_module', {})))
    if any(row.get('mode') == 'managed' and is_alarm(row) for row in rows):
        raise ValueError('NONPRODUCTION_ALARM_MIGRATION_REQUIRED')


def require_absent_readback(response):
    """Accept only complete describe-alarms output for both alarm kinds."""
    if (type(response) is not dict or response.get('MetricAlarms') != [] or
            response.get('CompositeAlarms') != [] or response.get('NextToken')):
        raise ValueError('NONPRODUCTION_ALARMS_STILL_PRESENT_OR_INCOMPLETE')
