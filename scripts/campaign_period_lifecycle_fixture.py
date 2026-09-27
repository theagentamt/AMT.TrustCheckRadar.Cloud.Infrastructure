#!/usr/bin/env python3
"""Owned five-table lifecycle qualification. No application resources or activation."""
import argparse,hashlib,importlib.util,json,os,re,subprocess,sys,time
from datetime import datetime,timezone
from pathlib import Path
from campaign_period_retirement_fixture import durable_journal,need,error_code,ACCOUNT,REGION,PERIOD_SECONDS

FAMILIES=('pipeline','outbox','users','ledger','intelligence')
CASES=('complete_replay','poison_recovery','lost_ack','retire_then_complete')

def shape(run):
    need(type(run)is str and re.fullmatch('[0-9a-f]{12}',run))
    prefix='amt-campaign-lifecycle-qual-'+run
    return prefix,{'Project':'trustcheckradar','Environment':'dev','Purpose':'campaign-lifecycle-qualification','QualificationRunId':run}

def table_spec(family):
    need(family in FAMILIES)
    attrs={'PK':'S','SK':'S'};indexes=[]
    def index(name,pk,sk,projection):
        indexes.append({'IndexName':name,'KeySchema':[{'AttributeName':pk,'KeyType':'HASH'},{'AttributeName':sk,'KeyType':'RANGE'}],'Projection':{'ProjectionType':projection}})
    if family=='pipeline':
        attrs.update(GSI2PK='S',GSI2SK='S');index('CandidateBucketIndex','GSI2PK','GSI2SK','ALL')
    if family=='intelligence':
        attrs.update(expiryPartition='S',expiresAt='N',GSI1PK='S',GSI1SK='S')
        index('ExpirationIndex','expiryPartition','expiresAt','KEYS_ONLY');index('PublicationIndex','GSI1PK','GSI1SK','ALL')
    result={'BillingMode':'PAY_PER_REQUEST','KeySchema':[{'AttributeName':'PK','KeyType':'HASH'},{'AttributeName':'SK','KeyType':'RANGE'}],
      'AttributeDefinitions':[{'AttributeName':k,'AttributeType':v} for k,v in attrs.items()],'StreamSpecification':{'StreamEnabled':False}}
    if indexes:result['GlobalSecondaryIndexes']=indexes
    return result

def validate(j,run):
    prefix,tags=shape(run)
    need(type(j.get('schemaVersion'))is int and j['schemaVersion']==1 and j['runId']==run and j['prefix']==prefix and j['tags']==tags
         and j['account']==ACCOUNT and j['region']==REGION and j['tables']=={f:prefix+'-'+f for f in FAMILIES})
    need(type(j['period'])is int and j['period']>=0 and j['keyTags']=={'Project':'trustcheckradar','Environment':'dev','Purpose':'campaign-contributor-token','PeriodId':str(j['period'])})
    arn=j.get('keyArn');need(arn is None or re.fullmatch(rf'arn:aws:kms:{REGION}:{ACCOUNT}:key/[0-9a-f]{{8}}(?:-[0-9a-f]{{4}}){{3}}-[0-9a-f]{{12}}',arn))
    return j

def source(root,sha):
    need(re.fullmatch('[0-9a-f]{40}',sha))
    def git(*args):return subprocess.check_output(['git','-C',str(root),*args])
    need(git('rev-parse','HEAD').decode().strip()==sha and not git('status','--porcelain','--untracked-files=all').strip())
    files=git('ls-files','src','scripts/qualification').decode().splitlines();hashes={}
    for name in files:
        if name.endswith('.py'):
            data=(root/name).read_bytes();need(data==git('show',sha+':'+name));compile(data,name,'exec');hashes[name]=hashlib.sha256(data).hexdigest()
    need('scripts/qualification/period_lifecycle.py'in hashes)
    return hashes

def main():
    import boto3
    from botocore.config import Config
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('operation',choices=('prepare','run','cleanup'))
    p.add_argument('--run-id',required=True);p.add_argument('--journal',required=True);p.add_argument('--profile',default='trustcheckradar')
    p.add_argument('--case',choices=CASES);p.add_argument('--source-root');p.add_argument('--source-sha');p.add_argument('--output');a=p.parse_args()
    prefix,tags=shape(a.run_id);path=Path(a.journal);s=boto3.Session(profile_name=a.profile,region_name=REGION)
    config=Config(connect_timeout=5,read_timeout=15,retries={'total_max_attempts':1})
    sts,d,k=[s.client(service,config=config) for service in ('sts','dynamodb','kms')];need(sts.get_caller_identity()['Account']==ACCOUNT)
    def save():durable_journal(path,j)
    def wait(name,present):
        deadline=time.monotonic()+180
        while time.monotonic()<deadline:
            try:
                t=d.describe_table(TableName=name)['Table']
                if present and t['TableStatus']=='ACTIVE' and all(x['IndexStatus']=='ACTIVE' for x in t.get('GlobalSecondaryIndexes',[])):return
            except Exception as e:
                if error_code(e)=='ResourceNotFoundException' and not present:return
                if error_code(e)!='ResourceNotFoundException':raise
            time.sleep(2)
        raise TimeoutError('FIXTURE_TABLE_WAIT_EXPIRED')
    def owned_key():
        need(j.get('keyArn'));m=k.describe_key(KeyId=j['keyArn'])['KeyMetadata'];t=k.list_resource_tags(KeyId=j['keyArn'])
        need(m['Arn']==j['keyArn'] and m['Description']==prefix and m['KeySpec']=='HMAC_256' and m['KeyUsage']=='GENERATE_VERIFY_MAC' and m['KeyManager']=='CUSTOMER' and m['Origin']=='AWS_KMS' and m['MultiRegion']is False)
        need(not t.get('Truncated') and not t.get('NextMarker') and len(t['Tags'])==4 and {x['TagKey']:x['TagValue'] for x in t['Tags']}==j['keyTags'])
        return m
    if a.operation=='prepare':
        period=int(time.time())//PERIOD_SECONDS-2
        j={'schemaVersion':1,'runId':a.run_id,'prefix':prefix,'tags':tags,'account':ACCOUNT,'region':REGION,'period':period,
          'keyTags':{'Project':'trustcheckradar','Environment':'dev','Purpose':'campaign-contributor-token','PeriodId':str(period)},
          'tables':{f:prefix+'-'+f for f in FAMILIES},'tableCreateAttempts':[],'createdAtUtc':datetime.now(timezone.utc).isoformat()}
        durable_journal(path,j,create=True)
        for family,name in j['tables'].items():
            j['tableCreateAttempts'].append(name);save();d.create_table(TableName=name,Tags=[{'Key':x,'Value':v} for x,v in tags.items()],**table_spec(family));wait(name,True)
            need(d.describe_continuous_backups(TableName=name)['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['PointInTimeRecoveryStatus']=='DISABLED')
        j['keyCreateAttempted']=True;save();m=k.create_key(KeySpec='HMAC_256',KeyUsage='GENERATE_VERIFY_MAC',Description=prefix,Tags=[{'TagKey':x,'TagValue':v} for x,v in j['keyTags'].items()])['KeyMetadata'];j['keyArn']=m['Arn'];save();need(owned_key()['KeyState']=='Enabled');j['prepared']=True;save();print(json.dumps({'prepared':True,'runId':a.run_id}));return
    j=validate(json.loads(path.read_text()),a.run_id)
    if a.operation=='run':
        need(j.get('prepared')is True and not j.get('invocationAttempted') and not j.get('cleanup') and a.source_root and a.source_sha and a.case and a.output)
        root=Path(a.source_root).resolve();hashes=source(root,a.source_sha);need(owned_key()['KeyState']=='Enabled' and j['period']==int(time.time())//PERIOD_SECONDS-2)
        sys.path.insert(0,str(root/'src'));spec=importlib.util.spec_from_file_location('qualified_lifecycle',root/'scripts/qualification/period_lifecycle.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        report={'sourceSha':a.source_sha,'memberSha256':hashes,'fixtureOnly':True,'productionActivation':False,'cloudExecuted':True,'passed':False,'runnerSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
        fd=os.open(a.output,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
        with os.fdopen(fd,'w')as f:
            json.dump(report,f);f.flush();os.fsync(f.fileno());j.update(invocationAttempted=True,case=a.case,sourceSha=a.source_sha);save();started=time.monotonic()
            result=module.run(d,k,run_id=a.run_id,tables=j['tables'],key_arn=j['keyArn'],case=a.case,remaining_ms=lambda:max(0,int((240-(time.monotonic()-started))*1000)))
            need(result.get('passed')is True);report.update(result,elapsedSeconds=round(time.monotonic()-started,3),observedAtUtc=datetime.now(timezone.utc).isoformat(),execution='local Python 3.14 with actual AWS DynamoDB/KMS; injected transport and synthetic clocks')
            f.seek(0);json.dump(report,f,indent=2);f.write('\n');f.truncate();f.flush();os.fsync(f.fileno())
        print(json.dumps({x:v for x,v in report.items() if x!='memberSha256'}));return
    need(not j.get('keyCreateAttempted')or j.get('keyArn'));result={'tablesAbsent':{},'keyDestroyed':False}
    if j.get('keyArn'):
        m=owned_key()
        if m['KeyState']!='PendingDeletion':
            need(m['KeyState']in('Enabled','Disabled'));k.schedule_key_deletion(KeyId=j['keyArn'],PendingWindowInDays=7)
        m=owned_key();need(m['KeyState']=='PendingDeletion');result.update(keyState=m['KeyState'],keyDeletionDate=m['DeletionDate'].isoformat())
    for family,name in j['tables'].items():
        try:
            m=d.describe_table(TableName=name)['Table'];need(m['TableArn']==f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{name}');t=d.list_tags_of_resource(ResourceArn=m['TableArn'])
            need(not t.get('NextToken') and len(t['Tags'])==4 and {x['Key']:x['Value']for x in t['Tags']}==tags)
            if m['TableStatus']!='DELETING':d.delete_table(TableName=name)
        except Exception as e:
            if error_code(e)!='ResourceNotFoundException':raise
        wait(name,False);result['tablesAbsent'][family]=True
    result['observedAtUtc']=datetime.now(timezone.utc).isoformat();j['cleanup']=result;save();print(json.dumps(result))

if __name__=='__main__':main()
