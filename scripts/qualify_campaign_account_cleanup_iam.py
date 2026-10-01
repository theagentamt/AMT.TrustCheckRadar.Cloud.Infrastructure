#!/usr/bin/env python3
"""Offline-first qualification of three new campaign account-cleanup grants only.

One combined fixture role is deliberately not a deployed role's effective union.
Optional complete role audit reports possible overlaps without hiding them.
"""
import argparse
import copy
from datetime import datetime
import fnmatch
import importlib.util
import json
from pathlib import Path
import re
import time

path=Path(__file__).with_name('qualify_campaign_completion_iam.py')
spec=importlib.util.spec_from_file_location('cleanup_fixture_engine',path)
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)
need=f.require;seq=f.seq;canonical=f.canonical;sha=f.sha
ACCOUNT=f.ACCOUNT;REGION=f.REGION;ROOT=f.ROOT
TABLES={k:ROOT+'trustcheckradar-dev-campaign-'+k for k in ('pipeline','intelligence')}
PREFIX='amt-cleanup-grant-'
ROLES={'deletion':'trustcheckradar-dev-campaign-deletion-bridge-role','lifecycle':'trustcheckradar-dev-campaign-lifecycle-role'}


def expected():
    def conditions(pk,check):
        result={'ForAllValues:StringLike':{'dynamodb:LeadingKeys':pk}}
        if check:result['StringEqualsIfExists']={'dynamodb:ReturnValues':'NONE'}
        return result
    return {
      'ReadDeletionPublicationAggregate':('deletion','dynamodb:GetItem',TABLES['intelligence'],conditions('CAMPAIGN#*',False)),
      'CheckDeletionPublicationAggregate':('deletion','dynamodb:ConditionCheckItem',TABLES['intelligence'],conditions('CAMPAIGN#*',True)),
      'CheckPublicationContributorTombstones':('lifecycle','dynamodb:ConditionCheckItem',TABLES['pipeline'],conditions('CONTRIB#*',True))}


def validate(policy,kind):
    need(set(policy)=={'Version','Statement'} and policy['Version']=='2012-10-17' and isinstance(policy['Statement'],list),'policy_schema')
    allowed={sid:s for sid,s in expected().items() if s[0]==kind};seen=set()
    for st in policy['Statement']:
        need(set(st)=={'Sid','Effect','Action','Resource','Condition'} and st['Effect']=='Allow','statement_fields')
        sid=st['Sid'];need(sid in allowed and sid not in seen,'statement_sid');seen.add(sid)
        _,action,resource,condition=allowed[sid]
        need(seq(st['Action'])==[action] and seq(st['Resource'])==[resource] and f.recovery.conditions(st['Condition'])==f.recovery.conditions(condition),'statement_scope')
    need(seen==set(allowed),'missing_statement');return copy.deepcopy(policy)


def pattern_may_overlap(pattern,prefix):
    # LeadingKeys restrictions can prove disjointness only through their fixed
    # literal prefix. Unknown wildcard intersections are retained conservatively.
    literal=re.split(r'[*?\[]',pattern,maxsplit=1)[0]
    return literal.startswith(prefix) or prefix.startswith(literal)


def audit_overlaps(audit_path):
    raw=Path(audit_path).read_bytes();audit=json.loads(raw)
    need(datetime.fromisoformat(audit['observedAtUtc']).tzinfo is not None,'audit_timestamp')
    overlaps=[];hashes={}
    for kind,name in ROLES.items():
        role=audit['roles'][name]
        need(role['arn']==f'arn:aws:iam::{ACCOUNT}:role/{name}' and role['permissionsBoundary'] is None,'audit_identity_boundary')
        need(isinstance(role['inline'],dict) and isinstance(role['managed'],dict) and (role['inline'] or role['managed']),'audit_policy_inventory')
        for source_type in ('inline','managed'):
            for source,policy in role[source_type].items():
                need(set(policy)=={'Version','Statement'} and policy['Version']=='2012-10-17','audit_policy_schema')
                hashes[name+'/'+source_type+'/'+source]=sha(canonical(policy).encode())
                for st in seq(policy['Statement']):
                    need(set(st)<={'Sid','Effect','Action','NotAction','Resource','NotResource','Condition'} and st.get('Effect') in ('Allow','Deny'),'audit_statement_schema')
                    need(('Action'in st)!=('NotAction'in st) and ('Resource'in st)!=('NotResource'in st),'audit_statement_selectors')
                    actions=seq(st.get('Action',st.get('NotAction')));resources=seq(st.get('Resource',st.get('NotResource')))
                    need(all(type(x)is str for x in actions+resources),'audit_selectors')
                    for target,(owner,action,resource,condition) in expected().items():
                        if owner!=kind:continue
                        matches_action=any('${' not in x and fnmatch.fnmatchcase(action.lower(),x.lower()) for x in actions)
                        matches_resource=any('${' not in x and fnmatch.fnmatchcase(resource,x) for x in resources)
                        possible_action=matches_action or any('${' in x for x in actions)
                        possible_resource=matches_resource or any('${' in x for x in resources)
                        if ('Action'in st and not possible_action) or ('NotAction'in st and matches_action):continue
                        if ('Resource'in st and not possible_resource) or ('NotResource'in st and matches_resource):continue
                        prefix=condition['ForAllValues:StringLike']['dynamodb:LeadingKeys'].rstrip('*')
                        disjoint=False
                        for operator,fields in st.get('Condition',{}).items():
                            need(isinstance(fields,dict),'audit_conditions')
                            if operator in ('ForAllValues:StringLike','ForAllValues:StringEquals') and 'dynamodb:LeadingKeys'in fields:
                                patterns=seq(fields['dynamodb:LeadingKeys']);need(patterns and all(type(x)is str for x in patterns),'audit_leading_keys')
                                # Policy variables cannot prove nonoverlap.
                                if not any('${'in x or pattern_may_overlap(x,prefix) for x in patterns):disjoint=True
                        if not disjoint:overlaps.append({'role':name,'sourceType':source_type,'source':source,'sid':st.get('Sid'),'effect':st['Effect'],'targetNewGrant':target})
    return {'roleAuditSha256':sha(raw),'roleAuditObservedAtUtc':audit['observedAtUtc'],'auditedPolicySha256':hashes,'possibleExistingNamespaceOverlaps':overlaps,
            'roleAuditScope':'complete supplied identity-policy inventory; conservative action/resource/key-prefix overlap analysis only, not effective permission evaluation'}


def load(plan_path,audit_path=None):
    raw=Path(plan_path).read_bytes();plan=json.loads(raw);combined={'Version':'2012-10-17','Statement':[]};hashes={}
    for kind,name in ROLES.items():
        address=f'aws_iam_role_policy.account_cleanup["{kind}"]';found=[r for r in plan['resource_changes'] if r.get('address')==address];need(len(found)==1,'plan_address')
        r=found[0];c=r['change'];need(r.get('type')=='aws_iam_role_policy' and r.get('mode')=='managed' and c['actions']==['create'] and c['before'] is None and c.get('after_unknown',{}).get('policy') is not True,'plan_shape')
        after=c['after'];need(after['name']=='campaign-account-cleanup' and after['role']==name,'plan_binding')
        policy=validate(json.loads(after['policy']),kind);combined['Statement'].extend(policy['Statement']);hashes[kind]=sha(canonical(policy).encode())
    evidence={'sourcePlanSha256':sha(raw),'newPolicySha256':hashes,'scope':'three new grants combined in one synthetic role; not full-role or per-role authorization',
      'helperSha256':{name:sha(Path(__file__).with_name(name+'.py').read_bytes()) for name in ('qualify_campaign_completion_iam','qualify_campaign_writer_iam','qualify_campaign_recovery_iam')}}
    if audit_path:evidence.update(audit_overlaps(audit_path))
    else:evidence['roleAuditScope']='not supplied; no existing identity-policy overlap claim'
    return combined,evidence


def remap(policy,names):
    need(set(names)==set(TABLES) and len(set(names.values()))==2,'fixture_tables')
    for k,n in names.items():need(re.fullmatch(PREFIX+r'[a-f0-9]{32}-'+k,n),'fixture_name')
    mapping={TABLES[k]:ROOT+n for k,n in names.items()};out=copy.deepcopy(policy)
    for st in out['Statement']:
        need(seq(st['Action']) in (['dynamodb:GetItem'],['dynamodb:ConditionCheckItem']) and all(r in mapping for r in seq(st['Resource'])),'fixture_grants')
        st['Resource']=[mapping[r] for r in seq(st['Resource'])]
    return out


def exercise(client,admin,n,report):
    def done(case):report['cases'].append(case)
    points=[(n['intelligence'],'CAMPAIGN#fixture','AGGREGATE'),(n['pipeline'],'CONTRIB#fixture','TOMBSTONE')]
    for table,pk,sk in points:admin.put_item(TableName=table,Item={**f.key(pk,sk),'revision':{'N':'1'}})
    for attempt in range(12):
        try:observed=f.read(client,*points[0]);need(observed and observed['revision']=={'N':'1'},'get_not_observed');break
        except Exception as exc:need(f.error_code(exc) in ('AccessDenied','AccessDeniedException') and attempt<11,'positive_get_failed');time.sleep(3)
    done('intelligence_campaign_get_allowed')
    f.denied(lambda:f.read(client,n['intelligence'],'OTHER#foreign','AGGREGATE'));done('foreign_intelligence_get_denied')
    f.denied(lambda:f.read(client,*points[1]));done('new_grants_do_not_grant_pipeline_get')
    checks=[]
    for i,(table,pk,sk) in enumerate(points):
        guard=f.check(table,pk,sk,'revision = :one',{':one':{'N':'1'}});client.transact_write_items(TransactItems=[guard]);checks.append(guard);done(str(i)+'_condition_none_allowed')
        f.denied(lambda:client.transact_write_items(TransactItems=[f.check(table,pk,sk,rv='ALL_OLD')]));done(str(i)+'_failed_condition_all_old_denied')
        f.denied(lambda:client.transact_write_items(TransactItems=[f.check(table,'OTHER#foreign',sk)]));done(str(i)+'_foreign_partition_denied')
        other=points[1-i][0];f.denied(lambda:client.transact_write_items(TransactItems=[f.check(other,pk,sk)]));done(str(i)+'_wrong_table_namespace_denied')
    bad=copy.deepcopy(checks);bad[1]['ConditionCheck']['ExpressionAttributeValues'][':one']={'N':'99'}
    f.canceled(lambda:client.transact_write_items(TransactItems=bad),1);done('failed_combined_check_returns_no_item')
    for table,pk,sk in points:
        f.denied(lambda:client.put_item(TableName=table,Item=f.key(pk,sk)))
        f.denied(lambda:client.delete_item(TableName=table,Key=f.key(pk,sk)))
        f.denied(lambda:client.update_item(TableName=table,Key=f.key(pk,sk),UpdateExpression='SET revision = :v',ExpressionAttributeValues={':v':{'N':'2'}}))
        f.denied(lambda:client.scan(TableName=table));done(('pipeline' if table==n['pipeline'] else 'intelligence')+'_new_grants_no_mutation_or_scan')


def qualify(session,policy,evidence):
    old=(f.TABLES,f.PREFIX,f.remap,f.exercise)
    try:
        f.TABLES=TABLES;f.PREFIX=PREFIX;f.remap=remap;f.exercise=exercise;report=f.qualify(session,policy,evidence)
    finally:f.TABLES,f.PREFIX,f.remap,f.exercise=old
    report['harnessSha256']=sha(Path(__file__).read_bytes())
    report['limitations']=['Only three new grants are attached to one combined fixture role. Negative cases do not prove denial by deployed roles with existing grants.','Optional audit reports possible overlaps conservatively; it does not apply IAM conditions, SCPs, boundaries, table policies or later changes.','No deployed role, live data, provider, handler, publication, cleanup, erasure or activation behavior is exercised.']
    return report


def main():
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('--plan',required=True);a.add_argument('--role-audit');a.add_argument('--profile',default='trustcheckradar');a.add_argument('--execute',action='store_true');args=a.parse_args()
    try:
        policy,evidence=load(args.plan,args.role_audit)
        if not args.execute:print(json.dumps({**evidence,'policyValidationPassed':True,'cloudExecuted':False,'harnessSha256':sha(Path(__file__).read_bytes())},sort_keys=True));return 0
        import boto3
        result=qualify(boto3.Session(profile_name=args.profile,region_name=REGION),policy,evidence);print(json.dumps(result,sort_keys=True));return 0 if result['passed'] and result['cleanupComplete'] else 1
    except Exception:print('{"passed":false,"failure":"account_cleanup_grant_qualification_setup_failed"}');return 1
if __name__=='__main__':raise SystemExit(main())
