import ast,base64,boto3,hashlib,json,sys,time,zipfile
from datetime import datetime,timezone
from pathlib import Path
from botocore.config import Config
journal=Path(sys.argv[1]);archive=Path(sys.argv[2]);out=Path(sys.argv[3]);j=json.loads(journal.read_text())
def require(v):
 if not v:raise ValueError('RUNTIME_VERIFICATION_FAILED')
require(hashlib.sha256(archive.read_bytes()).hexdigest()==j['zipSha256'])
with zipfile.ZipFile(archive) as z:
 runner=z.read('campaign_qualification.py');cases=next(ast.literal_eval(n.value) for n in ast.parse(runner).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='CASES' for t in n.targets));manifest=json.loads(z.read('qualification-manifest.json'))
 require(hashlib.sha256(runner).hexdigest()==manifest['memberSha256']['campaign_qualification.py'] and manifest['sourceSha']==j['sourceSha'])
require(isinstance(cases,tuple) and len(cases)<=40 and len(set(cases))==len(cases))
s=boto3.Session(profile_name='trustcheckradar',region_name='us-east-1');cfg=Config(connect_timeout=5,read_timeout=70,retries={'total_max_attempts':1});require(s.client('sts',config=cfg).get_caller_identity()['Account']=='107827791950');l=s.client('lambda',config=cfg)
f=l.get_function(FunctionName=j['function']);c=f['Configuration'];require(c['CodeSha256']==base64.b64encode(bytes.fromhex(j['zipSha256'])).decode() and c['Runtime']=='python3.14' and c['Architectures']==['arm64'] and c['Handler']=='campaign_qualification.lambda_handler' and f['Tags']==j['tags']);require(l.get_function_concurrency(FunctionName=j['function'])['ReservedConcurrentExecutions']==1)
require(c['Environment']['Variables']['QUALIFICATION_SOURCE_SHA']==j['sourceSha'])
r={'schemaVersion':1,'observedAtUtc':datetime.now(timezone.utc).isoformat(),'sourceSha':j['sourceSha'],'zipSha256':j['zipSha256'],'runId':j['runId'],'runtime':c['Runtime'],'architectures':c['Architectures'],'runtimeVersionArn':c.get('RuntimeVersionConfig',{}).get('RuntimeVersionArn'),'cases':[],'allPassed':False,'syntheticOnly':True,'historicalCoverageApproved':False,'productionActivation':False,'limits':['Synthetic snapshot reconstruction, not native AWS backup restoration.','Fixture seeding role is not production completion IAM acceptance.','Some races/lost acknowledgments are deliberately injected around actual AWS SDK operations.']}
start=time.monotonic();out.write_text(json.dumps(r,indent=2)+'\n')
for name in cases:
 require(time.monotonic()-start<600)
 event={'schemaVersion':1,'operation':'qualify-campaign-completion','runId':j['runId'],'case':name}
 response=l.invoke(FunctionName=j['function'],InvocationType='RequestResponse',LogType='None',Payload=json.dumps(event).encode())
 body=response['Payload'].read(4096);require(len(body)<4096)
 if response.get('FunctionError'):row={'case':name,'passed':False,'category':'FUNCTION_ERROR'}
 else:
  result=json.loads(body)
  ok=(response['StatusCode']==200 and result.get('passed') is True and result.get('case')==name and result.get('sourceSha')==j['sourceSha'] and result.get('syntheticOnly') is True and result.get('historicalCoverageApproved') is False and result.get('productionActivation') is False)
  row={'case':name,'passed':ok}
  if not ok:
   for field in ('code','failureStage','failureCategory'):
    if isinstance(result.get(field),str) and len(result[field])<=64:row[field]=result[field]
 r['cases'].append(row);out.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(row),flush=True)
 if not row['passed']:raise SystemExit(2)
r['allPassed']=True;r['elapsedSeconds']=round(time.monotonic()-start,3);out.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'allPassed':True,'cases':len(cases)}))
