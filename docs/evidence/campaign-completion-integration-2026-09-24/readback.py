import base64,boto3,hashlib,json,sys
from datetime import datetime,timezone
from pathlib import Path
from botocore.config import Config
plan,publication,output=sys.argv[1:];p=json.loads(Path(plan).read_text());a=json.loads(Path(publication).read_text())
def need(v):
 if not v:raise ValueError('READBACK_VERIFICATION_FAILED')
s=boto3.Session(profile_name='trustcheckradar',region_name='us-east-1');cfg=Config(connect_timeout=5,read_timeout=15,retries={'total_max_attempts':1})
need(s.client('sts',config=cfg).get_caller_identity()['Account']=='107827791950')
l=s.client('lambda',config=cfg);iam=s.client('iam',config=cfg);scheduler=s.client('scheduler',config=cfg);cw=s.client('cloudwatch',config=cfg)
r={'observedAtUtc':datetime.now(timezone.utc).isoformat(),'workers':[],'eventMappings':[],'schedules':[],'alarmActions':[],'allVerified':False,'campaignDeletionEnabled':False}
for resource in p['resource_changes']:
 b=resource['change']['before'];addr=resource['address']
 if resource['type']=='aws_lambda_function' and b:
  c=l.get_function_configuration(FunctionName=b['function_name']);is_deletion=addr=='aws_lambda_function.worker["deletion"]'
  expect=resource['change']['after'] if is_deletion else b
  need(c['CodeSha256']==expect['source_code_hash'] and c['Runtime']=='python3.14' and c['Architectures']==['arm64'] and c['State']=='Active' and c['LastUpdateStatus']=='Successful')
  need(c['Environment']['Variables']==expect['environment'][0]['variables'])
  need(l.get_function_concurrency(FunctionName=c['FunctionName'])['ReservedConcurrentExecutions']==2)
  r['workers'].append({'function':c['FunctionName'],'codeSha256':c['CodeSha256'],'runtime':c['Runtime'],'architecture':c['Architectures'],'environmentMatchedPlan':True,'reservedConcurrency':2})
 elif resource['type']=='aws_lambda_event_source_mapping' and b:
  m=l.get_event_source_mapping(UUID=b['uuid']);need(m['State']=='Disabled');r['eventMappings'].append({'uuid':b['uuid'],'state':m['State']})
 elif resource['type']=='aws_scheduler_schedule' and b:
  x=scheduler.get_schedule(Name=b['name'],GroupName=b.get('group_name') or 'default');need(x['State']=='DISABLED');r['schedules'].append({'name':b['name'],'state':x['State']})
 elif resource['type']=='aws_cloudwatch_metric_alarm' and b and 'recovery' in addr:
  x=cw.describe_alarms(AlarmNames=[b['alarm_name']])['MetricAlarms'];need(len(x)==1 and x[0]['ActionsEnabled'] is False);r['alarmActions'].append({'name':b['alarm_name'],'enabled':False})
need(len(r['workers'])==4 and len(r['eventMappings'])==3 and len(r['schedules'])==4 and len(r['alarmActions'])==8)
role='trustcheckradar-dev-campaign-deletion-bridge-role';policy=iam.get_role_policy(RoleName=role,PolicyName='campaign-completion-candidate')['PolicyDocument']
digest=hashlib.sha256(json.dumps(policy,sort_keys=True,separators=(',',':')).encode()).hexdigest();need(digest=='17c0ba3a26fd3b4610dc0deb995a3ce2b07b467e37240922524c814d38e060d0');r['completionPolicySha256']=digest
# Both requests are disabled-gate negative checks; neither contains account data.
for event,expected in [({'Records':[]},'CAMPAIGN_DELETION_STREAM_DISABLED'),({'schemaVersion':1,'operation':'reconcile-campaign-cleanup'},None)]:
 resp=l.invoke(FunctionName='trustcheckradar-dev-campaign-deletion-bridge',InvocationType='RequestResponse',LogType='None',Payload=json.dumps(event).encode());raw=resp['Payload'].read(4096);need(len(raw)<4096);body=json.loads(raw)
 if expected:need(resp.get('FunctionError') and body.get('errorMessage')==expected)
 else:need(not resp.get('FunctionError') and body=={'enabled':False,'complete':False})
r['disabledGateSmokePassed']=True;r['allVerified']=True;Path(output).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'allVerified':True,'workers':4,'disabledMappings':3,'disabledSchedules':4,'disabledAlarmActions':8,'disabledGateSmokePassed':True}))
