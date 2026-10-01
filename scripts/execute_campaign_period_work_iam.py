#!/usr/bin/env python3
"""Reviewed, bounded two-table/seven-role IAM fixture. Offline unless --execute.

No caller-supplied policy input, KMS/SQS operation, application data or deployment.
Cleanup-only consumes a strict journal and can only remove tagged fixture names.
"""
import argparse
import copy
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import re
import time
import traceback
import uuid

VALIDATOR_PATH=Path(__file__).with_name('qualify_campaign_period_work_iam.py')
FROZEN_VALIDATOR_SHA256='27e288977d6a62c7e847efb06a007e7bbf8b343fcbeadb1456fcb505fc0af3d3'
spec=importlib.util.spec_from_file_location('period_work_validation',VALIDATOR_PATH)
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
w=v.w;need=v.need;canonical=v.canonical;sha=v.sha;code=w.error_code
ACCOUNT,REGION=v.ACCOUNT,v.REGION
PREFIX='amt-period-work-qual-'
ROLE_SUFFIX={'publisher':'pub','cluster':'clu','deletion':'del','lifecycle':'life','analysis':'ana','account_data':'acct','export':'exp'}
TAGS_BASE={'Project':'trustcheckradar','Environment':'dev','Purpose':'period-work-iam-qualification'}


def now():return datetime.now(timezone.utc).isoformat()
def tags(run):return TAGS_BASE|{'QualificationRun':run}
def tag_list(run):return [{'Key':k,'Value':x} for k,x in tags(run).items()]
def names(run):
    need(re.fullmatch('[a-f0-9]{32}',run),'invalid_run')
    return ({k:PREFIX+run+'-'+k for k in ('pipeline','outbox')},
            {k:PREFIX+run+'-'+s for k,s in ROLE_SUFFIX.items()})


def validate_inputs(processing,api,audit,run):
    need(sha(VALIDATOR_PATH.read_bytes())==FROZEN_VALIDATOR_SHA256,'validator_changed_since_review')
    raw={k:Path(p).read_bytes() for k,p in [('processingPlan',processing),('apiPlan',api),('roleAudit',audit)]}
    result=v.validate_plans(*(json.loads(raw[k]) for k in ('processingPlan','apiPlan','roleAudit')),run_id=run)
    result['inputSha256']={k:sha(b) for k,b in raw.items()}
    for policy in result['syntheticUnions'].values():
        need(len(canonical(policy))<=10240,'fixture_inline_size')
        for st in policy['Statement']:
            need(all(x in {v.ROOT+n for n in names(run)[0].values()} for x in v.seq(st['Resource'])),'live_resource_escape')
    return result


def fsync_directory(path):
    fd=os.open(path,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:os.fsync(fd)
    finally:os.close(fd)


class Journal:
    def __init__(self,path,document=None):
        self.path=Path(path)
        need(self.path.is_absolute() and self.path.parent.is_dir(),'journal_path')
        # Canonicalize only the parent: macOS /tmp is a directory symlink.
        # The journal filename itself must never be followed through a symlink.
        self.path=self.path.parent.resolve(strict=True)/self.path.name
        if document is None:
            need(not self.path.is_symlink(),'journal_symlink');self.data=json.loads(self.path.read_text());validate_journal(self.data)
        else:
            self.data=document;validate_journal(document)
            fd=os.open(self.path,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
            with os.fdopen(fd,'w') as f:f.write(json.dumps(document,sort_keys=True,indent=2)+'\n');f.flush();os.fsync(f.fileno())
            fsync_directory(self.path.parent)
    def save(self):
        validate_journal(self.data);need(not self.path.is_symlink(),'journal_symlink')
        temporary=self.path.with_name(self.path.name+'.next-'+uuid.uuid4().hex)
        fd=os.open(temporary,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
        try:
            with os.fdopen(fd,'w') as f:f.write(json.dumps(self.data,sort_keys=True,indent=2)+'\n');f.flush();os.fsync(f.fileno())
            os.replace(temporary,self.path)
            fsync_directory(self.path.parent)
        finally:
            if temporary.exists():temporary.unlink()
    def attempt(self,kind,name):
        self.data['resources'][kind][name]={'createAttempted':True,'createAcknowledged':False,'createRejected':False,'absenceConfirmed':False};self.save()
    def acknowledged(self,kind,name):self.data['resources'][kind][name]['createAcknowledged']=True;self.save()


def validate_journal(d):
    need(d.get('schemaVersion')==1 and d.get('accountId')==ACCOUNT and d.get('region')==REGION,'journal_scope')
    tables,roles=names(d.get('runId',''))
    need(d.get('tableNames')==tables and d.get('roleNames')==roles and set(d.get('resources',{}))=={'table','role'},'journal_names')
    for kind,allowed in [('table',set(tables.values())),('role',set(roles.values()))]:
        need(set(d['resources'][kind])<=allowed,'journal_resource_escape')
        for status in d['resources'][kind].values():
            need(set(status)=={'createAttempted','createAcknowledged','createRejected','absenceConfirmed'} and all(type(x) is bool for x in status.values()) and status['createAttempted'],'journal_state')
    need(d.get('purpose')==TAGS_BASE['Purpose'],'journal_purpose')


def base_journal(run,evidence):
    tables,roles=names(run)
    return {'schemaVersion':1,'accountId':ACCOUNT,'region':REGION,'purpose':TAGS_BASE['Purpose'],
        'runId':run,'tableNames':tables,'roleNames':roles,'resources':{'table':{},'role':{}},
        'createdAtUtc':now(),'inputSha256':evidence['inputSha256'],
        'validatorSha256':sha(VALIDATOR_PATH.read_bytes()),'executorSha256':sha(Path(__file__).read_bytes()),
        'fixturePolicySha256':{k:v.policy_hash(p) for k,p in evidence['syntheticUnions'].items()},
        'cleanupComplete':False,'cleanupOutstanding':[]}


def exact_principal(sts,iam):
    who=sts.get_caller_identity();need(who['Account']==ACCOUNT,'wrong_account');arn=who['Arn']
    matched=re.fullmatch(f'arn:aws:sts::{ACCOUNT}:assumed-role/([^/]+)/[^/]+',arn)
    if matched:principal=iam.get_role(RoleName=matched.group(1))['Role']['Arn']
    else:need(re.fullmatch(f'arn:aws:iam::{ACCOUNT}:user/.+',arn),'unsupported_caller');principal=arn
    need(re.fullmatch(f'arn:aws:iam::{ACCOUNT}:(?:role|user)/.+',principal),'wrong_principal')
    return principal


def collect_tags(method,**kwargs):
    result=[]
    for _ in range(4):
        response=method(**kwargs);result+=response.get('Tags',[])
        token=response.get('NextToken') or response.get('Marker')
        if not response.get('IsTruncated') and not token:return {x['Key']:x['Value'] for x in result}
        need(type(token) is str,'tag_pagination');kwargs[('Marker' if 'Marker' in response else 'NextToken')]=token
    raise w.QualificationError('tag_pagination_bound')


def absent(method,expected,**kwargs):
    try:method(**kwargs)
    except Exception as e:need(code(e)==expected,'preflight_unavailable');return
    raise w.QualificationError('fixture_name_already_exists')


def create_recorded(journal,kind,name,call):
    # Persist before the service call so a timeout cannot lose cleanup ownership.
    journal.attempt(kind,name)
    try:response=call()
    except Exception as e:
        if code(e) in {'AccessDenied','AccessDeniedException','ValidationException','ValidationError','LimitExceededException','LimitExceeded','InvalidParameterValue'}:
            journal.data['resources'][kind][name]['createRejected']=True;journal.save()
        raise
    journal.acknowledged(kind,name);return response


def cleanup(journal,iam,ddb):
    validate_journal(journal.data);run=journal.data['runId'];outstanding=[]
    for kind,client in [('role',iam),('table',ddb)]:
        for name,state in reversed(list(journal.data['resources'][kind].items())):
            missing='NoSuchEntity' if kind=='role' else 'ResourceNotFoundException'
            found=False
            try:
                if kind=='role':
                    iam.get_role(RoleName=name);found=True
                    need(collect_tags(iam.list_role_tags,RoleName=name)==tags(run),'cleanup_ownership')
                    # Revoke only this fixture policy. Unexpected attachments or
                    # inline sources remain for owner review, never auto-deleted.
                    try:iam.delete_role_policy(RoleName=name,PolicyName='fixture')
                    except Exception as e:need(code(e)=='NoSuchEntity','cleanup_policy_failed')
                    inline=iam.list_role_policies(RoleName=name);managed=iam.list_attached_role_policies(RoleName=name)
                    need(not inline.get('PolicyNames') and not inline.get('IsTruncated') and not managed.get('AttachedPolicies') and not managed.get('IsTruncated'),'cleanup_unexpected_policy')
                    iam.delete_role(RoleName=name)
                    for attempt in range(12):
                        try:iam.get_role(RoleName=name)
                        except Exception as e:need(code(e)=='NoSuchEntity','cleanup_role_readback');break
                        need(attempt<11,'cleanup_role_timeout');time.sleep(2)
                else:
                    table=ddb.describe_table(TableName=name)['Table'];found=True
                    need(table['TableArn']==v.ROOT+name,'cleanup_table_arn')
                    need(collect_tags(ddb.list_tags_of_resource,ResourceArn=v.ROOT+name)==tags(run),'cleanup_ownership')
                    if table['TableStatus']!='DELETING':
                        if table['TableStatus']!='ACTIVE':w.wait_table(ddb,name,True)
                        ddb.delete_table(TableName=name)
                    w.wait_table(ddb,name,False)
                state['absenceConfirmed']=True
            except Exception as e:
                if code(e)==missing and (found or state['createAcknowledged'] or state['createRejected'] or state['absenceConfirmed']):state['absenceConfirmed']=True
                else:outstanding.append({'kind':kind,'name':name,'reason':str(e) if isinstance(e,w.QualificationError) else 'cleanup_unconfirmed'})
            journal.save()
    journal.data['cleanupOutstanding']=outstanding;journal.data['cleanupComplete']=not outstanding
    journal.data['cleanupObservedAtUtc']=now();journal.save();return not outstanding


def key(pk,sk='STATE'):return {'PK':{'S':pk},'SK':{'S':sk}}
def row(pk,revision=1,sk='STATE'):return key(pk,sk)|{'revision':{'N':str(revision)},'expiresAt':{'N':'2000000000'}}
def read(client,table,pk,sk='STATE'):return client.get_item(TableName=table,Key=key(pk,sk),ConsistentRead=True).get('Item')
def check(table,pk,revision=1,rv='NONE'):
    return {'ConditionCheck':{'TableName':table,'Key':key(pk),'ConditionExpression':'revision = :r','ExpressionAttributeValues':{':r':{'N':str(revision)}},'ReturnValuesOnConditionCheckFailure':rv}}
def mutation(kind,table,pk):
    op={'TableName':table,'Item' if kind=='Put' else 'Key':row(pk) if kind=='Put' else key(pk),'ReturnValuesOnConditionCheckFailure':'NONE'}
    if kind=='Update':op.update(UpdateExpression='SET revision = :r',ExpressionAttributeValues={':r':{'N':'2'}})
    return {kind:op}
def canceled(call,index,count):
    try:call()
    except Exception as e:
        need(code(e)=='TransactionCanceledException','unexpected_cancellation');reasons=getattr(e,'response',{}).get('CancellationReasons',[])
        need(len(reasons)==count and reasons[index].get('Code')=='ConditionalCheckFailed' and all('Item' not in r for r in reasons),'invalid_cancellation_evidence');return
    raise w.QualificationError('transaction_did_not_cancel')


def case_keys(kind,label):
    token=sha((kind+':'+label).encode())
    return {'work':'PERIOD_WORK#'+token,'lookup':'WORK_LOOKUP#'+token,'control':'PERIOD_WORK_CONTROL#'+token,
            'inventory':'INVENTORY#dev','period':'PERIOD#'+token,'prefix':'PERIOD_RETIRED_PREFIX#dev'}


def pair_creation(table,k):
    actions=[check(table,k[x]) for x in ('inventory','period','prefix')]
    for item in ('work','lookup'):
        op=mutation('Put',table,k[item]);op['Put']['ConditionExpression']='attribute_not_exists(PK)';actions.append(op)
    update=mutation('Update',table,k['control']);update['Update'].update(ConditionExpression='revision = :old',ExpressionAttributeValues={':r':{'N':'2'},':old':{'N':'1'}});actions.append(update)
    return actions


def prepare(admin,table,k):
    for name in ('inventory','period','prefix','control'):admin.put_item(TableName=table,Item=row(k[name]))
    for name in ('work','lookup'):admin.delete_item(TableName=table,Key=key(k[name]))


def positive_pairs(kind,client,admin,tables,done):
    table=tables['pipeline'];k=case_keys(kind,'positive');prepare(admin,table,k);actions=pair_creation(table,k)
    # Model an acknowledgment lost after successful SDK completion. The second
    # call uses the same DynamoDB idempotency token, not a second allowance/work.
    token=uuid.uuid4().hex
    def lost_ack():client.transact_write_items(TransactItems=actions,ClientRequestToken=token);raise TimeoutError('injected_after_commit')
    try:lost_ack()
    except TimeoutError:pass
    before={x:read(admin,table,k[x]) for x in ('work','lookup','control')}
    client.transact_write_items(TransactItems=actions,ClientRequestToken=token)
    need(before=={x:read(admin,table,k[x]) for x in before} and before['control']['revision']=={'N':'2'},'replay_changed_pair')
    done('pair_creation_and_injected_lost_ack_same_token_replay')
    # Deletion and counter change are atomic under the same inventory/period pins.
    actions=[check(table,k[x]) for x in ('inventory','period','prefix')]+[mutation('Delete',table,k[x]) for x in ('work','lookup')]
    update=mutation('Update',table,k['control']);update['Update'].update(ConditionExpression='revision = :old',ExpressionAttributeValues={':r':{'N':'3'},':old':{'N':'2'}});actions.append(update)
    client.transact_write_items(TransactItems=actions)
    need(read(admin,table,k['work']) is None and read(admin,table,k['lookup']) is None and read(admin,table,k['control'])['revision']=={'N':'3'},'pair_delete_not_observed');done('pair_delete_and_control_cas_atomic')
    for target,index in [('inventory',0),('period',1),('prefix',2),('control',5),('lookup',4)]:
        race=case_keys(kind,'race-'+target);prepare(admin,table,race);admin.put_item(TableName=table,Item=row(race[target],2));actions=pair_creation(table,race)
        before={x:read(admin,table,race[x]) for x in race}
        canceled(lambda:client.transact_write_items(TransactItems=actions),index,len(actions))
        need(before=={x:read(admin,table,race[x]) for x in race},'race_partial_mutation');done(target+'_race_atomic_no_returned_item')


def aggregate_cursor_cases(client,admin,table,done):
    pk='AGGREGATE_SWEEP#dev';admin.put_item(TableName=table,Item=row(pk))
    need(read(client,table,pk)==row(pk),'aggregate_cursor_read');done('aggregate_cursor_read')
    put=mutation('Put',table,pk);put['Put']['Item']=row(pk,2)
    put['Put'].update(ConditionExpression='revision = :r',ExpressionAttributeValues={':r':{'N':'1'}})
    client.transact_write_items(TransactItems=[put]);need(read(admin,table,pk)==row(pk,2),'aggregate_cursor_put')
    done('aggregate_cursor_transaction_put_preserves_deadline')
    for action in ('Put','Update','Delete'):
        if action=='Put':call=lambda:client.put_item(TableName=table,Item=row(pk))
        elif action=='Update':call=lambda:client.update_item(TableName=table,Key=key(pk),UpdateExpression='SET revision=:r',ExpressionAttributeValues={':r':{'N':'3'}})
        else:call=lambda:client.delete_item(TableName=table,Key=key(pk))
        w.denied(call)
    done('aggregate_cursor_standalone_mutations_denied')
    for action in ('Update','Delete'):w.denied(lambda action=action:client.transact_write_items(TransactItems=[mutation(action,table,pk)]))
    w.denied(lambda:client.transact_write_items(TransactItems=[check(table,pk,2)]))
    w.denied(lambda:client.transact_write_items(TransactItems=[mutation('Put',table,'AGGREGATE_SWEEP#uat')]))
    old=copy.deepcopy(put);old['Put']['ReturnValuesOnConditionCheckFailure']='ALL_OLD'
    w.denied(lambda:client.transact_write_items(TransactItems=[old]));done('aggregate_cursor_extra_actions_foreign_and_all_old_denied')
    foreign='EVENT#aggregate-cas-fixture'
    canceled(lambda:client.transact_write_items(TransactItems=[mutation('Put',table,foreign),put]),1,2)
    need(read(admin,table,foreign) is None and read(admin,table,pk)==row(pk,2),'aggregate_cursor_race_partial')
    done('aggregate_cursor_cas_race_atomic_no_returned_item')


def exercise(kind,client,admin,tables,report):
    def done(case):report['cases'].append(kind+':'+case)
    table=tables['pipeline'];k=case_keys(kind,'checks');prepare(admin,table,k)
    for x in ('work','lookup'):admin.put_item(TableName=table,Item=row(k[x]))
    for name in tables.values():
        t=client.describe_table(TableName=name)['Table'];need(t['TableName']==name and t['TableArn']==v.ROOT+name and t['TableStatus']=='ACTIVE','describe_identity')
    done('describe_two_fixture_tables')
    need(read(client,table,k['inventory'])==row(k['inventory']),'inventory_read');done('inventory_read_allowed')
    if kind=='export':
        w.denied(lambda:read(client,table,k['work']));w.denied(lambda:client.transact_write_items(TransactItems=[check(table,k['inventory'])]));done('export_no_work_read_or_check_authority')
    else:
        for x in ('work','lookup','control','period','prefix'):
            need(read(client,table,k[x])==row(k[x]),'work_read');client.transact_write_items(TransactItems=[check(table,k[x])])
        done('work_control_lookup_period_prefix_reads_and_checks')
        for x in ('work','lookup','control','inventory'):
            w.denied(lambda x=x:client.transact_write_items(TransactItems=[check(table,k[x],99,'ALL_OLD')]))
        done('new_namespace_all_old_denied')
    if kind not in ('analysis','export'):positive_pairs(kind,client,admin,tables,done)
    elif kind=='analysis':
        for table_name,pk in [(table,k['work']),(tables['outbox'],'EVENT#retired')]:
            for action in ('Put','Update','Delete'):w.denied(lambda action=action,table_name=table_name,pk=pk:client.transact_write_items(TransactItems=[mutation(action,table_name,pk)]))
        done('retired_analysis_explicit_write_deny_preserved')
    # These new namespaces do not overlap any legacy mutation grant.
    for target in ('work','lookup','control'):
        for action in ('Put','Update','Delete'):
            op=next(iter(mutation(action,table,k[target]).values()));method={'Put':client.put_item,'Update':client.update_item,'Delete':client.delete_item}[action]
            w.denied(lambda method=method,op=op:method(**op))
    done('new_namespace_standalone_mutations_denied')
    for target,actions in [('control',('Put','Delete')),('inventory',('Put','Update','Delete')),('period',('Put','Delete'))]:
        for action in actions:w.denied(lambda action=action,target=target:client.transact_write_items(TransactItems=[mutation(action,table,k[target])]))
    done('control_bootstrap_delete_inventory_writes_registry_put_delete_denied')
    for action in ('Put','Update','Delete'):w.denied(lambda action=action:client.transact_write_items(TransactItems=[mutation(action,table,'OTHER#foreign')]))
    w.denied(lambda:client.transact_write_items(TransactItems=[check(table,'OTHER#foreign')]))
    done('foreign_partition_writes_and_checks_denied')
    for name in tables.values():w.denied(lambda name=name:client.scan(TableName=name))
    done('two_table_scan_denied')
    # Explicitly preserve old wider behavior rather than manufacturing a denial.
    if kind in ('publisher','cluster','deletion','lifecycle'):
        admin.put_item(TableName=table,Item=row('OTHER#read'));need(read(client,table,'OTHER#read')==row('OTHER#read'),'legacy_broad_read');done('existing_broad_pipeline_read_preserved')
        client.transact_write_items(TransactItems=[mutation('Put',table,'EVENT#legacy-'+kind)]);done('existing_target_transaction_put_preserved')
    if kind=='lifecycle':
        if report.get('roleEvidence',{}).get('lifecycle',{}).get('aggregatePolicySha256'):
            aggregate_cursor_cases(client,admin,table,done)
        client.put_item(TableName=table,Item=row('EVENT#standalone'));client.delete_item(TableName=table,Key=key('EVENT#standalone'));done('existing_standalone_target_write_preserved')
        for pk in ('PERIOD_SWEEP#dev','PERIOD_RETIRED_PREFIX#dev'):
            client.transact_write_items(TransactItems=[mutation('Put',table,pk)]);client.transact_write_items(TransactItems=[check(table,pk)])
            client.transact_write_items(TransactItems=[mutation('Update',table,pk)]);need(read(admin,table,pk)['revision']=={'N':'2'},'lifecycle_progress')
            w.denied(lambda pk=pk:client.transact_write_items(TransactItems=[mutation('Delete',table,pk)]))
        done('lifecycle_cursor_prefix_progress_no_delete')
        admin.put_item(TableName=tables['outbox'],Item=row('ACCOUNT#fixture'));client.transact_write_items(TransactItems=[mutation('Delete',tables['outbox'],'ACCOUNT#fixture')]);need(read(admin,tables['outbox'],'ACCOUNT#fixture') is None,'outbox_delete')
        w.denied(lambda:client.delete_item(TableName=tables['outbox'],Key=key('ACCOUNT#fixture')));done('lifecycle_outbox_transaction_delete_only')
    if kind=='account_data':
        admin.put_item(TableName=tables['outbox'],Item=row('EVENT#legacy'));client.delete_item(TableName=tables['outbox'],Key=key('EVENT#legacy'));done('existing_account_outbox_standalone_delete_preserved')
    if kind=='export':
        for pk in ('EVENT#export','ACCOUNT#export'):
            admin.put_item(TableName=tables['outbox'],Item=row(pk));need(read(client,tables['outbox'],pk)==row(pk),'export_legacy_read')
        for name,pk in [(table,k['work']),(tables['outbox'],'EVENT#export')]:
            for action in ('Put','Update','Delete'):w.denied(lambda action=action,name=name,pk=pk:client.transact_write_items(TransactItems=[mutation(action,name,pk)]))
        done('export_existing_owned_reads_and_mutation_refusal')


def validate_fixture_evidence(evidence,journal):
    validate_journal(journal.data);run_id=journal.data['runId'];tables,_=names(run_id)
    need(evidence.get('fixtureRunId')==run_id and set(evidence.get('syntheticUnions',{}))==set(ROLE_SUFFIX),'evidence_namespace')
    need(evidence.get('inputSha256')==journal.data['inputSha256'],'evidence_inputs')
    for kind,policy in evidence['syntheticUnions'].items():
        need(v.policy_hash(policy)==journal.data['fixturePolicySha256'][kind] and len(canonical(policy))<=10240,'evidence_policy_changed')
        for st in policy['Statement']:
            need(set(v.seq(st['Resource']))<={v.ROOT+n for n in tables.values()}
                 and set(v.seq(st['Action']))<=v.DDB_ACTIONS,'evidence_resource_escape')


def authorization_reason(error):
    # Classify service wording in memory; persist only fixed categories.
    raw=getattr(error,'response',{}).get('Error',{}).get('Message','')
    if not isinstance(raw,str):return 'not_reported'
    text=raw.lower()
    for phrase,label in [('service control policy','service_control_policy'),('permissions boundary','permissions_boundary'),
      ('vpc endpoint policy','vpc_endpoint_policy'),('resource-based policy','resource_policy'),
      ('explicit deny','explicit_deny'),('no identity-based policy allows','identity_allow_missing')]:
        if phrase in text:return label
    return 'not_reported'


def diagnostic(error):
    # Fixed metadata only: never exception text, response bodies or local values.
    aws_code=code(error)
    return {'exceptionType':type(error).__name__ if re.fullmatch('[A-Za-z0-9_]{1,100}',type(error).__name__) else 'Unknown',
      'awsErrorCode':aws_code if isinstance(aws_code,str) and re.fullmatch('[A-Za-z0-9_]{1,100}',aws_code) else None,
      'authorizationReason':authorization_reason(error),
      'frames':[{'file':Path(f.filename).name,'function':f.name,'line':f.lineno} for f in traceback.extract_tb(error.__traceback__)[-8:]]}


def propagation_probe(client,table,*,verified_credentials_epoch=None):
    # Only these fixed read-only probes retry propagation, never test cases.
    # UnrecognizedClient is eligible only for just-minted, identity-verified STS credentials.
    retries={}
    for attempt in range(40):
        try:
            client.describe_table(TableName=table)
            client.get_item(TableName=table,Key=key('INVENTORY#dev'),ConsistentRead=True)
            return {'attempts':attempt+1,'retryCodes':retries}
        except Exception as e:
            error=code(e)
            fresh_unknown=(error=='UnrecognizedClientException' and verified_credentials_epoch is not None and 0<=time.monotonic()-verified_credentials_epoch<=60)
            if error not in ('AccessDenied','AccessDeniedException') and not fresh_unknown:raise
            if attempt==39:raise
            retries[error]=retries.get(error,0)+1
            time.sleep(3)


def verify_assumed_identity(client,role_name):
    identity=client.get_caller_identity()
    need(identity.get('Account')==ACCOUNT and identity.get('Arn')==f'arn:aws:sts::{ACCOUNT}:assumed-role/{role_name}/period-work-qualification','assumed_identity_mismatch')


def run(session,evidence,journal):
    validate_fixture_evidence(evidence,journal)
    import boto3
    from botocore.config import Config
    config=Config(connect_timeout=5,read_timeout=15,retries={'total_max_attempts':1})
    sts,iam,ddb=[session.client(x,region_name=REGION,config=config,**({'endpoint_url':f'https://sts.{REGION}.amazonaws.com'} if x=='sts' else {})) for x in ('sts','iam','dynamodb')]
    clients=[];tables,roles=names(journal.data['runId']);run_id=journal.data['runId']
    report={'schemaVersion':1,'observedAtUtc':now(),'accountId':ACCOUNT,'region':REGION,'runId':run_id,
        'inputSha256':evidence['inputSha256'],'validatorSha256':sha(VALIDATOR_PATH.read_bytes()),
        'executorSha256':sha(Path(__file__).read_bytes()),'writerHelperSha256':sha(v._HELPER.read_bytes()),
        'fixturePolicySha256':journal.data['fixturePolicySha256'],'roleEvidence':evidence['roles'],
        'omittedStatements':evidence['omittedStatements'],'cloudExecuted':True,'passed':False,'cases':[],'credentialPropagation':{},
        'limitations':evidence['limitations']+['Two synthetic base tables and seven temporary assumed roles; not live role/SCP/resource-policy acceptance.',
            'Fixed synthetic transaction fields are a partial IAM contract test, not production handlers, period erasure or retention approval.',
            'Lost acknowledgment is injected after a successful SDK return; same-token replay is not an uncontrolled network failure.',
            'No KMS, SQS, streams, native restores, application data or marker changes.'], 'journalPath':str(journal.path)}
    try:
        principal=exact_principal(sts,iam)
        for name in tables.values():absent(ddb.describe_table,'ResourceNotFoundException',TableName=name)
        for name in roles.values():absent(iam.get_role,'NoSuchEntity',RoleName=name)
        for name in tables.values():
            create_recorded(journal,'table',name,lambda name=name:ddb.create_table(TableName=name,BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':'PK','KeyType':'HASH'},{'AttributeName':'SK','KeyType':'RANGE'}],AttributeDefinitions=[{'AttributeName':x,'AttributeType':'S'} for x in ('PK','SK')],StreamSpecification={'StreamEnabled':False},Tags=tag_list(run_id)))
            w.wait_table(ddb,name,True)
            need(ddb.describe_table(TableName=name)['Table']['TableArn']==v.ROOT+name and collect_tags(ddb.list_tags_of_resource,ResourceArn=v.ROOT+name)==tags(run_id),'fixture_table_readback')
            need(ddb.describe_continuous_backups(TableName=name)['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['PointInTimeRecoveryStatus']=='DISABLED','fixture_pitr')
        for kind,name in roles.items():
            trust={'Version':'2012-10-17','Statement':[{'Effect':'Allow','Principal':{'AWS':principal},'Action':'sts:AssumeRole'}]}
            created=create_recorded(journal,'role',name,lambda name=name:iam.create_role(RoleName=name,AssumeRolePolicyDocument=canonical(trust),MaxSessionDuration=3600,Tags=tag_list(run_id)))
            need(created['Role']['Arn']==f'arn:aws:iam::{ACCOUNT}:role/{name}','fixture_role_arn')
            need(iam.get_role(RoleName=name)['Role']['AssumeRolePolicyDocument']==trust and collect_tags(iam.list_role_tags,RoleName=name)==tags(run_id),'fixture_trust_tags_readback')
            policy=evidence['syntheticUnions'][kind];iam.put_role_policy(RoleName=name,PolicyName='fixture',PolicyDocument=canonical(policy))
            need(v.equivalent(iam.get_role_policy(RoleName=name,PolicyName='fixture')['PolicyDocument'],policy),'fixture_policy_readback')
            credentials=None
            for attempt in range(12):
                try:credentials=sts.assume_role(RoleArn=created['Role']['Arn'],RoleSessionName='period-work-qualification',DurationSeconds=900)['Credentials'];break
                except Exception as e:need(code(e) in ('AccessDenied','AccessDeniedException'),'assume_failed');need(attempt<11,'assume_timeout');time.sleep(3)
            minted=time.monotonic()
            auth={'aws_access_key_id':credentials['AccessKeyId'],'aws_secret_access_key':credentials['SecretAccessKey'],'aws_session_token':credentials['SessionToken']}
            assumed_sts=boto3.client('sts',region_name=REGION,endpoint_url=f'https://sts.{REGION}.amazonaws.com',config=config,**auth);clients.append(assumed_sts)
            client=boto3.client('dynamodb',region_name=REGION,config=config,**auth);clients.append(client);del credentials,auth
            verify_assumed_identity(assumed_sts,name)
            report['credentialPropagation'][kind]=propagation_probe(client,tables['pipeline'],verified_credentials_epoch=minted)
            report['credentialPropagation'][kind]['assumedIdentityVerified']=True
            exercise(kind,client,ddb,tables,report)
        report['passed']=True
    except Exception as e:
        report['failure']=str(e) if isinstance(e,w.QualificationError) else 'fixture_operation_failed'
        report['failureDiagnostic']=diagnostic(e)
    finally:
        try:report['cleanupComplete']=cleanup(journal,iam,ddb)
        except Exception:report['cleanupComplete']=False;report['cleanupFailure']='journal_or_cleanup_unavailable'
        report['cleanupOutstanding']=journal.data['cleanupOutstanding'];report['finishedAtUtc']=now()
        for client in clients+[sts,iam,ddb]:client.close()
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--processing-plan');p.add_argument('--api-plan');p.add_argument('--role-audit');p.add_argument('--profile',default='trustcheckradar');p.add_argument('--journal');p.add_argument('--output');modes=p.add_mutually_exclusive_group();modes.add_argument('--execute',action='store_true');modes.add_argument('--cleanup-only',action='store_true');a=p.parse_args()
    try:
        if a.output:
            output=Path(a.output)
            need(output.is_absolute() and output.parent.is_dir() and not output.exists() and not output.is_symlink(),'output_path_or_exists')
            need(not a.journal or output.absolute()!=Path(a.journal).absolute(),'output_journal_conflict')
        if a.cleanup_only:
            need(bool(a.journal),'journal_required');journal=Journal(a.journal)
            import boto3
            from botocore.config import Config
            s=boto3.Session(profile_name=a.profile,region_name=REGION);cfg=Config(connect_timeout=5,read_timeout=15,retries={'total_max_attempts':1});sts,iam,ddb=[s.client(x,region_name=REGION,config=cfg) for x in ('sts','iam','dynamodb')]
            try:exact_principal(sts,iam);complete=cleanup(journal,iam,ddb)
            finally:
                for client in (sts,iam,ddb):client.close()
            result={'cleanupComplete':complete,'cleanupOutstanding':journal.data['cleanupOutstanding'],'cleanupOnly':True}
        else:
            need(all((a.processing_plan,a.api_plan,a.role_audit)),'plans_and_audit_required')
            run_id=uuid.uuid4().hex;evidence=validate_inputs(a.processing_plan,a.api_plan,a.role_audit,run_id)
            if not a.execute:result={'validationPassed':True,'cloudExecuted':False,'inputSha256':evidence['inputSha256'],'fixturePolicyCharacters':{k:len(canonical(x)) for k,x in evidence['syntheticUnions'].items()}}
            else:
                need(bool(a.journal) and bool(a.output),'journal_and_output_required');need(not Path(a.output).exists() and Path(a.output).absolute()!=Path(a.journal).absolute(),'output_exists_or_conflict')
                journal=Journal(a.journal,base_journal(run_id,evidence))
                import boto3
                result=run(boto3.Session(profile_name=a.profile,region_name=REGION),evidence,journal)
        if a.output:
            fd=os.open(a.output,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
            with os.fdopen(fd,'w') as f:f.write(json.dumps(result,indent=2,sort_keys=True)+'\n');f.flush();os.fsync(f.fileno())
        print(json.dumps(result if not a.execute else {k:result[k] for k in ('passed','cleanupComplete','cleanupOutstanding','journalPath')},sort_keys=True))
        return 0 if result.get('validationPassed') or result.get('cleanupComplete') and (a.cleanup_only or result.get('passed')) else 1
    except Exception as e:
        print(json.dumps({'passed':False,'failure':str(e) if isinstance(e,w.QualificationError) else 'setup_or_report_failed','cleanupRequired':bool(a.execute or a.cleanup_only),'journalPath':a.journal}));return 1
if __name__=='__main__':raise SystemExit(main())
