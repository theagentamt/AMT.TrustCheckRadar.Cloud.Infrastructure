import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('research_release',Path(__file__).resolve().parents[1]/'verify_research_release.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
REVISION='a'*40
SOURCE='b'*40


def fixture(stack):
    contents={function: ('synthetic-'+function).encode() for function in set(module.API.values())|set(module.CAMPAIGN.values())}
    manifest={'scope':'research_candidate','environment':'dev','publicationComplete':True,'runtimeUpdated':False,'activationApproved':False,
              'sourceSha':SOURCE,'artifacts':[{'function':name,'artifact':name+'.zip','bucket':module.BUCKET,
                'key':f'releases/{SOURCE}/{name}.zip','versionId':'version-'+name,'sourceCodeHash':base64.b64encode(hashlib.sha256(data).digest()).decode(),
                'sha256':hashlib.sha256(data).hexdigest(),'runtime':'python3.14','architecture':'arm64','handler':'app.lambda_handler'} for name,data in sorted(contents.items())]}
    mapping=module.CAMPAIGN if stack=='campaign-processing' else module.API
    rows={r['function']:r for r in manifest['artifacts']}
    selection={'release_id':SOURCE,'approval_reference':'reviewed-maintenance','promotion_approved':False,
               'workers' if stack=='campaign-processing' else 'artifacts':{k:{'object_version':rows[f]['versionId'],'source_hash':rows[f]['sourceCodeHash']} for k,f in mapping.items()}}
    values={'environment':'dev','project_name':'trustcheckradar','aws_region':module.REGION}
    if stack=='campaign-processing':
        values.update(reserved_concurrency=0,research_consent_migration=True,kill_switch_enabled=True,campaign_processing_enabled=True,account_privacy_artifacts=selection,publisher_fence_artifact=None,deletion_bridge_artifact=None)
    else:
        selection['consent_enabled']=False
        values.update({name+'_lambda_reserved_concurrency':0 for name in ('analysis','campaign_participation','entitlement_snapshot','web_risk_communication','purchase_handoff')})
        values.update(research_consent_migration_deployment=selection,history_features={'writes':False,'recognition':False,'durable_replay':False},enable_web_risk_communication=True,campaign_participation_fence_deployment=None,purchase_handoff_fence_deployment=None)
    resources=[]
    def resource(address,before,after,actions=None):
        resources.append({'mode':'managed','address':address,'change':{'actions':actions or ['update'],'before':before,'after':after,'after_unknown':{}}})
    for worker,function in mapping.items():
        artifact=rows[function];name=module.PREFIX+function.replace('_','-')
        env={'UNCHANGED_PRIVATE':'DO-NOT-PRINT'}
        before={'function_name':name,'arn':f'arn:aws:lambda:{module.REGION}:{module.ACCOUNT}:function:{name}',
                'role':f'arn:aws:iam::{module.ACCOUNT}:role/{name}-role','runtime':'python3.13','handler':'app.lambda_handler','architectures':['arm64'],
                's3_bucket':module.BUCKET,'s3_key':'releases/old/'+function+'.zip','s3_object_version':'old','source_code_hash':None,
                'reserved_concurrent_executions':0,'environment':[{'variables':dict(env)}]}
        if stack=='campaign-processing':
            env.update(module.LOCATOR_ENV)
            if worker=='lifecycle':env['CAMPAIGN_LIFECYCLE_CANDIDATE_ENABLED']='false'
            if worker in {'publisher','cluster'}:env.update(module.COMMON_ENV)
        elif worker=='analysis':env.update(module.ANALYSIS_ENV,COGNITO_ISSUER='https://cognito-idp.us-east-1.amazonaws.com/us-east-1_example',COGNITO_APP_CLIENT_ID='client123')
        elif worker=='participation':env.update({k:v for k,v in module.COMMON_ENV.items() if k.startswith('CAMPAIGN_')},CONSENT_INDEPENDENCE_ENABLED='false')
        elif worker=='purchase':env.update(DELETION_LEDGER_TABLE_NAME=module.PREFIX+'deletion-ledger',PURCHASE_OWNERSHIP_CANDIDATE_ENABLED='false')
        after=before|{'runtime':'python3.14','s3_key':artifact['key'],'s3_object_version':artifact['versionId'],'source_code_hash':artifact['sourceCodeHash'],
                      'reserved_concurrent_executions':0,'environment':[{'variables':env}]}
        address=f'aws_lambda_function.worker["{worker}"]' if stack=='campaign-processing' else module.API_ADDRESSES[worker]
        resource(address,before,after)
    if stack=='campaign-processing':
        for key in ('publisher','cluster','deletion'):
            resource(f'aws_lambda_event_source_mapping.{key}[0]',{'enabled':True,'function_name':'same'},{'enabled':False,'function_name':'same'})
        for key in ('expire_transient','finalize_periods','manage_keys'):
            resource(f'aws_scheduler_schedule.lifecycle["{key}"]',{'state':'ENABLED','target':['same']},{'state':'DISABLED','target':['same']})
        for key in (*module.CAMPAIGN,'scheduler'):
            address=f'aws_iam_role_policy.{key}_runtime[0]' if key!='scheduler' else 'aws_iam_role_policy.scheduler_invoke[0]'
            resource(address,{'policy':'old-private-policy','role':'same'},{'policy':'new-private-policy','role':'same'})
    else:
        for key,function in module.API.items():
            resource(f'aws_iam_role_policy.research_migration_boundary["{key}"]',None,
                     {'name':module.PREFIX+'research-migration-'+key,'role':module.PREFIX+function.replace('_','-')+'-role','policy':'{"Statement":[]}'},['create'])
        resource('terraform_data.research_migration_cutover[0]',None,{'input':SOURCE},['create'])
    return {'complete':True,'terraform_version':'1.12.1','variables':{k:{'value':v} for k,v in values.items()},'resource_changes':resources},manifest,contents


def at(plan,prefix):
    return next(r for r in plan['resource_changes'] if r['address'].startswith(prefix))['change']


class ResearchReleaseTests(unittest.TestCase):
    def test_two_stages_exact_pins_and_minimized_output(self):
        for stack,count in [('campaign-processing',4),('api',5)]:
            with self.subTest(stack=stack):
                plan,manifest,_=fixture(stack)
                result=module.review(plan,REVISION,stack,manifest)
                self.assertEqual(len(result['artifacts']),count)
                self.assertFalse(result['consentEnabled']);self.assertFalse(result['campaignConsumersEnabled'])
                self.assertNotIn('DO-NOT-PRINT',json.dumps(result));self.assertNotIn('new-private-policy',json.dumps(result))
                module.authorize_digest(result,result['reviewedPlanDigest'],True)
                for expected in (None,'c'*64):
                    with self.assertRaises(ValueError):module.authorize_digest(result,expected,True)

    def test_digest_ignores_discovery_session_and_order_but_binds_managed_plan(self):
        plan,manifest,_=fixture('campaign-processing')
        original=module.review(plan,REVISION,'campaign-processing',manifest)['reviewedPlanDigest']
        plan['resource_changes'].append({'mode':'data','address':'data.aws_caller_identity.current','change':{'after':{'arn':'session-private'}}})
        plan['timestamp']='different';plan['resource_changes'].reverse()
        self.assertEqual(original,module.review(plan,REVISION,'campaign-processing',manifest)['reviewedPlanDigest'])
        at(plan,'aws_iam_role_policy.cluster')['after']['policy']='changed-private-policy'
        self.assertNotEqual(original,module.review(plan,REVISION,'campaign-processing',manifest)['reviewedPlanDigest'])
        self.assertNotEqual(original,module.review(plan,'c'*40,'campaign-processing',manifest)['reviewedPlanDigest'])

    def test_wrong_identity_selection_and_immutable_pin_fail(self):
        for stack in ('campaign-processing','api'):
            plan,manifest,_=fixture(stack)
            for key,value in [('environment','prod'),('aws_region','us-west-2'),('project_name','other')]:
                altered=copy.deepcopy(plan);altered['variables'][key]['value']=value
                with self.subTest(stack=stack,key=key),self.assertRaises(ValueError):module.review(altered,REVISION,stack,manifest)
            for field,value in [('s3_bucket','other'),('s3_key','wrong'),('s3_object_version','wrong'),('source_code_hash','A'*43+'='),('runtime','python3.13'),('architectures',['x86_64']),('handler','other.handler'),('arn','arn:aws:lambda:us-east-1:999999999999:function:other'),('reserved_concurrent_executions',100)]:
                altered=copy.deepcopy(plan);at(altered,'aws_lambda_function')['after'][field]=value
                with self.subTest(stack=stack,field=field),self.assertRaises(ValueError):module.review(altered,REVISION,stack,manifest)

    def test_no_deletes_replacements_unknown_addresses_or_unrelated_configuration(self):
        for stack in ('campaign-processing','api'):
            plan,manifest,_=fixture(stack)
            for actions in (['delete'],['delete','create'],['create'],['forget']):
                altered=copy.deepcopy(plan);at(altered,'aws_lambda_function')['actions']=actions
                with self.subTest(actions=actions),self.assertRaises(ValueError):module.review(altered,REVISION,stack,manifest)
            for field in ('timeout','memory_size','role','tags','vpc_config'):
                altered=copy.deepcopy(plan);at(altered,'aws_lambda_function')['after'][field]='changed'
                with self.subTest(field=field),self.assertRaises(ValueError):module.review(altered,REVISION,stack,manifest)
            altered=copy.deepcopy(plan);altered['resource_changes'].append({'mode':'managed','address':'aws_dynamodb_table.private','change':{'actions':['update'],'before':{},'after':{}}})
            with self.assertRaises(ValueError):module.review(altered,REVISION,stack,manifest)

    def test_closed_gates_and_unchanged_environment_are_required(self):
        for stack in ('campaign-processing','api'):
            plan,manifest,_=fixture(stack)
            for field,value in [('UNCHANGED_PRIVATE','new-sensitive'),('INVENTED_GATE','true')]:
                altered=copy.deepcopy(plan);at(altered,'aws_lambda_function')['after']['environment'][0]['variables'][field]=value
                with self.assertRaises(ValueError):module.review(altered,REVISION,stack,manifest)
            altered=copy.deepcopy(plan);at(altered,'aws_lambda_function')['after_unknown']['environment']=True
            with self.assertRaises(ValueError):module.review(altered,REVISION,stack,manifest)
        plan,manifest,_=fixture('campaign-processing')
        for prefix,key,value in [('aws_lambda_event_source_mapping','enabled',True),('aws_scheduler_schedule','state','ENABLED')]:
            altered=copy.deepcopy(plan);at(altered,prefix)['after'][key]=value
            with self.assertRaises(ValueError):module.review(altered,REVISION,'campaign-processing',manifest)
        plan,manifest,_=fixture('api')
        for worker,flag in [('participation','CONSENT_INDEPENDENCE_ENABLED'),('purchase','PURCHASE_OWNERSHIP_CANDIDATE_ENABLED')]:
            altered=copy.deepcopy(plan);at(altered,module.API_ADDRESSES[worker])['after']['environment'][0]['variables'][flag]='true'
            with self.assertRaises(ValueError):module.review(altered,REVISION,'api',manifest)

    def test_missing_required_resources_and_failed_plan_rejected(self):
        plan,manifest,_=fixture('api')
        for index in range(len(plan['resource_changes'])):
            altered=copy.deepcopy(plan);altered['resource_changes'].pop(index)
            with self.assertRaises(ValueError):module.review(altered,REVISION,'api',manifest)
        for field,value in [('complete',False),('errored',True),('checks',[{'status':'fail'}])]:
            altered=copy.deepcopy(plan);altered[field]=value
            with self.assertRaises(ValueError):module.review(altered,REVISION,'api',manifest)

    def test_wrong_manifest_or_boundary_identity_rejected(self):
        plan,manifest,_=fixture('api')
        for key,value in [('publicationComplete',False),('environment','prod'),('sourceSha','c'*40)]:
            altered=copy.deepcopy(manifest);altered[key]=value
            with self.assertRaises(ValueError):module.review(plan,REVISION,'api',altered)
        altered=copy.deepcopy(plan);at(altered,'aws_iam_role_policy.research_migration_boundary')['after']['role']='wrong-role'
        with self.assertRaises(ValueError):module.review(altered,REVISION,'api',manifest)

    def test_exact_version_downloads_hash_bytes_and_never_mutates_cloud(self):
        plan,manifest,contents=fixture('api');report=module.review(plan,REVISION,'api',manifest)
        calls=[]
        def read(*args):
            calls.append(args)
            if args[0]=='sts':return {'Account':module.ACCOUNT}
            self.assertEqual(args[:2],('s3api','get-object'))
            function=Path(args[-1]).stem;Path(args[-1]).write_bytes(contents[function])
            return {'VersionId':args[args.index('--version-id')+1]}
        module.verify_artifacts(report['artifacts'],read)
        self.assertEqual(len(calls),6)
        with self.assertRaises(ValueError):module.verify_artifacts(report['artifacts'],lambda *args:{'Account':'other'})
        def corrupt(*args):
            result=read(*args)
            if args[0]=='s3api':Path(args[-1]).write_bytes(b'wrong')
            return result
        with self.assertRaises(ValueError):module.verify_artifacts(report['artifacts'],corrupt)
        def wrong_version(*args):
            result=read(*args)
            if args[0]=='s3api':result['VersionId']='wrong'
            return result
        with self.assertRaises(ValueError):module.verify_artifacts(report['artifacts'],wrong_version)

    def test_positive_concurrency_requires_already_installed_exact_code(self):
        for stack in ('campaign-processing','api'):
            plan,manifest,_=fixture(stack)
            maximum=2 if stack=='campaign-processing' else 5
            if stack=='campaign-processing':plan['variables']['reserved_concurrency']['value']=maximum
            else:
                for key in plan['variables']:
                    if key.endswith('_lambda_reserved_concurrency'):plan['variables'][key]['value']=maximum
            for r in plan['resource_changes']:
                if r['address'].startswith('aws_lambda_function'):
                    r['change']['after']['reserved_concurrent_executions']=maximum
            with self.assertRaises(ValueError):module.review(plan,REVISION,stack,manifest)
            for r in plan['resource_changes']:
                if r['address'].startswith('aws_lambda_function'):
                    r['change']['before']=copy.deepcopy(r['change']['after'])
                    r['change']['before']['reserved_concurrent_executions']=0
            self.assertEqual(len(module.review(plan,REVISION,stack,manifest)['artifacts']),len(module.CAMPAIGN if stack=='campaign-processing' else module.API))

    def test_only_reviewed_scheduler_configuration_may_have_computed_policy(self):
        plan,manifest,_=fixture('campaign-processing')
        policy=at(plan,'aws_iam_role_policy.scheduler_invoke')
        policy['after']['policy']=None;policy['after_unknown']['policy']=True
        with self.assertRaises(ValueError):module.review(plan,REVISION,'campaign-processing',manifest)
        expressions={'name':{'constant_value':'invoke-lifecycle'},
            'policy':{'references':['data.aws_iam_policy_document.scheduler_invoke[0].json','data.aws_iam_policy_document.scheduler_invoke[0]','data.aws_iam_policy_document.scheduler_invoke']},
            'role':{'references':['aws_iam_role.scheduler[0].id','aws_iam_role.scheduler[0]','aws_iam_role.scheduler']}}
        doc={'statement':[{'actions':{'constant_value':['lambda:InvokeFunction']},'effect':{'constant_value':'Allow'},
            'resources':{'references':['aws_lambda_function.worker["lifecycle"].arn','aws_lambda_function.worker["lifecycle"]','aws_lambda_function.worker']},
            'sid':{'constant_value':'InvokeLifecycle'}}]}
        plan['configuration']={'root_module':{'resources':[{'address':'aws_iam_role_policy.scheduler_invoke','expressions':expressions},
             {'address':'data.aws_iam_policy_document.scheduler_invoke','expressions':doc}]}}
        module.review(plan,REVISION,'campaign-processing',manifest)
        doc['statement'][0]['actions']['constant_value']=['lambda:*']
        with self.assertRaises(ValueError):module.review(plan,REVISION,'campaign-processing',manifest)

    def test_cli_error_never_echoes_raw_input(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'protected.json';path.write_text('DO-NOT-PRINT')
            result=subprocess.run([sys.executable,str(Path(module.__file__)),str(path),'--revision',REVISION,'--stack','api'],capture_output=True,text=True)
        self.assertEqual(result.returncode,1);self.assertEqual(result.stdout,'')
        self.assertEqual(result.stderr,'Research release rejected; inspect protected evidence locally.\n')


if __name__=='__main__':unittest.main()
