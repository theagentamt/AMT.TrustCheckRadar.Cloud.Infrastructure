#!/usr/bin/env python3
"""Offline-first History processing identity-policy qualification. No live grants.

Requires exact rendered plan and complete dated role audit. Execute only after
independent review. Each role gets three fresh tables and a separate fixture role.
"""
import argparse
import copy
from datetime import datetime
import importlib.util
import json
from pathlib import Path
import re
import time
import uuid

HELPERS=Path(__file__).parent
if not (HELPERS/'qualify_campaign_completion_iam.py').exists():
    HELPERS=Path('/tmp/amt-play-lifecycle-dev-deployment/scripts')
spec=importlib.util.spec_from_file_location('history_fixture_engine',HELPERS/'qualify_campaign_completion_iam.py')
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)
need=f.require;seq=f.seq;canonical=f.canonical;sha=f.sha
ACCOUNT=f.ACCOUNT;REGION=f.REGION;ROOT=f.ROOT
TABLES={k:ROOT+'trustcheckradar-dev-'+v for k,v in {'control':'history-control','content':'history-content','ledger':'deletion-ledger'}.items()}
PREFIX='amt-history-iam-'
ROLES={
 'lifecycle':('trustcheckradar-dev-history-lifecycle-role','history-lifecycle-runtime','aws_iam_role_policy.runtime[0]'),
 'bridge':('trustcheckradar-dev-history-account-deletion-bridge-role','history-account-deletion-runtime','aws_iam_role_policy.account_deletion[0]')}


def condition(prefix,tx=False,none=False):
    result={'ForAllValues:StringLike':{'dynamodb:LeadingKeys':prefix}}
    if tx:result['ForAnyValue:StringEquals']={'dynamodb:EnclosingOperation':'TransactWriteItems'}
    if none:result['StringEqualsIfExists']={'dynamodb:ReturnValues':'NONE'}
    return result


def shape(st):
    return canonical([sorted(seq(st['Action'])),sorted(seq(st['Resource'])),f.recovery.conditions(st.get('Condition',{}))])


def expected(kind):
    def s(actions,table,prefix=None,tx=False,none=False):
        return shape({'Action':['dynamodb:'+a for a in actions.split()], 'Resource':TABLES[table], 'Condition':condition(prefix,tx,none) if prefix else {}})
    common=[s('ConditionCheckItem','control','USER#*',none=True),s('ConditionCheckItem','ledger','ACCOUNT#*',none=True),s('GetItem','ledger','ACCOUNT#*'),s('PutItem','ledger','ACCOUNT#*',tx=True,none=True)]
    if kind=='bridge':return common+[s('GetItem','control','USER#*'),s('GetItem PutItem','control','LIFECYCLE#dev'),s('Scan','ledger'),s('PutItem UpdateItem','control','USER#*',tx=True,none=True)]
    need(kind=='lifecycle','role_kind')
    return common+[s('Query DeleteItem','content','USER#*#HISTORY#*'),s('GetItem PutItem UpdateItem DeleteItem','control',['USER#*','CURSOR#*','LIFECYCLE#dev']),s('Query','control','USER#*')]


def project(doc,kind,validate_expected=True):
    need(set(doc)=={'Version','Statement'} and doc['Version']=='2012-10-17' and isinstance(doc['Statement'],list),'policy_schema')
    retained=[];omitted=[];seen=set()
    indexes={TABLES['content']+'/index/ExpirationIndex',TABLES['control']+'/index/ExpirationIndex',TABLES['control']+'/index/PendingLifecycleIndex'}
    for st in doc['Statement']:
        need(set(st)<={'Sid','Effect','Action','Resource','Condition'} and st.get('Effect')=='Allow','unsupported_statement')
        sid=st.get('Sid');need(isinstance(sid,str) and sid not in seen,'statement_sid');seen.add(sid)
        actions=seq(st.get('Action'));resources=seq(st.get('Resource'))
        need(actions and resources and all(isinstance(x,str) for x in actions+resources) and len(actions)==len(set(actions)) and len(resources)==len(set(resources)),'action_resource_schema')
        need(all('*' not in a and '?' not in a for a in actions),'wildcard_action')
        if any(r in TABLES.values() for r in resources):
            need(all(r in TABLES.values() for r in resources) and all(a.startswith('dynamodb:') for a in actions),'mixed_table_scope')
            retained.append(copy.deepcopy(st));continue
        if set(actions)<={'logs:CreateLogStream','logs:PutLogEvents'}:
            need(all(r.startswith(f'arn:aws:logs:{REGION}:{ACCOUNT}:log-group:/aws/lambda/trustcheckradar-dev-history-') and r.endswith(':*') for r in resources),'logging_resource')
            reason='logging_actions_cannot_authorize_dynamodb'
        elif set(actions)=={'dynamodb:Query'} and set(resources)<=indexes:
            need(f.recovery.conditions(st.get('Condition',{}))==f.recovery.conditions(condition(['HISTORY#*','CONTROL#*','PENDING#*'])),'index_condition')
            reason='exact_index_arns_do_not_authorize_base_table_operations'
        elif set(actions)=={'dynamodb:ListStreams'}:
            need(resources==['*'] and f.recovery.conditions(st.get('Condition',{}))==f.recovery.conditions({'StringEquals':{'aws:RequestedRegion':REGION}}),'regional_stream_listing')
            reason='regional_list_streams_cannot_authorize_base_table_operations'
        elif set(actions)=={'dynamodb:DescribeStream','dynamodb:GetRecords','dynamodb:GetShardIterator'}:
            need(len(resources)==1 and re.fullmatch(re.escape(TABLES['ledger'])+r'/stream/[0-9T:.Z-]+',resources[0]),'stream_resource')
            need(not st.get('Condition'),'stream_conditions');reason='stream_actions_do_not_authorize_base_table_operations'
        elif set(actions)=={'dynamodb:Query','dynamodb:UpdateItem','dynamodb:PutItem'} and resources==[ROOT+'trustcheckradar-dev-analysis-abuse-control']:
            need(f.recovery.conditions(st.get('Condition',{}))==f.recovery.conditions(condition('ANALYSIS#REQUEST#*')),'abuse_conditions')
            reason='exact_distinct_analysis_abuse_table'
        else:raise f.QualificationError('unrecognized_or_potentially_overlapping_statement')
        omitted.append({'sid':sid,'statementSha256':sha(canonical(st).encode()),'reason':reason})
    if validate_expected:need(sorted(map(shape,retained))==sorted(expected(kind)),'unexpected_complete_table_union')
    return {'Version':'2012-10-17','Statement':retained},omitted


def equivalent(policy):
    return sorted(canonical({'Effect':s['Effect'],'Action':sorted(seq(s['Action'])),'Resource':sorted(seq(s['Resource'])),'Condition':f.recovery.conditions(s.get('Condition',{})),'Sid':s.get('Sid')}) for s in policy['Statement'])


def load_union(plan_path,audit_path,kind):
    raw=Path(plan_path).read_bytes();araw=Path(audit_path).read_bytes();plan=json.loads(raw);audit=json.loads(araw)
    need(datetime.fromisoformat(audit['observedAtUtc']).tzinfo is not None,'audit_timestamp')
    role_name,policy_name,address=ROLES[kind];role=audit['roles'][role_name]
    need(role['arn']==f'arn:aws:iam::{ACCOUNT}:role/{role_name}' and role['permissionsBoundary'] is None and not role['managed'],'role_sources')
    need(policy_name in role['inline'],'missing_runtime_policy')
    changes=[x for x in plan['resource_changes'] if x.get('address')==address];need(len(changes)==1,'plan_address')
    r=changes[0];c=r['change']
    need(r.get('type')=='aws_iam_role_policy' and r.get('mode')=='managed' and c['actions'] in (['update'],['no-op']) and not c.get('after_unknown',{}).get('policy'),'plan_shape')
    need(c['after']['role']==role_name and c['after']['name']==policy_name,'plan_binding')
    need(equivalent(json.loads(c['before']['policy']))==equivalent(role['inline'][policy_name]),'audit_before_mismatch')
    full=json.loads(c['after']['policy']);all_docs={**role['inline'],policy_name:full}
    combined={'Version':'2012-10-17','Statement':[]};omitted=[]
    for name,doc in all_docs.items():
        projected,excluded=project(doc,kind,validate_expected=False)
        combined['Statement'].extend(projected['Statement']);omitted.extend({'source':name,**s} for s in excluded)
    need(sorted(map(shape,combined['Statement']))==sorted(expected(kind)),'unexpected_complete_table_union')
    return combined,{'roleKind':kind,'sourcePlanSha256':sha(raw),'sourceRoleAuditSha256':sha(araw),'roleAuditObservedAtUtc':audit['observedAtUtc'],'fullSourcePolicySha256':sha(canonical(equivalent(full)).encode()),'projectedUnionSha256':sha(canonical(combined).encode()),'omittedStatements':omitted,'identityPolicyNames':sorted(all_docs),'helperSha256':{n:sha((HELPERS/(n+'.py')).read_bytes()) for n in ('qualify_campaign_completion_iam','qualify_campaign_writer_iam','qualify_campaign_recovery_iam')}}


def remap(policy,names):
    need(set(names)==set(TABLES) and len(set(names.values()))==3,'fixture_tables')
    for k,n in names.items():need(re.fullmatch(PREFIX+r'[a-f0-9]{32}-'+k,n),'fixture_name')
    mapping={TABLES[k]:ROOT+n for k,n in names.items()};result=copy.deepcopy(policy)
    for st in result['Statement']:
        need(all(r in mapping for r in seq(st['Resource'])) and all(a.startswith('dynamodb:') and '*' not in a for a in seq(st['Action'])),'fixture_grant')
        st['Resource']=[mapping[r] for r in seq(st['Resource'])]
    need('trustcheckradar-dev-' not in canonical(result),'live_resource_leak');return result


def seed(admin,n,label):
    pk='USER#fixture-'+label;account='ACCOUNT#fixture-'+label
    for table,key,sk in [(n['control'],pk,'STATE'),(n['control'],pk,'GUARD'),(n['ledger'],account,'ACCOUNT_DELETION')]:
        admin.put_item(TableName=table,Item={**f.key(key,sk),'revision':{'N':'1'}})
    return pk,account


def transaction(n,pk,account):
    one={':one':{'N':'1'}}
    return [f.check(n['control'],pk,'GUARD','revision = :one',one),f.check(n['ledger'],account,'ACCOUNT_DELETION','revision = :one',one),{'Update':{'TableName':n['control'],'Key':f.key(pk,'STATE'),'UpdateExpression':'SET revision = :two','ConditionExpression':'revision = :one','ExpressionAttributeValues':{**one,':two':{'N':'2'}},'ReturnValuesOnConditionCheckFailure':'NONE'}},f.put(n['control'],f.key(pk,'JOB')),f.put(n['ledger'],f.key(account,'COMPONENT#HISTORY'))]


def snapshot(admin,n,pk,account):
    return [f.read(admin,t,p,s) for t,p,s in [(n['control'],pk,'STATE'),(n['control'],pk,'JOB'),(n['ledger'],account,'COMPONENT#HISTORY')]]


def exercise(client,admin,n,report):
    kind=report['roleKind'];done=report['cases'].append
    pk,account=seed(admin,n,'complete');actions=transaction(n,pk,account)
    for attempt in range(12):
        try:client.transact_write_items(TransactItems=actions,ClientRequestToken=uuid.uuid5(uuid.UUID(report['runId']),'history').hex);break
        except Exception as exc:need(f.error_code(exc) in ('AccessDenied','AccessDeniedException') and attempt<11,'positive_transaction_failed');time.sleep(3)
    state=snapshot(admin,n,pk,account);need(state[0]['revision']=={'N':'2'} and all(s is not None for s in state[1:]),'positive_not_observed');done('guarded_control_put_update_and_ledger_receipt_atomic_allowed')
    for index,label in [(0,'control'),(1,'ledger')]:
        pk,account=seed(admin,n,label);actions=transaction(n,pk,account);op=actions[index]['ConditionCheck']
        admin.update_item(TableName=op['TableName'],Key=op['Key'],UpdateExpression='SET revision = :bad',ExpressionAttributeValues={':bad':{'N':'9'}})
        before=snapshot(admin,n,pk,account);f.canceled(lambda:client.transact_write_items(TransactItems=actions),index)
        need(before==snapshot(admin,n,pk,account),'rollback_changed_state');done(label+'_race_rolls_back_without_returned_item')
    for table,prefix in [(n['control'],'USER#'),(n['ledger'],'ACCOUNT#')]:
        client.transact_write_items(TransactItems=[f.check(table,prefix+'none','PROOF')])
    done('both_namespace_condition_checks_none_allowed')
    for table,prefix in [(n['control'],'USER#'),(n['ledger'],'ACCOUNT#')]:
        admin.put_item(TableName=table,Item=f.key(prefix+'old','PROOF'))
        f.denied(lambda:client.transact_write_items(TransactItems=[f.check(table,prefix+'old','PROOF',rv='ALL_OLD')]))
    done('both_condition_checks_all_old_denied')
    for table,prefix in [(n['control'],'ACCOUNT#'),(n['ledger'],'USER#'),(n['content'],'USER#')]:
        f.denied(lambda:client.transact_write_items(TransactItems=[f.check(table,prefix+'foreign','PROOF')]))
    done('foreign_namespace_and_content_condition_checks_denied')
    f.denied(lambda:client.put_item(TableName=n['ledger'],Item=f.key('ACCOUNT#standalone','RECEIPT')));done('standalone_ledger_receipt_put_denied')
    standalone=[lambda:client.put_item(TableName=n['control'],Item=f.key('USER#standalone','JOB')),lambda:client.update_item(TableName=n['control'],Key=f.key('USER#standalone','STATE'),UpdateExpression='SET revision = :r',ExpressionAttributeValues={':r':{'N':'1'}})]
    for call in standalone:call() if kind=='lifecycle' else f.denied(call)
    done('legacy_standalone_control_put_update_allowed' if kind=='lifecycle' else 'standalone_control_put_update_denied')
    admin.put_item(TableName=n['ledger'],Item=f.key('ACCOUNT#old','RECEIPT'))
    operation=f.put(n['ledger'],f.key('ACCOUNT#old','RECEIPT'));operation['Put']['ReturnValuesOnConditionCheckFailure']='ALL_OLD'
    f.denied(lambda:client.transact_write_items(TransactItems=[operation]));done('ledger_receipt_all_old_denied')
    for op in ('Put','Update'):
        admin.put_item(TableName=n['control'],Item=f.key('USER#old',op))
        operation=f.put(n['control'],f.key('USER#old',op)) if op=='Put' else {'Update':{'TableName':n['control'],'Key':f.key('USER#old',op),'UpdateExpression':'SET revision = :r','ExpressionAttributeValues':{':r':{'N':'2'}},'ConditionExpression':'attribute_not_exists(PK)'}}
        operation[op]['ReturnValuesOnConditionCheckFailure']='ALL_OLD'
        if kind=='bridge':f.denied(lambda:client.transact_write_items(TransactItems=[operation]))
        else:
            try:client.transact_write_items(TransactItems=[operation]);raise f.QualificationError('expected_legacy_condition_failure')
            except Exception as exc:
                need(f.error_code(exc)=='TransactionCanceledException','legacy_all_old_not_authorized')
                reasons=exc.response.get('CancellationReasons',[]);need(len(reasons)==1 and reasons[0].get('Code')=='ConditionalCheckFailed' and reasons[0].get('Item')==f.key('USER#old',op),'legacy_all_old_item_mismatch')
    done('legacy_control_all_old_allowed' if kind=='lifecycle' else 'control_put_update_all_old_denied')
    for table in (n['control'],n['ledger']):
        f.denied(lambda:client.transact_write_items(TransactItems=[f.put(table,f.key('OTHER#foreign','JOB'))]))
    done('foreign_mutation_prefix_denied')
    if kind=='bridge':
        client.scan(TableName=n['ledger'],Select='COUNT');client.put_item(TableName=n['control'],Item=f.key('LIFECYCLE#dev','CHECKPOINT'))
        need(f.read(client,n['control'],'LIFECYCLE#dev','CHECKPOINT') is not None,'checkpoint_read_failed')
        f.denied(lambda:client.query(TableName=n['content'],KeyConditionExpression='PK = :pk',ExpressionAttributeValues={':pk':{'S':'USER#fixture#HISTORY#1'}}))
    else:
        admin.put_item(TableName=n['content'],Item=f.key('USER#fixture#HISTORY#1','CONTENT'))
        client.query(TableName=n['content'],KeyConditionExpression='PK = :pk',ExpressionAttributeValues={':pk':{'S':'USER#fixture#HISTORY#1'}})
        client.delete_item(TableName=n['content'],Key=f.key('USER#fixture#HISTORY#1','CONTENT'));need(f.read(admin,n['content'],'USER#fixture#HISTORY#1','CONTENT') is None,'content_not_deleted')
        client.put_item(TableName=n['control'],Item=f.key('CURSOR#fixture','CURSOR'));client.delete_item(TableName=n['control'],Key=f.key('CURSOR#fixture','CURSOR'))
        f.denied(lambda:client.scan(TableName=n['ledger'],Select='COUNT'))
    done('retained_legacy_access_and_role_specific_boundaries_verified')


def qualify(session,policy,evidence):
    original=f.TABLES,f.PREFIX,f.remap,f.exercise
    try:
        f.TABLES=TABLES;f.PREFIX=PREFIX;f.remap=remap;f.exercise=exercise
        report=f.qualify(session,policy,evidence)
    finally:f.TABLES,f.PREFIX,f.remap,f.exercise=original
    report['harnessSha256']=sha(Path(__file__).read_bytes())
    report['limitations']=['Full dated identity-policy projection for exact three base tables; no SCP, table-resource-policy or later policy-change qualification.','Exact indexes, ledger stream, separate analysis-abuse table and logging are excluded and not exercised.','LeadingKeys qualifies namespace only, not caller ownership or sort keys.','Lifecycle legacy control standalone mutation and ALL_OLD remain allowed; bridge ledger Scan and checkpoint Put remain allowed.','Synthetic IAM/atomicity cases do not qualify actual handler behavior, encrypted-table KMS access or live deletion activation.']
    return report


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--plan',required=True);parser.add_argument('--role-audit',required=True);parser.add_argument('--role',choices=ROLES,required=True);parser.add_argument('--profile',default='trustcheckradar');parser.add_argument('--execute',action='store_true');args=parser.parse_args()
    try:
        policy,evidence=load_union(args.plan,args.role_audit,args.role)
        if not args.execute:print(json.dumps({**evidence,'policyValidationPassed':True,'cloudExecuted':False,'statementCount':len(policy['Statement']),'plannedGroupedCases':12,'harnessSha256':sha(Path(__file__).read_bytes())},sort_keys=True));return 0
        import boto3
        report=qualify(boto3.Session(profile_name=args.profile,region_name=REGION),policy,evidence);print(json.dumps(report,sort_keys=True));return 0 if report['passed'] and report['cleanupComplete'] else 1
    except Exception:print('{"passed":false,"failure":"history_iam_setup_failed"}');return 1
if __name__=='__main__':raise SystemExit(main())
