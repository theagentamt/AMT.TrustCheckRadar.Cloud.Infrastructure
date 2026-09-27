"""One-off reviewed Dev acceptance: at most five explicit aggregate ticks.
Not a general operator runner or proof of eight naturally scheduled invocations.
"""
import boto3,json,hashlib,time,sys,os,tempfile
from pathlib import Path
from botocore.config import Config
sys.path.insert(0,'/tmp/amt-period-core-frozen-build/src')
from shared_campaign_work.configuration import plain
s=boto3.Session(profile_name='trustcheckradar',region_name='us-east-1')
l=s.client('lambda',config=Config(connect_timeout=10,read_timeout=75,retries={'total_max_attempts':1}));d=s.client('dynamodb');k=s.client('kms')
def need(ok,reason):
 if not ok:raise RuntimeError(reason)
need(s.client('sts').get_caller_identity()['Account']=='107827791950','account')
def pinned(path,expected):
 raw=Path(path).read_bytes();need(hashlib.sha256(raw).hexdigest()==expected,'input_drift');return json.loads(raw)
m=pinned('/tmp/amt-sec207-work-bootstrap-candidate/bootstrap-manifest-candidate.json','248eb5ded8bc25c582f77a71923d91b5ff12fec9df025259f0884fcf983f516d')
f=pinned('/tmp/amt-sec207-final-runtime-config.json','4a616a53ff552882d9a548fc023e6f31ad6178f9aa6af723d10a53dcbe82b042')['functions']['campaign_lifecycle']
canon=lambda v:json.dumps(v,sort_keys=True,separators=(',',':'))
digest=lambda v:hashlib.sha256(canon(v).encode()).hexdigest()
out=Path('/tmp/amt-sec207-manual-aggregate-pass.json');need(not out.exists(),'existing_journal')
report={'schemaVersion':1,'startedAtEpoch':int(time.time()),'functionName':f['functionName'],'codeSha256':f['codeSha256'],'revisionId':f['revisionId'],'scheduledTickClaimed':False,'event':{'schemaVersion':1,'environment':'dev','operation':'reconcile_aggregates'},'calls':[],'status':'PRECHECK','scope':'Mixed composition: bounded explicit aggregate continuation after genuine scheduled ticks; next genuine schedule and natural alarm recovery observed separately.'}
def durable_journal(path, doc, *, create=False):
    """Keep the preceding ownership journal intact until a full update is durable."""
    path = Path(path)
    payload = (json.dumps(doc, sort_keys=True, indent=2) + '\n').encode()
    temporary = None
    try:
        if create:
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        else:
            fd, temporary = tempfile.mkstemp(prefix=path.name+'.', dir=path.parent)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(payload); stream.flush(); os.fsync(stream.fileno())
        if temporary is not None:
            os.replace(temporary, path); temporary = None
        directory = os.open(path.parent, os.O_RDONLY)
        try: os.fsync(directory)
        finally: os.close(directory)
    finally:
        if temporary is not None:
            try: os.unlink(temporary)
            except FileNotFoundError: pass


def save():
 durable_journal(out,report)
def scan(table):
 rows=[];args={'TableName':table,'ConsistentRead':True,'Limit':32};tokens=set()
 for _ in range(16):
  r=d.scan(**args);rows+=r['Items'];need(len(rows)<=128,'row_bound')
  if not r.get('LastEvaluatedKey'):return sorted(rows,key=canon)
  token=r['LastEvaluatedKey'];h=digest(token);need(h not in tokens,'repeated_cursor');tokens.add(h);args['ExclusiveStartKey']=token
 raise RuntimeError('scan_bound')
def inspect():
 c=l.get_function_configuration(FunctionName=f['functionName']);need(c['CodeSha256']==f['codeSha256'] and c['RevisionId']==f['revisionId'],'function_drift');need(c['Runtime']=='python3.14' and c['Architectures']==['arm64'] and c['State']=='Active' and c['LastUpdateStatus']=='Successful','function_state');need(digest(c['Environment']['Variables'])==f['environmentSha256'],'environment_drift');need(c['Role']==f['roleArn'],'role_drift')
 rows={}
 for fam,r in m['resources'].items():
  desc=d.describe_table(TableName=r['tableName'])['Table'];need(desc['TableId']==r['tableId'] and desc['TableStatus']=='ACTIVE','resource_drift');rows[fam]=scan(r['tableName'])
 need(not rows['outbox'] and not rows['intelligence'],'nonempty_data')
 stable=[r for r in rows['pipeline'] if not r['PK']['S'].startswith(('PERIOD_WORK_CONTROL#','PERIOD_SWEEP#','AGGREGATE_SWEEP#'))];need(digest(stable)=='5679328a71ab5e87c5fd0f7b0b1a00b5f9dd93617e001ce9dda38962b2bbacf9','baseline_drift')
 p=[plain(r) for r in rows['pipeline']];deadline=int(time.time())+600
 for row in p:
  if row['PK'].startswith('PERIOD#') and row['status']=='ENABLED':
   need(int(row['retireAfterEpoch'])>deadline,'recovery_due');need(k.describe_key(KeyId=row['keyArn'])['KeyMetadata']['KeyState']=='Enabled','key_changed')
 # Stable baseline consists of the reviewed three future tombstone work pairs,
 # two future period registries and fixed approval rows; no summary or job exists.
 cursors=[r for r in p if r['PK'].startswith('AGGREGATE_SWEEP#')];need(len(cursors)==1,'cursor_count');row=cursors[0]
 return {key:int(row[key]) if not isinstance(row[key],bool) else row[key] for key in ('revision','shard','lastFullPassAtEpoch','passIncomplete')}
durable_journal(out,report,create=True)
try:
 first=inspect();report['initialCursor']=first;save()
 for i in range(5):
  before=inspect()
  if before['lastFullPassAtEpoch']>0:
   report['status']='FULL_PASS_OBSERVED';report['finalCursor']=before;break
  call={'number':i+1,'before':before,'startedAtEpoch':int(time.time()),'status':'INTENT'};report['calls'].append(call);save()
  r=l.invoke(FunctionName=f['functionName'],InvocationType='RequestResponse',LogType='None',Payload=canon(report['event']).encode())
  need(r['StatusCode']==200 and not r.get('FunctionError') and r.get('ExecutedVersion')=='$LATEST','invoke_failure');v=json.loads(r['Payload'].read());need(v.get('schemaVersion')==1 and v.get('aggregateErasureComplete') is False,'response_shape');metrics=v['metrics'];need(type(metrics) is dict and set(metrics)=={'AggregateHeartbeat','AggregateFailures','AggregateWorkDeleted','AggregateWorkUnverified','AggregateOverdueObserved','AggregateFullPassAgeSeconds'} and all(type(x) is int and 0<=x<=9007199254740991 for x in metrics.values()),'metric_schema');need(metrics['AggregateHeartbeat']==1,'heartbeat')
  need(all(metrics[x]==0 for x in ('AggregateFailures','AggregateWorkDeleted','AggregateWorkUnverified','AggregateOverdueObserved')),'unexpected_work_or_failure')
  call.update(status='ACKNOWLEDGED',metrics=metrics,finishedAtEpoch=int(time.time()));save();after=inspect();call['after']=after;save()
  if after['lastFullPassAtEpoch']>0:
   report['status']='FULL_PASS_OBSERVED';report['finalCursor']=after;break
 else:report['status']='BOUND_EXHAUSTED_WITHOUT_FULL_PASS'
 report['finishedAtEpoch']=int(time.time());save();need(report['status']=='FULL_PASS_OBSERVED','full_pass_missing')
except Exception as exc:
 report['status']='STOPPED_NO_RETRY';report['failureClass']=type(exc).__name__;report['finishedAtEpoch']=int(time.time())
 try:save()
 except Exception:pass # The preceding durable intent remains authoritative.
 raise
print(json.dumps({'status':report['status'],'explicitCallCount':len(report['calls']),'finalCursor':report['finalCursor']}))
