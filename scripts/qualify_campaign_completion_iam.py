#!/usr/bin/env python3
"""Offline-first exact completion users/ledger identity-union qualification.

Execute only after independent review. Disposable tables and an assumed fixture
role exercise IAM and synthetic atomic transaction shapes, not handler semantics.
"""
import argparse
import copy
from datetime import datetime,timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import time
import uuid

ACCOUNT='107827791950';REGION='us-east-1'
ROOT=f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/'
TABLES={n:ROOT+'trustcheckradar-dev-'+('deletion-ledger' if n=='ledger' else n) for n in ('users','ledger')}
ROLE='trustcheckradar-dev-campaign-deletion-bridge-role'
ADDRESS='aws_iam_role_policy.completion_runtime[0]'
PREFIX='amt-completion-iam-'

class QualificationError(Exception):pass

def require(value,code):
    if not value:raise QualificationError(code)
def seq(value):return value if isinstance(value,list) else [value]
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'))
def sha(raw):return hashlib.sha256(raw).hexdigest()
def error_code(exc):return getattr(exc,'response',{}).get('Error',{}).get('Code')
def helper(name):
    path=Path(__file__).with_name(name+'.py')
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

writer=helper('qualify_campaign_writer_iam')
recovery=helper('qualify_campaign_recovery_iam')

def helper_hashes():
    return {n:sha(Path(__file__).with_name(n+'.py').read_bytes()) for n in ('qualify_campaign_writer_iam','qualify_campaign_recovery_iam')}

def specifications():
    lead=lambda prefix:{'ForAllValues:StringLike':{'dynamodb:LeadingKeys':prefix}}
    tx=lambda prefix:{**lead(prefix),'ForAnyValue:StringEquals':{'dynamodb:EnclosingOperation':'TransactWriteItems'},'StringEqualsIfExists':{'dynamodb:ReturnValues':'NONE'}}
    return {
      'QueryOwnedRecoveryJobs':({'dynamodb:Query'},TABLES['ledger'],lead('ACCOUNT#*')),
      'CompleteOwnedCampaignLedger':({'dynamodb:PutItem','dynamodb:DeleteItem'},TABLES['ledger'],tx('ACCOUNT#*')),
      'CompleteOwnedParticipation':({'dynamodb:PutItem'},TABLES['users'],tx('USER#*')),
      'CheckOwnedCompletionProfile':({'dynamodb:ConditionCheckItem'},TABLES['users'],{**lead('USER#*'),'StringEqualsIfExists':{'dynamodb:ReturnValues':'NONE'}})}

def validate_candidate(policy):
    require(isinstance(policy,dict) and set(policy)=={'Version','Statement'} and policy['Version']=='2012-10-17','candidate_schema')
    require(isinstance(policy['Statement'],list),'candidate_statements')
    seen=set();expected=specifications()
    for st in policy['Statement']:
        require(isinstance(st,dict) and set(st)=={'Sid','Effect','Action','Resource','Condition'},'candidate_fields')
        sid=st['Sid'];require(sid in expected and sid not in seen and st['Effect']=='Allow','candidate_sid_effect');seen.add(sid)
        actions,resource,condition=expected[sid]
        actual=seq(st['Action']);require(set(actual)==actions and len(actual)==len(actions),'candidate_actions')
        require(seq(st['Resource'])==[resource],'candidate_resource')
        require(recovery.conditions(st['Condition'])==recovery.conditions(condition),'candidate_conditions')
    require(seen==set(expected),'candidate_missing_statement')
    return copy.deepcopy(policy)

def load_union(plan_path,audit_path):
    plan_raw=Path(plan_path).read_bytes();plan=json.loads(plan_raw)
    matches=[x for x in plan.get('resource_changes',[]) if x.get('address')==ADDRESS]
    require(len(matches)==1,'candidate_plan_address');resource=matches[0];change=resource['change']
    require(resource.get('mode')=='managed' and resource.get('type')=='aws_iam_role_policy','candidate_resource_kind')
    require(change.get('actions')==['create'] and change.get('before') is None and change.get('after_unknown',{}).get('policy') is not True,'candidate_not_known_new_policy')
    after=change['after'];require(after.get('name')=='campaign-completion-candidate' and after.get('role')==ROLE,'candidate_role_binding')
    candidate=validate_candidate(json.loads(after['policy']))
    audit_raw=Path(audit_path).read_bytes();audit=json.loads(audit_raw);role=audit['roles'][ROLE]
    require(role['arn']==f'arn:aws:iam::{ACCOUNT}:role/{ROLE}' and role['permissionsBoundary'] is None and not role['managed'],'role_identity_or_boundary')
    require(set(role['inline'])=={'deletion-runtime','content-free-logging','campaign-recovery-candidate'},'role_policy_inventory')
    logging=role['inline']['content-free-logging']
    require(set(logging)=={'Version','Statement'} and logging['Version']=='2012-10-17' and len(logging['Statement'])==2,'logging_schema')
    for st in logging['Statement']:
        require(set(st)<={'Sid','Effect','Action','Resource','Condition'} and st.get('Effect')=='Allow' and seq(st.get('Action')) and set(seq(st.get('Action'))) <= {'logs:PutLogEvents','logs:CreateLogStream','cloudwatch:PutMetricData'},'logging_overlap')
    deletion,omitted=writer.validate_policy(role['inline']['deletion-runtime'],'deletion')
    old_recovery=recovery.validate_policy(role['inline']['campaign-recovery-candidate'])
    statements=copy.deepcopy(candidate['Statement']);excluded=[{'source':'deletion-runtime',**x} for x in omitted]
    for name,policy in [('deletion-runtime',deletion),('campaign-recovery-candidate',old_recovery)]:
        for st in policy['Statement']:
            resources=seq(st['Resource']);target=[x for x in resources if x in TABLES.values()]
            if target:
                require(len(target)==len(resources),'mixed_scope_statement');statements.append(copy.deepcopy(st))
            else:excluded.append({'source':name,'sid':st['Sid'],'reason':'strict_validated_other_table_index_or_service'})
    excluded.append({'source':'content-free-logging','reason':'strict_logging_actions_disjoint_from_dynamodb'})
    expected=set(specifications())|{'CompleteParticipationWithdrawal','CompleteDeletionLedgerCommand','GuardedDeletionCommand','ReadCampaignRecoveryInventory','CheckCampaignRecoveryInventory','AdvanceOwnedRecoveryRetryTransaction'}
    require(len(statements)==10 and {s['Sid'] for s in statements}==expected,'unexpected_union')
    observed=audit.get('observedAtUtc');require(isinstance(observed,str) and datetime.fromisoformat(observed).tzinfo is not None,'audit_timestamp')
    policy={'Version':'2012-10-17','Statement':statements}
    return policy,{'sourcePlanSha256':sha(plan_raw),'sourceRoleAuditSha256':sha(audit_raw),'roleAuditObservedAtUtc':observed,'candidatePolicySha256':sha(canonical(candidate).encode()),'unionPolicySha256':sha(canonical(policy).encode()),'omittedStatements':excluded,'helperSha256':helper_hashes()}

def remap(policy,names):
    require(set(names)==set(TABLES) and len(set(names.values()))==2,'fixture_table_set')
    for kind,name in names.items():require(re.fullmatch(PREFIX+'[0-9a-f]{32}-'+kind,name),'fixture_table_name')
    mapping={TABLES[k]:ROOT+n for k,n in names.items()};result=copy.deepcopy(policy)
    for st in result['Statement']:
        require(all(r in mapping for r in seq(st['Resource'])) and all(a.startswith('dynamodb:') for a in seq(st['Action'])),'fixture_live_grant')
        st['Resource']=[mapping[r] for r in seq(st['Resource'])]
    require('trustcheckradar-dev-' not in canonical(result),'fixture_live_resource')
    return result

def key(pk,sk):return {'PK':{'S':pk},'SK':{'S':sk}}
def read(c,t,pk,sk):return c.get_item(TableName=t,Key=key(pk,sk),ConsistentRead=True).get('Item')
def put(t,item,condition='attribute_not_exists(PK)',values=None):
    result={'TableName':t,'Item':item,'ConditionExpression':condition,'ReturnValuesOnConditionCheckFailure':'NONE'}
    if values:result['ExpressionAttributeValues']=values
    return {'Put':result}
def check(t,pk,sk,expression='attribute_not_exists(PK)',values=None,rv='NONE'):
    result={'TableName':t,'Key':key(pk,sk),'ConditionExpression':expression,'ReturnValuesOnConditionCheckFailure':rv}
    if values:result['ExpressionAttributeValues']=values
    return {'ConditionCheck':result}
def denied(call):
    try:call()
    except Exception as exc:require(error_code(exc) in ('AccessDenied','AccessDeniedException'),'unexpected_denial_type');return
    raise QualificationError('expected_access_denied')
def canceled(call,index=None):
    try:call()
    except Exception as exc:
        require(error_code(exc)=='TransactionCanceledException','unexpected_cancellation_type')
        reasons=getattr(exc,'response',{}).get('CancellationReasons',[])
        require(reasons and any(x.get('Code')=='ConditionalCheckFailed' for x in reasons),'missing_condition_failure')
        if index is not None:require(len(reasons)>index and reasons[index].get('Code')=='ConditionalCheckFailed','wrong_guard_failure')
        require(all('Item' not in x for x in reasons),'unexpected_returned_item');return
    raise QualificationError('guard_did_not_cancel')

def prepare(admin,names,subject):
    ledger,users=names['ledger'],names['users'];pk='ACCOUNT#'+subject
    for sk in ('COMMAND','CAMPAIGN_RECOVERY#job'):
        admin.put_item(TableName=ledger,Item={**key(pk,sk),'revision':{'N':'1'}})
    admin.put_item(TableName=ledger,Item={**key(pk,'CAMPAIGN_RECOVERY_CONTROL'),'revision':{'N':'1'},'pendingJobs':{'N':'1'},'phase':{'S':'OPEN'}})
    admin.put_item(TableName=users,Item={**key('USER#'+subject,'PROFILE'),'revision':{'N':'1'}})
    admin.put_item(TableName=ledger,Item={**key('INVENTORY#dev','CAMPAIGN_COMPLETION_INVENTORY'),'revision':{'N':'1'}})

def transaction(names,subject,withdrawal=False):
    ledger,users=names['ledger'],names['users'];pk='ACCOUNT#'+subject;upk='USER#'+subject;one={':one':{'N':'1'}}
    items=[put(ledger,{**key(pk,'COMMAND' if withdrawal else 'ACCOUNT_DELETION#CAMPAIGN'),'revision':{'N':'2'}},'revision = :one' if withdrawal else 'attribute_not_exists(PK)',one if withdrawal else None),
      {'Delete':{'TableName':ledger,'Key':key(pk,'CAMPAIGN_RECOVERY#job'),'ConditionExpression':'revision = :one','ExpressionAttributeValues':one,'ReturnValuesOnConditionCheckFailure':'NONE'}},
      {'Update':{'TableName':ledger,'Key':key(pk,'CAMPAIGN_RECOVERY_CONTROL'),'UpdateExpression':'SET revision = :two, pendingJobs = :zero, phase = :phase','ConditionExpression':'revision = :one AND pendingJobs = :one AND phase = :open','ExpressionAttributeValues':{**one,':two':{'N':'2'},':zero':{'N':'0'},':phase':{'S':'OPEN' if withdrawal else 'SEALED'},':open':{'S':'OPEN'}},'ReturnValuesOnConditionCheckFailure':'NONE'}},
      check(users,upk,'PROFILE','revision = :one',one),check(ledger,'INVENTORY#dev','CAMPAIGN_COMPLETION_INVENTORY','revision = :one',one)]
    if withdrawal:items.extend([put(users,{**key(upk,'CAMPAIGN_PARTICIPATION'),'revision':{'N':'2'}}),put(users,key(upk,'CAMPAIGN_CONSENT#AUDIT'))])
    else:items.append(check(ledger,pk,'COMMAND','revision = :one',one))
    return items

def exercise(client,admin,names,report):
    ledger,users=names['ledger'],names['users']
    def done(case):report['cases'].append(case)
    for withdrawal in (False,True):
        label='withdrawal' if withdrawal else 'account';report['phase']=label
        prepare(admin,names,label);actions=transaction(names,label,withdrawal)
        for attempt in range(12):
            try:client.transact_write_items(TransactItems=actions,ClientRequestToken=uuid.uuid5(uuid.UUID(report['runId']),label).hex);break
            except Exception as exc:
                require(error_code(exc) in ('AccessDenied','AccessDeniedException'),'positive_transaction_failed')
                require(attempt<11,'permission_propagation_timeout');time.sleep(3)
        pk='ACCOUNT#'+label;control=read(admin,ledger,pk,'CAMPAIGN_RECOVERY_CONTROL')
        require(control['pendingJobs']=={'N':'0'} and control['phase']=={'S':'OPEN' if withdrawal else 'SEALED'} and read(admin,ledger,pk,'CAMPAIGN_RECOVERY#job') is None,'completion_not_atomic')
        require(read(admin,ledger,pk,'COMMAND' if withdrawal else 'ACCOUNT_DELETION#CAMPAIGN')['revision']=={'N':'2'},'completion_result_missing')
        if withdrawal:require(read(admin,users,'USER#'+label,'CAMPAIGN_PARTICIPATION') and read(admin,users,'USER#'+label,'CAMPAIGN_CONSENT#AUDIT'),'withdrawal_users_missing')
        done(label+'_atomic_completion_allowed')
        canceled(lambda:client.transact_write_items(TransactItems=actions));require(read(admin,ledger,pk,'CAMPAIGN_RECOVERY_CONTROL')==control,'duplicate_mutation');done(label+'_duplicate_atomic_rollback')
        result=client.query(TableName=ledger,ConsistentRead=True,KeyConditionExpression='PK = :pk',ExpressionAttributeValues={':pk':{'S':pk}},Select='COUNT');require(result['Count']==(2 if withdrawal else 3),'owned_query_wrong');done(label+'_owned_query_allowed')
        for target,index in [('control',2),('profile',3),('inventory',4)]:
            subject=label+'-'+target;prepare(admin,names,subject);actions=transaction(names,subject,withdrawal);owner='ACCOUNT#'+subject
            table,rpk,sk=(users,'USER#'+subject,'PROFILE') if target=='profile' else (ledger,'INVENTORY#dev','CAMPAIGN_COMPLETION_INVENTORY') if target=='inventory' else (ledger,owner,'CAMPAIGN_RECOVERY_CONTROL')
            admin.update_item(TableName=table,Key=key(rpk,sk),UpdateExpression='SET revision = :r',ExpressionAttributeValues={':r':{'N':'99'}})
            before=[read(admin,ledger,owner,k) for k in ('COMMAND','CAMPAIGN_RECOVERY#job','CAMPAIGN_RECOVERY_CONTROL')]
            canceled(lambda:client.transact_write_items(TransactItems=actions),index)
            require(before==[read(admin,ledger,owner,k) for k in ('COMMAND','CAMPAIGN_RECOVERY#job','CAMPAIGN_RECOVERY_CONTROL')] and read(admin,ledger,owner,'ACCOUNT_DELETION#CAMPAIGN') is None,'race_changed_ledger')
            if withdrawal:require(read(admin,users,'USER#'+subject,'CAMPAIGN_PARTICIPATION') is None and read(admin,users,'USER#'+subject,'CAMPAIGN_CONSENT#AUDIT') is None,'race_changed_users')
            done(label+'_'+target+'_race_atomic_without_item')
    report['phase']='boundaries'
    require(read(client,ledger,'ACCOUNT#account','COMMAND') is not None and read(client,users,'USER#account','PROFILE') is not None,'existing_owned_get_missing');done('existing_account_and_profile_get_allowed')
    require(read(client,ledger,'INVENTORY#dev','CAMPAIGN_COMPLETION_INVENTORY') is not None,'inventory_get_missing');done('existing_inventory_get_allowed')
    for table,pk in [(ledger,'ACCOUNT#checks'),(users,'USER#checks')]:
        denied(lambda:client.put_item(TableName=table,Item=key(pk,'ITEM')))
        denied(lambda:client.delete_item(TableName=table,Key=key(pk,'ITEM')))
        done(('ledger' if table==ledger else 'users')+'_standalone_put_delete_denied')
        client.transact_write_items(TransactItems=[check(table,pk,'ITEM')]);done(('ledger' if table==ledger else 'users')+'_condition_none_allowed')
        admin.put_item(TableName=table,Item=key(pk,'ITEM'))
        denied(lambda:client.transact_write_items(TransactItems=[check(table,pk,'ITEM',rv='ALL_OLD')]))
        for kind in ('Put','Delete'):
            op={'TableName':table,'ConditionExpression':'attribute_not_exists(PK)','ReturnValuesOnConditionCheckFailure':'ALL_OLD',('Item' if kind=='Put' else 'Key'):key(pk,'ITEM')}
            denied(lambda:client.transact_write_items(TransactItems=[{kind:op}]))
        done(('ledger' if table==ledger else 'users')+'_check_put_delete_all_old_denied')
        for foreign in ('OTHER#foreign','INVENTORY#dev'):
            for kind in ('Put','Delete','Update'):
                op={'TableName':table,('Item' if kind=='Put' else 'Key'):key(foreign,'ITEM')}
                if kind=='Update':op.update(UpdateExpression='SET revision = :r',ExpressionAttributeValues={':r':{'N':'1'}})
                denied(lambda:client.transact_write_items(TransactItems=[{kind:op}]))
        denied(lambda:read(client,table,'OTHER#foreign','ITEM'))
        denied(lambda:client.query(TableName=table,KeyConditionExpression='PK=:p',ExpressionAttributeValues={':p':{'S':'OTHER#foreign'}}))
        denied(lambda:client.transact_write_items(TransactItems=[check(table,'OTHER#foreign','ITEM')]))
        denied(lambda:client.scan(TableName=table));done(('ledger' if table==ledger else 'users')+'_foreign_mutations_reads_and_scan_denied')
    denied(lambda:client.transact_write_items(TransactItems=[{'Delete':{'TableName':users,'Key':key('USER#checks','ITEM')}}]));done('transaction_user_delete_not_granted')
    denied(lambda:client.query(TableName=users,KeyConditionExpression='PK=:p',ExpressionAttributeValues={':p':{'S':'USER#checks'}}));done('users_query_not_granted')
    args={'TableName':ledger,'Key':key('ACCOUNT#checks','ITEM'),'UpdateExpression':'SET revision = :r','ExpressionAttributeValues':{':r':{'N':'1'}}}
    denied(lambda:client.update_item(**args));done('ledger_standalone_update_denied')
    # Existing recovery Update has no ReturnValues NONE restriction. Preserve
    # that union behavior rather than claiming the new policy overrides it.
    args.update(ConditionExpression='attribute_not_exists(PK)',ReturnValuesOnConditionCheckFailure='ALL_OLD')
    try:client.transact_write_items(TransactItems=[{'Update':args}])
    except Exception as exc:
        require(error_code(exc)=='TransactionCanceledException','existing_update_all_old_not_allowed')
        reasons=getattr(exc,'response',{}).get('CancellationReasons',[])
        require(len(reasons)==1 and reasons[0].get('Code')=='ConditionalCheckFailed' and reasons[0].get('Item')==key('ACCOUNT#checks','ITEM'),'existing_update_item_not_observed')
    else:raise QualificationError('existing_update_guard_not_failed')
    done('existing_recovery_update_all_old_remains_allowed_synthetic_item')
    client.transact_write_items(TransactItems=[check(ledger,'INVENTORY#dev','ABSENT')]);done('inventory_condition_none_allowed')
    denied(lambda:client.transact_write_items(TransactItems=[check(ledger,'INVENTORY#dev','CAMPAIGN_COMPLETION_INVENTORY',rv='ALL_OLD')]))
    done('inventory_condition_all_old_denied')


def wait_table(client,name,present):
    deadline=time.monotonic()+90
    while time.monotonic()<deadline:
        try:
            result=client.describe_table(TableName=name)
            if present and result['Table']['TableStatus']=='ACTIVE':return
        except Exception as exc:
            require(error_code(exc)=='ResourceNotFoundException','table_wait_failed')
            if not present:return
        time.sleep(2)
    raise QualificationError('table_wait_timeout')

def qualify(session,policy,evidence):
    import boto3
    from botocore.config import Config
    cfg=Config(retries={'total_max_attempts':1},connect_timeout=5,read_timeout=15)
    sts,iam,ddb=[session.client(s,region_name=REGION,config=cfg) for s in ('sts','iam','dynamodb')]
    run=uuid.uuid4().hex;names={k:PREFIX+run+'-'+k for k in TABLES};role_name=PREFIX+run+'-role';tables=[];role_started=False;client=None
    report={**evidence,'harnessSha256':sha(Path(__file__).read_bytes()),'schemaVersion':1,'observedAtUtc':datetime.now(timezone.utc).isoformat(),'accountId':ACCOUNT,'region':REGION,'runId':run,'passed':False,'cloudExecuted':True,'cleanupComplete':False,'cases':[],'phase':'caller','limitations':['Audited identity-policy union with new completion policy only; excludes SCPs, resource policies and later identity-policy changes.','Exact unrelated pipeline/index, KMS, stream and logging permissions are validated then omitted from fixture grants.','Synthetic transaction shapes are not full producer/completion handler, deployment or erasure proof.','IAM ACCOUNT/USER prefixes do not enforce authenticated account or sort-key ownership.','Existing transactional recovery Update still permits ALL_OLD; new Put/Delete guards do not override it.']}
    try:
        who=sts.get_caller_identity();require(who['Account']==ACCOUNT,'wrong_account');arn=who['Arn'];match=re.fullmatch('arn:aws:sts::'+ACCOUNT+r':assumed-role/([^/]+)/[^/]+',arn)
        if match:principal=iam.get_role(RoleName=match.group(1))['Role']['Arn']
        else:require(re.fullmatch('arn:aws:iam::'+ACCOUNT+r':user/.+',arn),'unsupported_caller');principal=arn
        require(principal.startswith('arn:aws:iam::'+ACCOUNT+':'),'wrong_trust_principal')
        for name in names.values():
            tables.append(name);ddb.create_table(TableName=name,BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':'PK','KeyType':'HASH'},{'AttributeName':'SK','KeyType':'RANGE'}],AttributeDefinitions=[{'AttributeName':x,'AttributeType':'S'} for x in ('PK','SK')],StreamSpecification={'StreamEnabled':False},Tags=[{'Key':'QualificationRun','Value':run}]);wait_table(ddb,name,True)
            require(ddb.describe_continuous_backups(TableName=name)['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['PointInTimeRecoveryStatus']=='DISABLED','unexpected_pitr')
        role_started=True;created=iam.create_role(RoleName=role_name,AssumeRolePolicyDocument=canonical({'Version':'2012-10-17','Statement':[{'Effect':'Allow','Principal':{'AWS':principal},'Action':'sts:AssumeRole'}]}),Tags=[{'Key':'QualificationRun','Value':run}])
        fixture=remap(policy,names);report['fixturePolicySha256']=sha(canonical(fixture).encode())
        iam.put_role_policy(RoleName=role_name,PolicyName='fixture',PolicyDocument=canonical(fixture));require(iam.get_role_policy(RoleName=role_name,PolicyName='fixture')['PolicyDocument']==fixture,'policy_readback')
        credentials=None
        for attempt in range(12):
            try:credentials=sts.assume_role(RoleArn=created['Role']['Arn'],RoleSessionName='completion-iam',DurationSeconds=900)['Credentials'];break
            except Exception as exc:require(error_code(exc) in ('AccessDenied','AccessDeniedException'),'assume_failed');time.sleep(3)
        require(credentials is not None,'trust_propagation_timeout')
        client=boto3.client('dynamodb',region_name=REGION,aws_access_key_id=credentials['AccessKeyId'],aws_secret_access_key=credentials['SecretAccessKey'],aws_session_token=credentials['SessionToken'],config=cfg);del credentials
        exercise(client,ddb,names,report);report['passed']=True;report['phase']='completed'
    except Exception as exc:report['failure']=str(exc) if isinstance(exc,QualificationError) else 'qualification_operation_failed'
    finally:
        outstanding=[]
        if role_started:
            try:
                require({'Key':'QualificationRun','Value':run} in iam.list_role_tags(RoleName=role_name)['Tags'],'role_cleanup_ownership')
                try:iam.delete_role_policy(RoleName=role_name,PolicyName='fixture')
                except Exception as exc:require(error_code(exc)=='NoSuchEntity','policy_cleanup_failed')
                iam.delete_role(RoleName=role_name)
            except Exception as exc:
                if error_code(exc)!='NoSuchEntity':outstanding.append({'kind':'role','name':role_name})
        for name in reversed(tables):
            try:
                require({'Key':'QualificationRun','Value':run} in ddb.list_tags_of_resource(ResourceArn=ROOT+name)['Tags'],'table_cleanup_ownership');ddb.delete_table(TableName=name);wait_table(ddb,name,False)
            except Exception as exc:
                if error_code(exc)!='ResourceNotFoundException':outstanding.append({'kind':'table','name':name})
        report['cleanupComplete']=not outstanding;report['cleanupOutstanding']=outstanding
        for c in ([client] if client else [])+[sts,iam,ddb]:c.close()
    return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--plan',required=True);p.add_argument('--role-audit',required=True);p.add_argument('--profile',default='trustcheckradar');p.add_argument('--execute',action='store_true');args=p.parse_args()
    try:
        policy,evidence=load_union(args.plan,args.role_audit)
        if not args.execute:print(json.dumps({**evidence,'policyValidationPassed':True,'cloudExecuted':False,'statementCount':len(policy['Statement']),'harnessSha256':sha(Path(__file__).read_bytes())},sort_keys=True));return 0
        import boto3
        report=qualify(boto3.Session(profile_name=args.profile,region_name=REGION),policy,evidence);print(json.dumps(report,sort_keys=True));return 0 if report['passed'] and report['cleanupComplete'] else 1
    except Exception:print('{"passed":false,"failure":"qualification_setup_failed"}');return 1
if __name__=='__main__':raise SystemExit(main())
