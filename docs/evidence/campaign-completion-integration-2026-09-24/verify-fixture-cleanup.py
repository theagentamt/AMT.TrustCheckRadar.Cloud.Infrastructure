import boto3,json
from pathlib import Path
from botocore.config import Config
j=json.loads(Path('/tmp/amt-campaign-handler-fixture-journal.json').read_text());s=boto3.Session(profile_name='trustcheckradar',region_name='us-east-1');cfg=Config(connect_timeout=5,read_timeout=15,retries={'total_max_attempts':1})
assert s.client('sts',config=cfg).get_caller_identity()['Account']==j['account']
def gone(fn,**kwargs):
 try:fn(**kwargs)
 except Exception as e:
  assert e.response['Error']['Code'] in ('ResourceNotFoundException','NoSuchEntity','NoSuchEntityException');return True
 raise ValueError('FIXTURE_STILL_PRESENT')
r={'runId':j['runId'],'functionAbsent':gone(s.client('lambda',config=cfg).get_function,FunctionName=j['function']),'roleAbsent':gone(s.client('iam',config=cfg).get_role,RoleName=j['role'])}
r['tablesAbsent']={k:gone(s.client('dynamodb',config=cfg).describe_table,TableName=v) for k,v in j['tables'].items()}
k=s.client('kms',config=cfg).describe_key(KeyId=j['keyArn'])['KeyMetadata'];assert k['KeyState']=='PendingDeletion'
r.update(keyState=k['KeyState'],keyDeletionDate=k['DeletionDate'].isoformat(),keyDestroyed=False)
Path('/tmp/amt-handler-fixture-cleanup-readback.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
