import boto3,importlib.util,json,sys
from datetime import datetime,timezone
from pathlib import Path
from botocore.config import Config
plan,output=sys.argv[1:];p=json.loads(Path(plan).read_text())
def need(v):
 if not v:raise ValueError('PERIOD_READBACK_VERIFICATION_FAILED')
spec=importlib.util.spec_from_file_location('period_iam',Path.cwd()/'scripts/qualify_campaign_period_admission_iam.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
s=boto3.Session(profile_name='trustcheckradar',region_name='us-east-1');cfg=Config(connect_timeout=5,read_timeout=15,retries={'total_max_attempts':1});need(s.client('sts',config=cfg).get_caller_identity()['Account']=='107827791950')
l=s.client('lambda',config=cfg);iam=s.client('iam',config=cfg);sch=s.client('scheduler',config=cfg);cw=s.client('cloudwatch',config=cfg)
r={'observedAtUtc':datetime.now(timezone.utc).isoformat(),'workers':[],'policies':[],'disabledMappings':0,'disabledSchedules':0,'disabledAlarmActions':0,'negativeSmoke':[],'allVerified':False,'admissionEnabled':False,'campaignDeletionEnabled':False}
for item in p['resource_changes']:
 old=item['change']['before'];new=item['change']['after'];addr=item['address']
 if item['type']=='aws_lambda_function' and old:
  x=l.get_function_configuration(FunctionName=new['function_name']);need(x['CodeSha256']==new['source_code_hash'] and x['Runtime']=='python3.14' and x['Architectures']==['arm64'] and x['State']=='Active' and x['LastUpdateStatus']=='Successful')
  need(x['Environment']['Variables']==new['environment'][0]['variables']);need(l.get_function_concurrency(FunctionName=x['FunctionName'])['ReservedConcurrentExecutions']==2)
  r['workers'].append({'function':x['FunctionName'],'codeSha256':x['CodeSha256'],'configurationMatched':True,'runtime':x['Runtime'],'architectures':x['Architectures']})
 elif item['type']=='aws_iam_role_policy' and ('period_admission' in addr or addr=='aws_iam_role_policy.lifecycle_runtime[0]'):
  x=iam.get_role_policy(RoleName=new['role'],PolicyName=new['name'])['PolicyDocument'];need(m.equivalent(x)==m.equivalent(json.loads(new['policy'])));r['policies'].append({'role':new['role'],'name':new['name'],'matched':True})
 elif item['type']=='aws_lambda_event_source_mapping' and old:need(l.get_event_source_mapping(UUID=old['uuid'])['State']=='Disabled');r['disabledMappings']+=1
 elif item['type']=='aws_scheduler_schedule' and old:need(sch.get_schedule(Name=old['name'],GroupName=old.get('group_name') or 'default')['State']=='DISABLED');r['disabledSchedules']+=1
 elif item['type']=='aws_cloudwatch_metric_alarm' and old and 'recovery' in addr:
  x=cw.describe_alarms(AlarmNames=[old['alarm_name']])['MetricAlarms'];need(len(x)==1 and x[0]['ActionsEnabled'] is False);r['disabledAlarmActions']+=1
need(len(r['workers'])==4 and len(r['policies'])==4 and (r['disabledMappings'],r['disabledSchedules'],r['disabledAlarmActions'])==(3,4,8))
for function,event in [('campaign-observation-publisher',{'Records':[]}),('campaign-cluster-aggregator',{'Records':[]}),('campaign-lifecycle',{'schemaVersion':1,'environment':'dev','operation':'close_period','periodId':0}),('campaign-deletion-bridge',{'Records':[]})]:
 response=l.invoke(FunctionName='trustcheckradar-dev-'+function,InvocationType='RequestResponse',LogType='None',Payload=json.dumps(event).encode());raw=response['Payload'].read(4096);need(len(raw)<4096);body=json.loads(raw)
 need(response.get('FunctionError') and body.get('errorMessage') in ('Campaign locator coverage is unavailable','Campaign lifecycle candidate is disabled','CAMPAIGN_DELETION_STREAM_DISABLED'))
 r['negativeSmoke'].append({'function':function,'disabledRefusal':True,'error':body['errorMessage']})
r['allVerified']=True;Path(output).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'allVerified':True,'workers':4,'policies':4,'disabledMappings':3,'disabledSchedules':4,'disabledAlarmActions':8,'negativeSmoke':4}))
