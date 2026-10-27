"""Pure configuration/ZIP/compiler guards; not provider or cloud acceptance."""
import copy
import base64
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import message_ai_configuration as a
import prepare_preserved_deployment as p
import verify_preserved_deployment as v
import test_preserved_deployment as fixtures


def inactive():
    return {'message_ai_primary_enabled': False, 'candidate3_rules_only_enabled': None,
            'ai_configuration': None, 'provider_budget': None}


def active():
    return {'message_ai_primary_enabled': True, 'candidate3_rules_only_enabled': False,
        'provider_budget': {'window_seconds': 86400, 'max_attempts_per_window': 10, 'max_failures_per_window': 3},
        'ai_configuration': {'secret_arn': 'arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/openai-ABC123',
            'qualification_id': 'unit-only-not-real-qualification', 'qualification_evidence_sha256': hashlib.sha256(b'unit-only').hexdigest(),
            'timeout_ms': 8000, 'max_nano_usd_per_window': 5000000000,
            'cost_policy': {'model': 'fixture-model-2026-01-01', 'contextTokens': 400000, 'maxOutputTokens': 512,
                            'inputNanoUsdPerToken': 750, 'outputNanoUsdPerToken': 4500}}}


def consumer_policy():
    return {'Version': '2012-10-17', 'Statement': [
        {'Sid': 'UnrelatedExistingBoundary', 'Effect': 'Deny', 'Action': 's3:*', 'Resource': '*'},
        {'Sid': 'MessageProviderBudget', 'Effect': 'Allow', 'Action': ['dynamodb:UpdateItem'],
         'Resource': 'arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements',
         'Condition': {'ForAllValues:StringEquals': {'dynamodb:LeadingKeys': ['V1#CONTROL'],
            'dynamodb:Attributes': ['PK','SK','recordType','revision','windowStart','attempts','failures']},
            'ForAnyValue:StringEquals': {'dynamodb:EnclosingOperation': ['TransactWriteItems']}}}]}


def qualification_zip(config):
    """Minimal static source fixture. It is not a deployable/qualified package."""
    span = {'type': 'object', 'properties': {'start': {'type': 'integer'}}}
    schema = {'type': 'object', 'enum': ['REASON'], 'items': span}
    contents = {
        'message_evaluator/ai_provider.py': "INSTRUCTIONS='unit prompt'\nSCHEMA={'type':'object','enum':sorted(AI_REASONS),'items':proposer.SCHEMA['properties']['spans']['items']}\n",
        'message_evaluator/proposer.py': 'SCHEMA=' + repr({'properties': {'spans': {'items': span}}}),
        'shared_message_contract/validation_v2.py': "AI_REASONS={'REASON'}\n",
        'message_evaluator/ai_contract/outcome.json': '{}',
        'message_evaluator/qualifications/unit-only-not-real-qualification.json': 'unit-only',
    }
    manifest = hashlib.sha256(b'{}').hexdigest() + '  outcome.json\n'
    contents['message_evaluator/ai_contract/SHA256SUMS'] = manifest
    record = {'model': config['cost_policy']['model'], 'policyVersion': a.POLICY,
        'promptSha256': hashlib.sha256(b'unit prompt').hexdigest(),
        'schemaSha256': hashlib.sha256(json.dumps(schema,sort_keys=True,separators=(',',':')).encode()).hexdigest(),
        'contractSha256': hashlib.sha256(manifest.encode()).hexdigest(),
        'evidenceSha256': config['qualification_evidence_sha256'], 'costPolicy': config['cost_policy'], 'status':'approved'}
    contents['message_evaluator/ai_qualifications.json'] = json.dumps({config['qualification_id']:record})
    return contents


def alarm_rows():
    """Closed fixture matching the existing operations.tf native alarms."""
    rows=[]
    topic='arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts'
    for name,timeout in [('consumer',29),('evaluator',23)]:
        function='trustcheckradar-dev-message-'+name
        for suffix,metric,statistic,threshold in [('errors','Errors','Sum',1),('throttles','Throttles','Sum',1),('duration','Duration','Maximum',(timeout-3)*1000)]:
            value={'alarm_name':function+'-'+suffix,'namespace':'AWS/Lambda','metric_name':metric,
                'dimensions':{'FunctionName':function},'statistic':statistic,'period':300,'evaluation_periods':1,
                'datapoints_to_alarm':1,'threshold':threshold,'comparison_operator':'GreaterThanOrEqualToThreshold',
                'treat_missing_data':'notBreaching','alarm_actions':[topic],'ok_actions':[topic],'actions_enabled':True}
            rows.append({'address':f'aws_cloudwatch_metric_alarm.runtime["{name}-{suffix}"]','mode':'managed',
                'provider_name':'registry.terraform.io/hashicorp/aws','change':{'actions':['no-op'],'before':copy.deepcopy(value),'after':value}})
    return rows


def cloudwatch_alarms(rows):
    mapping={'alarm_name':'AlarmName','namespace':'Namespace','metric_name':'MetricName','statistic':'Statistic',
        'period':'Period','evaluation_periods':'EvaluationPeriods','datapoints_to_alarm':'DatapointsToAlarm',
        'threshold':'Threshold','comparison_operator':'ComparisonOperator','treat_missing_data':'TreatMissingData',
        'alarm_actions':'AlarmActions','ok_actions':'OKActions','actions_enabled':'ActionsEnabled'}
    result=[]
    for row in rows:
        value=row['change']['before'];alarm={out:copy.deepcopy(value[key]) for key,out in mapping.items()}
        alarm['Dimensions']=[{'Name':k,'Value':v} for k,v in value['dimensions'].items()]
        result.append(alarm)
    return result


def log_rows():
    rows=[]
    for name in ('consumer','evaluator'):
        value={'name':'/aws/lambda/trustcheckradar-dev-message-'+name,'retention_in_days':30,'kms_key_id':None}
        rows.append({'address':f'aws_cloudwatch_log_group.runtime["{name}"]','mode':'managed',
            'provider_name':'registry.terraform.io/hashicorp/aws',
            'change':{'actions':['no-op'],'before':copy.deepcopy(value),'after':value}})
    return rows


def monitoring_read(rows, alarms=None):
    def read(service, operation, *args):
        if service=='cloudwatch':
            return {'MetricAlarms':[] if alarms is None else alarms,'CompositeAlarms':[]}
        name=args[args.index('--log-group-name-prefix')+1]
        value=next(r['change']['before'] for r in rows if r['change']['before']['name']==name)
        return {'logGroups':[{'logGroupName':name,'retentionInDays':value['retention_in_days']}]}
    return read


class ConfigurationTests(unittest.TestCase):
    def test_normal_publisher_metadata_requires_exact_byte_verification(self):
        sha=hashlib.sha256(b'unit artifact').hexdigest()
        encoded=base64.b64encode(bytes.fromhex(sha)).decode()
        self.assertEqual(p.published_source_hash({'Metadata':{'sha256':sha}}),encoded)
        self.assertEqual(p.published_source_hash({'Metadata':{'sha256':sha},'ChecksumSHA256':encoded}),encoded)
        for head in ({},{'Metadata':{'sha256':'bad'}},{'Metadata':{'sha256':sha},'ChecksumSHA256':'different'}):
            with self.subTest(head=head),self.assertRaises(ValueError):p.published_source_hash(head)

    def test_dispatch_modes_are_mutually_exclusive(self):
        text=(Path(__file__).resolve().parents[2]/'.github/workflows/deploy.yml').read_text()
        import re
        def condition(job):
            section=text.split('\n  '+job+':\n',1)[1]
            return re.search(r'^    if: (.+)$',section,re.M).group(1)
        legacy=condition('message-consumer');normal=condition('preserved-dev')
        self.assertNotIn('startsWith(inputs.deployment_scope',legacy)
        scopes=lambda expression:set(re.findall(r"inputs.deployment_scope == '([^']+)'",expression))
        self.assertEqual(scopes(legacy),{'message-consumer','message-consumer-engineering'})
        self.assertEqual(scopes(normal),{'message-consumer-ai','message-consumer-preserve-history','authority-maintenance'})
        self.assertFalse(scopes(legacy)&scopes(normal))
        for expression in (legacy,normal):
            self.assertIn("github.ref == 'refs/heads/main'",expression)
            self.assertIn("inputs.environment == 'dev'",expression)
            self.assertIn("github.event_name == 'workflow_dispatch'",expression)

    def test_inactive_preserves_profile_and_circuit(self):
        for flag, circuit in [('false','false'),('true','true')]:
            before={'MESSAGE_AI_ENABLED':'false','MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED':flag,
                    'MESSAGE_PROVIDER_CIRCUIT_OPEN':circuit,'IDENTITY_FENCE':'unchanged'}
            self.assertEqual(a.environment(before,'consumer',inactive()),before)

    def test_invalid_configuration_has_no_defaults(self):
        for field,value in [('secret_arn','arn:foreign'),('timeout_ms',8001),('max_nano_usd_per_window',1)]:
            desired=active();desired['ai_configuration'][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):a.validate(desired)
        desired=active();desired['ai_configuration']['cost_policy']['model']='mutable-alias'
        with self.assertRaises(ValueError):a.validate(desired)
        desired=active();desired['candidate3_rules_only_enabled']=True
        with self.assertRaises(ValueError):a.validate(desired)

    def test_exact_currency_and_secret_delta(self):
        old=consumer_policy();dep=fixtures.message_fixture.f.fixture('engineering')['variables']['deployment']['value']
        evaluator=fixtures.message_fixture.v.evaluator_policy(dep,True)
        left,right=a.policies(old,evaluator,dep['authority_table_arn'],dep['assessment_alias_arn'],True,active()['ai_configuration']['secret_arn'])
        self.assertEqual(left['Statement'][0],old['Statement'][0])
        self.assertEqual(right['Statement'][1],evaluator['Statement'][1])
        self.assertEqual(len(right['Statement']),7)
        self.assertEqual(a.policies(left,right,dep['authority_table_arn'],dep['assessment_alias_arn'],False),(old,evaluator))

    def test_archive_checks_exact_schema_dependencies_contract_and_evidence(self):
        desired=active();original=qualification_zip(desired['ai_configuration'])
        mutations=[None,('message_evaluator/ai_provider.py',"INSTRUCTIONS='changed'\nSCHEMA={}\n"),
            ('message_evaluator/proposer.py',"SCHEMA={'properties':{'spans':{'items':{}}}}"),
            ('message_evaluator/ai_contract/outcome.json','changed'),
            ('message_evaluator/qualifications/unit-only-not-real-qualification.json','changed'),
            ('message_evaluator/ai_qualifications.json','{}'),('../unsafe','x')]
        for mutation in mutations:
            contents=copy.deepcopy(original)
            if mutation:contents[mutation[0]]=mutation[1]
            with self.subTest(mutation=mutation),tempfile.TemporaryDirectory() as directory:
                path=Path(directory)/'package.zip'
                with zipfile.ZipFile(path,'w') as output:
                    for name,data in contents.items():output.writestr(name,data)
                if mutation:
                    with self.assertRaises(ValueError):a.archive('evaluator',path,desired)
                else:a.archive('evaluator',path,desired)


class NormalPlanTests(unittest.TestCase):
    def setUp(self):
        self.scope=p.SCOPE_SHA;self.rules_scope=p.RULES_SCOPE_SHA
        p.SCOPE_SHA=p.digest(fixtures.SYNTHETIC);p.RULES_SCOPE_SHA=p.digest(fixtures.SYNTHETIC)

    def tearDown(self):
        p.SCOPE_SHA=self.scope;p.RULES_SCOPE_SHA=self.rules_scope

    def plan(self):
        final,baseline,captured,targets=fixtures.message()
        for plan in (final,baseline):
            plan['resource_changes'].extend(log_rows())
            plan['variables'].update({k:{'value':val} for k,val in {
                'message_ai_primary_enabled':False,'ai_configuration':None,'url_assessment_enabled':False}.items()})
            value={'name':'fenced-message-authority-and-private-evaluator','role':'trustcheckradar-dev-message-consumer-execution',
                   'policy':json.dumps(consumer_policy())}
            plan['resource_changes'].append({'address':'aws_iam_role_policy.consumer[0]','mode':'managed',
                'provider_name':'registry.terraform.io/hashicorp/aws','change':{'actions':['no-op'],'before':copy.deepcopy(value),'after':copy.deepcopy(value)}})
        captured['policies']={n:p.digest(json.loads(p.inventory(baseline)[f'aws_iam_role_policy.{n}[0]']['change']['before']['policy'])) for n in ('consumer','evaluator')}
        captured['monitoring']={name:p.digest(value) for name,value in p.message_monitoring(p.inventory(baseline)).items()}
        for k,val in p.build(baseline,captured,'message-ai',targets,inactive()).items():final['variables'][k]={'value':val}
        final['output_changes']['candidate_contract']['after'].update(ai_primary_enabled=False,url_assessment_enabled=False,daily_reporting_ready=False)
        fixtures.sync(baseline);fixtures.sync(final)
        return final,baseline,captured,targets

    def test_default_off_plan_preserves_existing_profile(self):
        plan,base,captured,targets=self.plan()
        result,_=v.review(plan,base,captured,fixtures.REVISION,'message-ai',targets,inactive())
        self.assertFalse(result['providerCallsEnabled'])
        self.assertEqual(result['resourceUpdates'],4)

    def test_environment_policy_scope_and_apply_inventory_drift_rejected(self):
        for mutation in ('environment','policy','subject','resource'):
            plan,base,captured,targets=self.plan();rows=p.inventory(plan)
            if mutation=='environment':p.environment(rows['aws_lambda_function.runtime["consumer"]']['change']['after'])['AUTHORITY_ENABLED']='false'
            if mutation=='policy':rows['aws_iam_role_policy.consumer[0]']['change']['after']['policy']='{}';rows['aws_iam_role_policy.consumer[0]']['change']['actions']=['update']
            if mutation=='subject':plan['variables']['engineering_subjects']['value']=['01997e3a-0000-7000-8000-000000000003']
            if mutation=='resource':plan['resource_changes'][0]['change']['actions']=['delete','create']
            fixtures.sync(plan)
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):v.review(plan,base,captured,fixtures.REVISION,'message-ai',targets,inactive())

    def active_plan(self):
        # A pure plan compiler fixture, not actual model qualification or AWS.
        plan,base,captured,targets=self.plan();desired=active();rows=p.inventory(plan)
        for key,value in p.build(base,captured,'message-ai',targets,desired).items():plan['variables'][key]={'value':value}
        for name in ('consumer','evaluator'):
            change=rows[f'aws_lambda_function.runtime["{name}"]']['change']
            change['after']['environment']=[{'variables':a.environment(p.environment(change['before']),name,desired)}]
        dep=plan['variables']['deployment']['value']
        policies=a.policies(*[json.loads(rows[f'aws_iam_role_policy.{n}[0]']['change']['before']['policy']) for n in ('consumer','evaluator')],
            dep['authority_table_arn'],dep['assessment_alias_arn'],True,desired['ai_configuration']['secret_arn'])
        for name,policy in zip(('consumer','evaluator'),policies):
            change=rows[f'aws_iam_role_policy.{name}[0]']['change'];change['actions']=['update'];change['after']['policy']=json.dumps(policy)
        output=plan['output_changes']['candidate_contract']['after']
        output.update({k:True for k in ['ai_enabled','ai_qualified','ai_primary_enabled','model_enabled']})
        output.update(candidate3_rules_only_enabled=False,provider_circuit_open=False,daily_reporting_ready=False)
        fixtures.sync(plan)
        return plan,base,captured,targets,desired

    def test_dev_plan_defers_delivery_without_fabricating_readiness(self):
        plan,base,captured,targets,desired=self.active_plan()
        result,_=v.review(plan,base,captured,fixtures.REVISION,'message-ai',targets,desired)
        self.assertTrue(result['providerCallsEnabled'])
        self.assertEqual(result['resourceUpdates'],6)
        self.assertIs(plan['output_changes']['candidate_contract']['after']['daily_reporting_ready'],False)

    def test_missing_or_untruthful_reporting_state_is_rejected(self):
        for value in (None,True,'false',0):
            plan,base,captured,targets,desired=self.active_plan()
            output=plan['output_changes']['candidate_contract']['after']
            if value is None:output.pop('daily_reporting_ready')
            else:output['daily_reporting_ready']=value
            with self.subTest(value=value),self.assertRaisesRegex(ValueError,'^AI_REPORTING_STATE$'):
                v.review(plan,base,captured,fixtures.REVISION,'message-ai',targets,desired)

    def test_dev_deferral_cannot_expand_environment_or_subject_identity(self):
        for field,value in [('environment','prod'),('environment','uat'),('aws_region','us-west-2'),
            ('engineering_subjects',[fixtures.SYNTHETIC[0],'01997e3a-0000-7000-8000-000000000003'])]:
            plan,base,captured,targets,desired=self.active_plan()
            for source in (plan,base):source['variables'][field]={'value':value}
            if field=='engineering_subjects':
                for source in (plan,base):
                    p.environment(p.inventory(source)['aws_lambda_function.runtime["consumer"]']['change']['before'])['DEV_SUBJECT_ALLOWLIST_JSON']=json.dumps(value)
                captured['functions']['consumer']['environmentSha256']=p.digest(p.environment(p.inventory(base)['aws_lambda_function.runtime["consumer"]']['change']['before']))
            fixtures.sync(plan);fixtures.sync(base)
            with self.subTest(field=field,value=value),self.assertRaises(ValueError):
                v.review(plan,base,captured,fixtures.REVISION,'message-ai',targets,desired)

    def test_unqualified_budget_and_monitoring_cannot_use_delivery_deferral(self):
        for mutation in ('money','output','qualification','capture','missing_log','changed_log','recreated_alarm'):
            plan,base,captured,targets,desired=self.active_plan()
            if mutation=='money':desired['ai_configuration']['max_nano_usd_per_window']=1
            elif mutation=='output':desired['ai_configuration']['cost_policy']['maxOutputTokens']=513
            elif mutation=='qualification':desired['ai_configuration']['qualification_id']=''
            elif mutation=='capture':captured.pop('monitoring')
            elif mutation=='missing_log':
                for source in (plan,base):source['resource_changes']=[r for r in source['resource_changes'] if r['address']!='aws_cloudwatch_log_group.runtime["consumer"]']
            elif mutation=='changed_log':
                for source in (plan,base):
                    row=p.inventory(source)['aws_cloudwatch_log_group.runtime["consumer"]']
                    for side in ('before','after'):row['change'][side]['retention_in_days']=0
            else:
                plan['resource_changes'].extend(alarm_rows())
            fixtures.sync(plan);fixtures.sync(base)
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):
                v.review(plan,base,captured,fixtures.REVISION,'message-ai',targets,desired)

    def test_capture_and_post_readback_require_logs_and_no_dev_alarms(self):
        _,base,_,_=self.plan();rows=p.inventory(base);calls=[];alarms=[]
        history={'State':'Active','Version':'12','CodeSha256':'history-source','Environment':{'Variables':{
            'AUTHORITY_ENABLED':'true','GOVERNED_HISTORY_LIST_ENABLED':'true','GOVERNED_HISTORY_DETAIL_ENABLED':'true',
            'DEV_SUBJECT_ALLOWLIST_JSON':json.dumps(fixtures.SYNTHETIC)}}}
        def read(service,operation,*args):
            if service=='sts':return {'Account':'107827791950'}
            if service=='cloudwatch':calls.append(operation);return {'MetricAlarms':copy.deepcopy(alarms),'CompositeAlarms':[]}
            if service=='logs':return monitoring_read(log_rows())(service,operation,*args)
            self.assertEqual(service,'lambda')
            function=args[args.index('--function-name')+1]
            if function.endswith('governed-history'):
                return {'FunctionVersion':'12'} if operation=='get-alias' else history
            name=function.rsplit('-',1)[1];value=rows[f'aws_lambda_function.runtime["{name}"]']['change']['before']
            if operation=='get-alias':return {'FunctionVersion':value['version']}
            if operation=='get-function-concurrency':return {'ReservedConcurrentExecutions':value['reserved_concurrent_executions']}
            result={out:value[key] for key,out in {'function_name':'FunctionName','runtime':'Runtime','architectures':'Architectures',
                'role':'Role','handler':'Handler','timeout':'Timeout','memory_size':'MemorySize','version':'Version','code_sha256':'CodeSha256'}.items()}
            return result|{'State':'Active','LastUpdateStatus':'Successful','Environment':{'Variables':p.environment(value)}}
        with patch.object(p,'maintenance_readback',return_value=fixtures.maintenance_contract(True)),patch.object(p,'message_policy_readback',return_value={}):
            captured=p.capture(base,'message-ai',read)
            self.assertEqual(len(captured['monitoring']),3)
            v.verify_deployed(base,base,captured,'message-ai',read)
            self.assertEqual(calls,['describe-alarms','describe-alarms'])
            alarms.append(cloudwatch_alarms(alarm_rows())[0])
            with self.assertRaisesRegex(ValueError,'^NONPRODUCTION_ALARMS_STILL_PRESENT_OR_INCOMPLETE$'):
                v.verify_deployed(base,base,captured,'message-ai',read)


class MonitoringTests(unittest.TestCase):
    def test_readback_matches_runtime_logs_and_explicit_alarm_absence(self):
        rows=log_rows();inventory={r['address']:r for r in rows}
        expected={k:p.digest(v) for k,v in p.message_monitoring(inventory).items()}
        self.assertEqual(p.message_monitoring_readback(inventory,monitoring_read(rows)),expected)
        self.assertEqual(len(expected),3)

    def test_legacy_alarm_variants_are_all_rejected_by_absence_policy(self):
        for mutation in ('missing','duplicate','disabled','destination','dimensions','threshold','bool_period','bool_datapoints','unit','expression'):
            rows=log_rows();alarms=cloudwatch_alarms(alarm_rows())
            if mutation=='missing':alarms.pop()
            elif mutation=='duplicate':alarms[-1]=copy.deepcopy(alarms[0])
            elif mutation=='disabled':alarms[0]['ActionsEnabled']=False
            elif mutation=='destination':alarms[0]['AlarmActions']=['other']
            elif mutation=='dimensions':alarms[0]['Dimensions'].append({'Name':'Account','Value':'unexpected'})
            elif mutation=='threshold':alarms[0]['Threshold']=99
            elif mutation=='bool_period':alarms[0]['EvaluationPeriods']=True
            elif mutation=='bool_datapoints':alarms[0]['DatapointsToAlarm']=True
            elif mutation=='unit':alarms[0]['Unit']='Seconds'
            else:alarms[0]['Metrics']=[{}]
            with self.subTest(mutation=mutation),self.assertRaisesRegex(ValueError,'^NONPRODUCTION_ALARMS_STILL_PRESENT_OR_INCOMPLETE$'):
                p.message_monitoring_readback({r['address']:r for r in rows},monitoring_read(rows,alarms))

    def test_plan_alarm_unit_filter_cannot_bypass_absence_policy(self):
        for unit in ('Seconds','None',False,0,None,''):
            rows=log_rows()+alarm_rows();rows[-1]['change']['before']['unit']=unit
            with self.subTest(unit=unit),self.assertRaisesRegex(ValueError,'^NONPRODUCTION_ALARM_MIGRATION_REQUIRED$'):
                p.message_monitoring({r['address']:r for r in rows})
