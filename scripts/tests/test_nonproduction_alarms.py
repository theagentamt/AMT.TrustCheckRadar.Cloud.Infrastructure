"""Isolated guard regressions. These fixtures are never live acceptance evidence."""

import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import nonproduction_alarms as policy
import verify_nonproduction_alarm_removal as guard

REVISION = 'a' * 40


def fixture(environment='dev'):
    name = 'trustcheckradar-' + environment + '-message-consumer-errors'
    alarm = {'alarm_name': name, 'id': name,
             'arn': f'arn:aws:cloudwatch:us-east-1:107827791950:alarm:{name}'}
    log = {'name': '/aws/lambda/trustcheckradar-' + environment + '-message-consumer',
           'retention_in_days': 30}
    rows = [
        {'address': 'aws_cloudwatch_metric_alarm.runtime["consumer-errors"]',
         'type': 'aws_cloudwatch_metric_alarm', 'mode': 'managed',
         'provider_name': 'registry.terraform.io/hashicorp/aws',
         'change': {'actions': ['delete'], 'before': alarm, 'after': None}},
        {'address': 'aws_cloudwatch_log_group.runtime["consumer"]',
         'type': 'aws_cloudwatch_log_group', 'mode': 'managed',
         'provider_name': 'registry.terraform.io/hashicorp/aws',
         'change': {'actions': ['no-op'], 'before': copy.deepcopy(log), 'after': log}},
    ]
    return {'terraform_version': '1.12.1', 'complete': True, 'errored': False,
            'variables': {key: {'value': value} for key, value in {
                'environment': environment, 'aws_region': 'us-east-1', 'project_name': 'trustcheckradar'}.items()},
            'resource_changes': rows, 'resource_drift': [], 'checks': [{'status': 'pass'}],
            'planned_values': {'root_module': {'resources': [
                {'address': rows[1]['address'], 'type': rows[1]['type'], 'mode': 'managed', 'values': log}]}}}


class AlarmRemovalTests(unittest.TestCase):
    def test_only_scoped_alarm_delete_and_identical_logs_are_accepted(self):
        for environment in ('dev', 'uat'):
            result = guard.review(fixture(environment), REVISION, environment, 'message-consumer')
            self.assertEqual(result['alarmDeletes'], 1)
            self.assertFalse(result['deploymentAuthorized'])

    def test_unchanged_random_provider_resource_is_preserved(self):
        plan = fixture()
        row = plan['resource_changes'][1]
        row.update(address='random_id.existing', type='random_id',
                   provider_name='registry.terraform.io/hashicorp/random')
        planned = plan['planned_values']['root_module']['resources'][0]
        planned.update(address=row['address'], type=row['type'])
        self.assertEqual(guard.review(plan, REVISION, 'dev', 'message-consumer')['alarmDeletes'], 1)

    def test_production_wrong_account_and_unknown_address_are_rejected(self):
        for mutation in ('production', 'account', 'region', 'name', 'stack', 'address'):
            plan = fixture()
            row = plan['resource_changes'][0]
            environment = 'dev'
            stack = 'message-consumer'
            if mutation == 'production': environment = 'prod'
            if mutation == 'account': row['change']['before']['arn'] = row['change']['before']['arn'].replace('107827791950', '000000000000')
            if mutation == 'region': plan['variables']['aws_region']['value'] = 'us-west-2'
            if mutation == 'name': row['change']['before']['alarm_name'] = 'trustcheckradar-prod-critical'
            if mutation == 'stack': stack = 'api'
            if mutation == 'address': row['address'] = 'aws_cloudwatch_metric_alarm.unreviewed[0]'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                guard.review(plan, REVISION, environment, stack)

    def test_log_sns_budget_and_runtime_mutations_are_rejected(self):
        for kind in ('aws_cloudwatch_log_group', 'aws_sns_topic', 'aws_sns_topic_subscription',
                     'aws_budgets_budget', 'aws_iam_role_policy', 'aws_lambda_function'):
            for actions in (['delete'], ['update'], ['create'], ['delete', 'create']):
                plan = fixture()
                row = plan['resource_changes'][1]
                row.update(type=kind, address=kind + '.protected[0]')
                row['change']['actions'] = actions
                with self.subTest(kind=kind, actions=actions), self.assertRaises(ValueError):
                    guard.review(plan, REVISION, 'dev', 'message-consumer')

    def test_incomplete_unknown_drift_and_inconsistent_inventory_are_rejected(self):
        for mutation in ('complete', 'error', 'check', 'unknown', 'drift', 'duplicate', 'planned', 'replacement'):
            plan = fixture()
            if mutation == 'complete': plan['complete'] = False
            if mutation == 'error': plan['errored'] = True
            if mutation == 'check': plan['checks'] = [{'status': 'unknown'}]
            if mutation == 'unknown': plan['resource_changes'][0]['change']['after_unknown'] = {'arn': True}
            if mutation == 'drift': plan['resource_drift'] = [copy.deepcopy(plan['resource_changes'][0])]
            if mutation == 'duplicate': plan['resource_changes'].append(copy.deepcopy(plan['resource_changes'][0]))
            if mutation == 'planned': plan['planned_values']['root_module']['resources'][0]['values'] = {}
            if mutation == 'replacement': plan['resource_changes'][0]['change']['actions'] = ['delete', 'create']
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                guard.review(plan, REVISION, 'dev', 'message-consumer')

    def test_runtime_verifiers_require_migration_first(self):
        for plan in (fixture(), {'planned_values': {'root_module': {'child_modules': [
                {'resources': [{'mode': 'managed', 'type': 'aws_cloudwatch_composite_alarm',
                                'address': 'module.nested.aws_cloudwatch_composite_alarm.example'}]}]}}}):
            with self.assertRaisesRegex(ValueError, '^NONPRODUCTION_ALARM_MIGRATION_REQUIRED$'):
                policy.require_alarm_free_plan(plan)
        plan = fixture()
        plan['resource_changes'] = plan['resource_changes'][1:]
        policy.require_alarm_free_plan(plan)

    def test_absence_readback_requires_both_kinds_and_complete_pagination(self):
        policy.require_absent_readback({'MetricAlarms': [], 'CompositeAlarms': []})
        for response in ({}, {'MetricAlarms': []}, {'MetricAlarms': [], 'CompositeAlarms': [{}]},
                         {'MetricAlarms': [{}], 'CompositeAlarms': []},
                         {'MetricAlarms': [], 'CompositeAlarms': [], 'NextToken': 'more'}):
            with self.subTest(response=response), self.assertRaises(ValueError):
                policy.require_absent_readback(response)
