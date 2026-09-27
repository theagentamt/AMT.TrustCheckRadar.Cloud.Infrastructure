#!/usr/bin/env python3
"""Offline-only binding of period-work plans to seven deployed identity-policy unions.

No AWS SDK, execution switch, policy attachment or data operation. The projection
is for two synthetic base tables only; it is not a full-system authorization test.
"""
import argparse
import copy
from datetime import datetime
import importlib.util
import json
from pathlib import Path
import re

_HELPER = Path(__file__).with_name('qualify_campaign_writer_iam.py')
_spec = importlib.util.spec_from_file_location('period_work_writer', _HELPER)
w = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(w)
need, seq, canonical, sha = w.require, w.seq, w.canonical, w.sha
ACCOUNT, REGION = w.ACCOUNT, w.REGION
ROOT = w.TABLE_ROOT
TABLES = {k: ROOT+'trustcheckradar-dev-campaign-'+k for k in ('pipeline', 'outbox')}
ROLES = {k: 'trustcheckradar-dev-'+n+'-role' for k, n in {
    'publisher':'campaign-observation-publisher', 'cluster':'campaign-cluster-aggregator',
    'deletion':'campaign-deletion-bridge', 'lifecycle':'campaign-lifecycle',
    'analysis':'conversation-analysis', 'account_data':'account-data-api', 'export':'account-export-api'}.items()}
INLINE = {
    'publisher': {'publisher-runtime','content-free-logging','campaign-period-admission'},
    'cluster': {'cluster-runtime','content-free-logging','campaign-period-admission'},
    'deletion': {'deletion-runtime','content-free-logging','campaign-account-cleanup',
        'campaign-account-cleanup-decryption','campaign-completion-candidate','campaign-recovery-candidate'},
    'lifecycle': {'lifecycle-runtime','content-free-logging','campaign-account-cleanup','campaign-period-admission'},
    'analysis': {'history-analysis-runtime','trustcheckradar-dev-research-migration-analysis'},
    'account_data': {'account-data-runtime'},
    'export': {'authenticated-read-only-account-export'},
}
ANALYSIS_MANAGED = {
    f'arn:aws:iam::{ACCOUNT}:policy/trustcheckradar-dev-conversation-analysis-runtime',
    'arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'}
API_KINDS = {'analysis','account_data','export'}
WORK_KEYS = ['PERIOD_WORK#*','WORK_LOOKUP#*']
CONTROL = ['PERIOD_WORK_CONTROL#*']
APPROVAL = ['INVENTORY#dev','PERIOD_RETIRED_PREFIX#dev']
MUTATIONS = w.MUTATIONS | {'dynamodb:PartiQLInsert','dynamodb:PartiQLUpdate','dynamodb:PartiQLDelete'}
DDB_ACTIONS = MUTATIONS | {'dynamodb:GetItem','dynamodb:Query','dynamodb:Scan',
    'dynamodb:ConditionCheckItem','dynamodb:DescribeTable'}


def normalized(policy):
    need(set(policy)=={'Version','Statement'} and policy['Version']=='2012-10-17'
         and isinstance(policy['Statement'],list), 'policy_schema')
    result=copy.deepcopy(policy)
    for st in result['Statement']:
        need(set(st)<= {'Sid','Effect','Action','Resource','Condition'} and st.get('Effect') in ('Allow','Deny'), 'statement_schema')
        for key in ('Action','Resource'):
            values=seq(st.get(key));need(values and all(type(x) is str for x in values) and len(values)==len(set(values)), 'statement_values')
            st[key]=sorted(values)
        if 'Condition' in st:st['Condition']=w.normalized_conditions(st['Condition'])
    result['Statement']=sorted(result['Statement'],key=canonical)
    return result


def equivalent(a,b):return normalized(a)==normalized(b)
def policy_hash(p):return sha(canonical(normalized(p)).encode())


def expected_new(kind, transient_key):
    if kind=='export':
        return {'Version':'2012-10-17','Statement':[
            {'Sid':'VerifyPeriodWorkExportResourceIdentity','Effect':'Allow','Action':['dynamodb:DescribeTable'],'Resource':list(TABLES.values())},
            {'Sid':'ReadPeriodWorkExportApproval','Effect':'Allow','Action':['dynamodb:GetItem'],'Resource':[TABLES['pipeline']],
             'Condition':{'ForAllValues:StringEquals':{'dynamodb:LeadingKeys':['INVENTORY#dev']}}}]}
    statements=[]
    def add(sid, actions, resources=None, keys=None, check=False, tx=False, exact=False):
        st={'Sid':sid,'Effect':'Allow','Action':actions,'Resource':resources or [TABLES['pipeline']]}
        cond={}
        if keys:cond['ForAllValues:StringEquals' if exact else 'ForAllValues:StringLike']={'dynamodb:LeadingKeys':keys}
        if tx:cond['ForAnyValue:StringEquals']={'dynamodb:EnclosingOperation':['TransactWriteItems']}
        if tx or check:cond['StringEqualsIfExists']={'dynamodb:ReturnValues':['NONE']}
        if cond:st['Condition']=cond
        statements.append(st)
    add('VerifyPeriodWorkResourceIdentity',['dynamodb:DescribeTable'],list(TABLES.values()))
    add('ReadPeriodWorkAndControls',['dynamodb:GetItem'],keys=WORK_KEYS+CONTROL+APPROVAL+(['PERIOD#*'] if kind in API_KINDS else []))
    add('MutatePairedWorkRecordsTransactionally',['dynamodb:PutItem','dynamodb:DeleteItem'],keys=WORK_KEYS,tx=True)
    add('AdvanceExistingWorkControlTransactionally',['dynamodb:UpdateItem'],keys=CONTROL,tx=True)
    add('CheckPeriodWorkApproval',['dynamodb:ConditionCheckItem'],keys=APPROVAL,check=True,exact=True)
    add('CheckExactPeriodWorkRecords',['dynamodb:ConditionCheckItem'],keys=WORK_KEYS+CONTROL+(['PERIOD#*'] if kind in API_KINDS else [])+(['PERIOD_SWEEP#dev'] if kind=='lifecycle' else []),check=True)
    if kind=='lifecycle':
        add('ReadRegisteredOutboxTargets',['dynamodb:GetItem'],[TABLES['outbox']],['ACCOUNT#*','EVENT#*'])
        add('EraseRegisteredOutboxTargetsTransactionally',['dynamodb:DeleteItem'],[TABLES['outbox']],['ACCOUNT#*','EVENT#*'],tx=True)
        add('PersistPeriodProgressTransactionally',['dynamodb:PutItem','dynamodb:UpdateItem'],keys=['PERIOD_SWEEP#dev','PERIOD_RETIRED_PREFIX#dev'],tx=True,exact=True)
    if kind in API_KINDS:
        statements.append({'Sid':'UsePeriodWorkEncryptionThroughDynamoDB','Effect':'Allow',
            'Action':['kms:Decrypt','kms:DescribeKey','kms:GenerateDataKey'],'Resource':[transient_key],
            'Condition':{'StringEquals':{'kms:CallerAccount':[ACCOUNT],'kms:ViaService':[f'dynamodb.{REGION}.amazonaws.com']}}})
    return {'Version':'2012-10-17','Statement':statements}


def expected_aggregate():
    intelligence=ROOT+'trustcheckradar-dev-campaign-intelligence'
    cursor={'ForAllValues:StringEquals':{'dynamodb:LeadingKeys':['AGGREGATE_SWEEP#dev']}}
    return {'Version':'2012-10-17','Statement':[
      {'Sid':'VerifyAggregateTableIdentity','Effect':'Allow','Action':['dynamodb:DescribeTable'],'Resource':[intelligence]},
      {'Sid':'DiscoverExpiredAnonymousAggregates','Effect':'Allow','Action':['dynamodb:Query'],'Resource':[intelligence+'/index/ExpirationIndex'],
       'Condition':{'ForAllValues:StringEquals':{'dynamodb:LeadingKeys':[f'EXPIRY#dev#{i:02d}' for i in range(16)]}}},
      {'Sid':'ReadAnonymousAggregateProgress','Effect':'Allow','Action':['dynamodb:GetItem'],'Resource':[TABLES['pipeline']],'Condition':copy.deepcopy(cursor)},
      {'Sid':'PersistAnonymousAggregateProgress','Effect':'Allow','Action':['dynamodb:PutItem'],'Resource':[TABLES['pipeline']],
       'Condition':cursor|{'ForAnyValue:StringEquals':{'dynamodb:EnclosingOperation':['TransactWriteItems']},'StringEqualsIfExists':{'dynamodb:ReturnValues':['NONE']}}}]}


def aggregate_binding(plan):
    address='aws_iam_policy.aggregate_expiry[0]';attachment_address='aws_iam_role_policy_attachment.aggregate_expiry[0]'
    present={x['address'] for x in plan['resource_changes']}
    if not ({address,attachment_address}&present):return None
    change=resource(plan,address)['change'];name='trustcheckradar-dev-campaign-aggregate-expiry';arn=f'arn:aws:iam::{ACCOUNT}:policy/{name}'
    need(change['actions']==['create'] and change['before'] is None and change['after']['name']==name
      and change['after'].get('path','/')=='/' and change['after'].get('arn') in (None,arn),'aggregate_policy_binding')
    policy=policy_from(change,'after');need(equivalent(policy,expected_aggregate()) and len(canonical(policy))<=6144,'aggregate_policy_contract')
    attachment=resource(plan,attachment_address)['change']
    need(attachment['actions']==['create'] and attachment['before'] is None and attachment['after']['role']==ROLES['lifecycle']
      and attachment['after'].get('policy_arn') in (None,arn),'aggregate_attachment_binding')
    if attachment['after'].get('policy_arn') is None:
        configs=[x for x in plan['configuration']['root_module']['resources'] if x['address']=='aws_iam_role_policy_attachment.aggregate_expiry']
        refs={'aws_iam_policy.aggregate_expiry[0].arn','aws_iam_policy.aggregate_expiry[0]','aws_iam_policy.aggregate_expiry'}
        need(attachment.get('after_unknown',{}).get('policy_arn') is True and len(configs)==1
          and set(configs[0]['expressions']['policy_arn'].get('references',[]))==refs,'aggregate_attachment_reference')
    return {'arn':arn,'policy':policy,'attachmentAddress':attachment_address}


def validate_new(policy,kind,transient_key):
    need(equivalent(policy,expected_new(kind,transient_key)), 'new_policy_contract')
    size=len(canonical(policy));need(size<=6144,'managed_policy_size')
    return size


def lifecycle_after(before,after):
    expected=copy.deepcopy(before)
    drops={'CreatePeriodHmacKeys','TagNewPeriodHmacKeys'}
    need(drops <= {s.get('Sid') for s in expected['Statement']},'kms_old_statements')
    expected['Statement']=[s for s in expected['Statement'] if s.get('Sid') not in drops]
    st=[s for s in expected['Statement'] if s.get('Sid')=='ManageTaggedPeriodHmacKeys']
    need(len(st)==1 and set(seq(st[0]['Action']))=={'kms:DescribeKey','kms:DisableKey','kms:EnableKey','kms:GetKeyPolicy','kms:TagResource'},'kms_old_management')
    st[0]['Action']=['kms:DescribeKey','kms:ListResourceTags','kms:DisableKey']
    need(equivalent(expected,after),'unexpected_lifecycle_change')


def resource(plan,address):
    found=[r for r in plan.get('resource_changes',[]) if r.get('address')==address]
    need(len(found)==1 and found[0].get('mode')=='managed','plan_resource_missing')
    return found[0]


def policy_from(change,side):
    need(not change.get(side+'_unknown',{}).get('policy'), 'policy_unknown')
    return json.loads(change[side]['policy'])


def audit_valid(audit):
    need(audit.get('accountId')==ACCOUNT and audit.get('region')==REGION and audit.get('environment')=='dev'
         and audit.get('readComplete') is True and set(audit['roles'])==set(ROLES.values()),'audit_scope')
    need(datetime.fromisoformat(audit['observedAtUtc']).tzinfo is not None,'audit_timestamp')
    for kind,name in ROLES.items():
        r=audit['roles'][name]
        need(r['arn']==f'arn:aws:iam::{ACCOUNT}:role/{name}' and r['permissionsBoundary'] is None and r.get('readComplete') is True,'role_boundary')
        need(set(r['inline'])==INLINE[kind] and set(r['managed'])==(ANALYSIS_MANAGED if kind=='analysis' else set()),'unexpected_identity_source')
        for src,p in list(r['inline'].items())+list(r['managed'].items()):
            normalized(p)
            metadata=r['policyMetadata'][src if src.startswith('arn:') else 'inline:'+src]
            need(metadata['sha256']==sha(canonical(p).encode()),'audit_policy_hash')
            if src.startswith('arn:'):need(re.fullmatch('v[1-9][0-9]*',metadata['versionId']) and metadata['defaultVersionConfirmed'] is True,'managed_version')
        need(r['trustPolicySha256']==sha(canonical(r['trustPolicy']).encode()),'trust_hash')
    retired=audit['roles'][ROLES['analysis']]['inline']['trustcheckradar-dev-research-migration-analysis']
    deny=[s for s in retired['Statement'] if s.get('Sid')=='DenyLegacySettlementAndWrites']
    need(len(deny)==1 and deny[0]['Effect']=='Deny' and seq(deny[0]['Resource'])==['*']
         and set(seq(deny[0]['Action']))==MUTATIONS and 'Condition' not in deny[0],'retired_analysis_deny')


def project(policy,source):
    """Keep every statement's intersection with the two base-table namespaces."""
    normalized(policy);kept=[];omitted=[]
    for st in policy['Statement']:
        label={'source':source,'sid':st.get('Sid'),'sourceStatementSha256':sha(canonical(st).encode())}
        actions=seq(st['Action']);need(all(':' in a and not a.startswith('*') for a in actions),'unbounded_action')
        ddb=[a for a in actions if a.startswith('dynamodb:') and a not in w.STREAM_ACTIONS]
        excluded=[a for a in actions if a not in ddb]
        if excluded:omitted.append(label|{'reason':'non_table_actions','actions':excluded})
        if not ddb:continue
        need(set(ddb)<=DDB_ACTIONS,'unsupported_ddb_action')
        selected=[];removed=[]
        for arn in seq(st['Resource']):
            if arn in TABLES.values():selected.append(arn)
            elif arn=='*':
                need(st['Effect']=='Deny','wildcard_resource_allow');selected.extend(TABLES.values())
                omitted.append(label|{'reason':'global_deny_projected_to_two_tables_other_resources_excluded'})
            else:
                # Exact account/region table namespaces; only terminal index/* may
                # contain wildcard. A wildcard table could overlap and is refused.
                need(re.fullmatch(re.escape(ROOT)+r'[A-Za-z0-9_.-]+(?:/(?:index/[A-Za-z0-9_.-]+|index/\*|stream/[0-9T:.Z-]+))?',arn), 'unproven_resource_disjointness')
                need(arn not in TABLES.values(),'resource_overlap');removed.append(arn)
        if removed:omitted.append(label|{'reason':'other_tables_indexes_or_streams_out_of_scope','resources':removed})
        if not selected:continue
        allowed_conditions={'ForAllValues:StringLike':{'dynamodb:LeadingKeys'},'ForAllValues:StringEquals':{'dynamodb:LeadingKeys'},
            'ForAnyValue:StringEquals':{'dynamodb:EnclosingOperation'},'StringEquals':{'dynamodb:EnclosingOperation'},
            'StringEqualsIfExists':{'dynamodb:ReturnValues'}}
        for operator,terms in st.get('Condition',{}).items():
            need(operator in allowed_conditions and set(terms)<=allowed_conditions[operator],'unsupported_fixture_condition')
        out=copy.deepcopy(st);out['Action']=ddb;out['Resource']=sorted(set(selected));kept.append(out)
    return kept,omitted


def synthetic(policy,run_id):
    need(re.fullmatch('[a-f0-9]{32}',run_id),'fixture_run_id')
    mapping={arn:ROOT+'amt-period-work-qual-'+run_id+'-'+name for name,arn in TABLES.items()}
    out=copy.deepcopy(policy)
    for i,st in enumerate(out['Statement']):
        need(set(seq(st['Resource']))<=set(mapping),'fixture_resource_escape')
        st['Resource']=[mapping[x] for x in seq(st['Resource'])];st['Sid']='FixtureStatement'+str(i)
    return out


def validate_plans(processing,api,audit,run_id='0'*32):
    audit_valid(audit);plans={'processing':processing,'api':api};sources={};evidence={};omissions={};unions={}
    aggregate=aggregate_binding(processing)
    for plan in plans.values():
        for change in plan.get('resource_changes',[]):
            if change.get('type') in ('aws_iam_policy_attachment','aws_iam_role_policies_exclusive','aws_iam_role_policy_attachments_exclusive'):
                need(False,'unsupported_bulk_identity_mutation')
            if change.get('type')=='aws_iam_role_policy_attachment':
                after=change['change'].get('after') or {}
                need(type(after.get('role')) is str,'unknown_attachment_role')
            if change.get('type')=='aws_iam_role_policy' and not (change['change'].get('after') or {}).get('role'):
                # The one newly created scheduler role is outside the seven runtime
                # unions. Require its specific expression rather than guessing.
                need(change['address']=='aws_iam_role_policy.period_lifecycle_scheduler_invoke[0]','unknown_inline_role')
                configs=[x for x in plan['configuration']['root_module']['resources'] if x['address']=='aws_iam_role_policy.period_lifecycle_scheduler_invoke']
                need(len(configs)==1 and set(configs[0]['expressions']['role']['references'])=={'aws_iam_role.period_lifecycle_scheduler[0].id','aws_iam_role.period_lifecycle_scheduler[0]','aws_iam_role.period_lifecycle_scheduler'},'scheduler_disjointness')
    transient_doc=audit['roles'][ROLES['analysis']]['managed'][next(x for x in ANALYSIS_MANAGED if ACCOUNT in x)]
    kms=[s for s in transient_doc['Statement'] if s.get('Sid')=='UseCampaignOutboxEncryptionThroughDynamoDB']
    need(len(kms)==1 and len(seq(kms[0]['Resource']))==1,'transient_binding')
    transient=seq(kms[0]['Resource'])[0];need(re.fullmatch(f'arn:aws:kms:{REGION}:{ACCOUNT}:key/[a-f0-9-]{{36}}',transient),'transient_key_arn')
    for kind,name in ROLES.items():
        plan=api if kind in API_KINDS else processing;r=audit['roles'][name]
        role_resources=[x for x in plan['resource_changes'] if x.get('type')=='aws_iam_role' and (x['change'].get('before') or {}).get('name')==name]
        need(len(role_resources)==1,'installed_role_plan_binding')
        role_change=role_resources[0]['change']
        need(role_change['actions']==['no-op'] and role_change['after']['name']==name
             and role_change['after'].get('permissions_boundary') in (None,'')
             and json.loads(role_change['before']['assume_role_policy'])==r['trustPolicy']
             and json.loads(role_change['after']['assume_role_policy'])==r['trustPolicy'],'role_trust_or_boundary_change')
        planned_sources={};covered=set()
        # Every installed inline source must have an exact before-policy binding.
        for src,observed in r['inline'].items():
            matches=[x for x in plan['resource_changes'] if x.get('type')=='aws_iam_role_policy' and (x['change'].get('before') or {}).get('role')==name and (x['change'].get('before') or {}).get('name')==src]
            need(len(matches)==1,'installed_inline_plan_binding');x=matches[0];c=x['change'];covered.add(x['address'])
            need(c['after']['name']==src and c['after']['role']==name and equivalent(policy_from(c,'before'),observed),'installed_before_mismatch')
            after=policy_from(c,'after')
            if kind=='lifecycle' and src=='lifecycle-runtime':
                need(c['actions']==['update'],'lifecycle_update_action');lifecycle_after(observed,after)
            else:need(c['actions']==['no-op'] and equivalent(after,observed),'unexpected_installed_change')
            planned_sources['inline:'+src]=after
        for arn,observed in r['managed'].items():
            attachments=[x for x in plan['resource_changes'] if x.get('type')=='aws_iam_role_policy_attachment' and (x['change'].get('before') or {}).get('role')==name and (x['change'].get('before') or {}).get('policy_arn')==arn]
            need(len(attachments)==1 and attachments[0]['change']['actions']==['no-op'] and attachments[0]['change']['after']['role']==name and attachments[0]['change']['after']['policy_arn']==arn,'installed_attachment_binding');covered.add(attachments[0]['address'])
            if f'::{ACCOUNT}:' in arn:
                found=[x for x in plan['resource_changes'] if x.get('type')=='aws_iam_policy' and (x['change'].get('before') or {}).get('arn')==arn]
                need(len(found)==1,'installed_managed_binding');c=found[0]['change']
                need(c['actions']==['no-op'] and equivalent(policy_from(c,'before'),observed) and equivalent(policy_from(c,'after'),observed),'installed_managed_change')
            planned_sources[arn]=observed
        suffix='period_work_export[0]' if kind=='export' else f'period_work["{kind}"]'
        new=resource(plan,'aws_iam_policy.'+suffix);change=new['change'];need(new['type']=='aws_iam_policy' and change['actions']==['create'] and change['before'] is None,'new_policy_action')
        expected_name='trustcheckradar-dev-'+('' if kind in API_KINDS else 'campaign-')+('account-export' if kind=='export' else kind.replace('_','-'))+'-period-work'
        need(change['after']['name']==expected_name and change['after'].get('path','/')=='/'
             and change['after'].get('arn') in (None,f'arn:aws:iam::{ACCOUNT}:policy/{expected_name}'),'new_policy_name')
        policy=policy_from(change,'after');size=validate_new(policy,kind,transient)
        attachment=resource(plan,'aws_iam_role_policy_attachment.'+suffix);c=attachment['change'];covered.add(attachment['address'])
        need(attachment['type']=='aws_iam_role_policy_attachment' and c['actions']==['create'] and c['before'] is None and c['after']['role']==name,'new_attachment_role')
        expected_arn=f'arn:aws:iam::{ACCOUNT}:policy/{expected_name}'
        need(c['after'].get('policy_arn') in (None,expected_arn),'new_attachment_arn')
        if c['after'].get('policy_arn') is None:
            config_address='aws_iam_role_policy_attachment.period_work_export' if kind=='export' else 'aws_iam_role_policy_attachment.period_work'
            refs={'aws_iam_policy.period_work_export[0].arn','aws_iam_policy.period_work_export[0]','aws_iam_policy.period_work_export'} if kind=='export' else {'aws_iam_policy.period_work','each.key'}
            configs=[x for x in plan['configuration']['root_module']['resources'] if x['address']==config_address]
            need(c.get('after_unknown',{}).get('policy_arn') is True and len(configs)==1 and set(configs[0]['expressions']['policy_arn'].get('references',[]))==refs,'attachment_reference_binding')
        additions=1
        if kind=='lifecycle' and aggregate is not None:
            covered.add(aggregate['attachmentAddress']);planned_sources['new:'+aggregate['arn']]=aggregate['policy'];additions+=1
        for x in plan['resource_changes']:
            c=x['change'];before=c.get('before') or {};after=c.get('after') or {}
            if x['type'] in ('aws_iam_role_policy','aws_iam_role_policy_attachment') and (before.get('role')==name or after.get('role')==name):need(x['address'] in covered,'untracked_role_policy_change')
            if x['type']=='aws_iam_role' and (before.get('name')==name or after.get('name')==name):
                need(c['actions']==['no-op'] and after.get('permissions_boundary') in (None,'') and json.loads(after['assume_role_policy'])==r['trustPolicy'],'role_trust_or_boundary_change')
        need(len(r['managed'])+additions<=20,'attachment_headroom')
        planned_sources['new:'+expected_arn]=policy;sources[kind]=planned_sources
        out=[];omissions[kind]=[]
        for source,doc in planned_sources.items():
            statements,excluded=project(doc,source);out.extend(statements);omissions[kind]+=excluded
        if kind=='export':need(all(set(seq(st['Action']))<={'dynamodb:GetItem','dynamodb:Query','dynamodb:DescribeTable'} for st in out),'export_write_overlap')
        union={'Version':'2012-10-17','Statement':out};unions[kind]=synthetic(union,run_id)
        evidence[kind]={'role':name,'newManagedPolicyCharacters':size,'attachmentCountAfter':len(r['managed'])+additions,
            'aggregatePolicySha256':policy_hash(aggregate['policy']) if kind=='lifecycle' and aggregate else None,
            'aggregatePolicyCharacters':len(canonical(aggregate['policy'])) if kind=='lifecycle' and aggregate else None,
            'newManagedPolicySha256':policy_hash(policy),'plannedSourceHashes':{src:policy_hash(d) for src,d in planned_sources.items()},
            'projectedUnionSha256':policy_hash(union),'syntheticUnionSha256':policy_hash(unions[kind]),
            'writerStatus':'RETIRED_DISABLED' if kind=='analysis' else 'READ_ONLY_READER' if kind=='export' else 'PREPARATION_ONLY'}
    return {'validationPassed':True,'cloudExecuted':False,'roleAuditObservedAtUtc':audit['observedAtUtc'],
        'roles':evidence,'syntheticUnions':unions,'omittedStatements':omissions,'fixtureRunId':run_id,
        'limitations':['Offline validation only; no AWS authorization or runtime behavior claim.',
            'This is not a deployment/activation validator: runtime gates, artifact contents, schedules and approval inventories require separate review.',
            'Only DynamoDB two base-table intersections retained. Other tables/indexes/streams/services, SCPs and resource policies are excluded.',
            'Optional aggregate policy is bound completely; only its pipeline cursor enters this fixture. Intelligence table/ExpirationIndex authorization and runtime require separate qualification.',
            'Global analysis write Deny is preserved on both fixture tables; new Allows do not reactivate it.',
            'New managed ARN is inferred from exact name and Terraform attachment references while unknown; final applied binding still requires readback.',
            'The supplied AWS audit is a point-in-time evidence input, not a signature or protection against changes after observation.',
            'Existing broad reads/writes are retained; application control existence/retention/coverage invariants are not enforced by IAM.']}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--processing-plan',required=True);p.add_argument('--api-plan',required=True);p.add_argument('--role-audit',required=True);p.add_argument('--fixture-run-id',default='0'*32);p.add_argument('--output');a=p.parse_args()
    try:
        raw={k:Path(v).read_bytes() for k,v in {'processingPlan':a.processing_plan,'apiPlan':a.api_plan,'roleAudit':a.role_audit}.items()}
        result=validate_plans(*(json.loads(raw[k]) for k in ('processingPlan','apiPlan','roleAudit')),run_id=a.fixture_run_id)
        result['inputSha256']={k:sha(v) for k,v in raw.items()};result['harnessSha256']=sha(Path(__file__).read_bytes());result['helperSha256']=sha(_HELPER.read_bytes())
        if a.output:Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
        print(json.dumps({'validationPassed':True,'cloudExecuted':False,'roles':result['roles'],'inputSha256':result['inputSha256']},sort_keys=True));return 0
    except Exception as e:
        reason=str(e) if isinstance(e,w.QualificationError) else 'invalid_input'
        print(json.dumps({'validationPassed':False,'cloudExecuted':False,'reason':reason}));return 1
if __name__=='__main__':raise SystemExit(main())
