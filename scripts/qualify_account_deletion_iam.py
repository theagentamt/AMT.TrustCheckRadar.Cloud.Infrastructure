#!/usr/bin/env python3
"""Offline-first account-data purchase cleanup identity-policy qualification.

Independent source review is required before --execute. Three synthetic tables
and one assumed role only; no live data, deletion activation or provider calls.
"""
import argparse
import copy
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import re
import time
import uuid


def helper(name):
    path=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

p=helper('qualify_campaign_producer_iam')
f=helper('qualify_campaign_completion_iam')
need=f.require;seq=p.seq;canonical=p.canonical;sha=p.sha
ACCOUNT=p.ACCOUNT;REGION=p.REGION;ROOT=p.ROOT
TABLES={'users':p.USERS,'ledger':p.LEDGER,'purchase':ROOT+'trustcheckradar-dev-purchase-entitlements'}
ROLE='trustcheckradar-dev-account-data-api-role';ADDRESS='aws_iam_role_policy.account_data[0]'
PREFIX='amt-account-iam-'


def specifications():
    specs=copy.deepcopy(p.SPECS['account_data'])
    specs['TransactionallyFenceAuthoritativeProfile']=p.specification('dynamodb:UpdateItem',TABLES['users'],'USER#*',tx='ForAnyValue:StringEquals',check=True)
    specs.update({
      'ReadOwnedPurchaseCleanupTargets':p.specification('dynamodb:GetItem',TABLES['purchase'],['USER#*','TOKEN#*','PURCHASE#CONTROL']),
      'FindOwnedPurchaseCleanupTargets':p.specification('dynamodb:Query',TABLES['purchase'],'USER#*'),
      'EraseOwnedPurchaseTransaction':p.specification('dynamodb:DeleteItem',TABLES['purchase'],['USER#*','TOKEN#*'],tx='ForAnyValue:StringEquals',check=True),
      'CheckPurchaseCleanupInventory':p.specification('dynamodb:ConditionCheckItem',TABLES['purchase'],'PURCHASE#CONTROL',equals=True,check=True)})
    return specs


def project(policy):
    need(set(policy)=={'Version','Statement'} and policy['Version']=='2012-10-17' and isinstance(policy['Statement'],list),'policy_schema')
    specs=specifications();retained=[];other=[];seen=set()
    for st in policy['Statement']:
        need(set(st)<={'Sid','Effect','Action','Resource','Condition'} and st.get('Effect')=='Allow','statement_fields_effect')
        sid=st.get('Sid');need(isinstance(sid,str) and sid not in seen,'statement_sid');seen.add(sid)
        actions=seq(st.get('Action'));resources=seq(st.get('Resource'))
        need(all(type(x)is str for x in actions+resources) and len(actions)==len(set(actions)) and len(resources)==len(set(resources)),'action_resource_schema')
        if sid in specs:
            expected=specs[sid]
            need(set(actions)==expected['actions'] and resources==[expected['table']] and p.normalize_conditions(st.get('Condition',{}))==p.normalize_conditions(expected['conditions']),'overlapping_statement_shape')
            retained.append(copy.deepcopy(st));continue
        # The reviewed producer validator classifies every omitted statement,
        # including streams and exact foreign tables, rather than ignoring SIDs.
        need(not any(r in TABLES.values() for r in resources),'unknown_overlapping_statement')
        other.append(st)
    need({s['Sid'] for s in retained}==set(specs),'missing_statement')
    # Revalidate ancillary nonoverlap through the existing strict classifier.
    # Purchase is no longer an omittable table in this qualification.
    known=copy.deepcopy(p.SPECS['account_data']);old_others=p.OTHER_TABLES
    try:
        p.OTHER_TABLES=old_others-{TABLES['purchase']}
        synthetic={'Version':'2012-10-17','Statement':other+[
          {'Sid':sid,'Effect':'Allow','Action':sorted(s['actions']),'Resource':s['table'],**({'Condition':s['conditions']} if s['conditions'] else {})}
          for sid,s in known.items()]}
        _,omitted=p.project_policy(synthetic,'account_data')
    finally:p.OTHER_TABLES=old_others
    return {'Version':'2012-10-17','Statement':retained},omitted


def load_union(plan_path,audit_path):
    raw=Path(plan_path).read_bytes();araw=Path(audit_path).read_bytes();plan=json.loads(raw);audit=json.loads(araw)
    need(datetime.fromisoformat(audit['observedAtUtc']).tzinfo is not None,'audit_timestamp')
    role=audit['roles'][ROLE]
    need(role['arn']==f'arn:aws:iam::{ACCOUNT}:role/{ROLE}' and role['permissionsBoundary'] is None and not role['managed'] and set(role['inline'])=={'account-data-runtime'},'role_sources')
    changes=[r for r in plan['resource_changes'] if r.get('address')==ADDRESS];need(len(changes)==1,'plan_address')
    r=changes[0];c=r['change'];need(r.get('mode')=='managed' and r.get('type')=='aws_iam_role_policy' and c['actions'] in (['update'],['no-op']) and c.get('after_unknown',{}).get('policy') is not True,'plan_shape')
    need(c['after']['role']==ROLE and c['after']['name']=='account-data-runtime','plan_binding')
    need(p.policy_equivalent(json.loads(c['before']['policy']))==p.policy_equivalent(role['inline']['account-data-runtime']),'audit_before_mismatch')
    full=json.loads(c['after']['policy']);policy,omitted=project(full)
    return policy,{'sourcePlanSha256':sha(raw),'sourceRoleAuditSha256':sha(araw),'roleAuditObservedAtUtc':audit['observedAtUtc'],
      'fullSourcePolicySha256':sha(p.policy_equivalent(full).encode()),'projectedPolicySha256':sha(canonical(policy).encode()),'omittedStatements':omitted,
      'helperSha256':{n:sha(Path(__file__).with_name(n+'.py').read_bytes()) for n in ('qualify_campaign_producer_iam','qualify_campaign_completion_iam','qualify_campaign_writer_iam','qualify_campaign_recovery_iam')}}


def remap(policy,names):
    need(set(names)==set(TABLES) and len(set(names.values()))==3,'fixture_tables')
    for k,n in names.items():need(re.fullmatch(PREFIX+r'[a-f0-9]{32}-'+k,n),'fixture_name')
    mapping={TABLES[k]:ROOT+n for k,n in names.items()};result=copy.deepcopy(policy)
    for st in result['Statement']:
        need(all(r in mapping for r in seq(st['Resource'])) and all(a.startswith('dynamodb:') and '*' not in a for a in seq(st['Action'])),'fixture_grant')
        st['Resource']=[mapping[r] for r in seq(st['Resource'])]
    need('trustcheckradar-dev-' not in canonical(result),'live_resource_leak');return result


def prepare(c,n,label):
    subject='fixture-'+label
    for table,pk,sk in ((n['purchase'],'PURCHASE#CONTROL','INVENTORY'),(n['ledger'],'ACCOUNT#'+subject,'ACCOUNT_DELETION'),(n['users'],'USER#'+subject,'PROFILE'),(n['purchase'],'USER#'+subject,'PURCHASE'),(n['purchase'],'TOKEN#'+subject,'OWNER')):
        c.put_item(TableName=table,Item={**f.key(pk,sk),'revision':{'N':'1'},'owner':{'S':subject}})
    return subject


def transaction(n,subject):
    one={':one':{'N':'1'}};actions=[
      f.check(n['purchase'],'PURCHASE#CONTROL','INVENTORY','revision = :one',one),
      f.check(n['ledger'],'ACCOUNT#'+subject,'ACCOUNT_DELETION','revision = :one',one),
      {'Update':{'TableName':n['users'],'Key':f.key('USER#'+subject,'PROFILE'),'UpdateExpression':'SET revision = :two','ConditionExpression':'revision = :one','ExpressionAttributeValues':{**one,':two':{'N':'2'}},'ReturnValuesOnConditionCheckFailure':'NONE'}}]
    for pk,sk in [('USER#'+subject,'PURCHASE'),('TOKEN#'+subject,'OWNER')]:
        actions.append({'Delete':{'TableName':n['purchase'],'Key':f.key(pk,sk),'ConditionExpression':'#owner = :owner AND revision = :one','ExpressionAttributeNames':{'#owner':'owner'},'ExpressionAttributeValues':{**one,':owner':{'S':subject}},'ReturnValuesOnConditionCheckFailure':'NONE'}})
    actions.append(f.put(n['ledger'],{**f.key('ACCOUNT#'+subject,'ACCOUNT_DELETION#PURCHASES'),'fixture':{'BOOL':True}}))
    return actions


def snapshot(c,n,subject):
    return [f.read(c,t,pk,sk) for t,pk,sk in [(n['users'],'USER#'+subject,'PROFILE'),(n['purchase'],'USER#'+subject,'PURCHASE'),(n['purchase'],'TOKEN#'+subject,'OWNER'),(n['ledger'],'ACCOUNT#'+subject,'ACCOUNT_DELETION#PURCHASES')]]


def exercise(client,admin,n,report):
    def done(case):report['cases'].append(case)
    subject=prepare(admin,n,'complete');actions=transaction(n,subject)
    for attempt in range(12):
        try:client.transact_write_items(TransactItems=actions,ClientRequestToken=uuid.uuid5(uuid.UUID(report['runId']),'purchase').hex);break
        except Exception as exc:need(f.error_code(exc) in ('AccessDenied','AccessDeniedException') and attempt<11,'positive_transaction_failed');time.sleep(3)
    state=snapshot(admin,n,subject);need(state[0]['revision']=={'N':'2'} and state[1:3]==[None,None] and state[3] is not None,'positive_not_observed');done('profile_update_purchase_user_token_delete_and_receipt_atomic_allowed')
    for label,index in [('purchase_control',0),('command',1),('profile',2),('purchase_owner',4)]:
        subject=prepare(admin,n,label);actions=transaction(n,subject);op=next(iter(actions[index].values()))
        admin.update_item(TableName=op['TableName'],Key=op['Key'],UpdateExpression='SET revision = :bad',ExpressionAttributeValues={':bad':{'N':'99'}})
        before=snapshot(admin,n,subject);f.canceled(lambda:client.transact_write_items(TransactItems=actions),index)
        need(before==snapshot(admin,n,subject),'rollback_mutated_state');done(label+'_race_atomic_no_returned_item')
    for table,pk,sk in [(n['purchase'],'PURCHASE#CONTROL','PROOF'),(n['ledger'],'ACCOUNT#proof','PROOF'),(n['ledger'],'INVENTORY#dev','PROOF')]:
        client.transact_write_items(TransactItems=[f.check(table,pk,sk)]);admin.put_item(TableName=table,Item=f.key(pk,sk))
        f.denied(lambda:client.transact_write_items(TransactItems=[f.check(table,pk,sk,rv='ALL_OLD')]))
        done(('purchase' if table==n['purchase'] else 'ledger_'+pk.split('#')[0])+'_check_none_allowed_all_old_denied')
    for table,pk in [(n['purchase'],'OTHER#foreign'),(n['purchase'],'USER#not-control'),(n['ledger'],'OTHER#foreign'),(n['users'],'ACCOUNT#wrong-table')]:
        f.denied(lambda:client.transact_write_items(TransactItems=[f.check(table,pk,'PROOF')]))
    done('wrong_namespace_and_wrong_table_checks_denied')
    for pk in ('USER#standalone','TOKEN#standalone'):
        f.denied(lambda:client.delete_item(TableName=n['purchase'],Key=f.key(pk,'OWNER')))
    f.denied(lambda:client.update_item(TableName=n['users'],Key=f.key('USER#standalone','PROFILE'),UpdateExpression='SET revision = :r',ExpressionAttributeValues={':r':{'N':'2'}}));done('standalone_purchase_delete_and_profile_update_denied')
    for table,pk in [(n['purchase'],'OTHER#foreign'),(n['purchase'],'PURCHASE#CONTROL'),(n['users'],'OTHER#foreign')]:
        f.denied(lambda:client.transact_write_items(TransactItems=[{'Delete':{'TableName':table,'Key':f.key(pk,'OWNER')}}]))
    f.denied(lambda:client.transact_write_items(TransactItems=[{'Update':{'TableName':n['purchase'],'Key':f.key('USER#wrong-table','PROFILE'),'UpdateExpression':'SET revision = :r','ExpressionAttributeValues':{':r':{'N':'2'}}}}]));done('foreign_mutation_control_delete_and_wrong_table_update_denied')
    # Existing broad grants are retained, not hidden behind new narrow conditions.
    client.put_item(TableName=n['ledger'],Item=f.key('ACCOUNT#legacy','RECEIPT'));client.delete_item(TableName=n['ledger'],Key=f.key('ACCOUNT#legacy','RECEIPT'))
    client.scan(TableName=n['ledger'],Select='COUNT');done('existing_ledger_standalone_put_delete_and_scan_allowed')
    subject=prepare(admin,n,'all-old');actions=transaction(n,subject)
    for index in (2,3,4):
        operation=copy.deepcopy(actions[index]);item=next(iter(operation.values()))
        item['ReturnValuesOnConditionCheckFailure']='ALL_OLD'
        item['ConditionExpression']='attribute_not_exists(PK)'
        item.pop('ExpressionAttributeNames',None)
        if index==2:item['ExpressionAttributeValues']={':two':{'N':'2'}}
        else:item.pop('ExpressionAttributeValues',None)
        f.denied(lambda:client.transact_write_items(TransactItems=[operation]))
    done('profile_update_purchase_user_token_delete_all_old_denied')


def qualify(session,policy,evidence):
    # Reuse frozen cleanup/trust/timeout engine; only explicit fixture table map,
    # remapping validator and test callback change. Helpers are never edited.
    original=(f.TABLES,f.PREFIX,f.remap,f.exercise)
    try:
        f.TABLES=TABLES;f.PREFIX=PREFIX;f.remap=remap;f.exercise=exercise
        report=f.qualify(session,policy,evidence)
    finally:f.TABLES,f.PREFIX,f.remap,f.exercise=original
    report['harnessSha256']=sha(Path(__file__).read_bytes())
    report['scope']='complete account-data identity-policy projections for users, deletion ledger and purchase entitlements on three disposable tables'
    report['limitations']=['Dated full role inventory excludes SCPs, table policies and subsequent identity-policy changes.','Only exact disjoint tables/services/streams are omitted; their runtime behavior is unqualified.','Synthetic transactions qualify IAM, not full handler, store provider, Cognito deletion, account export, retention or live activation.','LeadingKeys constrains namespaces, not authenticated account or sort-key ownership.','Existing ledger Scan and standalone ACCOUNT Put/Delete, users Delete and recovery-control Update authority remain; profile Update and purchase Delete are narrowed to NONE.']
    return report


def main():
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('--plan',required=True);a.add_argument('--role-audit',required=True);a.add_argument('--profile',default='trustcheckradar');a.add_argument('--execute',action='store_true');args=a.parse_args()
    try:
        policy,evidence=load_union(args.plan,args.role_audit)
        if not args.execute:print(json.dumps({**evidence,'policyValidationPassed':True,'cloudExecuted':False,'statementCount':len(policy['Statement']),'harnessSha256':sha(Path(__file__).read_bytes())},sort_keys=True));return 0
        import boto3
        report=qualify(boto3.Session(profile_name=args.profile,region_name=REGION),policy,evidence);print(json.dumps(report,sort_keys=True));return 0 if report['passed'] and report['cleanupComplete'] else 1
    except Exception:print('{"passed":false,"failure":"account_deletion_qualification_setup_failed"}');return 1
if __name__=='__main__':raise SystemExit(main())
