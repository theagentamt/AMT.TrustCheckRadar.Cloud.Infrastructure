#!/usr/bin/env python3
"""Create-only current-period Dev HMAC key helper; dry-run metadata plan by default.

Root must serialize this operator across hosts. Metadata discovery is not an
atomic lock against an external creator. Never writes registry/inventory, reads
key material, rotates, disables, or deletes a key. One SDK CreateKey attempt per
journal; an uncertain attempt can only be discovered, never retried.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import time

ACCOUNT='107827791950';REGION='us-east-1';TABLE='trustcheckradar-dev-campaign-pipeline'
PERIOD_SECONDS=1209600
OPERATION='provision-current-campaign-hmac-key'
KEY_PATTERN=rf'arn:aws:kms:{REGION}:{ACCOUNT}:key/[0-9a-f]{{8}}(?:-[0-9a-f]{{4}}){{3}}-[0-9a-f]{{12}}'
ERROR='CAMPAIGN_PERIOD_KEY_PROVISIONING_UNAVAILABLE'
PLAN_FIELDS={'schemaVersion','operation','accountId','region','tableName','periodSeconds','periodId','observedAtEpoch','tags','registryAbsent','discovery','mode','candidateKeyArn'}
JOURNAL_FIELDS={'schemaVersion','operation','accountId','region','tableName','periodId','tags','planSha256','mode','candidateKeyArn','createAttempted','attemptedAtEpoch','keyArn','status'}

class Unavailable(RuntimeError):
    def __init__(self,code):super().__init__(code)

def need(value,code):
    if not value:raise Unavailable(code)
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def integer(value):return type(value) is int and 0<=value<=9007199254740991

def tags_for(period):
    need(integer(period),'PERIOD_INVALID')
    return {'Project':'trustcheckradar','Environment':'dev','Purpose':'campaign-contributor-token','PeriodId':str(period)}

def key_arn(value):
    need(isinstance(value,str) and re.fullmatch(KEY_PATTERN,value),'KEY_ARN_BOUNDARY');return value

def discovery_key_arn(value):
    pattern=rf'arn:aws:kms:{REGION}:{ACCOUNT}:key/(?:[0-9a-f]{{8}}(?:-[0-9a-f]{{4}}){{3}}-[0-9a-f]{{12}}|mrk-[0-9a-f]{{32}})'
    need(isinstance(value,str) and re.fullmatch(pattern,value),'DISCOVERY_ARN_BOUNDARY');return value

def validate_plan(plan):
    need(type(plan) is dict and set(plan)==PLAN_FIELDS,'PLAN_SCHEMA')
    need(type(plan['schemaVersion']) is int and plan['schemaVersion']==1 and plan['operation']==OPERATION and plan['accountId']==ACCOUNT and plan['region']==REGION and plan['tableName']==TABLE and type(plan['periodSeconds']) is int and plan['periodSeconds']==PERIOD_SECONDS,'PLAN_BOUNDARY')
    need(integer(plan['periodId']) and integer(plan['observedAtEpoch']) and plan['observedAtEpoch']//PERIOD_SECONDS==plan['periodId'] and plan['tags']==tags_for(plan['periodId']) and plan['registryAbsent'] is True,'PLAN_PERIOD_TAGS')
    discovery=plan['discovery']
    need(type(discovery) is dict and set(discovery)=={'complete','keysExamined','listPages','matches'} and discovery['complete'] is True and integer(discovery['keysExamined']) and integer(discovery['listPages']) and 1<=discovery['listPages']<=10 and type(discovery['matches']) is list and len(discovery['matches'])<=1,'PLAN_DISCOVERY')
    for match in discovery['matches']:validate_metadata(match,plan['tags'])
    mode=plan['mode'];candidate=plan['candidateKeyArn'];need(mode in ('create','reuse','selection_required'),'PLAN_MODE')
    if mode=='create':need(not discovery['matches'] and candidate is None,'PLAN_CREATE_COLLISION')
    else:
        need(len(discovery['matches'])==1 and candidate==discovery['matches'][0]['arn'],'PLAN_REUSE_BINDING');key_arn(candidate)
    return plan


def validate_metadata(value,tags):
    need(type(value) is dict and set(value)=={'arn','keyState','keySpec','keyUsage','origin','keyManager','multiRegion','createdAtEpoch','tags'},'KEY_METADATA_SCHEMA')
    key_arn(value['arn'])
    need(value['keyState']=='Enabled' and value['keySpec']=='HMAC_256' and value['keyUsage']=='GENERATE_VERIFY_MAC' and value['origin']=='AWS_KMS' and value['keyManager']=='CUSTOMER' and value['multiRegion'] is False and integer(value['createdAtEpoch']) and value['tags']==tags,'KEY_NOT_ELIGIBLE')
    return value


def fresh_journal(plan,digest):
    return {'schemaVersion':1,'operation':OPERATION,'accountId':ACCOUNT,'region':REGION,'tableName':TABLE,'periodId':plan['periodId'],'tags':plan['tags'],'planSha256':digest,'mode':plan['mode'],'candidateKeyArn':plan['candidateKeyArn'],'createAttempted':False,'attemptedAtEpoch':None,'keyArn':None,'status':'prepared'}

def validate_journal(doc,plan,digest):
    need(type(doc) is dict and set(doc)==JOURNAL_FIELDS,'JOURNAL_SCHEMA')
    expected=fresh_journal(plan,digest)
    for name in JOURNAL_FIELDS-{'createAttempted','attemptedAtEpoch','keyArn','status'}:need(type(doc[name]) is type(expected[name]) and doc[name]==expected[name],'JOURNAL_BOUNDARY')
    need(type(doc['createAttempted']) is bool and doc['status'] in ('prepared','create_attempted','ambiguous','key_identified','verified'),'JOURNAL_STATE')
    if doc['createAttempted']:
        need(doc['mode']=='create' and integer(doc['attemptedAtEpoch']) and doc['attemptedAtEpoch']//PERIOD_SECONDS==plan['periodId'] and doc['status']!='prepared','JOURNAL_ATTEMPT')
    else:need(doc['attemptedAtEpoch'] is None and doc['status'] in ('prepared','key_identified','verified'),'JOURNAL_ATTEMPT')
    if doc['keyArn'] is not None:
        key_arn(doc['keyArn']);need(doc['status'] in ('key_identified','verified') and (doc['createAttempted'] or doc['mode']=='reuse' and doc['keyArn']==doc['candidateKeyArn']),'JOURNAL_KEY_BINDING')
    else:need(doc['status'] not in ('key_identified','verified'),'JOURNAL_KEY_BINDING')
    return doc


class Operator:
    def __init__(self,ddb,kms,sts,*,now=lambda:int(time.time()),monotonic=time.monotonic):
        self.ddb,self.kms,self.sts=ddb,kms,sts;self.now,self.monotonic=now,monotonic
        self.deadline=monotonic()+180;self.last=0
    def clock(self,period=None):
        need(self.monotonic()<self.deadline,'DEADLINE');now=self.now()
        need(integer(now) and now>=self.last and (period is None or now//PERIOD_SECONDS==period),'PERIOD_ROLLOVER_OR_CLOCK');self.last=now;return now
    def identity(self,period):
        self.clock(period)
        for client in (self.ddb,self.kms,self.sts):need(client.meta.region_name==REGION,'CLIENT_REGION')
        need(self.sts.get_caller_identity().get('Account')==ACCOUNT,'CALLER_ACCOUNT');self.clock(period)
    def registry_absent(self,period):
        self.clock(period)
        result=self.ddb.get_item(TableName=TABLE,Key={'PK':{'S':f'PERIOD#{period}'},'SK':{'S':'HMAC_KEY'}},ConsistentRead=True,ProjectionExpression='PK,SK')
        self.clock(period);need('Item' not in result,'REGISTRY_ALREADY_EXISTS')
    def tags(self,arn,period):
        tags={};marker=None
        for _ in range(5):
            self.clock(period);response=self.kms.list_resource_tags(KeyId=discovery_key_arn(arn),Limit=50,**({'Marker':marker} if marker else {}));self.clock(period)
            need(isinstance(response.get('Tags'),list),'KEY_TAG_RESPONSE')
            for tag in response['Tags']:
                need(type(tag) is dict and set(tag)=={'TagKey','TagValue'} and all(type(v) is str for v in tag.values()) and tag['TagKey'] not in tags,'KEY_TAG_SCHEMA');tags[tag['TagKey']]=tag['TagValue']
            if not response.get('Truncated'):
                need(not response.get('NextMarker'),'KEY_TAG_PAGINATION');return tags
            marker=response.get('NextMarker');need(isinstance(marker,str) and marker,'KEY_TAG_PAGINATION')
        raise Unavailable('KEY_TAG_DISCOVERY_INCOMPLETE')
    def metadata(self,arn,period,observed_tags=None):
        self.clock(period);data=self.kms.describe_key(KeyId=key_arn(arn))['KeyMetadata'];self.clock(period)
        need(data.get('Arn')==arn and data.get('KeyId')==arn.rsplit('/',1)[1],'KEY_METADATA_BINDING')
        created=data.get('CreationDate');need(isinstance(created,datetime) and created.tzinfo is not None,'KEY_CREATION_DATE')
        value={'arn':arn,'keyState':data.get('KeyState'),'keySpec':data.get('KeySpec'),'keyUsage':data.get('KeyUsage'),'origin':data.get('Origin'),'keyManager':data.get('KeyManager'),'multiRegion':data.get('MultiRegion'),'createdAtEpoch':int(created.timestamp()),'tags':self.tags(arn,period) if observed_tags is None else observed_tags}
        return validate_metadata(value,tags_for(period))
    def discover(self,period):
        expected=tags_for(period);marker=None;seen=set();matches=[]
        for page in range(1,11):
            self.clock(period);response=self.kms.list_keys(Limit=100,**({'Marker':marker} if marker else {}));self.clock(period)
            need(type(response.get('Keys')) is list,'KEY_LIST_SCHEMA')
            for entry in response['Keys']:
                arn=discovery_key_arn(entry.get('KeyArn'));need(arn not in seen,'DUPLICATE_KEY_LIST_ENTRY');seen.add(arn)
                self.clock(period);metadata=self.kms.describe_key(KeyId=arn)['KeyMetadata'];self.clock(period)
                need(metadata.get('Arn')==arn and metadata.get('KeyId')==arn.rsplit('/',1)[1] and metadata.get('KeyManager') in ('AWS','CUSTOMER'),'DISCOVERY_METADATA_BINDING')
                # AWS-managed keys cannot be candidate customer HMAC keys; their tags may be inaccessible.
                # Never skip CUSTOMER keys, missing metadata or any DescribeKey denial.
                if metadata['KeyManager']=='AWS':continue
                observed=self.tags(arn,period)
                if all(observed.get(k)==v for k,v in expected.items()):
                    # Extra tags or disabled/wrong-type keys are collisions, not permission to mint another.
                    matches.append(self.metadata(arn,period,observed));need(len(matches)<=1,'DUPLICATE_PERIOD_KEYS')
            if not response.get('Truncated'):
                need(not response.get('NextMarker'),'KEY_LIST_PAGINATION');return {'complete':True,'keysExamined':len(seen),'listPages':page,'matches':matches}
            marker=response.get('NextMarker');need(isinstance(marker,str) and marker,'KEY_LIST_PAGINATION')
        raise Unavailable('KEY_DISCOVERY_INCOMPLETE')
    def plan(self,reuse=None):
        now=self.clock();period=now//PERIOD_SECONDS;self.identity(period);self.registry_absent(period);discovery=self.discover(period);self.registry_absent(period)
        found=discovery['matches'];mode='create';candidate=None
        if found:
            candidate=found[0]['arn'];mode='reuse' if reuse==candidate else 'selection_required'
            need(reuse is None or reuse==candidate,'EXPLICIT_REUSE_MISMATCH')
        else:need(reuse is None,'EXPLICIT_REUSE_NOT_FOUND')
        result={'schemaVersion':1,'operation':OPERATION,'accountId':ACCOUNT,'region':REGION,'tableName':TABLE,'periodSeconds':PERIOD_SECONDS,'periodId':period,'observedAtEpoch':self.clock(period),'tags':tags_for(period),'registryAbsent':True,'discovery':discovery,'mode':mode,'candidateKeyArn':candidate}
        return validate_plan(result)
    def apply(self,plan,digest,doc,save):
        validate_plan(plan);need(re.fullmatch('[0-9a-f]{64}',digest),'PLAN_DIGEST');validate_journal(doc,plan,digest)
        need(plan['mode']!='selection_required','EXPLICIT_REUSE_REQUIRED')
        period=plan['periodId'];self.clock(period);self.identity(period);self.registry_absent(period)
        found=self.discover(period)['matches']
        if doc['createAttempted']:
            # Never call CreateKey again, even when discovery currently returns nothing.
            need(len(found)==1,'AMBIGUOUS_CREATE_KEY')
            candidate=found[0];need(candidate['createdAtEpoch']>=doc['attemptedAtEpoch']-5,'RECOVERY_PREDATES_ATTEMPT')
            need(doc['keyArn'] is None or doc['keyArn']==candidate['arn'],'RECOVERED_KEY_MISMATCH')
            doc.update(keyArn=candidate['arn'],status='key_identified');save(doc)
        elif plan['mode']=='reuse':
            need(len(found)==1 and found[0]['arn']==plan['candidateKeyArn'] and found[0]==plan['discovery']['matches'][0],'REUSE_METADATA_CHANGED')
            doc.update(keyArn=found[0]['arn'],status='key_identified');save(doc)
        else:
            need(not found and doc['keyArn'] is None,'NEW_KEY_COLLISION')
            self.registry_absent(period)
            doc.update(createAttempted=True,attemptedAtEpoch=self.clock(period),status='create_attempted');save(doc)
            self.clock(period)
            try:
                response=self.kms.create_key(KeySpec='HMAC_256',KeyUsage='GENERATE_VERIFY_MAC',Origin='AWS_KMS',MultiRegion=False,Description=f'TrustCheckRadar Dev campaign contributor token period {period}',Tags=[{'TagKey':k,'TagValue':v} for k,v in plan['tags'].items()])
                arn=key_arn(response['KeyMetadata']['Arn']);doc.update(keyArn=arn,status='key_identified');save(doc)
            except Exception:
                # Includes a lost acknowledgement. The attempt marker remains durable.
                doc['status']='key_identified' if doc['keyArn'] else 'ambiguous';save(doc)
                found=self.discover(period)['matches']
                need(len(found)==1 and found[0]['createdAtEpoch']>=doc['attemptedAtEpoch']-5,'AMBIGUOUS_CREATE_KEY')
                need(doc['keyArn'] is None or doc['keyArn']==found[0]['arn'],'RECOVERED_KEY_MISMATCH')
                doc.update(keyArn=found[0]['arn'],status='key_identified');save(doc)
        self.clock(period);self.registry_absent(period);confirmed=self.discover(period)['matches']
        need(len(confirmed)==1 and confirmed[0]['arn']==doc['keyArn'],'POSTCREATE_DISCOVERY_MISMATCH')
        self.metadata(doc['keyArn'],period);self.registry_absent(period);self.clock(period)
        doc['status']='verified';save(doc)
        return {'schemaVersion':1,'keyVerified':True,'periodId':period,'keyArn':doc['keyArn'],'reusedExistingKey':plan['mode']=='reuse','createAttemptRecorded':doc['createAttempted'],'registryWritten':False,'inventoryApproved':False,'runtimeActivated':False,'planSha256':digest}


def strict_json(raw):
    need(len(raw)<=32768,'FILE_SIZE')
    def pairs(items):
        out={}
        for key,value in items:need(key not in out,'DUPLICATE_JSON_FIELD');out[key]=value
        return out
    return json.loads(raw.decode(),object_pairs_hook=pairs,parse_constant=lambda _:(_ for _ in ()).throw(Unavailable('JSON_CONSTANT')))

def save_journal(path,doc):
    # Single serialized root operator; atomic replacement avoids partial journal writes.
    temp=path.with_name(path.name+'.pending')
    with open(temp,'xb') as stream:
        os.chmod(temp,0o600);stream.write((canonical(doc)+'\n').encode());stream.flush();os.fsync(stream.fileno())
    os.replace(temp,path)
    directory=os.open(path.parent,os.O_RDONLY)
    try:os.fsync(directory)
    finally:os.close(directory)


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);mode=parser.add_mutually_exclusive_group()
    mode.add_argument('--plan-out');mode.add_argument('--apply-plan')
    parser.add_argument('--plan-sha256');parser.add_argument('--journal');parser.add_argument('--reuse-key-arn');parser.add_argument('--profile',default='trustcheckradar');args=parser.parse_args(argv)
    clients=[]
    try:
        if args.apply_plan:
            need(args.journal and args.plan_sha256 and args.reuse_key_arn is None,'APPLY_ARGUMENTS')
            raw=Path(args.apply_plan).read_bytes();need(sha(raw)==args.plan_sha256,'PLAN_SHA_MISMATCH');plan=validate_plan(strict_json(raw));need(plan['mode']!='selection_required','EXPLICIT_REUSE_REQUIRED')
            path=Path(args.journal);need(not path.is_symlink() and not path.with_name(path.name+'.pending').exists(),'JOURNAL_PATH')
            if path.exists():doc=validate_journal(strict_json(path.read_bytes()),plan,args.plan_sha256)
            else:
                doc=fresh_journal(plan,args.plan_sha256)
                with open(path,'xb') as stream:
                    os.chmod(path,0o600);stream.write((canonical(doc)+'\n').encode());stream.flush();os.fsync(stream.fileno())
        else:need(args.journal is None and args.plan_sha256 is None,'DRY_RUN_ARGUMENTS')
        import boto3
        from botocore.config import Config
        session=boto3.Session(profile_name=args.profile,region_name=REGION);cfg=Config(connect_timeout=2,read_timeout=3,retries={'total_max_attempts':1})
        clients=[session.client(service,region_name=REGION,config=cfg) for service in ('dynamodb','kms','sts')];operator=Operator(*clients)
        if args.apply_plan:result=operator.apply(plan,args.plan_sha256,doc,lambda value:save_journal(path,value))
        else:
            plan=operator.plan(args.reuse_key_arn);payload=(json.dumps(plan,indent=2,sort_keys=True)+'\n').encode()
            if args.plan_out:
                with open(args.plan_out,'xb') as stream:stream.write(payload)
            result={'dryRun':True,'plan':plan,'planSha256':sha(payload),'scriptSha256':sha(Path(__file__).read_bytes())}
        print(json.dumps(result,sort_keys=True));return 0
    except Exception as exc:
        print(json.dumps({'ok':False,'code':str(exc) if isinstance(exc,Unavailable) else ERROR,'noAutomaticCreateRetry':True,'registryWritten':False,'inventoryApproved':False}));return 1
    finally:
        for client in clients:client.close()
if __name__=='__main__':raise SystemExit(main())
