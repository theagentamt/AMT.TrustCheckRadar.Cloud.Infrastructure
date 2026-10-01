"""Self-contained offline negative cases; no AWS SDK or external fixture files."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

PATH=Path(__file__).resolve().parents[1]/'scripts/qualify_campaign_period_work_iam.py'
spec=importlib.util.spec_from_file_location('work_iam',PATH);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
KEY=f'arn:aws:kms:{m.REGION}:{m.ACCOUNT}:key/11111111-1111-1111-1111-111111111111'
TRUST={'Version':'2012-10-17','Statement':[{'Effect':'Allow','Principal':{'Service':'lambda.amazonaws.com'},'Action':'sts:AssumeRole'}]}


def document(*statements):return {'Version':'2012-10-17','Statement':list(statements)}
def stmt(sid,action,resource=None,**extra):return {'Sid':sid,'Effect':'Allow','Action':action,'Resource':resource or m.TABLES['pipeline'],**extra}
def resource(address,kind,before,after,actions=('no-op',)):
    return {'address':address,'type':kind,'mode':'managed','change':{'before':before,'after':after,'actions':list(actions),'after_unknown':{}}}


def fixture():
    processing={'resource_changes':[],'configuration':{'root_module':{'resources':[]}}};api=copy.deepcopy(processing)
    audit={'accountId':m.ACCOUNT,'region':m.REGION,'environment':'dev','readComplete':True,'observedAtUtc':'2026-09-27T01:00:00+00:00','roles':{}}
    for kind,name in m.ROLES.items():
        plan=api if kind in m.API_KINDS else processing
        role={'arn':f'arn:aws:iam::{m.ACCOUNT}:role/{name}','permissionsBoundary':None,'readComplete':True,'inline':{},'managed':{},'policyMetadata':{},'trustPolicy':TRUST,'trustPolicySha256':m.sha(m.canonical(TRUST).encode())}
        for source in m.INLINE[kind]:
            doc=document(stmt('Logs',['logs:PutLogEvents'],'*'))
            if source=='lifecycle-runtime':
                doc=document(stmt('ReadBase','dynamodb:GetItem'),stmt('LegacyMutable','dynamodb:PutItem',Condition={'ForAllValues:StringLike':{'dynamodb:LeadingKeys':['EVENT#*']}}),
                    stmt('CreatePeriodHmacKeys','kms:CreateKey','*'),stmt('TagNewPeriodHmacKeys','kms:TagResource',KEY),
                    stmt('ManageTaggedPeriodHmacKeys',['kms:DescribeKey','kms:DisableKey','kms:EnableKey','kms:GetKeyPolicy','kms:TagResource'],KEY))
            if source=='trustcheckradar-dev-research-migration-analysis':
                doc=document({'Sid':'DenyLegacySettlementAndWrites','Effect':'Deny','Action':sorted(m.MUTATIONS),'Resource':'*'})
            role['inline'][source]=doc;role['policyMetadata']['inline:'+source]={'sha256':m.sha(m.canonical(doc).encode()),'versionId':None}
            old={'name':source,'role':name,'policy':json.dumps(doc)};new=copy.deepcopy(old)
            if source=='lifecycle-runtime':
                narrowed=copy.deepcopy(doc);narrowed['Statement']=[s for s in narrowed['Statement'] if s['Sid'] not in {'CreatePeriodHmacKeys','TagNewPeriodHmacKeys'}]
                next(s for s in narrowed['Statement'] if s['Sid']=='ManageTaggedPeriodHmacKeys')['Action']=['kms:DescribeKey','kms:ListResourceTags','kms:DisableKey'];new['policy']=json.dumps(narrowed)
            plan['resource_changes'].append(resource('aws_iam_role_policy.'+kind+'_'+source.replace('-','_'),'aws_iam_role_policy',old,new,('update',) if source=='lifecycle-runtime' else ('no-op',)))
        if kind=='analysis':
            for index,arn in enumerate(sorted(m.ANALYSIS_MANAGED)):
                doc=document(stmt('Logs','logs:PutLogEvents','*')) if '::aws:' in arn else document(stmt('UseCampaignOutboxEncryptionThroughDynamoDB','kms:Decrypt',KEY))
                role['managed'][arn]=doc;role['policyMetadata'][arn]={'sha256':m.sha(m.canonical(doc).encode()),'versionId':'v1','defaultVersionConfirmed':True}
                attachment={'role':name,'policy_arn':arn};plan['resource_changes'].append(resource('aws_iam_role_policy_attachment.installed'+str(index),'aws_iam_role_policy_attachment',attachment,copy.deepcopy(attachment)))
                if m.ACCOUNT in arn:
                    attrs={'arn':arn,'policy':json.dumps(doc)};plan['resource_changes'].append(resource('aws_iam_policy.installed','aws_iam_policy',attrs,copy.deepcopy(attrs)))
        old={'name':name,'assume_role_policy':json.dumps(TRUST),'permissions_boundary':None};plan['resource_changes'].append(resource('aws_iam_role.'+kind,'aws_iam_role',old,copy.deepcopy(old)))
        new_name='trustcheckradar-dev-'+('' if kind in m.API_KINDS else 'campaign-')+('account-export' if kind=='export' else kind.replace('_','-'))+'-period-work'
        after={'name':new_name,'path':'/','policy':json.dumps(m.expected_new(kind,KEY))}
        suffix='period_work_export[0]' if kind=='export' else f'period_work["{kind}"]'
        plan['resource_changes'].append(resource('aws_iam_policy.'+suffix,'aws_iam_policy',None,after,('create',)))
        attachment={'role':name,'policy_arn':f'arn:aws:iam::{m.ACCOUNT}:policy/{new_name}'}
        plan['resource_changes'].append(resource('aws_iam_role_policy_attachment.'+suffix,'aws_iam_role_policy_attachment',None,attachment,('create',)))
        audit['roles'][name]=role
    return processing,api,audit


class Validation(unittest.TestCase):
    def setUp(self):self.processing,self.api,self.audit=fixture()
    def validate(self):return m.validate_plans(self.processing,self.api,self.audit)
    def reject(self):
        with self.assertRaises(m.w.QualificationError):self.validate()
    def new(self,kind='publisher'):
        p=self.api if kind in m.API_KINDS else self.processing
        return m.resource(p,'aws_iam_policy.'+('period_work_export[0]' if kind=='export' else f'period_work["{kind}"]'))['change']['after']
    def mutate_new(self,callback,kind='publisher'):
        after=self.new(kind);doc=json.loads(after['policy']);callback(doc);after['policy']=json.dumps(doc)

    def add_aggregate(self):
        name='trustcheckradar-dev-campaign-aggregate-expiry';arn=f'arn:aws:iam::{m.ACCOUNT}:policy/{name}'
        self.processing['resource_changes'] += [
          resource('aws_iam_policy.aggregate_expiry[0]','aws_iam_policy',None,{'name':name,'path':'/','policy':json.dumps(m.expected_aggregate())},('create',)),
          resource('aws_iam_role_policy_attachment.aggregate_expiry[0]','aws_iam_role_policy_attachment',None,{'role':m.ROLES['lifecycle'],'policy_arn':arn},('create',))]
    def test_aggregate_complete_contract_bound_only_cursor_projected(self):
        self.add_aggregate();result=self.validate();role=result['roles']['lifecycle']
        self.assertEqual(role['attachmentCountAfter'],2);self.assertIsNotNone(role['aggregatePolicySha256'])
        self.assertTrue(any('AGGREGATE_SWEEP#dev' in json.dumps(s) for s in result['syntheticUnions']['lifecycle']['Statement']))
        self.assertFalse(any('EXPIRY#dev#' in json.dumps(s) for s in result['syntheticUnions']['lifecycle']['Statement']))
        omitted=result['omittedStatements']['lifecycle'];self.assertTrue(any('ExpirationIndex' in json.dumps(x) for x in omitted))
    def test_aggregate_extra_shard_mutation_or_condition_is_refused(self):
        self.add_aggregate();after=m.resource(self.processing,'aws_iam_policy.aggregate_expiry[0]')['change']['after'];original=after['policy']
        for mutation in ('shard','update','check','standalone'):
            policy=json.loads(original)
            if mutation=='shard':policy['Statement'][1]['Condition']['ForAllValues:StringEquals']['dynamodb:LeadingKeys'].append('EXPIRY#dev#16')
            elif mutation=='standalone':policy['Statement'][3]['Condition'].pop('ForAnyValue:StringEquals')
            else:policy['Statement'][3]['Action'].append('dynamodb:UpdateItem' if mutation=='update' else 'dynamodb:ConditionCheckItem')
            after['policy']=json.dumps(policy)
            with self.subTest(mutation=mutation):self.reject()
    def test_aggregate_wrong_attachment_or_missing_document_refused(self):
        self.add_aggregate();attachment=m.resource(self.processing,'aws_iam_role_policy_attachment.aggregate_expiry[0]')['change']['after']
        attachment['role']=m.ROLES['export'];self.reject();attachment['role']=m.ROLES['lifecycle']
        self.processing['resource_changes']=[x for x in self.processing['resource_changes'] if x['address']!='aws_iam_policy.aggregate_expiry[0]'];self.reject()
    def test_full_binding_preserves_retired_deny_and_no_live_resources(self):
        result=self.validate();self.assertFalse(result['cloudExecuted'])
        analysis=result['syntheticUnions']['analysis']['Statement'];deny=[s for s in analysis if s['Effect']=='Deny']
        self.assertEqual(len(deny),1);self.assertEqual(set(deny[0]['Action']),m.MUTATIONS)
        for policy in result['syntheticUnions'].values():
            for st in policy['Statement']:
                self.assertTrue(all('amt-period-work-qual-' in arn for arn in st['Resource']))
                self.assertTrue(all(a.startswith('dynamodb:') for a in st['Action']))
        self.assertTrue(result['omittedStatements']['analysis'])
    def test_export_addition_is_read_only_and_inventory_scoped(self):
        result=self.validate();self.assertEqual(result['roles']['export']['writerStatus'],'READ_ONLY_READER')
        for st in result['syntheticUnions']['export']['Statement']:
            self.assertLessEqual(set(st['Action']),{'dynamodb:GetItem','dynamodb:Query','dynamodb:DescribeTable'})
    def test_export_work_read_is_rejected(self):
        self.mutate_new(lambda d:d['Statement'][1]['Condition']['ForAllValues:StringEquals']['dynamodb:LeadingKeys'].append('PERIOD_WORK#*'),kind='export');self.reject()
    def test_export_existing_overlap_cannot_be_hidden(self):
        role=self.audit['roles'][m.ROLES['export']];src='authenticated-read-only-account-export'
        doc=document(stmt('ExistingWrite','dynamodb:PutItem'))
        role['inline'][src]=doc;role['policyMetadata']['inline:'+src]['sha256']=m.sha(m.canonical(doc).encode())
        change=next(x['change'] for x in self.api['resource_changes'] if x['type']=='aws_iam_role_policy' and x['change']['after']['name']==src)
        for side in ('before','after'):change[side]['policy']=json.dumps(doc)
        self.reject()
    def test_export_new_write_is_rejected(self):
        self.mutate_new(lambda d:d['Statement'][1]['Action'].append('dynamodb:PutItem'),kind='export');self.reject()
    def test_missing_work_check_rejected(self):
        self.mutate_new(lambda d:d['Statement'].pop());self.reject()
    def test_control_put_rejected(self):
        self.mutate_new(lambda d:next(s for s in d['Statement'] if s['Sid']=='AdvanceExistingWorkControlTransactionally')['Action'].append('dynamodb:PutItem'));self.reject()
    def test_bad_transaction_operator_rejected(self):
        def edit(d):
            c=next(s for s in d['Statement'] if s['Sid']=='MutatePairedWorkRecordsTransactionally')['Condition'];c['StringEquals']=c.pop('ForAnyValue:StringEquals')
        self.mutate_new(edit);self.reject()
    def test_all_old_check_rejected(self):
        self.mutate_new(lambda d:next(s for s in d['Statement'] if s['Sid']=='CheckPeriodWorkApproval')['Condition']['StringEqualsIfExists'].update({'dynamodb:ReturnValues':'ALL_OLD'}));self.reject()
    def test_marker_write_broadening_rejected(self):
        self.mutate_new(lambda d:next(s for s in d['Statement'] if s['Sid']=='MutatePairedWorkRecordsTransactionally')['Condition']['ForAllValues:StringLike']['dynamodb:LeadingKeys'].append('INVENTORY#*'));self.reject()
    def test_describe_extra_table_rejected(self):
        self.mutate_new(lambda d:d['Statement'][0]['Resource'].append(m.ROOT+'other'));self.reject()
    def test_extra_inline_audit_source_rejected(self):
        self.audit['roles'][m.ROLES['publisher']]['inline']['surprise']=document();self.reject()
    def test_extra_managed_source_rejected(self):
        self.audit['roles'][m.ROLES['deletion']]['managed']['arn:unexpected']=document();self.reject()
    def test_existing_before_drift_rejected(self):
        r=next(x for x in self.processing['resource_changes'] if x['type']=='aws_iam_role_policy');r['change']['before']['policy']=json.dumps(document());self.reject()
    def test_existing_after_broadening_rejected(self):
        r=next(x for x in self.processing['resource_changes'] if x['type']=='aws_iam_role_policy' and x['change']['actions']==['no-op']);r['change']['after']['policy']=json.dumps(document());self.reject()
    def test_kms_reenable_not_allowed_by_narrowing(self):
        r=next(x for x in self.processing['resource_changes'] if x['type']=='aws_iam_role_policy' and x['change']['actions']==['update']);doc=json.loads(r['change']['after']['policy']);next(s for s in doc['Statement'] if s['Sid']=='ManageTaggedPeriodHmacKeys')['Action'].append('kms:EnableKey');r['change']['after']['policy']=json.dumps(doc);self.reject()
    def test_boundary_and_trust_changes_rejected(self):
        self.audit['roles'][m.ROLES['publisher']]['permissionsBoundary']={'arn':'x'};self.reject()
    def test_deleted_analysis_deny_rejected_even_with_updated_hash(self):
        r=self.audit['roles'][m.ROLES['analysis']];src='trustcheckradar-dev-research-migration-analysis';r['inline'][src]['Statement'][0]['Effect']='Allow';r['policyMetadata']['inline:'+src]['sha256']=m.sha(m.canonical(r['inline'][src]).encode());self.reject()
    def test_managed_version_hash_tampering_rejected(self):
        r=self.audit['roles'][m.ROLES['analysis']];r['policyMetadata'][next(iter(r['managed']))]['sha256']='0'*64;self.reject()
    def test_new_policy_wrong_arn_rejected(self):
        self.new()['arn']='arn:aws:iam::999999999999:policy/foreign';self.reject()
    def test_attachment_wrong_role_rejected(self):
        m.resource(self.processing,'aws_iam_role_policy_attachment.period_work["publisher"]')['change']['after']['role']=m.ROLES['lifecycle'];self.reject()
    def test_attachment_unknown_wrong_reference_rejected(self):
        c=m.resource(self.processing,'aws_iam_role_policy_attachment.period_work["publisher"]')['change'];c['after']['policy_arn']=None;c['after_unknown']={'policy_arn':True};self.reject()
    def test_extra_role_attachment_rejected(self):
        self.processing['resource_changes'].append(resource('aws_iam_role_policy_attachment.rogue','aws_iam_role_policy_attachment',None,{'role':m.ROLES['publisher'],'policy_arn':'arn:unexpected'},('create',)));self.reject()
    def test_unmanaged_bulk_attachment_rejected(self):
        self.processing['resource_changes'].append(resource('aws_iam_policy_attachment.rogue','aws_iam_policy_attachment',None,{'roles':[m.ROLES['publisher']]},('create',)));self.reject()
    def test_unknown_inline_role_fails_closed(self):
        self.processing['resource_changes'].append(resource('aws_iam_role_policy.rogue','aws_iam_role_policy',None,{'policy':json.dumps(document())},('create',)));self.reject()
    def test_missing_role_binding_rejected(self):
        self.processing['resource_changes']=[x for x in self.processing['resource_changes'] if x['address']!='aws_iam_role.publisher'];self.reject()
    def test_existing_broad_allow_is_not_silently_narrowed(self):
        result=self.validate();stmts=result['syntheticUnions']['lifecycle']['Statement']
        matching=[s for s in stmts if s['Action']==['dynamodb:PutItem'] and s.get('Condition')=={'ForAllValues:StringLike':{'dynamodb:LeadingKeys':['EVENT#*']}}]
        self.assertEqual(len(matching),1)
    def test_projection_foreign_exact_and_index_exclusion_recorded(self):
        p=document(stmt('Read','dynamodb:GetItem',[m.TABLES['pipeline'],m.TABLES['pipeline']+'/index/ExpirationIndex',m.ROOT+'other']))
        kept,omitted=m.project(p,'test');self.assertEqual(kept[0]['Resource'],[m.TABLES['pipeline']]);self.assertTrue(any(len(x.get('resources',[]))==2 for x in omitted))
    def test_projection_wildcard_allow_and_unprovable_resource_rejected(self):
        for arn in ('*',m.ROOT+'trustcheckradar-dev-campaign-*'):
            with self.subTest(arn=arn),self.assertRaises(m.w.QualificationError):m.project(document(stmt('Bad','dynamodb:GetItem',arn)),'test')
    def test_projection_unsupported_context_rejected(self):
        p=document(stmt('Bad','dynamodb:GetItem',Condition={'Bool':{'custom:key':'true'}}))
        with self.assertRaises(m.w.QualificationError):m.project(p,'test')
    def test_remap_refuses_live_resource_escape_and_invalid_run(self):
        for p,run in [(document(stmt('Bad','dynamodb:GetItem',m.ROOT+'users')),'a'*32),(document(stmt('Read','dynamodb:GetItem')),'../escape')]:
            with self.assertRaises(m.w.QualificationError):m.synthetic(p,run)

if __name__=='__main__':unittest.main()
