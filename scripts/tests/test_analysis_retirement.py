import ast
import base64
import copy
import hashlib
import importlib.util
import json
import re
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location('retirement', Path(__file__).resolve().parents[1] / 'verify_analysis_retirement.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
REVISION = '1' * 40
RELEASE = 'd98ffd65b42d54953ad83e980e58846b6fc02c5d'
VERSION = 'K6SXSdTc6rYObyN4qxbRVGTbsNvxAuU1'
SHA = 'vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4='
NAME = 'trustcheckradar-dev-conversation-analysis'


def fixture():
    env = {'APP_ENVIRONMENT': 'dev', 'COGNITO_REQUIRED_SCOPE': 'aws.cognito.signin.user.admin',
           'COGNITO_ISSUER': 'synthetic-issuer', 'COGNITO_APP_CLIENT_ID': 'synthetic-client',
           'USERS_TABLE_NAME': 'trustcheckradar-dev-users', 'DEVICE_BINDINGS_TABLE_NAME': 'trustcheckradar-dev-device-bindings',
           'ANALYSIS_ABUSE_TABLE_NAME': 'trustcheckradar-dev-analysis-abuse-control', 'DELETION_LEDGER_TABLE_NAME': 'trustcheckradar-dev-deletion-ledger',
           'HISTORY_MAX_SUMMARY_BYTES': '4096', 'HISTORY_MAX_LIST_ITEMS': '20', 'HISTORY_MAX_TEXT_FIELD_BYTES': '1024',
           'HISTORY_CONTENT_TABLE_NAME': 'trustcheckradar-dev-history-content', 'HISTORY_CONTROL_TABLE_NAME': 'trustcheckradar-dev-history-control',
           'HISTORY_MAX_RESPONSE_BYTES': '262144', 'HISTORY_WRITES_ENABLED': 'false', 'HISTORY_DURABLE_REPLAY_ENABLED': 'false', 'RECOGNITION_ENABLED': 'false'}
    fn = {'function_name': NAME, 'role': 'synthetic-role', 's3_bucket': 'trustcheckradar-dev-107827791950-artifacts',
          's3_key': 'releases/'+RELEASE+'/conversation_analysis.zip', 's3_object_version': VERSION, 'source_code_hash': SHA,
          'publish': True, 'runtime': 'python3.14', 'architectures': ['arm64'], 'handler': 'app.lambda_handler',
          'reserved_concurrent_executions': 5, 'timeout': 29, 'memory_size': 256, 'environment': [{'variables': env}]}
    old = copy.deepcopy(fn)
    old['publish'] = False
    old['environment'][0]['variables']['OPENAI_SECRET_ARN'] = 'synthetic-old-unused-secret-reference'
    def row(address, actions, before, after):
        return {'address': address, 'mode': 'managed', 'change': {'actions': actions, 'before': before, 'after': after, 'after_unknown': {}}}
    permission = {'function_name': NAME, 'qualifier': 'retired', 'source_account': '107827791950', 'principal': 'apigateway.amazonaws.com',
                  'action': 'lambda:InvokeFunction', 'statement_id': 'AllowExecutionFromApiGatewayAnalysis',
                  'source_arn': 'arn:aws:execute-api:us-east-1:107827791950:example1234/$default/POST/analysis'}
    old_permission = dict(permission, qualifier=None, source_arn='arn:aws:execute-api:us-east-1:107827791950:example1234/*/*')
    return {'complete': True, 'errored': False, 'terraform_version': '1.12.1',
      'variables': {key: {'value': value} for key, value in {
         'environment': 'dev', 'aws_region': 'us-east-1', 'project_name': 'trustcheckradar', 'analysis_legacy_path_enabled': False,
         'analysis_retirement_deployment': {'release_id': RELEASE, 'object_version': VERSION, 'source_hash': SHA}}.items()},
      'resource_changes': [row('aws_lambda_function.analysis', ['update'], old, fn),
         row('aws_iam_policy.analysis_runtime', ['update'], {'policy': '{}'}, {'policy': MODULE.runtime_policy()}),
         row('aws_lambda_alias.analysis_retired[0]', ['create'], None, {'name': 'retired', 'function_name': NAME, 'function_version': None, 'routing_config': []}),
         row('aws_apigatewayv2_integration.analysis_lambda', ['update'], {'integration_uri': 'unqualified', 'integration_method': 'POST'}, {'integration_uri': None, 'integration_method': 'POST'}),
         row('aws_lambda_permission.allow_api_gateway_invoke_analysis[0]', ['delete', 'create'], old_permission, permission)],
      'configuration': {'root_module': {'resources': [
         {'address': 'aws_lambda_alias.analysis_retired', 'expressions': {'function_version': {'references': ['aws_lambda_function.analysis.version']}}},
         {'address': 'aws_apigatewayv2_integration.analysis_lambda', 'expressions': {'integration_uri': {'references': ['aws_lambda_alias.analysis_retired[0].invoke_arn']}}}]}},
      'resource_drift': [], 'checks': []}


class RetirementTests(unittest.TestCase):
    def kms_repair_plan(self):
        plan = self.post_role_plan()
        runtime = next(row for row in plan['resource_changes'] if row['address'] == 'aws_iam_policy.analysis_runtime')['change']
        runtime['actions'] = ['update']
        runtime['before']['policy'] = MODULE.runtime_before_kms_fix()
        return plan

    def test_kms_repair_is_one_exact_policy_update_and_separate_approval(self):
        plan = self.kms_repair_plan()
        report = MODULE.review(plan, REVISION, bounded=True, runtime_repair=True)
        self.assertTrue(report['runtimeKmsRepair'])
        self.assertEqual(report['changes'], [{'address': 'aws_iam_policy.analysis_runtime', 'actions': ['update']}])
        self.assertEqual(report['verifiedPostApplyRoleReadbacks'], 1)
        for kwargs in ({'bounded': True}, {'bounded': True, 'post_apply': True}, {'runtime_repair': True},
                       {'bounded': True, 'post_apply': True, 'runtime_repair': True}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                MODULE.review(plan, REVISION, **kwargs)
        MODULE.authorize(report, report['reviewedPlanDigest'], True)
        with self.assertRaises(ValueError): MODULE.authorize(report, 'old-retirement-approval', True)
        with self.assertRaises(ValueError): MODULE.ordinary_guard(plan)
        # The repair is valid when provider-computed views have already refreshed.
        plan['resource_drift'] = []
        self.assertEqual(MODULE.review(plan, REVISION, bounded=True, runtime_repair=True)['verifiedPostApplyRoleReadbacks'], 0)

    def test_kms_repair_rejects_policy_widening_other_changes_and_unknowns(self):
        def runtime(plan): return next(row for row in plan['resource_changes'] if row['address'] == 'aws_iam_policy.analysis_runtime')['change']
        def policy_mutation(change):
            def mutate(plan):
                doc = json.loads(runtime(plan)['after']['policy']); change(doc)
                runtime(plan)['after']['policy'] = json.dumps(doc)
            return mutate
        def kms(doc): return next(row for row in doc['Statement'] if row['Sid'] == 'DenyApplicationKmsUse')
        mutations = [
            lambda p: runtime(p)['before'].__setitem__('policy', '{}'),
            lambda p: runtime(p)['after_unknown'].__setitem__('policy', True),
            lambda p: runtime(p)['after'].__setitem__('arn', 'other'),
            lambda p: p['resource_changes'][0]['change'].__setitem__('actions', ['update']),
            lambda p: p['resource_changes'][0]['change']['after_unknown'].__setitem__('version', True),
            lambda p: p['resource_changes'][0]['change']['after'].__setitem__('reserved_concurrent_executions', 6),
            lambda p: p['resource_changes'][2]['change']['after'].__setitem__('function_version', '2'),
            lambda p: p['resource_drift'].append(copy.deepcopy(p['resource_drift'][1])),
            policy_mutation(lambda d: kms(d).pop('Condition')),
            policy_mutation(lambda d: kms(d).__setitem__('Condition', {'Null': {'lambda:SourceFunctionArn': ['true']}})),
            policy_mutation(lambda d: kms(d).__setitem__('Condition', {'Null': {'other': ['false']}})),
            policy_mutation(lambda d: kms(d)['Action'].append('kms:*')),
            policy_mutation(lambda d: kms(d).__setitem__('Resource', ['specific-key'])),
            policy_mutation(lambda d: kms(d).__setitem__('Effect', 'Allow')),
            policy_mutation(lambda d: d['Statement'].append({'Sid': 'AllowKms', 'Effect': 'Allow', 'Action': ['kms:Decrypt'], 'Resource': ['*']})),
            policy_mutation(lambda d: d['Statement'].__setitem__(4, {'Sid': 'ProviderAllow', 'Effect': 'Allow', 'Action': ['secretsmanager:GetSecretValue'], 'Resource': ['*']})),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                plan = self.kms_repair_plan(); mutate(plan)
                with self.assertRaises(ValueError): MODULE.review(plan, REVISION, bounded=True, runtime_repair=True)

    def post_role_plan(self):
        plan = self.stage_readback_plan()
        role = 'trustcheckradar-dev-conversation-analysis-role'
        role_arn = 'arn:aws:iam::107827791950:role/' + role
        runtime_arn = 'arn:aws:iam::107827791950:policy/trustcheckradar-dev-conversation-analysis-runtime'
        basic_arn = 'arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
        period_arn = 'arn:aws:iam::107827791950:policy/trustcheckradar-dev-analysis-period-work'
        table = 'arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-'
        history = json.dumps({'Version': '2012-10-17', 'Statement': [{'Sid': 'ReadHistoryReplayAndState', 'Effect': 'Allow',
            'Action': ['dynamodb:GetItem'], 'Resource': [table+'history-content', table+'history-control'],
            'Condition': {'ForAllValues:StringLike': {'dynamodb:LeadingKeys': ['USER#*']}}}]})
        # Historical public Terraform policy at 26b2437, bound to the pre-apply SDK inventory digest.
        rows = []
        for label, suffix, key in [('DeletionFence', 'deletion-ledger', 'ACCOUNT#*'), ('Profile', 'users', 'USER#*')]:
            for prefix, action, atomic in [('ReadAuthoritative', 'dynamodb:GetItem', False),
                ('CheckAuthoritative' if suffix == 'users' else 'Check', 'dynamodb:ConditionCheckItem', True)]:
                conditions = {'ForAllValues:StringLike': {'dynamodb:LeadingKeys': [key]}}
                if atomic: conditions['StringEquals'] = {'dynamodb:EnclosingOperation': ['TransactWriteItems']}
                rows.append({'Sid': prefix+label+('Atomically' if atomic else ''), 'Effect':'Allow','Action':[action],'Resource':[table+suffix],'Condition':conditions})
        rows += [json.loads(history)['Statement'][0], {'Sid':'AtomicHistoryCompletion','Effect':'Allow',
            'Action':['dynamodb:PutItem','dynamodb:UpdateItem','dynamodb:ConditionCheckItem'],
            'Resource':[table+'history-content',table+'history-control'],
            'Condition':{'StringEquals':{'dynamodb:EnclosingOperation':['TransactWriteItems']},'ForAllValues:StringLike':{'dynamodb:LeadingKeys':['USER#*']}}}]
        old_history = json.dumps({'Version':'2012-10-17','Statement':rows})
        self.assertEqual(MODULE.policy_digest(old_history), '95a70a4cb727366daa2f93f60e90402e40b4813551ebc594ddbb7731431c3ab0')
        boundary = MODULE.migration_boundary_policy()
        inline = [{'name':'history-analysis-runtime','policy':history},
            {'name':'trustcheckradar-dev-research-migration-analysis','policy':boundary}]
        trust = json.dumps({'Version':'2012-10-17','Statement':[{'Sid':'LambdaAssumeRole','Effect':'Allow',
            'Action':'sts:AssumeRole','Principal':{'Service':'lambda.amazonaws.com'}}]})
        current_role = {'name':role,'arn':role_arn,'assume_role_policy':trust,'inline_policy':inline,'managed_policy_arns':[basic_arn,runtime_arn]}
        stale = copy.deepcopy(current_role);stale['managed_policy_arns'].append(period_arn);stale['inline_policy'][0]['policy']=old_history
        plan['resource_drift'].append({'address':'aws_iam_role.analysis','mode':'managed','provider_name':'registry.terraform.io/hashicorp/aws',
            'change':{'actions':['update'],'before':stale,'after':copy.deepcopy(current_role),'after_unknown':{}}})
        def add(address, value):
            plan['resource_changes'].append({'address':address,'mode':'managed','provider_name':'registry.terraform.io/hashicorp/aws',
                'change':{'actions':['no-op'],'before':copy.deepcopy(value),'after':copy.deepcopy(value),'after_unknown':{}}})
        add('aws_iam_role.analysis',current_role)
        add('aws_iam_role_policy_attachment.analysis_runtime',{'role':role,'policy_arn':runtime_arn})
        add('aws_iam_role_policy_attachment.analysis_basic_execution',{'role':role,'policy_arn':basic_arn})
        add('aws_iam_role_policy.history_analysis[0]',{'name':'history-analysis-runtime','role':role,'policy':history})
        add('aws_iam_role_policy.research_migration_boundary["analysis"]',{'name':'trustcheckradar-dev-research-migration-analysis','role':role,'policy':boundary})
        plan['resource_changes'][0]['change']['after']['role']=role_arn
        plan['resource_changes'][0]['change']['after']['code_sha256']=SHA
        plan['resource_changes'][1]['change']['after']['arn']=runtime_arn
        plan['resource_changes'][2]['change']['after']['function_version']='1'
        for row in plan['resource_changes']:
            row['provider_name']='registry.terraform.io/hashicorp/aws'
            row['change']['actions']=['no-op'];row['change']['before']=copy.deepcopy(row['change']['after'])
        plan['configuration']['root_module']['resources'] += [
            {'address':'aws_iam_role.analysis','expressions':{'assume_role_policy':{'references':['data.aws_iam_policy_document.age_attestation_assume_role.json']}}},
            {'address':'aws_lambda_function.analysis','expressions':{'role':{'references':['aws_iam_role.analysis.arn']}}}]
        return plan

    def test_post_role_readback_is_post_only_exact_inventory_and_digest_bound(self):
        plan = self.post_role_plan()
        report = MODULE.review(plan,REVISION,bounded=True,post_apply=True)
        self.assertEqual(report['verifiedPostApplyRoleReadbacks'],1)
        self.assertEqual(report['changes'],[])
        self.assertFalse(MODULE.automatic_stage_readback(plan,plan['resource_drift'][1]))
        with self.assertRaises(ValueError):MODULE.review(plan,REVISION,bounded=True)
        reordered=copy.deepcopy(plan)
        for point in ('before','after'):
            reordered['resource_drift'][1]['change'][point]['managed_policy_arns'].reverse()
            reordered['resource_drift'][1]['change'][point]['inline_policy'].reverse()
        for row in reordered['resource_changes']:
            if row['address']=='aws_iam_role.analysis':
                for point in ('before','after'):
                    row['change'][point]['managed_policy_arns'].reverse();row['change'][point]['inline_policy'].reverse()
        self.assertTrue(MODULE.post_role_readback(reordered,reordered['resource_drift'][1]))
        self.assertNotEqual(report['reviewedPlanDigest'],MODULE.review(reordered,REVISION,bounded=True,post_apply=True)['reviewedPlanDigest'])

    def test_post_role_readback_rejects_extra_permissions_unbound_history_and_changes(self):
        def role_row(plan):return plan['resource_drift'][1]
        def managed(plan,address):return next(row for row in plan['resource_changes'] if row['address']==address)
        mutations=[
            lambda p: role_row(p).__setitem__('provider_name','other'),
            lambda p: role_row(p)['change']['after'].__setitem__('name','other'),
            lambda p: role_row(p)['change']['after']['managed_policy_arns'].append('private-extra'),
            lambda p: role_row(p)['change']['before']['managed_policy_arns'].pop(),
            lambda p: role_row(p)['change']['after']['inline_policy'].append({'name':'extra','policy':'{}'}),
            lambda p: role_row(p)['change']['before']['inline_policy'][0].__setitem__('policy','{}'),
            lambda p: role_row(p)['change']['after']['inline_policy'][1].__setitem__('policy','{}'),
            lambda p: role_row(p)['change'].__setitem__('after_unknown',{'inline_policy':True}),
            lambda p: managed(p,'aws_iam_role.analysis')['change'].__setitem__('actions',['update']),
            lambda p: managed(p,'aws_iam_role.analysis')['change']['after_unknown'].__setitem__('name',True),
            lambda p: managed(p,'aws_iam_role_policy_attachment.analysis_runtime')['change']['after'].__setitem__('role','other'),
            lambda p: managed(p,'aws_iam_role_policy.history_analysis[0]')['change']['after'].__setitem__('policy','{}'),
            lambda p: managed(p,'aws_iam_role_policy.research_migration_boundary["analysis"]')['change']['after'].__setitem__('policy','{}'),
            lambda p: p['resource_drift'].append(copy.deepcopy(role_row(p))),
            lambda p: p['configuration']['root_module']['resources'][-2]['expressions'].__setitem__('inline_policy',{'constant_value':[]}),
            lambda p: p['configuration']['root_module']['resources'][-1]['expressions'].__setitem__('role',{'references':['other']}),
        ]
        for index,mutate in enumerate(mutations):
            with self.subTest(index=index):
                plan=self.post_role_plan();mutate(plan)
                with self.assertRaises(ValueError):MODULE.review(plan,REVISION,bounded=True,post_apply=True)

    def stage_readback_plan(self):
        plan = fixture()
        api = {'id': 'example1234', 'name': 'trustcheckradar-dev-age-attestation-api',
               'protocol_type': 'HTTP', 'arn': 'arn:aws:apigateway:us-east-1::/apis/example1234'}
        stage = {'api_id': api['id'], 'name': '$default', 'auto_deploy': True,
                 'deployment_id': 'new123', 'arn': api['arn'] + '/stages/$default',
                 'default_route_settings': [{'throttling_rate_limit': 10}]}
        for address, value in [('aws_apigatewayv2_api.age_attestation', api), ('aws_apigatewayv2_stage.age_attestation', stage)]:
            plan['resource_changes'].append({'address': address, 'mode': 'managed',
                'provider_name': 'registry.terraform.io/hashicorp/aws', 'change': {
                    'actions': ['no-op'], 'before': copy.deepcopy(value), 'after': copy.deepcopy(value), 'after_unknown': {}}})
        old = dict(stage, deployment_id='old123')
        plan['resource_drift'] = [{'address': 'aws_apigatewayv2_stage.age_attestation', 'mode': 'managed',
            'provider_name': 'registry.terraform.io/hashicorp/aws', 'change': {
                'actions': ['update'], 'before': old, 'after': copy.deepcopy(stage), 'after_unknown': {}}}]
        plan['configuration']['root_module']['resources'].append({'address': 'aws_apigatewayv2_stage.age_attestation',
            'expressions': {'auto_deploy': {'constant_value': True},
                'api_id': {'references': ['aws_apigatewayv2_api.age_attestation.id']}}})
        return plan

    def test_only_verified_service_managed_stage_pointer_readback_is_accepted(self):
        plan = self.stage_readback_plan()
        report = MODULE.review(plan, REVISION, bounded=True)
        self.assertEqual(report['verifiedAutomaticStageReadbacks'], 1)
        self.assertEqual(len(report['changes']), 5)
        changed = copy.deepcopy(plan)
        changed['resource_drift'][0]['change']['before']['deployment_id'] = 'other123'
        self.assertNotEqual(report['reviewedPlanDigest'], MODULE.review(changed, REVISION, bounded=True)['reviewedPlanDigest'])

    def test_stage_readback_rejects_configuration_identity_and_unbound_drift(self):
        mutations = [
            lambda p: p['resource_drift'][0].__setitem__('provider_name', 'other'),
            lambda p: p['resource_drift'][0].__setitem__('address', 'aws_apigatewayv2_stage.other'),
            lambda p: p['resource_drift'][0]['change'].__setitem__('actions', ['delete']),
            lambda p: p['resource_drift'][0]['change']['after'].__setitem__('auto_deploy', False),
            lambda p: p['resource_drift'][0]['change']['after'].__setitem__('name', 'prod'),
            lambda p: p['resource_drift'][0]['change']['after'].__setitem__('deployment_id', None),
            lambda p: p['resource_drift'][0]['change']['after'].__setitem__('default_route_settings', []),
            lambda p: p['resource_drift'][0]['change'].__setitem__('after_unknown', {'deployment_id': True}),
            lambda p: p['resource_changes'][-1]['change'].__setitem__('actions', ['update']),
            lambda p: p['resource_changes'][-1]['change']['after_unknown'].__setitem__('api_id', True),
            lambda p: p['resource_changes'][-2]['change'].__setitem__('actions', ['update']),
            lambda p: p['resource_changes'][-2]['change']['after'].__setitem__('name', 'production-api'),
            lambda p: p['resource_changes'].pop(-2),
            lambda p: p['configuration']['root_module']['resources'].pop(),
            lambda p: p['configuration']['root_module']['resources'][-1]['expressions'].__setitem__('deployment_id', {'constant_value': 'new123'}),
            lambda p: p['resource_drift'].append(copy.deepcopy(p['resource_drift'][0])),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                plan = self.stage_readback_plan()
                mutate(plan)
                with self.assertRaises(ValueError):
                    MODULE.review(plan, REVISION, bounded=True)

    def rejected(self, mutate):
        plan = fixture()
        mutate(plan)
        with self.assertRaises(ValueError):
            MODULE.review(plan, REVISION, bounded=True)

    def test_diagnostics_use_only_static_check_labels(self):
        tree = ast.parse(Path(MODULE.__file__).read_text())
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == 'require':
                self.assertIsInstance(node.args[1], ast.Constant)
                self.assertIsInstance(node.args[1].value, str)
        with self.assertRaises(MODULE.ReviewRejected) as caught:
            MODULE.require(False, 'Managed drift requires review')
        self.assertIn('Managed drift requires review', MODULE.safe_failure_message(caught.exception))
        for error in [ValueError('private-plan-value'), RuntimeError('private-sdk-value')]:
            self.assertNotIn('private', MODULE.safe_failure_message(error))

    def test_drift_diagnostics_redact_all_plan_values_and_unknown_labels(self):
        plan = fixture()
        plan['resource_drift'] = [
            {'mode': 'managed', 'address': 'aws_iam_role.analysis', 'change': {
                'before': {'inline_policy': 'private-old'}, 'after': {'inline_policy': 'private-new'}}},
            {'mode': 'managed', 'address': 'private-resource', 'change': {
                'before': {'private-field': 'private-old'}, 'after': {'private-field': 'private-new'}}},
        ]
        report = MODULE.safe_drift_summary(plan)
        self.assertEqual(report, {'managedDrift': [
            {'resource': 'analysis role', 'fields': ['inline_policy'], 'otherFieldCount': 0},
            {'resource': 'other managed resource', 'fields': [], 'otherFieldCount': 1}]})
        self.assertNotIn('private', json.dumps(report))
        with self.assertRaises(MODULE.ReviewRejected):
            MODULE.review(plan, REVISION, bounded=True)

    def test_diagnostic_catalog_has_only_source_names_and_provider_fields(self):
        catalog = json.loads((MODULE.ROOT / 'scripts/analysis-retirement-diagnostic-catalog.json').read_text())
        names = set()
        for source in (MODULE.ROOT / 'terraform/api').glob('*.tf'):
            names.update(a + '.' + b for a, b in re.findall(r'resource "([^"]+)" "([^"]+)"', source.read_text()))
        self.assertEqual(set(catalog['resources']), names)
        self.assertTrue(all(re.fullmatch(r'[a-z][a-z0-9_]*', field) for field in catalog['fields']))
        plan = {'resource_drift': [{'mode': 'managed', 'address': 'aws_apigatewayv2_stage.age_attestation["private-index"]',
            'change': {'before': {'deployment_id': 'private-old'}, 'after': {'deployment_id': 'private-new'}}}]}
        report = MODULE.safe_drift_summary(plan)
        self.assertEqual(report, {'managedDrift': [{'resource': 'aws_apigatewayv2_stage.age_attestation',
            'fields': ['deployment_id'], 'otherFieldCount': 0}]})
        self.assertNotIn('private', json.dumps(report))

    def test_bounded_transition_and_digest(self):
        report = MODULE.review(fixture(), REVISION, bounded=True)
        self.assertEqual(len(report['changes']), 5)
        MODULE.authorize(report, report['reviewedPlanDigest'], True)
        with self.assertRaises(ValueError):
            MODULE.authorize(report, 'wrong', True)
        with self.assertRaises(ValueError):
            MODULE.authorize(report, None, True)

    def test_version_and_hash_are_exact(self):
        for key, value in [('object_version', 'other'), ('source_hash', 'A'*43+'='), ('release_id', '2'*40)]:
            with self.subTest(key=key):
                self.rejected(lambda p: p['variables']['analysis_retirement_deployment']['value'].__setitem__(key, value))

    def test_dev_catalog_cannot_be_used_elsewhere(self):
        for env in ['uat', 'prod']:
            with self.subTest(env=env):
                self.rejected(lambda p: p['variables']['environment'].__setitem__('value', env))

    def test_other_capability_or_drift_rejected(self):
        self.rejected(lambda p: p['resource_changes'].append({'address': 'aws_lambda_function.account_data[0]', 'mode': 'managed', 'change': {'actions': ['update'], 'before': {}, 'after': {}}}))
        self.rejected(lambda p: p['resource_drift'].append({'address': 'aws_lambda_function.analysis', 'mode': 'managed'}))

    def test_omitted_or_noop_transition_is_not_acceptance(self):
        self.rejected(lambda p: p['resource_changes'].pop(1))
        self.rejected(lambda p: p['resource_changes'][1]['change'].__setitem__('actions', ['no-op']))

    def test_function_role_and_unknown_network_changes_rejected(self):
        self.rejected(lambda p: p['resource_changes'][0]['change']['after'].__setitem__('role', 'changed-role'))
        self.rejected(lambda p: p['resource_changes'][0]['change']['after_unknown'].__setitem__('vpc_config', True))

    def test_env_cannot_reactivate_provider_or_work(self):
        for key in ['OPENAI_SECRET_ARN', 'FREE_MONTHLY_SCAN_LIMIT', 'CAMPAIGN_PERIOD_WORK_ENABLED']:
            with self.subTest(key=key):
                self.rejected(lambda p: p['resource_changes'][0]['change']['after']['environment'][0]['variables'].__setitem__(key, 'true'))

    def test_runtime_policy_cannot_broaden(self):
        self.rejected(lambda p: p['resource_changes'][1]['change']['after'].__setitem__('policy', json.dumps({'Version': '2012-10-17', 'Statement': [{'Effect': 'Allow', 'Action': '*', 'Resource': '*'}]})))

    def test_alias_cannot_use_latest_weighted_or_wrong_reference(self):
        self.rejected(lambda p: p['resource_changes'][2]['change']['after'].__setitem__('function_version', '$LATEST'))
        self.rejected(lambda p: p['resource_changes'][2]['change']['after'].__setitem__('routing_config', [{'additional_version_weights': {'3': 0.1}}]))
        self.rejected(lambda p: p['configuration']['root_module']['resources'][0]['expressions']['function_version'].__setitem__('references', ['var.unsafe_version']))

    def test_integration_cannot_point_to_latest(self):
        self.rejected(lambda p: p['resource_changes'][3]['change']['after'].__setitem__('integration_uri', 'unqualified'))

    def test_permission_cannot_broaden_or_activate_legacy(self):
        for key, value in [('qualifier', None), ('source_account', '999999999999'), ('source_arn', 'arn:aws:execute-api:us-east-1:107827791950:example1234/*/*')]:
            with self.subTest(key=key):
                self.rejected(lambda p: p['resource_changes'][4]['change']['after'].__setitem__(key, value))
        self.rejected(lambda p: p['variables']['analysis_legacy_path_enabled'].__setitem__('value', True))

    def test_ordinary_deploy_cannot_bypass_reviewed_transition(self):
        plan = fixture()
        with self.assertRaises(ValueError):
            MODULE.ordinary_guard(plan)
        for row in plan['resource_changes']:
            row['change']['actions'] = ['no-op']
        MODULE.ordinary_guard(plan)

    def test_old_unqualified_permission_must_be_removed(self):
        self.rejected(lambda p: p['resource_changes'][4]['change'].update(actions=['create'], before=None))

    def test_post_apply_checks_active_shapes_even_when_noop(self):
        plan = self.stage_readback_plan()
        for row in plan['resource_changes']:
            row['change']['actions'] = ['no-op']
            row['change']['before'] = copy.deepcopy(row['change']['after'])
        plan['resource_changes'][0]['change']['after']['code_sha256'] = SHA
        plan['resource_changes'][0]['change']['before']['code_sha256'] = SHA
        plan['resource_changes'][2]['change']['after']['function_version'] = '4'
        plan['resource_changes'][2]['change']['before']['function_version'] = '4'
        report = MODULE.review(plan, REVISION, bounded=True, post_apply=True)
        self.assertEqual(report['verifiedAutomaticStageReadbacks'], 1)
        for mutate in [
            lambda p: p['resource_changes'][1]['change']['after'].__setitem__('policy', '{}'),
            lambda p: p['resource_changes'][2]['change']['after'].__setitem__('routing_config', [{'additional_version_weights': {'2': .1}}]),
            lambda p: p['resource_changes'][3]['change']['after'].__setitem__('integration_uri', 'unqualified'),
            lambda p: p['resource_changes'][4]['change']['after'].__setitem__('qualifier', None),
            lambda p: p['resource_changes'][0]['change']['after'].__setitem__('code_sha256', 'wrong'),
        ]:
            with self.subTest(mutate=mutate):
                bad = copy.deepcopy(plan)
                mutate(bad)
                # Simulate refreshed no-op state, so changed-fields cannot alone catch it.
                for row in bad['resource_changes']:
                    row['change']['before'] = copy.deepcopy(row['change']['after'])
                with self.assertRaises((ValueError, KeyError)):
                    MODULE.review(bad, REVISION, bounded=True, post_apply=True)

    def test_archive_bytes_and_version_verified(self):
        data = b'synthetic-qualified-archive'
        artifact = {'bucket': 'synthetic', 'key': 'synthetic', 'version': 'v1', 'source_hash': base64.b64encode(hashlib.sha256(data).digest()).decode()}
        def download(value, path):
            path.write_bytes(data)
            return {'VersionId': 'v1'}
        MODULE.verify_archive(artifact, download)
        with self.assertRaises(ValueError):
            MODULE.verify_archive(dict(artifact, source_hash='A'*43+'='), download)
        with self.assertRaises(ValueError):
            MODULE.verify_archive(dict(artifact, version='v2'), download)


if __name__ == '__main__':
    unittest.main()
