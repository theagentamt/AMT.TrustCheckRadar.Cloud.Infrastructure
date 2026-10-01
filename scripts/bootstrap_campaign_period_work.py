#!/usr/bin/env python3
"""Dev-only external inventory bootstrap. Plan is read-only; apply needs review.

Full strong scans plus a closed/drained operator boundary are required. DynamoDB
cannot condition absence of arbitrary unknown items across a whole table. The
reviewer/operator must serialize all privileged writes/restores through apply.
No raw records, contributor identifiers, environment values or actions are saved.
"""
import argparse
from contextlib import contextmanager
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

ACCOUNT='107827791950';REGION='us-east-1';ENV='dev';PREFIX='trustcheckradar-dev-'
TABLES={k:PREFIX+'campaign-'+k for k in ('pipeline','outbox','intelligence')}
FUNCTIONS={k:PREFIX+v for k,v in {
 'conversation_analysis':'conversation-analysis','account_data_api':'account-data-api',
 'campaign_observation_publisher':'campaign-observation-publisher','campaign_cluster_aggregator':'campaign-cluster-aggregator',
 'campaign_deletion_bridge':'campaign-deletion-bridge','campaign_lifecycle':'campaign-lifecycle',
 'account_export_api':'account-export-api','campaign_review':'campaign-review'}.items()}
GATES={k:['CAMPAIGN_PERIOD_WORK_ENABLED'] for k in FUNCTIONS}
GATES['campaign_review']=[]
GATES['account_data_api']+=['ACCOUNT_DELETION_ENABLED','ACCOUNT_IDENTITY_FINALIZER_ENABLED']
GATES['account_export_api']+=['ACCOUNT_EXPORT_ENABLED']
GATES['campaign_lifecycle']+=['CAMPAIGN_LIFECYCLE_CANDIDATE_ENABLED','CAMPAIGN_PERIOD_LIFECYCLE_ENABLED','CAMPAIGN_PERIOD_RETIREMENT_ENABLED']
GATES['campaign_deletion_bridge']+=['CAMPAIGN_DELETION_STREAM_ENABLED','CAMPAIGN_COMPLETION_ENABLED','CAMPAIGN_RECOVERY_ENABLED']
MANIFEST_FIELDS={'schemaVersion','accountId','region','environment','sourceCommit','sourceTreeSha256','resources','functions','marker','locatorSha256','retiredRegistrySha256','retiredExclusionReference','expectedCounts'}
COUNTS={'enabledRegistries':2,'excludedRegistries':1,'terminalTombstones':3,'locatorInventory':1,'outbox':0,'intelligence':0}

class Refusal(RuntimeError):pass
def need(ok,reason):
    if not ok:raise Refusal(reason)
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'))
def digest(value):return hashlib.sha256(value if isinstance(value,bytes) else canonical(value).encode()).hexdigest()
def sha(value):need(type(value) is str and re.fullmatch('[0-9a-f]{64}',value),'invalid_digest');return value
def integer(value,low=0):need(type(value) is int and value>=low,'invalid_integer');return value
def identifier(value):
    try:need(type(value) is str and str(uuid.UUID(value))==value,'invalid_uuid')
    except (ValueError,TypeError,AttributeError):raise Refusal('invalid_uuid') from None
    return value

def validate_manifest(m):
    need(type(m) is dict and set(m)==MANIFEST_FIELDS,'manifest_schema')
    need(m['schemaVersion']==1 and m['accountId']==ACCOUNT and m['region']==REGION and m['environment']==ENV,'manifest_scope')
    need(re.fullmatch('[0-9a-f]{40}',m['sourceCommit']) is not None,'source_commit');sha(m['sourceTreeSha256']);sha(m['locatorSha256']);sha(m['retiredRegistrySha256'])
    need(type(m['retiredExclusionReference']) is str and 1<=len(m['retiredExclusionReference'])<=200,'retired_exclusion_review')
    need(m['expectedCounts']==COUNTS,'unsupported_baseline_counts')
    need(set(m['resources'])==set(TABLES) and set(m['functions'])==set(FUNCTIONS),'manifest_inventory')
    for kind,r in m['resources'].items():
        need(set(r)=={'tableName','tableId'} and r['tableName']==TABLES[kind],'resource_scope');identifier(r['tableId'])
    for kind,f in m['functions'].items():
        need(set(f)=={'codeSha256','roleArn','configurationSha256'},'function_schema')
        sha(f['codeSha256']);sha(f['configurationSha256'])
        need(re.fullmatch(f'arn:aws:iam::{ACCOUNT}:role/trustcheckradar-dev-[A-Za-z0-9_-]+',f['roleArn']),'role_scope')
    return m

def source_tree(root):
    root=Path(root).resolve(strict=True);src=root/'src';need(src.is_dir(),'source_directory')
    files=sorted(src.rglob('*.py'));need(0<len(files)<=2000,'source_bound')
    need(all(not f.is_symlink() and f.resolve().is_relative_to(src) for f in files),'source_symlink')
    return digest({str(f.relative_to(src)):digest(f.read_bytes()) for f in files})

def load_source(root,m):
    root=Path(root).resolve(strict=True)
    def git(*args):return subprocess.check_output(['git','-C',str(root),*args],stderr=subprocess.DEVNULL,text=True).strip()
    need(git('rev-parse','HEAD')==m['sourceCommit'],'source_commit_mismatch')
    need(not git('status','--porcelain','--untracked-files=all','--','src'),'source_not_frozen')
    need(source_tree(root)==m['sourceTreeSha256'],'source_tree_mismatch')
    sys.path.insert(0,str(root/'src'))
    B=importlib.import_module('shared_campaign_work.bootstrap');C=importlib.import_module('shared_campaign_work.configuration');P=importlib.import_module('shared_campaign_locators.period');L=importlib.import_module('shared_campaign_locators.core')
    need(all(Path(x.__file__).resolve().is_relative_to(root/'src') for x in (B,C,P,L)),'source_import_collision')
    return B,C,P,L

@contextmanager
def planner_environment(m):
    marker=m['marker'];values={'APP_ENVIRONMENT':ENV,'AWS_REGION':REGION,'CAMPAIGN_PERIOD_ADMISSION_ACCOUNT_ID':ACCOUNT,
      'CAMPAIGN_PERIOD_ADMISSION_ENABLED':'true','CAMPAIGN_PERIOD_ADMISSION_GENERATION':marker['admissionGeneration'],
      'CAMPAIGN_PERIOD_WORK_ENABLED':'true','CAMPAIGN_PERIOD_WORK_MANIFEST_SHA256':marker['manifestSha256'],
      'CAMPAIGN_PERIOD_WORK_INVENTORY_REVISION':str(marker['revision'])}
    for k in ('pipeline','outbox'):
        values['CAMPAIGN_PERIOD_WORK_'+k.upper()+'_TABLE_NAME']=m['resources'][k]['tableName']
        values['CAMPAIGN_PERIOD_WORK_'+k.upper()+'_TABLE_ID']=m['resources'][k]['tableId']
    before={k:os.environ.get(k) for k in values};os.environ.update(values)
    try:yield
    finally:
        for k,v in before.items():
            if v is None:os.environ.pop(k,None)
            else:os.environ[k]=v

def pages(method,result_key,*,request_token='NextToken',response_token='NextToken',bound=16,**kw):
    result=[];seen=set()
    for _ in range(bound):
        response=method(**kw);part=response.get(result_key,[]);need(type(part) is list,'page_shape');result+=part
        need(len(result)<=1000,'metadata_count_bound');token=response.get(response_token)
        if not token:return result
        need(type(token) is str and token not in seen,'pagination_invalid');seen.add(token);kw[request_token]=token
    raise Refusal('metadata_truncated')

def scan(ddb,table):
    rows=[];seen=set();kw={'TableName':table,'ConsistentRead':True,'Limit':32}
    for _ in range(16):
        page=ddb.scan(**kw);items=page.get('Items');need(type(items) is list,'scan_shape');rows+=items
        need(len(rows)<=128,'scan_record_bound')
        token=page.get('LastEvaluatedKey')
        if not token:
            keys=[canonical({k:r.get(k) for k in ('PK','SK')}) for r in rows]
            need(len(set(keys))==len(keys),'duplicate_scan_key');return sorted((json.loads(canonical(row)) for row in rows),key=canonical)
        token_hash=digest(token);need(token_hash not in seen,'scan_cursor_repeat');seen.add(token_hash);kw['ExclusiveStartKey']=token
    raise Refusal('scan_truncated')

def resources(ddb,m):
    report={}
    for family,name in TABLES.items():
        table=ddb.describe_table(TableName=name)['Table']
        need(table.get('TableArn')==f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{name}' and table.get('TableStatus')=='ACTIVE'
          and table.get('TableName')==name and table.get('TableId')==m['resources'][family]['tableId'],'table_binding')
        need(table.get('KeySchema')==[{'AttributeName':'PK','KeyType':'HASH'},{'AttributeName':'SK','KeyType':'RANGE'}],'table_schema')
        report[family]={'tableName':name,'tableId':table['TableId']}
    return report

def closed_writers(lam,scheduler,m):
    report={};max_timeout=0;arns={}
    for kind,name in FUNCTIONS.items():
        cfg=lam.get_function_configuration(FunctionName=name);arn=f'arn:aws:lambda:{REGION}:{ACCOUNT}:function:{name}'
        need(cfg.get('FunctionArn')==arn and cfg.get('State')=='Active' and cfg.get('LastUpdateStatus')=='Successful','function_unstable')
        need(lam.get_function_concurrency(FunctionName=name).get('ReservedConcurrentExecutions')==0,'writer_not_closed')
        env=cfg.get('Environment',{}).get('Variables',{})
        need(all(env.get(k)=='false' for k in GATES[kind]),'writer_gate_open_or_absent')
        import base64
        try:code=base64.b64decode(cfg['CodeSha256'],validate=True).hex()
        except Exception:raise Refusal('function_digest_invalid') from None
        need(len(code)==64 and code==m['functions'][kind]['codeSha256'] and cfg['Role']==m['functions'][kind]['roleArn'],'function_source_binding')
        # Store no environment values/subject allowlists. Bind approved config via
        # digest; only known boolean gates, runtime and source metadata enter it.
        config={k:cfg.get(k) for k in ('Runtime','Handler','Architectures','Timeout','MemorySize','RevisionId','Role','CodeSha256')}
        config['closedGates']={k:env.get(k) for k in GATES[kind]}
        need(digest(config)==m['functions'][kind]['configurationSha256'],'configuration_drift')
        aliases=pages(lam.list_aliases,'Aliases',request_token='Marker',response_token='NextMarker',FunctionName=name)
        versions=pages(lam.list_versions_by_function,'Versions',request_token='Marker',response_token='NextMarker',FunctionName=name)
        mappings=pages(lam.list_event_source_mappings,'EventSourceMappings',request_token='Marker',response_token='NextMarker',FunctionName=name)
        need(all(x.get('State')=='Disabled' for x in mappings),'mapping_not_disabled')
        report[kind]={'configurationSha256':digest(config),'aliasesSha256':digest(aliases),
          'versionsSha256':digest([{k:v.get(k) for k in ('Version','CodeSha256','RevisionId','Role','Timeout')} for v in versions]),
          'mappingsSha256':digest([{k:v.get(k) for k in ('UUID','FunctionArn','EventSourceArn','State')} for v in mappings])}
        max_timeout=max(max_timeout,integer(cfg['Timeout'],1),*[integer(v.get('Timeout',cfg['Timeout']),1) for v in versions]);arns[arn]=kind
    groups=pages(scheduler.list_schedule_groups,'ScheduleGroups');schedules=[]
    for group in groups:
        for item in pages(scheduler.list_schedules,'Schedules',GroupName=group['Name']):
            target=item.get('Target',{}).get('Arn','')
            if any(target==arn or target.startswith(arn+':') for arn in arns):
                full=scheduler.get_schedule(Name=item['Name'],GroupName=group['Name'])
                need(full.get('State')=='DISABLED','schedule_not_disabled');schedules.append({k:full.get(k) for k in ('Name','GroupName','State','Target','ScheduleExpression','ScheduleExpressionTimezone','FlexibleTimeWindow')})
    return {'functions':report,'schedulesSha256':digest(schedules),'maximumTimeoutSeconds':max_timeout}

def classify(snapshot,m,modules,now):
    B,C,P,L=modules;config=C.pins();C.validate_marker(m['marker'],config,now)
    need(not snapshot['outbox'] and not snapshot['intelligence'],'nonempty_external_target_table')
    registries=[];tombs=[];excluded=[];locator=[]
    for raw in snapshot['pipeline']:
        row=C.plain(raw);pk=row.get('PK');sk=row.get('SK')
        if type(pk) is str and pk.startswith('PERIOD#') and sk=='HMAC_KEY':
            period=row.get('periodId');need(type(period).__name__ in ('int','Decimal') and period==int(period) and period>=0,'registry_period')
            if period<m['marker']['minimumPeriodId']:
                need(set(row)==P.BASE_FIELDS|{'retiredAtEpoch'} and row['PK']==f'PERIOD#{int(period)}' and row['status']=='RETIRED','retired_registry_shape')
                need(row['retireAfterEpoch']==(int(period)+1)*P.PERIOD_SECONDS+P.RECOVERY_SECONDS,'retired_registry_clock')
                C.integer(row['retiredAtEpoch'],int(row['retireAfterEpoch']),now)
                need(re.fullmatch(f'arn:aws:kms:{REGION}:{ACCOUNT}:key/[0-9a-f-]{{36}}',row['keyArn']),'retired_registry_key')
                identifier(row['keyArn'].rsplit('/',1)[1])
                need(digest(raw)==m['retiredRegistrySha256'],'retired_registry_review_mismatch');excluded.append(row)
            else:registries.append(row)
        elif type(pk) is str and pk.startswith('CONTRIB#') and sk=='TOMBSTONE':B.tombstone(row,config,now);tombs.append(row)
        elif pk=='INVENTORY#dev' and sk=='CAMPAIGN_LOCATORS':
            need(digest(raw)==m['locatorSha256'],'locator_review_mismatch');locator.append(row)
        else:raise Refusal('unknown_pipeline_record')
    counts={'enabledRegistries':len(registries),'excludedRegistries':len(excluded),'terminalTombstones':len(tombs),'locatorInventory':len(locator),'outbox':0,'intelligence':0}
    need(counts==m['expectedCounts'],'baseline_count_mismatch')
    class Observed:
        def get_item(self,**kw):return {'Item':C.wire(locator[0])}
    observed=L.load_inventory(Observed(),TABLES['pipeline'],ENV,m['marker']['locatorManifestSha256'],m['marker']['locatorInventoryRevision'],now)
    first=int(m['marker']['minimumPeriodId']);current=integer(now,1)//P.PERIOD_SECONDS
    need(first<=int(observed['minimumPeriodId'])<=current and 0<=current-first<8,'minimum_period_bounds')
    need({int(row['periodId']) for row in registries}==set(range(first,current+1)),'enabled_registry_coverage_gap')
    # The externally reviewed timestamp is stable across plan/apply. Legacy
    # admission metadata must not silently acquire a new clock during apply.
    actions=B.actions(registries,tombs,m['marker'],config,int(m['marker']['approvedAtEpoch']))
    # Below-minimum metadata is preserved, not promoted to a new erasure proof.
    actions += [C.condition(TABLES['pipeline'],x) for x in excluded]
    actions += [L.inventory_condition(TABLES['pipeline'],observed),{'Put':{'TableName':TABLES['pipeline'],'Item':C.wire(m['marker']),'ConditionExpression':'attribute_not_exists(PK) AND attribute_not_exists(SK)'}}]
    need(len(actions)<=100,'transaction_bound')
    for a in actions:
        op=next(iter(a.values()));need(op['TableName']==TABLES['pipeline'] and len(a)==1 and next(iter(a)) in ('Put','ConditionCheck'),'planner_action_scope')
        op['ReturnValuesOnConditionCheckFailure']='NONE'
    # Independently check duplicate physical keys, irrespective of row content.
    keys=[canonical({k:next(iter(a.values())).get('Key',next(iter(a.values())).get('Item'))[k] for k in ('PK','SK')}) for a in actions]
    need(len(keys)==len(set(keys)),'duplicate_transaction_target')
    return actions,counts

class ReadBudget:
    def __init__(self,client,deadline):self.client,self.deadline=client,deadline
    def __getattr__(self,name):
        method=getattr(self.client,name)
        def bounded(*args,**kwargs):
            need(time.monotonic()<self.deadline,'read_budget_exhausted')
            return method(*args,**kwargs)
        return bounded


def recheck_source(modules,m):
    root=Path(modules[0].__file__).resolve().parents[2]
    load_source(root,m)


def capture(ddb,lam,scheduler,m,modules,now):
    deadline=time.monotonic()+120
    ddb,lam,scheduler=(ReadBudget(client,deadline) for client in (ddb,lam,scheduler))
    r=resources(ddb,m);writers=closed_writers(lam,scheduler,m)
    snapshot={k:scan(ddb,t) for k,t in TABLES.items()}
    actions,counts=classify(snapshot,m,modules,now)
    return {'resources':r,'writers':writers,'snapshotSha256':{k:digest(v) for k,v in snapshot.items()},'counts':counts,'actionsSha256':digest(actions),'actionCount':len(actions)},actions

def write_new(path,value):
    path=Path(path);need(path.is_absolute() and path.parent.is_dir(),'output_path');parent=path.parent.resolve(strict=True);path=parent/path.name
    fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'w') as f:f.write(json.dumps(value,indent=2,sort_keys=True)+'\n');f.flush();os.fsync(f.fileno())
    directory=os.open(parent,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:os.fsync(directory)
    finally:os.close(directory)

def reviewed_apply(ddb,lam,scheduler,m,modules,plan,approval,journal,now=time.time):
    stamp=int(now());need(set(approval)=={'schemaVersion','planSha256','manifestSha256','reviewReference','serializedWriterBoundary','approvalExpiresAtEpoch'},'approval_schema')
    need(approval['schemaVersion']==1 and approval['planSha256']==digest(plan) and approval['manifestSha256']==digest(m)
      and approval['serializedWriterBoundary'] is True and type(approval['reviewReference']) is str and 1<=len(approval['reviewReference'])<=200,'approval_binding')
    need(stamp<=integer(approval['approvalExpiresAtEpoch'],1)<=stamp+3600,'approval_expired')
    need(plan['manifestSha256']==digest(m) and plan['helperSha256']==digest(Path(__file__).read_bytes()),'plan_source_mismatch')
    age=stamp-integer(plan['observedAtEpoch'],1)
    need(plan['observation']['writers']['maximumTimeoutSeconds']+60<=age<=3600,'writer_drain_interval')
    observation,actions=capture(ddb,lam,scheduler,m,modules,stamp)
    need(observation==plan['observation'],'fresh_snapshot_changed')
    # Persist intent before final closure reread and single SDK transaction.
    token=uuid.uuid4().hex
    write_new(journal,{'schemaVersion':1,'state':'APPLY_INTENT_ONLY','attemptId':token,'planSha256':digest(plan),
      'manifestSha256':digest(m),'actionCount':len(actions),'actionsSha256':digest(actions),'recordValuesPersisted':False,
      'ambiguityPolicy':'On any missing acknowledgment, do not replay bootstrap blindly; independently inspect marker/control/index metadata and retain original plan.'})
    recheck_source(modules,m)
    deadline=time.monotonic()+30
    need(resources(ReadBudget(ddb,deadline),m)==observation['resources'] and closed_writers(ReadBudget(lam,deadline),ReadBudget(scheduler,deadline),m)==observation['writers'],'boundary_changed_before_commit')
    need(int(now())-stamp<=60,'freshness_budget')
    try:ddb.transact_write_items(TransactItems=actions,ClientRequestToken=token)
    except Exception:raise Refusal('apply_unconfirmed_preserve_intent_no_blind_retry') from None
    return {'schemaVersion':1,'transactionAcknowledged':True,'planSha256':digest(plan),'actionsSha256':digest(actions),
      'actionCount':len(actions),'independentReadbackRequired':True,'wholeTableAtomicSnapshotClaimed':False}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source-root',required=True);p.add_argument('--manifest',required=True);p.add_argument('--plan',required=True);p.add_argument('--mode',choices=('plan','apply'),default='plan');p.add_argument('--approval');p.add_argument('--journal');p.add_argument('--output');p.add_argument('--profile',default='trustcheckradar');a=p.parse_args()
    try:
        m=validate_manifest(json.loads(Path(a.manifest).read_text()));modules=load_source(a.source_root,m)
        import boto3
        from botocore.config import Config
        cfg=Config(connect_timeout=5,read_timeout=15,retries={'total_max_attempts':1});s=boto3.Session(profile_name=a.profile,region_name=REGION)
        clients={k:s.client(k,region_name=REGION,config=cfg) for k in ('sts','dynamodb','lambda','scheduler')}
        try:
            need(clients['sts'].get_caller_identity()['Account']==ACCOUNT,'wrong_account')
            with planner_environment(m):
                if a.mode=='plan':
                    need(not a.approval and not a.journal and not a.output,'plan_argument_scope');observed=int(time.time())
                    observation,_=capture(clients['dynamodb'],clients['lambda'],clients['scheduler'],m,modules,observed)
                    plan={'schemaVersion':1,'observedAtEpoch':observed,'manifestSha256':digest(m),'helperSha256':digest(Path(__file__).read_bytes()),'observation':observation,'requiresExternalReview':True}
                    write_new(a.plan,plan);result={'planCreated':True,'planSha256':digest(plan),'recordValuesPersisted':False}
                else:
                    need(all((a.approval,a.journal,a.output)),'apply_inputs_required')
                    out=Path(a.output);intent=Path(a.journal)
                    need(out.is_absolute() and out.parent.is_dir() and not out.exists() and not out.is_symlink(),'output_exists_or_path')
                    need(intent.is_absolute() and intent.parent.is_dir() and not intent.exists() and not intent.is_symlink(),'journal_exists_or_path')
                    paths=[Path(x).resolve() for x in (a.output,a.journal,a.manifest,a.plan,a.approval)]
                    need(len(set(paths))==len(paths),'input_output_path_collision')
                    result=reviewed_apply(clients['dynamodb'],clients['lambda'],clients['scheduler'],m,modules,json.loads(Path(a.plan).read_text()),json.loads(Path(a.approval).read_text()),a.journal)
                    write_new(a.output,result)
            print(json.dumps(result,sort_keys=True));return 0
        finally:
            for client in clients.values():client.close()
    except Exception as e:
        print(json.dumps({'passed':False,'reason':str(e) if isinstance(e,Refusal) else 'bootstrap_refused','applyMayNeedReconciliation':a.mode=='apply'}));return 1
if __name__=='__main__':raise SystemExit(main())
