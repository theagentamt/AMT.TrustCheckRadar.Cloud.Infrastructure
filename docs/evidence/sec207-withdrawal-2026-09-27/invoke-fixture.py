import argparse,base64,boto3,hashlib,json,os,sys,time,zipfile
from datetime import datetime,timezone
from pathlib import Path
from botocore.config import Config
sys.path.insert(0,'/tmp/amt-play-lifecycle-dev-deployment/scripts')
import campaign_completion_fixture as F

def require(v):
 if not v: raise ValueError('QUALIFICATION_BOUNDARY_REJECTED')
cases=['actual_withdrawal_complete_replay','actual_withdrawal_lost_ack','actual_withdrawal_delayed_replay']
p=argparse.ArgumentParser();p.add_argument('--journal',required=True);p.add_argument('--archive',required=True);p.add_argument('--output',required=True);p.add_argument('--case',required=True,choices=cases)
a=p.parse_args();j=json.loads(Path(a.journal).read_text());F.validate_journal(j,j['runId'])
require(j.get('prepared') is True and j.get('fixtureKind')=='campaign' and not j.get('realCognito'))
require(hashlib.sha256(Path(a.archive).read_bytes()).hexdigest()==j['zipSha256'])
with zipfile.ZipFile(a.archive) as z:
 m=json.loads(z.read('qualification-manifest.json'))
 require(m['sourceSha']==j['sourceSha'] and m['handler']=='campaign_qualification.lambda_handler')
 require(len(z.namelist())==len(set(z.namelist())) and set(z.namelist())==set(m['memberSha256'])|{'qualification-manifest.json'})
 for name,digest in m['memberSha256'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest)
s=boto3.Session(profile_name='trustcheckradar',region_name=F.REGION)
cfg=Config(connect_timeout=5,read_timeout=70,retries={'total_max_attempts':1})
require(s.client('sts',config=cfg).get_caller_identity()['Account']==F.ACCOUNT)
l=s.client('lambda',config=cfg);f=l.get_function(FunctionName=j['function']);c=f['Configuration']
require(c['CodeSha256']==base64.b64encode(bytes.fromhex(j['zipSha256'])).decode() and c['Runtime']=='python3.14' and c['Architectures']==['arm64'] and c['Handler']==m['handler'] and f['Tags']==j['tags'])
require(c.get('State')=='Active' and c.get('LastUpdateStatus')=='Successful' and c.get('Version')=='$LATEST' and c.get('Role')==f"arn:aws:iam::{F.ACCOUNT}:role/{j['role']}" and c['Timeout']==60)
require(l.get_function_concurrency(FunctionName=j['function'])['ReservedConcurrentExecutions']==1)
env={'QUALIFICATION_RUN_ID':j['runId'],'QUALIFICATION_KEY_ARN':j['keyArn'],'QUALIFICATION_FUNCTION_NAME':j['function'],'QUALIFICATION_SOURCE_SHA':j['sourceSha']}|F.table_environment(j['tables'])
require(c['Environment']['Variables']==env)
report={'schemaVersion':1,'case':a.case,'sourceSha':j['sourceSha'],'zipSha256':j['zipSha256'],'runId':j['runId'],'observedAtUtc':datetime.now(timezone.utc).isoformat(),'runtime':c['Runtime'],'architectures':c['Architectures'],'runtimeVersionArn':c.get('RuntimeVersionConfig',{}).get('RuntimeVersionArn'),'invocationAttempted':False,'passed':False,'fixtureOnly':True,'productionActivation':False,'nativeBackupRestore':False,'productionRoleQualified':False,'queueTransportInjected':True,'nativeDlqRedrive':False}
with open(a.output,'x') as out:
 def save():
  out.seek(0);json.dump(report,out,indent=2);out.write('\n');out.truncate();out.flush();os.fsync(out.fileno())
 report['invocationAttempted']=True;save();start=time.monotonic()
 response=l.invoke(FunctionName=j['function'],InvocationType='RequestResponse',LogType='None',Payload=json.dumps({'schemaVersion':1,'operation':'qualify-campaign-completion','runId':j['runId'],'case':a.case}).encode())
 raw=response['Payload'].read(8193);require(len(raw)<=8192)
 require(response['StatusCode']==200 and not response.get('FunctionError'))
 body=json.loads(raw)
 require(body.get('case')==a.case and body.get('sourceSha')==j['sourceSha'] and body.get('passed') is True and body.get('syntheticOnly') is True and body.get('historicalCoverageApproved') is False and body.get('productionActivation') is False)
 report['passed']=True;report['elapsedSeconds']=round(time.monotonic()-start,3);save();print(json.dumps(report))
