import boto3,json,time,hashlib
from datetime import datetime,timezone
from pathlib import Path
from botocore.config import Config
s=boto3.Session(profile_name='trustcheckradar',region_name='us-east-1');cfg=Config(connect_timeout=5,read_timeout=10,retries={'total_max_attempts':1});assert s.client('sts',config=cfg).get_caller_identity()['Account']=='107827791950'
c=s.client('cloudtrail',config=cfg);ddb=s.client('dynamodb',config=cfg)
names={'trustcheckradar-dev-campaign-outbox','trustcheckradar-dev-campaign-pipeline','trustcheckradar-dev-campaign-intelligence','trustcheckradar-dev-deletion-ledger','trustcheckradar-dev-users'}
start=min(ddb.describe_table(TableName=n)['Table']['CreationDateTime'] for n in names).astimezone(timezone.utc);end=datetime.now(timezone.utc)
assert 0<(end-start).total_seconds()<90*86400
r={'schemaVersion':1,'accountId':'107827791950','region':'us-east-1','startUtc':start.isoformat(),'endUtc':end.isoformat(),'scope':'Management event history in this region, since earliest creation of the five current tables','events':{},'complete':True,'historicalErasureVerified':False};deadline=time.monotonic()+120
operations=['CreateBackup','DeleteBackup','RestoreTableFromBackup','RestoreTableToPointInTime','ExportTableToPointInTime','ImportTable','DeleteTable']
def relevant(value):
 if isinstance(value,dict):return any(relevant(v) for v in value.values())
 if isinstance(value,list):return any(relevant(v) for v in value)
 if not isinstance(value,str):return False
 return value in names or any(value==f'arn:aws:dynamodb:us-east-1:107827791950:table/{n}' or value.startswith(f'arn:aws:dynamodb:us-east-1:107827791950:table/{n}/') for n in names)
for op in operations:
 entry={'pages':0,'matchingKnownTables':0,'unclassifiedRecords':0,'otherRecords':0,'complete':False};r['events'][op]=entry;cursor=None
 try:
  for _ in range(10):
   if time.monotonic()>=deadline:raise TimeoutError()
   time.sleep(.55)
   page=c.lookup_events(LookupAttributes=[{'AttributeKey':'EventName','AttributeValue':op}],StartTime=start,EndTime=end,MaxResults=50,**({'NextToken':cursor} if cursor else {}));entry['pages']+=1
   for e in page['Events']:
    try:
     detail=json.loads(e['CloudTrailEvent']);assert detail['eventSource']=='dynamodb.amazonaws.com' and detail['eventName']==op and detail['awsRegion']=='us-east-1' and detail['recipientAccountId']=='107827791950'
     request=detail.get('requestParameters');response=detail.get('responseElements');resources=e.get('Resources',[])
     if not isinstance(request,dict):entry['unclassifiedRecords']+=1
     elif relevant(request) or relevant(response) or relevant(resources):entry['matchingKnownTables']+=1
     else:entry['otherRecords']+=1
    except Exception:entry['unclassifiedRecords']+=1
   cursor=page.get('NextToken')
   if not cursor:entry['complete']=True;break
 except Exception:entry['reason']='OBSERVATION_UNAVAILABLE'
 if not entry['complete'] or entry['unclassifiedRecords']:r['complete']=False
r['limitations']=['No CloudTrail event payloads, identities, arbitrary resource names or pagination cursors retained.','Records failing source/account/region/shape classification remain unclassified.','No item data-event history, backup contents, other regions/accounts or manually copied data covered.','Absence of matching management events does not prove complete historical writer coverage or erasure.']
r['auditScriptSha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
Path('docs/evidence/campaign-restore-2026-09-24/control-history.json').write_text(json.dumps(r,indent=2)+'\n');print(r)
