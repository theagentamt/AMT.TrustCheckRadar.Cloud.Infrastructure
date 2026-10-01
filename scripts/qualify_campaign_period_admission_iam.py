#!/usr/bin/env python3
"""Offline-first exact period-admission union validation and disposable IAM tests.

No KMS, application data or live writer operation. Execute after frozen review.
"""
import argparse
import copy
from datetime import datetime,timezone
import importlib.util
import json
from pathlib import Path
import time

_path=Path(__file__).with_name('qualify_campaign_writer_iam.py')
_spec=importlib.util.spec_from_file_location('period_writer_fixture',_path)
w=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(w)
require=w.require;seq=w.seq;canonical=w.canonical;sha=w.sha
KINDS=('publisher','cluster','lifecycle')
ROLE_NAMES={k:'trustcheckradar-dev-campaign-'+n+'-role' for k,n in [('publisher','observation-publisher'),('cluster','cluster-aggregator'),('lifecycle','lifecycle')]}
PIPELINE=w.TABLES['campaign-pipeline']
PERIOD_CHECK='CheckExactPeriodAdmission';CLOSE='ClosePeriodAdmissionTransaction'
NARROW_SID='WriteMutableLifecyclePipeline'
OLD_KEYS=['PERIOD#*','EVENT#*','CONTRIB#*','CANDIDATE#*','BUCKET#*']
NEW_KEYS=OLD_KEYS[1:]


def equivalent(policy):
    p=copy.deepcopy(policy)
    for st in p['Statement']:
        for key in ('Action','Resource'):
            if key in st:st[key]=sorted(seq(st[key]))
        if 'Condition' in st:st['Condition']=w.normalized_conditions(st['Condition'])
    p['Statement']=sorted(p['Statement'],key=canonical)
    return canonical(p)


def admission_policy(policy,kind):
    require(set(policy)=={'Version','Statement'} and policy['Version']=='2012-10-17','admission_schema')
    expected={PERIOD_CHECK:({'dynamodb:ConditionCheckItem'},{'ForAllValues:StringLike':{'dynamodb:LeadingKeys':'PERIOD#*'},'StringEqualsIfExists':{'dynamodb:ReturnValues':'NONE'}})}
    if kind=='lifecycle':expected[CLOSE]=({'dynamodb:UpdateItem'},{'ForAllValues:StringLike':{'dynamodb:LeadingKeys':'PERIOD#*'},'ForAnyValue:StringEquals':{'dynamodb:EnclosingOperation':'TransactWriteItems'},'StringEqualsIfExists':{'dynamodb:ReturnValues':'NONE'}})
    seen=set()
    for st in policy['Statement']:
        require(set(st)=={'Sid','Effect','Action','Resource','Condition'},'admission_fields')
        sid=st['Sid'];require(sid in expected and sid not in seen and st['Effect']=='Allow','admission_sid');seen.add(sid)
        actions,conditions=expected[sid]
        require(set(seq(st['Action']))==actions and len(seq(st['Action']))==len(actions) and seq(st['Resource'])==[PIPELINE],'admission_actions_resource')
        require(w.normalized_conditions(st['Condition'])==w.normalized_conditions(conditions),'admission_conditions')
    require(seen==set(expected),'admission_missing_statement')
    return copy.deepcopy(policy)


def narrowed_lifecycle(policy):
    """Only remove PERIOD from the known broad grant, preserving every other bit."""
    restored=copy.deepcopy(policy)
    matches=[st for st in restored['Statement'] if st.get('Sid')==NARROW_SID]
    require(len(matches)==1,'lifecycle_mutation_statement')
    leading=matches[0]['Condition']['ForAllValues:StringLike']['dynamodb:LeadingKeys']
    require(len(seq(leading))==4 and set(seq(leading))==set(NEW_KEYS),'lifecycle_narrowing_exact')
    matches[0]['Condition']['ForAllValues:StringLike']['dynamodb:LeadingKeys']=OLD_KEYS
    validated,omitted=w.validate_policy(restored,'lifecycle')
    next(st for st in validated['Statement'] if st['Sid']==NARROW_SID)['Condition']['ForAllValues:StringLike']['dynamodb:LeadingKeys']=copy.deepcopy(leading)
    return validated,omitted


def plan_resource(plan,address,actions):
    matches=[r for r in plan.get('resource_changes',[]) if r.get('address')==address]
    require(len(matches)==1,'plan_address')
    r=matches[0];require(r.get('type')=='aws_iam_role_policy' and r.get('mode')=='managed' and r['change']['actions']==actions,'plan_resource_action')
    require(r['change'].get('after_unknown',{}).get('policy') is not True,'plan_policy_unknown')
    return r['change']


def load_union(plan_path,audit_path):
    raw=Path(plan_path).read_bytes();plan=json.loads(raw);araw=Path(audit_path).read_bytes();audit=json.loads(araw)
    require(isinstance(audit.get('observedAtUtc'),str) and datetime.fromisoformat(audit['observedAtUtc']).tzinfo is not None,'audit_timestamp')
    policies={};omitted={};full_hashes={}
    for kind in KINDS:
        name=ROLE_NAMES[kind];role=audit['roles'][name]
        require(role['arn']==f'arn:aws:iam::{w.ACCOUNT}:role/{name}' and role['permissionsBoundary'] is None and not role['managed'],'role_identity_or_sources')
        require(set(role['inline'])=={'content-free-logging',kind+'-runtime'},'role_inline_inventory')
        logs=role['inline']['content-free-logging']
        require(set(logs)=={'Version','Statement'} and logs['Version']=='2012-10-17' and len(logs['Statement'])==2,'logging_schema')
        for st in logs['Statement']:
            require(set(st)<={'Sid','Effect','Action','Resource','Condition'} and st.get('Effect')=='Allow' and seq(st.get('Action')) and set(seq(st.get('Action'))) <= {'logs:PutLogEvents','logs:CreateLogStream','cloudwatch:PutMetricData'},'logging_overlap')
        observed=role['inline'][kind+'-runtime']
        w.validate_policy(observed,kind)
        base=plan_resource(plan,f'aws_iam_role_policy.{kind}_runtime[0]',['update'] if kind=='lifecycle' else ['no-op'])
        require(base['after']['name']==kind+'-runtime' and base['after']['role']==name,'runtime_binding')
        require(equivalent(json.loads(base['before']['policy']))==equivalent(observed),'audited_runtime_before_mismatch')
        after=json.loads(base['after']['policy'])
        if kind=='lifecycle':
            original=copy.deepcopy(after);matches=[st for st in original['Statement'] if st.get('Sid')==NARROW_SID];require(len(matches)==1,'narrowing_missing')
            matches[0]['Condition']['ForAllValues:StringLike']['dynamodb:LeadingKeys']=OLD_KEYS
            require(equivalent(original)==equivalent(observed),'other_lifecycle_change')
            projected,excluded=narrowed_lifecycle(after)
        else:
            require(equivalent(after)==equivalent(observed),'unexpected_base_change')
            projected,excluded=w.validate_policy(after,kind)
        new=plan_resource(plan,f'aws_iam_role_policy.period_admission["{kind}"]',['create'])
        require(new['before'] is None and new['after']['name']=='campaign-period-admission' and new['after']['role']==name,'new_policy_binding')
        addition=admission_policy(json.loads(new['after']['policy']),kind)
        policies[kind]={'Version':'2012-10-17','Statement':projected['Statement']+addition['Statement']}
        require(len({st['Sid'] for st in policies[kind]['Statement']})==len(policies[kind]['Statement']),'union_duplicate_sid')
        omitted[kind]=excluded+[{'source':'content-free-logging','reason':'strict_non_dynamodb_logging_actions'}]
        full_hashes[kind]={'auditedRuntime':sha(equivalent(observed).encode()),'plannedRuntime':sha(equivalent(after).encode()),'newAdmissionPolicy':sha(equivalent(addition).encode())}
    return policies,omitted,{'sourcePlanSha256':sha(raw),'sourceRoleAuditSha256':sha(araw),'roleAuditObservedAtUtc':audit['observedAtUtc'],'fullSourcePolicySha256':full_hashes,'helperSha256':sha(_path.read_bytes())}


def check(table,pk,closed=False,rv='NONE'):
    return {'ConditionCheck':{'TableName':table,'Key':w.key(pk),'ConditionExpression':'admissionState = :state AND revision = :one','ExpressionAttributeValues':{':state':{'S':'CLOSING' if closed else 'OPEN'},':one':{'N':'1'}},'ReturnValuesOnConditionCheckFailure':rv}}


def exercise(kind,client,admin,policy,names,report):
    table=names['campaign-pipeline'];period='PERIOD#'+kind
    def record(name):report['cases'].append(kind+':'+name)
    def registry():admin.put_item(TableName=table,Item={**w.key(period),'admissionState':{'S':'OPEN'},'revision':{'N':'1'}})
    registry()
    for attempt in range(12):
        try:client.transact_write_items(TransactItems=[check(table,period)]);break
        except Exception as exc:
            require(w.error_code(exc) in ('AccessDenied','AccessDeniedException'),'positive_period_check_failed');require(attempt<11,'propagation_timeout');time.sleep(3)
    record('period_condition_none_allowed')
    w.denied(lambda:client.transact_write_items(TransactItems=[check(table,period,closed=True,rv='ALL_OLD')]));record('period_check_all_old_denied')
    w.denied(lambda:client.transact_write_items(TransactItems=[check(table,'OTHER#foreign')]));record('foreign_period_namespace_check_denied')
    event='EVENT#guard-'+kind;action=w.tx_action('dynamodb:PutItem',table,event)
    client.transact_write_items(TransactItems=[check(table,period),action]);record('guarded_existing_event_write_allowed')
    before=admin.get_item(TableName=table,Key=w.key(event),ConsistentRead=True)['Item']
    admin.update_item(TableName=table,Key=w.key(period),UpdateExpression='SET admissionState = :closed',ExpressionAttributeValues={':closed':{'S':'CLOSING'}})
    mutation=w.tx_action('dynamodb:UpdateItem',table,event)
    mutation['Update']['ExpressionAttributeValues']={':v':{'BOOL':False}}
    w.canceled_without_item(lambda:client.transact_write_items(TransactItems=[mutation,check(table,period)]),1)
    require(admin.get_item(TableName=table,Key=w.key(event),ConsistentRead=True)['Item']==before,'closing_race_changed_event');record('closing_guard_race_atomic_without_item')
    # Every role must lack old standalone/batch PERIOD write authority.
    for op in ('dynamodb:PutItem','dynamodb:UpdateItem','dynamodb:DeleteItem','dynamodb:BatchWriteItem'):
        if op=='dynamodb:BatchWriteItem':
            for change in ('PutRequest','DeleteRequest'):
                request={change:{'Item' if change=='PutRequest' else 'Key':w.key(period)}}
                w.denied(lambda:client.batch_write_item(RequestItems={table:[request]}))
        else:w.denied(lambda:w.action_call(client,op,table,period)())
    record('standalone_and_batch_period_writes_denied')
    for action_name in ('dynamodb:PutItem','dynamodb:DeleteItem'):
        w.denied(lambda:client.transact_write_items(TransactItems=[w.tx_action(action_name,table,period)]))
    record('transaction_period_put_delete_denied')
    if kind=='lifecycle':
        registry();admin.put_item(TableName=table,Item=w.key('INVENTORY#dev'))
        args={'TableName':table,'Key':w.key(period),'UpdateExpression':'SET admissionState = :closed','ConditionExpression':'admissionState = :open AND revision = :one','ExpressionAttributeValues':{':closed':{'S':'CLOSING'},':open':{'S':'OPEN'},':one':{'N':'1'}},'ReturnValuesOnConditionCheckFailure':'NONE'}
        inventory={'ConditionCheck':{'TableName':table,'Key':w.key('INVENTORY#dev'),'ConditionExpression':'attribute_exists(PK)','ReturnValuesOnConditionCheckFailure':'NONE'}}
        client.transact_write_items(TransactItems=[{'Update':args},inventory]);require(admin.get_item(TableName=table,Key=w.key(period),ConsistentRead=True)['Item']['admissionState']=={'S':'CLOSING'},'close_not_observed');record('transaction_closure_with_inventory_allowed')
        denied_args=copy.deepcopy(args);denied_args['ReturnValuesOnConditionCheckFailure']='ALL_OLD';w.denied(lambda:client.transact_write_items(TransactItems=[{'Update':denied_args}]))
        record('closure_update_all_old_denied')
        registry();admin.delete_item(TableName=table,Key=w.key('INVENTORY#dev'))
        w.canceled_without_item(lambda:client.transact_write_items(TransactItems=[{'Update':args},inventory]),1)
        require(admin.get_item(TableName=table,Key=w.key(period),ConsistentRead=True)['Item']['admissionState']=={'S':'OPEN'},'inventory_race_closed_period');record('inventory_guard_race_keeps_period_open')
    else:
        w.denied(lambda:client.transact_write_items(TransactItems=[w.tx_action('dynamodb:UpdateItem',table,period)]));record('non_lifecycle_period_update_denied')
    # Retained mutation statements are tested on each existing key family; read,
    # index, stream, queue and KMS paths remain explicitly outside this evidence.
    for st in policy['Statement']:
        if st['Sid']==CLOSE or not set(seq(st['Action']))&w.MUTATIONS:continue
        target=w.table_for(st,names);tx_only='ForAnyValue:StringEquals' in st.get('Condition',{})
        for pattern in w.patterns(st):
            pk=pattern.replace('*','retained-'+kind)
            for operation in sorted(set(seq(st['Action']))&w.MUTATIONS):
                if tx_only:client.transact_write_items(TransactItems=[w.tx_action(operation,target,pk)])
                else:w.action_call(client,operation,target,pk)()
                observed=admin.get_item(TableName=target,Key=w.key(pk),ConsistentRead=True).get('Item')
                require(observed is None if operation=='dynamodb:DeleteItem' else observed and observed.get('fixture')=={'BOOL':True},'retained_mutation_not_observed')
            record(st['Sid']+':'+pattern.split('#')[0]+'_retained_mutations_allowed')


def qualify(session,policies,omitted,evidence):
    # The independently reviewed helper owns fixture creation/remapping/trust and
    # tag-checked finally cleanup. Replace only its explicit per-role test callback.
    original=w.qualify_role
    try:
        w.qualify_role=exercise
        report=w.qualify(session,policies,omitted,evidence['sourcePlanSha256'],selected_roles=KINDS)
    finally:w.qualify_role=original
    report.update(evidence)
    report['fixtureEngineSha256']=sha(_path.read_bytes());report['harnessSha256']=sha(Path(__file__).read_bytes())
    report['observedAtUtc']=datetime.now(timezone.utc).isoformat()
    report['scope']='audited identity-policy unions plus planned admission grants and exact lifecycle narrowing on disposable fixtures'
    report['limitations']=['No live SCP/resource-policy, KMS, stream/queue, table/index read, writer runtime or application acceptance.','Synthetic guards validate IAM/atomic cancellation, not actual period schemas or a retirement protocol.','Exact prior lifecycle PERIOD mutation overlap is removed; all other existing DynamoDB statements are preserved.','No key state, retention, approval marker or live table is changed.']
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--plan',required=True);p.add_argument('--role-audit',required=True);p.add_argument('--profile',default='trustcheckradar');p.add_argument('--execute',action='store_true');a=p.parse_args()
    try:
        policies,omitted,evidence=load_union(a.plan,a.role_audit)
        if not a.execute:print(json.dumps({**evidence,'harnessSha256':sha(Path(__file__).read_bytes()),'policyValidationPassed':True,'cloudExecuted':False,'statementCounts':{k:len(p['Statement']) for k,p in policies.items()},'omittedStatements':omitted},sort_keys=True));return 0
        import boto3
        r=qualify(boto3.Session(profile_name=a.profile,region_name=w.REGION),policies,omitted,evidence);print(json.dumps(r,sort_keys=True));return 0 if r['passed'] and r['cleanupComplete'] else 1
    except Exception:print('{"passed":false,"failure":"period_qualification_setup_failed"}');return 1
if __name__=='__main__':raise SystemExit(main())
