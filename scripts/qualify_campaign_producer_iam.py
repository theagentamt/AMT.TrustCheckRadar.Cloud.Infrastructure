#!/usr/bin/env python3
"""Qualify selected producer users/ledger policy unions on disposable fixtures.

Offline by default; independently review frozen source before --execute. Keep
all overlapping statements, including legacy Scan/checkpoint/standalone writes.
Unrelated services, streams and disjoint tables are explicitly outside evidence.
An exact role-audit snapshot binds replacement policies and disjoint ancillary
policies; this does not prove SCPs, table policies or producer handler behavior.
"""
import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
import re
import time
import uuid
from pathlib import Path

ACCOUNT='107827791950'
REGION='us-east-1'
ROOT=f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/'
USERS=ROOT+'trustcheckradar-dev-users'
LEDGER=ROOT+'trustcheckradar-dev-deletion-ledger'
ADDRESSES={'account_data':'aws_iam_role_policy.account_data[0]', 'participation':'aws_iam_policy.campaign_participation_runtime'}
OTHER_TABLES={ROOT+'trustcheckradar-dev-'+name for name in ('purchase-entitlements','device-bindings','device-recovery-control','analysis-abuse-control','campaign-outbox')}
PREFIX='amt-producer-qual-'

class QualificationError(Exception):pass

def need(value,code):
    if not value:raise QualificationError(code)
def seq(value):return value if isinstance(value,list) else [value]
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'))
def sha(value):return hashlib.sha256(value).hexdigest()
def code(exc):return getattr(exc,'response',{}).get('Error',{}).get('Code','')
def normalize_conditions(value):
    need(isinstance(value,dict),'condition_schema');result={}
    for operator, fields in value.items():
        need(isinstance(fields,dict),'condition_schema');result[operator]={}
        for k,v in fields.items():
            values=seq(v);need(all(isinstance(x,str) for x in values) and len(values)==len(set(values)),'condition_values')
            result[operator][k]=sorted(values)
    return result

def specification(actions,table,keys=None,equals=False,tx=None,check=False):
    c={}
    if keys:c['ForAllValues:StringEquals' if equals else 'ForAllValues:StringLike']={'dynamodb:LeadingKeys':keys}
    if tx:c[tx]={'dynamodb:EnclosingOperation':'TransactWriteItems'}
    if check:c['StringEqualsIfExists']={'dynamodb:ReturnValues':'NONE'}
    return {'actions':set(seq(actions)),'table':table,'conditions':c}

def specifications():
    common={
      'FindAccountCampaignRecoverySidecars':specification('dynamodb:Query',LEDGER,'ACCOUNT#*'),
      'UpdateCampaignRecoveryControlTransaction':specification('dynamodb:UpdateItem',LEDGER,'ACCOUNT#*',tx='ForAnyValue:StringEquals')}
    return {
      'account_data':common|{
        'TransactionallyFenceAuthoritativeProfile':specification('dynamodb:UpdateItem',USERS,'USER#*',tx='StringEquals'),
        'ReadAccountInventoryProof':specification('dynamodb:GetItem',LEDGER,'INVENTORY#dev',equals=True),
        'CheckDeletionProofTransaction':specification('dynamodb:ConditionCheckItem',LEDGER,['ACCOUNT#*','INVENTORY#dev'],check=True),
        'ReadCommandAndWriteRevocationReceipt':specification(['dynamodb:GetItem','dynamodb:PutItem','dynamodb:DeleteItem'],LEDGER,'ACCOUNT#*'),
        'ReconcileMissedRevocations':specification('dynamodb:Scan',LEDGER),
        'EraseFencedUserProfileState':specification(['dynamodb:Query','dynamodb:DeleteItem'],USERS,'USER#*'),
        'PersistOwnReconciliationCheckpoint':specification(['dynamodb:GetItem','dynamodb:PutItem'],LEDGER,'LIFECYCLE#dev')},
      'participation':common|{
        'CheckParticipationAuthorityLedger':specification('dynamodb:ConditionCheckItem',LEDGER,'ACCOUNT#*',check=True),
        'CheckParticipationAuthorityUsers':specification('dynamodb:ConditionCheckItem',USERS,'USER#*',check=True),
        'ReadParticipationDeletionFence':specification('dynamodb:GetItem',LEDGER,'ACCOUNT#*'),
        'ReadParticipationAndEntitlements':specification('dynamodb:GetItem',USERS,'USER#*'),
        'WriteParticipationTransactionLedger':specification('dynamodb:PutItem',LEDGER,'ACCOUNT#*',tx='ForAnyValue:StringEquals'),
        'WriteParticipationTransactionUsers':specification('dynamodb:PutItem',USERS,'USER#*',tx='ForAnyValue:StringEquals')}}
SPECS=specifications()

def project_policy(policy,role):
    need(isinstance(policy,dict) and set(policy)=={'Version','Statement'} and policy['Version']=='2012-10-17','policy_schema')
    need(isinstance(policy['Statement'],list),'statement_schema')
    retained=[];omitted=[];seen=set()
    for st in policy['Statement']:
        need(isinstance(st,dict) and set(st)<={'Sid','Effect','Action','Resource','Condition'},'statement_fields')
        sid=st.get('Sid');need(isinstance(sid,str) and sid not in seen,'duplicate_or_invalid_sid');seen.add(sid)
        need(st.get('Effect')=='Allow','unexpected_effect_requires_review')
        actions=seq(st.get('Action'));resources=seq(st.get('Resource'))
        need(all(isinstance(x,str) for x in actions+resources) and len(actions)==len(set(actions)) and len(resources)==len(set(resources)),'action_resource_schema')
        # Global ListStreams and exact stream read actions cannot grant table
        # reads/writes. Never attach their live stream/discovery grants to fixtures.
        if sid=='DiscoverDeletionStreamsInRegion':
            need(role=='account_data' and actions==['dynamodb:ListStreams'] and resources==['*'] and normalize_conditions(st.get('Condition',{}))==normalize_conditions({'StringEquals':{'aws:RequestedRegion':REGION}}),'unexpected_stream_discovery')
            omitted.append({'sid':sid,'reason':'stream_discovery_not_table_operation','actions':actions,'resources':resources});continue
        if sid=='ReadOwnDeletionStream':
            need(role=='account_data' and set(actions)=={'dynamodb:DescribeStream','dynamodb:GetRecords','dynamodb:GetShardIterator'} and len(resources)==1 and re.fullmatch(re.escape(LEDGER)+r'/stream/[0-9TZ:.+-]+',resources[0]) and not st.get('Condition'),'unexpected_stream_read')
            omitted.append({'sid':sid,'reason':'stream_reads_not_table_operations','actions':actions,'resources':resources});continue
        ddb=[x.startswith('dynamodb:') for x in actions]
        need(all(ddb) or not any(ddb),'mixed_service_statement')
        if not any(ddb):
            need(all(x.startswith(('kms:','logs:','cognito-idp:')) for x in actions),'unexpected_omitted_service')
            need(all(re.fullmatch(r'arn:aws:(kms|logs|cognito-idp):'+REGION+':'+ACCOUNT+r':.+',x) for x in resources),'unexpected_omitted_service_resource')
            omitted.append({'sid':sid,'reason':'disjoint_service_resource','actions':actions,'resources':resources});continue
        # Explicit resource classification rejects wildcards/unknown tables and
        # future overlapping grants instead of silently cherry-picking known SIDs.
        target=[];other=[]
        for resource in resources:
            if resource in (USERS,LEDGER):target.append(resource)
            elif any(resource==arn or resource.startswith(arn+'/index/') for arn in OTHER_TABLES):other.append(resource)
            else:raise QualificationError('unclassified_or_overlapping_resource')
        if not target:
            omitted.append({'sid':sid,'reason':'exact_disjoint_table_resource','actions':actions,'resources':other});continue
        need(sid in SPECS[role],'unexpected_overlapping_statement')
        expected=SPECS[role][sid]
        need(target==[expected['table']] and not other,'unexpected_mixed_target_statement')
        need(set(actions)==expected['actions'],'unexpected_overlapping_actions')
        need(normalize_conditions(st.get('Condition',{}))==normalize_conditions(expected['conditions']),'unexpected_overlapping_conditions')
        retained.append(copy.deepcopy(st))
    need({s['Sid'] for s in retained}==set(SPECS[role]),'missing_overlapping_statement')
    return {'Version':'2012-10-17','Statement':retained},omitted

def load_policies(path):
    raw=Path(path).read_bytes();plan=json.loads(raw);policies={};omitted={};full_hashes={}
    for role,address in ADDRESSES.items():
        matches=[r for r in plan.get('resource_changes',[]) if r.get('address')==address]
        need(len(matches)==1,'policy_address_missing_or_ambiguous');r=matches[0];change=r['change']
        need(r.get('mode')=='managed' and r.get('type')==('aws_iam_role_policy' if role=='account_data' else 'aws_iam_policy'),'unexpected_policy_resource')
        need(change.get('after_unknown',{}).get('policy') is not True,'policy_unknown')
        full=json.loads(change['after']['policy']);full_hashes[role]=sha(canonical(full).encode())
        policies[role],omitted[role]=project_policy(full,role)
    return policies,omitted,full_hashes,sha(raw)


def policy_equivalent(policy):
    """Compare IAM documents without depending on AWS serialization order."""
    result=copy.deepcopy(policy)
    for st in result['Statement']:
        for field in ('Action','Resource'):
            if field in st:st[field]=sorted(seq(st[field]))
        if 'Condition' in st:st['Condition']=normalize_conditions(st['Condition'])
    result['Statement']=sorted(result['Statement'],key=canonical)
    return canonical(result)

def validate_role_audit(plan_path,audit_path):
    raw=Path(audit_path).read_bytes();audit=json.loads(raw);plan=json.loads(Path(plan_path).read_bytes())
    need(isinstance(audit.get('observedAtUtc'),str),'audit_observation_missing')
    observed=datetime.fromisoformat(audit['observedAtUtc']);need(observed.tzinfo is not None,'audit_observation_timezone')
    omitted=[]
    for role,address in ADDRESSES.items():
        name='trustcheckradar-dev-'+('account-data-api-role' if role=='account_data' else 'campaign-participation-role')
        entry=audit['roles'][name]
        need(entry['arn']==f'arn:aws:iam::{ACCOUNT}:role/{name}' and entry['permissionsBoundary'] is None,'audit_role_identity_or_boundary')
        if role=='account_data':
            need(set(entry['inline'])=={'account-data-runtime'} and not entry['managed'],'audit_account_policy_sources')
            before=entry['inline']['account-data-runtime']
        else:
            runtime=f'arn:aws:iam::{ACCOUNT}:policy/trustcheckradar-dev-campaign-participation-runtime'
            basic='arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
            migration='trustcheckradar-dev-research-migration-participation'
            need(set(entry['managed'])=={runtime,basic} and set(entry['inline'])=={migration},'audit_participation_policy_sources')
            before=entry['managed'][runtime]
            expected_basic={'Version':'2012-10-17','Statement':[{'Effect':'Allow','Action':['logs:CreateLogGroup','logs:CreateLogStream','logs:PutLogEvents'],'Resource':'*'}]}
            need(policy_equivalent(entry['managed'][basic])==policy_equivalent(expected_basic),'audit_logging_overlap')
            expected_migration={'Version':'2012-10-17','Statement':[
              {'Sid':'DenyProviderCredentialsAndDispatch','Effect':'Deny','Action':['ssm:GetParametersByPath','ssm:GetParameters','ssm:GetParameter','secretsmanager:GetSecretValue','lambda:InvokeFunction'],'Resource':'*'},
              {'Sid':'DenyConsentEntitlementAccess','Effect':'Deny','Action':'dynamodb:*','Resource':[ROOT+'trustcheckradar-dev-purchase-entitlements',ROOT+'trustcheckradar-dev-purchase-entitlements/index/*']}]}
            need(policy_equivalent(entry['inline'][migration])==policy_equivalent(expected_migration),'audit_migration_overlap')
            omitted.extend([{'role':role,'source':basic,'reason':'exact_logging_actions_disjoint_from_dynamodb'},
              {'role':role,'source':migration,'reason':'exact_denies_on_other_services_and_purchase_table_disjoint_from_users_ledger'}])
        matches=[r for r in plan['resource_changes'] if r.get('address')==address]
        need(len(matches)==1,'audit_plan_policy_ambiguous')
        change=matches[0]['change'];need(change['actions']==['update'],'audit_requires_policy_replacement')
        need(policy_equivalent(before)==policy_equivalent(json.loads(change['before']['policy'])),'audit_before_policy_mismatch')
        after=change['after']
        if role=='account_data':need(after['role']==name and after['name']=='account-data-runtime','audit_replacement_identity')
        else:need(after['arn']==runtime,'audit_replacement_identity')
    return {'sourceRoleAuditSha256':sha(raw),'roleAuditObservedAtUtc':audit['observedAtUtc'],'omittedAncillaryPolicies':omitted}

def remap(policy,names):
    need(set(names)=={'users','ledger'} and names['users']!=names['ledger'],'fixture_table_set')
    for suffix,name in names.items():need(re.fullmatch(PREFIX+r'[a-f0-9]{32}-'+suffix,name),'fixture_table_name')
    mapping={USERS:ROOT+names['users'],LEDGER:ROOT+names['ledger']};result=copy.deepcopy(policy)
    for st in result['Statement']:
        need(all(r in mapping for r in seq(st['Resource'])) and all(a.startswith('dynamodb:') and a not in ('dynamodb:ListStreams','dynamodb:DescribeStream','dynamodb:GetRecords','dynamodb:GetShardIterator') for a in seq(st['Action'])),'fixture_live_permission')
        st['Resource']=[mapping[r] for r in st['Resource']] if isinstance(st['Resource'],list) else mapping[st['Resource']]
    need('trustcheckradar-dev-' not in canonical(result),'fixture_live_resource_leak')
    return result

def key(pk,sk):return {'PK':{'S':pk},'SK':{'S':sk}}
def read(c,t,pk,sk):return c.get_item(TableName=t,Key=key(pk,sk),ConsistentRead=True).get('Item')
def put_action(t,item):return {'Put':{'TableName':t,'Item':item,'ConditionExpression':'attribute_not_exists(PK)'}}
def absent(t,pk,sk,rv='NONE'):return {'ConditionCheck':{'TableName':t,'Key':key(pk,sk),'ConditionExpression':'attribute_not_exists(PK)','ReturnValuesOnConditionCheckFailure':rv}}
def denied(call):
    try:call()
    except Exception as exc:
        need(code(exc) in ('AccessDenied','AccessDeniedException'),'unexpected_denial_type');return
    raise QualificationError('expected_access_denied')
def canceled(call,index=None):
    try:call()
    except Exception as exc:
        need(code(exc)=='TransactionCanceledException','unexpected_cancellation_type')
        reasons=getattr(exc,'response',{}).get('CancellationReasons',[])
        need(reasons and (any(r.get('Code')=='ConditionalCheckFailed' for r in reasons) if index is None else len(reasons)>index and reasons[index].get('Code')=='ConditionalCheckFailed'),'missing_condition_cancellation')
        need(all('Item' not in r for r in reasons),'cancellation_returned_item');return
    raise QualificationError('guard_did_not_cancel')

def prepare(admin,names,role,label,existing=False):
    subject=role+'-'+label;pk='ACCOUNT#'+subject;user='USER#'+subject
    admin.put_item(TableName=names['users'],Item={**key(user,'PROFILE'),'status':{'S':'ACTIVE'},'sub':{'S':subject}})
    if existing:admin.put_item(TableName=names['ledger'],Item={**key(pk,'CAMPAIGN_RECOVERY_CONTROL'),'revision':{'N':'1'},'pendingJobs':{'N':'1'},'state':{'S':'OPEN'}})
    return subject,pk,user

def transaction(names,role,subject,existing=False):
    pk='ACCOUNT#'+subject;upk='USER#'+subject;ledger=names['ledger'];users=names['users']
    command_sk='ACCOUNT_DELETION' if role=='account_data' else 'CAMPAIGN_WITHDRAWAL#fixture'
    actions=[put_action(ledger,{**key(pk,command_sk),'fixture':{'BOOL':True}}),put_action(ledger,{**key(pk,'CAMPAIGN_RECOVERY#fixture'),'fixture':{'BOOL':True}})]
    control={**key(pk,'CAMPAIGN_RECOVERY_CONTROL'),'revision':{'N':'1'},'pendingJobs':{'N':'1'},'state':{'S':'OPEN'}}
    if existing:
        actions.append({'Update':{'TableName':ledger,'Key':key(pk,'CAMPAIGN_RECOVERY_CONTROL'),
          'UpdateExpression':'SET revision = :two, pendingJobs = :two',
          'ConditionExpression':'revision = :one AND pendingJobs = :one AND #state = :open',
          'ExpressionAttributeNames':{'#state':'state'},'ExpressionAttributeValues':{':one':{'N':'1'},':two':{'N':'2'},':open':{'S':'OPEN'}}}})
    else:actions.append(put_action(ledger,control))
    actions.append(absent(ledger,pk,'ACCOUNT_DELETION#CAMPAIGN'))
    profile={'TableName':users,'Key':key(upk,'PROFILE'),'ConditionExpression':'#status = :active AND #sub = :subject',
       'ExpressionAttributeNames':{'#status':'status','#sub':'sub'},'ExpressionAttributeValues':{':active':{'S':'ACTIVE'},':subject':{'S':subject}}}
    if role=='account_data':
        profile['UpdateExpression']='SET #status = :requested';profile['ExpressionAttributeValues'][':requested']={'S':'DELETION_REQUESTED'}
        actions.append({'Update':profile})
        actions.append({'ConditionCheck':{'TableName':ledger,'Key':key('INVENTORY#dev','ACCOUNT_DATA_INVENTORY'),'ConditionExpression':'fixture = :yes','ExpressionAttributeValues':{':yes':{'BOOL':True}},'ReturnValuesOnConditionCheckFailure':'NONE'}})
    else:
        actions.extend([{'ConditionCheck':profile},absent(ledger,pk,'ACCOUNT_DELETION'),put_action(users,{**key(upk,'CAMPAIGN_PARTICIPATION'),'fixture':{'BOOL':True}})])
    return actions,command_sk

def exercise(role,client,admin,names,report):
    def record(case):report['cases'].append(role+':'+case)
    ledger,users=names['ledger'],names['users']
    admin.put_item(TableName=ledger,Item={**key('INVENTORY#dev','ACCOUNT_DATA_INVENTORY'),'fixture':{'BOOL':True}})
    for existing in (False,True):
        label='existing' if existing else 'new';report['phase']=role+':'+label+'_transaction'
        subject,pk,upk=prepare(admin,names,role,label,existing)
        actions,command_sk=transaction(names,role,subject,existing)
        # Retry only permission propagation. This idempotency token prevents
        # duplicate writes if an allowed first transaction response is repeated.
        for attempt in range(12):
            try:
                client.transact_write_items(TransactItems=actions,ClientRequestToken=uuid.uuid5(uuid.UUID(report['runId']),role+label).hex);break
            except Exception as exc:
                need(code(exc) in ('AccessDenied','AccessDeniedException'),'positive_transaction_failed')
                need(attempt<11,'permission_propagation_timeout');time.sleep(3)
        need(read(admin,ledger,pk,command_sk) is not None and read(admin,ledger,pk,'CAMPAIGN_RECOVERY#fixture') is not None,'atomic_rows_missing')
        control=read(admin,ledger,pk,'CAMPAIGN_RECOVERY_CONTROL');need(control and control.get('pendingJobs')=={'N':'2' if existing else '1'},'counter_wrong')
        record(label+'_command_job_control_transaction_allowed')
        found=client.query(TableName=ledger,ConsistentRead=True,Select='COUNT',KeyConditionExpression='PK = :pk',ExpressionAttributeValues={':pk':{'S':pk}})
        need(found.get('Count')==3,'account_query_count');record(label+'_base_account_query_allowed')
        need(read(client,ledger,pk,command_sk) is not None,'command_read_missing');record(label+'_owned_command_get_allowed')
        before=control
        canceled(lambda:client.transact_write_items(TransactItems=actions))
        need(read(admin,ledger,pk,'CAMPAIGN_RECOVERY_CONTROL')==before,'duplicate_changed_count');record(label+'_replay_rolls_back_no_increment')
    for target in ('receipt','profile','control')+ (('inventory',) if role=='account_data' else ('fence',)):
        report['phase']=role+':race_'+target
        subject,pk,upk=prepare(admin,names,role,'race-'+target,True);actions,command_sk=transaction(names,role,subject,True)
        if target=='receipt':admin.put_item(TableName=ledger,Item=key(pk,'ACCOUNT_DELETION#CAMPAIGN'))
        elif target=='profile':admin.put_item(TableName=users,Item={**key(upk,'PROFILE'),'status':{'S':'DELETED'},'sub':{'S':subject}})
        elif target=='control':admin.update_item(TableName=ledger,Key=key(pk,'CAMPAIGN_RECOVERY_CONTROL'),UpdateExpression='SET revision = :n',ExpressionAttributeValues={':n':{'N':'99'}})
        elif target=='inventory':admin.put_item(TableName=ledger,Item={**key('INVENTORY#dev','ACCOUNT_DATA_INVENTORY'),'fixture':{'BOOL':False}})
        else:admin.put_item(TableName=ledger,Item=key(pk,'ACCOUNT_DELETION'))
        before=read(admin,ledger,pk,'CAMPAIGN_RECOVERY_CONTROL')
        canceled(lambda:client.transact_write_items(TransactItems=actions))
        need(read(admin,ledger,pk,'CAMPAIGN_RECOVERY#fixture') is None and read(admin,ledger,pk,command_sk) is None and read(admin,ledger,pk,'CAMPAIGN_RECOVERY_CONTROL')==before,'race_mutated_rows')
        record(target+'_race_atomic_without_returned_item')
        if target=='inventory':admin.put_item(TableName=ledger,Item={**key('INVENTORY#dev','ACCOUNT_DATA_INVENTORY'),'fixture':{'BOOL':True}})
    report['phase']=role+':permission_boundaries'
    # Test each complete projected union, including its intentional legacy rights.
    for table,pk in ((ledger,'ACCOUNT#standalone'),(users,'USER#standalone')):
        denied(lambda:client.update_item(TableName=table,Key=key(pk,'FIXTURE'),UpdateExpression='SET fixture = :v',ExpressionAttributeValues={':v':{'BOOL':True}}))
    record('standalone_updates_denied')
    for table in (users,ledger):
        denied(lambda:client.query(TableName=table,KeyConditionExpression='PK = :pk',ExpressionAttributeValues={':pk':{'S':'OTHER#foreign'}}))
        denied(lambda:client.get_item(TableName=table,Key=key('OTHER#foreign','FIXTURE')))
        denied(lambda:client.transact_write_items(TransactItems=[{'Update':{'TableName':table,'Key':key('OTHER#foreign','FIXTURE'),'UpdateExpression':'SET fixture = :v','ExpressionAttributeValues':{':v':{'BOOL':True}}}}]))
        denied(lambda:client.transact_write_items(TransactItems=[put_action(table,key('OTHER#foreign','FIXTURE'))]))
        denied(lambda:client.delete_item(TableName=table,Key=key('OTHER#foreign','FIXTURE')))
    record('foreign_partition_point_reads_queries_and_mutations_denied')
    for pk in ('ACCOUNT#check','INVENTORY#dev') if role=='account_data' else ('ACCOUNT#check',):
        client.transact_write_items(TransactItems=[absent(ledger,pk,'ABSENT_PROOF')]);record('ledger_'+pk.split('#')[0].lower()+'_condition_none_allowed')
        admin.put_item(TableName=ledger,Item=key(pk,'ABSENT_PROOF'))
        denied(lambda:client.transact_write_items(TransactItems=[absent(ledger,pk,'ABSENT_PROOF','ALL_OLD')]))
        admin.delete_item(TableName=ledger,Key=key(pk,'ABSENT_PROOF'))
    denied(lambda:client.transact_write_items(TransactItems=[absent(ledger,'OTHER#foreign','FIXTURE')]))
    record('ledger_foreign_and_all_old_conditions_denied')
    if role=='account_data':
        need(read(client,ledger,'INVENTORY#dev','ACCOUNT_DATA_INVENTORY') is not None,'inventory_read_missing');record('inventory_get_allowed')
        # Full-ledger Scan is existing source authority: demonstrate rather than hide it.
        admin.put_item(TableName=ledger,Item=key('OTHER#scan-visible','FIXTURE'))
        observed=client.scan(TableName=ledger,Select='COUNT',FilterExpression='PK = :pk',ExpressionAttributeValues={':pk':{'S':'OTHER#scan-visible'}})
        need(observed.get('Count')==1,'legacy_scan_not_observed');record('legacy_whole_ledger_scan_allowed_including_other_partition')
        client.put_item(TableName=ledger,Item=key('LIFECYCLE#dev','CHECKPOINT'))
        need(read(client,ledger,'LIFECYCLE#dev','CHECKPOINT') is not None,'checkpoint_read_missing');record('legacy_lifecycle_checkpoint_get_put_allowed')
        denied(lambda:client.put_item(TableName=ledger,Item=key('LIFECYCLE#prod','CHECKPOINT')));record('foreign_environment_checkpoint_put_denied')
        client.put_item(TableName=ledger,Item=key('ACCOUNT#legacy','FIXTURE'))
        client.delete_item(TableName=ledger,Key=key('ACCOUNT#legacy','FIXTURE'));record('legacy_standalone_account_put_delete_allowed')
        admin.put_item(TableName=users,Item=key('USER#legacy','FIXTURE'))
        need(client.query(TableName=users,Select='COUNT',KeyConditionExpression='PK = :pk',ExpressionAttributeValues={':pk':{'S':'USER#legacy'}}).get('Count')==1,'legacy_users_query_not_observed')
        client.delete_item(TableName=users,Key=key('USER#legacy','FIXTURE'));record('legacy_users_query_delete_allowed')
        denied(lambda:client.scan(TableName=users));record('users_scan_denied')
        denied(lambda:client.transact_write_items(TransactItems=[absent(users,'USER#none','FIXTURE')]));record('users_conditioncheck_not_granted')
    else:
        for table,pk in ((ledger,'ACCOUNT#standalone'),(users,'USER#standalone')):
            denied(lambda:client.put_item(TableName=table,Item=key(pk,'FIXTURE')))
            denied(lambda:client.delete_item(TableName=table,Key=key(pk,'FIXTURE')))
            denied(lambda:client.scan(TableName=table))
        record('standalone_put_delete_and_scans_denied')
        denied(lambda:client.query(TableName=users,KeyConditionExpression='PK = :pk',ExpressionAttributeValues={':pk':{'S':'USER#participation-new'}}));record('users_query_not_granted')
        denied(lambda:read(client,ledger,'INVENTORY#dev','ACCOUNT_DATA_INVENTORY'))
        denied(lambda:client.transact_write_items(TransactItems=[absent(ledger,'INVENTORY#dev','FIXTURE')]));record('inventory_get_and_condition_not_granted')
        need(read(client,users,'USER#participation-new','PROFILE') is not None,'users_get_missing');record('owned_profile_get_allowed')
        client.transact_write_items(TransactItems=[absent(users,'USER#check','FIXTURE')]);record('owned_profile_condition_none_allowed')
        admin.put_item(TableName=users,Item=key('USER#check','FIXTURE'))
        denied(lambda:client.transact_write_items(TransactItems=[absent(users,'USER#check','FIXTURE','ALL_OLD')]))
        denied(lambda:client.transact_write_items(TransactItems=[absent(users,'OTHER#check','FIXTURE')]))
        record('profile_all_old_and_foreign_conditions_denied')

def wait_table(client,name,present):
    deadline=time.monotonic()+90
    while time.monotonic()<deadline:
        try:
            if client.describe_table(TableName=name)['Table']['TableStatus']=='ACTIVE' and present:return
        except Exception as exc:
            if code(exc)=='ResourceNotFoundException' and not present:return
            need(code(exc)=='ResourceNotFoundException','table_wait_failed')
        time.sleep(2)
    raise QualificationError('table_wait_timeout')

def qualify(session,policies,omitted,full_hashes,plan_hash,audit_evidence):
    import boto3
    from botocore.config import Config
    cfg=Config(retries={'total_max_attempts':1},connect_timeout=5,read_timeout=15)
    sts,iam,ddb=[session.client(s,region_name=REGION,config=cfg) for s in ('sts','iam','dynamodb')]
    run_id=uuid.uuid4().hex;names={k:PREFIX+run_id+'-'+k for k in ('users','ledger')};tables=[];roles=[];clients=[]
    report={'schemaVersion':1,'observedAtUtc':datetime.now(timezone.utc).isoformat(),'accountId':ACCOUNT,'region':REGION,'runId':run_id,'harnessSha256':sha(Path(__file__).read_bytes()),'sourcePlanSha256':plan_hash,'fullSourcePolicySha256':full_hashes,'projectedPolicySha256':{k:sha(canonical(v).encode()) for k,v in policies.items()},'omittedStatements':omitted,'cloudExecuted':True,'passed':False,'cleanupComplete':False,'cases':[],'phase':'caller_validation','scope':'complete selected-policy users/ledger projections on disposable tables and assumed fixture roles','limitations':['Identity-policy scope uses a dated exact role-audit snapshot with selected replacements; it excludes SCPs, resource policies and later policy changes.','Unrelated tables/services/stream operations are omitted only after nonoverlap checks.','Synthetic transaction shapes test IAM and atomic predicates, not complete producer handler semantics.','Account-data legacy ledger Scan, LIFECYCLE checkpoint, standalone ACCOUNT Put/Delete and USER Query/Delete remain permitted.','IAM LeadingKeys does not enforce exact account equality or sort-key ownership.','No live data, code deployment, activation, backfill or completed erasure is exercised.']}
    report.update(audit_evidence)
    try:
        identity=sts.get_caller_identity();need(identity['Account']==ACCOUNT,'wrong_account');caller=identity['Arn']
        assumed=re.fullmatch(r'arn:aws:sts::'+ACCOUNT+r':assumed-role/([^/]+)/[^/]+',caller)
        if assumed:principal=iam.get_role(RoleName=assumed.group(1))['Role']['Arn']
        else:need(re.fullmatch(r'arn:aws:iam::'+ACCOUNT+r':user/.+',caller),'unsupported_caller');principal=caller
        need(principal.startswith(f'arn:aws:iam::{ACCOUNT}:'),'wrong_trust_account')
        for name in names.values():
            tables.append(name)
            ddb.create_table(TableName=name,BillingMode='PAY_PER_REQUEST',AttributeDefinitions=[{'AttributeName':x,'AttributeType':'S'} for x in ('PK','SK')],KeySchema=[{'AttributeName':'PK','KeyType':'HASH'},{'AttributeName':'SK','KeyType':'RANGE'}],StreamSpecification={'StreamEnabled':False},Tags=[{'Key':'Purpose','Value':'synthetic-campaign-producer-qualification'},{'Key':'QualificationRun','Value':run_id}])
            wait_table(ddb,name,True)
            need(ddb.describe_continuous_backups(TableName=name)['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['PointInTimeRecoveryStatus']=='DISABLED','unexpected_pitr')
        for role,policy in policies.items():
            role_name=PREFIX+run_id+('-account' if role=='account_data' else '-consent');roles.append(role_name)
            trust={'Version':'2012-10-17','Statement':[{'Effect':'Allow','Principal':{'AWS':principal},'Action':'sts:AssumeRole'}]}
            created=iam.create_role(RoleName=role_name,AssumeRolePolicyDocument=canonical(trust),MaxSessionDuration=3600,Tags=[{'Key':'QualificationRun','Value':run_id}])
            fixture=remap(policy,names)
            report.setdefault('fixturePolicySha256',{})[role]=sha(canonical(fixture).encode())
            iam.put_role_policy(RoleName=role_name,PolicyName='fixture',PolicyDocument=canonical(fixture))
            need(iam.get_role_policy(RoleName=role_name,PolicyName='fixture')['PolicyDocument']==fixture,'fixture_policy_readback_mismatch')
            credentials=None
            for attempt in range(12):
                try:credentials=sts.assume_role(RoleArn=created['Role']['Arn'],RoleSessionName='synthetic-producer-qualification',DurationSeconds=900)['Credentials'];break
                except Exception as exc:need(code(exc) in ('AccessDenied','AccessDeniedException'),'assume_role_failed');time.sleep(3)
            need(credentials is not None,'trust_propagation_timeout')
            client=boto3.client('dynamodb',region_name=REGION,aws_access_key_id=credentials['AccessKeyId'],aws_secret_access_key=credentials['SecretAccessKey'],aws_session_token=credentials['SessionToken'],config=cfg);clients.append(client);del credentials
            exercise(role,client,ddb,names,report)
        report['passed']=True;report['phase']='completed'
    except Exception as exc:report['failure']=str(exc) if isinstance(exc,QualificationError) else 'qualification_operation_failed'
    finally:
        failures=[]
        for role_name in reversed(roles):
            try:
                need({'Key':'QualificationRun','Value':run_id} in iam.list_role_tags(RoleName=role_name)['Tags'],'cleanup_role_ownership')
                try:iam.delete_role_policy(RoleName=role_name,PolicyName='fixture')
                except Exception as exc:need(code(exc)=='NoSuchEntity','cleanup_policy_failed')
                iam.delete_role(RoleName=role_name)
            except Exception as exc:
                if code(exc)!='NoSuchEntity':failures.append({'kind':'role','name':role_name})
        for name in reversed(tables):
            try:
                need({'Key':'QualificationRun','Value':run_id} in ddb.list_tags_of_resource(ResourceArn=ROOT+name)['Tags'],'cleanup_table_ownership')
                ddb.delete_table(TableName=name);wait_table(ddb,name,False)
            except Exception as exc:
                if code(exc)!='ResourceNotFoundException':failures.append({'kind':'table','name':name})
        report['cleanupComplete']=not failures;report['cleanupOutstanding']=failures
        for client in clients+[sts,iam,ddb]:client.close()
    return report

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--plan',required=True);parser.add_argument('--role-audit',required=True);parser.add_argument('--profile',default='trustcheckradar');parser.add_argument('--execute',action='store_true');args=parser.parse_args()
    try:
        policies,omitted,full_hashes,plan_hash=load_policies(args.plan)
        audit_evidence=validate_role_audit(args.plan,args.role_audit)
        if not args.execute:
            print(json.dumps({**audit_evidence,'policyValidationPassed':True,'cloudExecuted':False,'sourcePlanSha256':plan_hash,'fullSourcePolicySha256':full_hashes,'retainedStatementCounts':{k:len(v['Statement']) for k,v in policies.items()},'omittedStatements':omitted,'harnessSha256':sha(Path(__file__).read_bytes())},sort_keys=True));return 0
        import boto3
        report=qualify(boto3.Session(profile_name=args.profile,region_name=REGION),policies,omitted,full_hashes,plan_hash,audit_evidence);print(json.dumps(report,sort_keys=True));return 0 if report['passed'] and report['cleanupComplete'] else 1
    except Exception as exc:print(json.dumps({'passed':False,'failure':str(exc) if isinstance(exc,QualificationError) else 'qualification_setup_failed'}));return 1
if __name__=='__main__':raise SystemExit(main())
