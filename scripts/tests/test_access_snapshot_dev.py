import base64
import copy
import hashlib
import io
import tempfile
from contextlib import redirect_stdout
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import prepare_access_snapshot_dev as prepare
import verify_access_snapshot_dev_plan as gate
import verify_access_snapshot_dev_readback as readback
from verify_billing_dev_readback import snapshot
from test_governed_trial_plan import fixture as governed_fixture, SUBJECT, REVISION
import verify_governed_trial_plan as previous_gate

EXTRA='00000000-0000-4000-8000-000000000002'
SOURCE='c'*40
CONTENTS=b'synthetic-reviewed-snapshot-zip'


def fixture():
    plan=governed_fixture()
    baseline=plan['variables']['deployment']['value']['artifacts']['entitlements']
    provenance={'source_sha':SOURCE,'v1_entitlements':hashlib.sha256(CONTENTS).hexdigest(),'object_version':'immutable-snapshot-version',
        'terraform_baseline':{'source_sha':'a'*40,'source_hash':baseline['source_hash'],'object_version':baseline['object_version']}}
    new=prepare.provenance_artifact(provenance)
    plan['variables']['dev_access_snapshot_extra_subjects']={'value':[EXTRA]}
    plan['variables']['entitlements_artifact_override']={'value':{
        'source_sha':SOURCE,'baseline_source_sha':'a'*40,'baseline_source_hash':baseline['source_hash'],
        'baseline_object_version':baseline['object_version'],'provenance_reference':prepare.PROVENANCE_REFERENCE,'artifact':new}}
    old=prepare.previous_artifact()
    for row in plan['resource_changes']:
        if row['address']==gate.FUNCTION:
            value=row['change']['after']
            for field,key in gate.PACKAGE_FIELDS.items():value[field]=old[key]
            value['version']='14'
            row['change']['before']=copy.deepcopy(value)
            for field,key in gate.PACKAGE_FIELDS.items():value[field]=new[key]
            value['version']=None
            value['environment'][0]['variables'][prepare.EXTRA_GATE]=json.dumps([EXTRA],separators=(',',':'))
            row['change']['actions']=['update'];row['change']['after_unknown']={'version':True}
        elif row['address']==gate.ALIAS:
            row['change']['before']['function_version']='14'
    plan['output_changes']['candidate_contract']['before']=copy.deepcopy(plan['output_changes']['candidate_contract']['after'])
    return plan,provenance


def read_fixture(provenance):
    plan,_=fixture()
    old=next(r for r in plan['resource_changes'] if r['address']==gate.FUNCTION)['change']['before']
    def read(service,operation,*args):
        if service=='sts':return {'Account':prepare.ACCOUNT}
        if service=='s3api':
            Path(args[-1]).write_bytes(CONTENTS)
            return {'VersionId':provenance['object_version']}
        if operation=='get-alias':return {'FunctionVersion':'14'}
        if '--function-name' in args and args[args.index('--function-name')+1]=='trustcheckradar-dev-governed-history':
            return {'Environment':{'Variables':{'DEV_SUBJECT_ALLOWLIST_JSON':json.dumps([SUBJECT],separators=(',',':'))}}}
        return {'FunctionName':prepare.FUNCTION_NAME,'State':'Active','LastUpdateStatus':'Successful','Version':'14',
            'Environment':{'Variables':old['environment'][0]['variables']},'CodeSha256':old['source_code_hash']}
    return read


class SnapshotOnlyTests(unittest.TestCase):
    def test_cli_rejection_emits_only_minimized_inventory(self):
        plan, provenance = fixture()
        plan['resource_changes'][0]['change']['actions'] = ['update']
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'private-plan.json'
            path.write_text(json.dumps(plan))
            output = io.StringIO()
            with patch.object(sys, 'argv', ['guard', str(path), '--revision', REVISION]), patch.object(gate, 'load_provenance', return_value=provenance), redirect_stdout(output):
                with self.assertRaisesRegex(SystemExit, r'Snapshot plan rejected \(review-line-[0-9]+\)'):
                    gate.main()
            result = json.loads(output.getvalue())
            self.assertEqual(result, gate.minimized_changes(plan))
            self.assertNotIn(SUBJECT, output.getvalue())
            self.assertNotIn(EXTRA, output.getvalue())

    def test_change_inventory_omits_private_values_addresses_and_fields(self):
        private = 'private-subject-and-token-must-not-be-emitted'
        plan, _ = fixture()
        row = copy.deepcopy(plan['resource_changes'][0])
        row['address'] = private
        row['change'] = {'actions': ['update'], 'before': {private: 'old'}, 'after': {private: private}}
        plan['resource_changes'].append(row)
        result = gate.minimized_changes(plan)
        self.assertNotIn(private, json.dumps(result))
        self.assertEqual(result['managedChanges'][-1], {'resource': 'other-managed-resource',
            'actions': ['update'], 'changedFields': [], 'otherFieldCount': 1})

    def test_change_inventory_names_only_expected_runtime_and_schema_fields(self):
        plan, _ = fixture()
        result = gate.minimized_changes(plan)['managedChanges']
        self.assertEqual({r['resource'] for r in result}, {gate.FUNCTION, gate.ALIAS})
        self.assertIn('environment', next(r for r in result if r['resource'] == gate.FUNCTION)['changedFields'])

    def test_rejection_diagnostic_never_contains_exception_values(self):
        private = 'private-subject-and-token-must-not-be-emitted'
        try:
            raise ValueError(private)
        except ValueError as error:
            self.assertEqual(gate.rejection_location(error), 'external-validation')
        plan, provenance = fixture()
        plan['complete'] = False
        try:
            gate.review(plan, REVISION, provenance)
        except ValueError as error:
            diagnostic = gate.rejection_location(error)
            self.assertRegex(diagnostic, r'^review-line-[0-9]+$')
            self.assertNotIn(private, diagnostic)
        else:
            self.fail('Incomplete plan was accepted')

    def test_exact_two_resource_transition(self):
        plan,provenance=fixture()
        artifacts,digest=gate.review(plan,REVISION,provenance)
        self.assertEqual(artifacts['entitlements'],prepare.provenance_artifact(provenance))
        self.assertEqual(len(digest),64)

    def test_distinct_private_selection_and_package_are_prepared(self):
        _,p=fixture()
        result=prepare.build(SOURCE,[SUBJECT],[EXTRA],p,read_fixture(p))
        self.assertEqual(result['governed_trial_subjects'],[SUBJECT])
        self.assertEqual(result['dev_access_snapshot_extra_subjects'],[EXTRA])
        self.assertEqual(set(result),{'governed_trial_subjects','dev_access_snapshot_extra_subjects','entitlements_artifact_override'})

    def test_bad_selection_fails_before_aws(self):
        _,p=fixture()
        for old,new in [([], [EXTRA]),([SUBJECT],[]),([SUBJECT],[SUBJECT]),([SUBJECT],[EXTRA,EXTRA]),([SUBJECT],['*']),([SUBJECT],[EXTRA.upper()]),([SUBJECT],[123])]:
            # Numeric-only UUID does not exercise uppercase rejection; add letters below.
            if new==[EXTRA.upper()]:continue
            with self.subTest(old=old,new=new),self.assertRaises(ValueError):
                prepare.build(SOURCE,old,new,p,lambda *args:self.fail('AWS called for invalid selection'))
        with self.assertRaises(ValueError):prepare.selection(['AAAAAAAA-0000-4000-8000-000000000002'])

    def test_preparation_rejects_changed_history_or_original_trial(self):
        _,p=fixture()
        original=read_fixture(p)
        for target in ('history','trial','code','extra','account','alias'):
            def read(service,operation,*args):
                value=copy.deepcopy(original(service,operation,*args))
                if target=='account' and service=='sts':value['Account']='999999999999'
                elif target=='alias' and operation=='get-alias':value['RoutingConfig']={'AdditionalVersionWeights':{'1':0.1}}
                elif operation=='get-function-configuration':
                    env=value.get('Environment',{}).get('Variables',{})
                    name=args[args.index('--function-name')+1]
                    if target=='history' and name.endswith('governed-history'):env['DEV_SUBJECT_ALLOWLIST_JSON']='[]'
                    if name==prepare.FUNCTION_NAME:
                        if target=='trial':env['TRIAL_AUTHORITY_RETENTION_APPROVED']='false'
                        if target=='code':value['CodeSha256']='unreviewed'
                        if target=='extra':env[prepare.EXTRA_GATE]=json.dumps([EXTRA])
                return value
            with self.subTest(target=target),self.assertRaises(ValueError):prepare.build(SOURCE,[SUBJECT],[EXTRA],p,read)

    def test_plan_rejects_trial_allowlist_policy_and_hidden_config_changes(self):
        for key,value in [('DEV_SUBJECT_ALLOWLIST_JSON',json.dumps([SUBJECT,EXTRA])),('TRIAL_AUTHORITY_RETENTION_APPROVED','false'),('CONSUMER_ENABLED','true'),('AUTHORITY_ENABLED','false'),('COGNITO_REQUIRED_SCOPE','changed'),(prepare.EXTRA_GATE,json.dumps([SUBJECT]))]:
            plan,p=fixture()
            row=next(r for r in plan['resource_changes'] if r['address']==gate.FUNCTION)
            row['change']['after']['environment'][0]['variables'][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):gate.review(plan,REVISION,p)

    def test_plan_rejects_unrelated_changes_even_disguised_as_noop(self):
        for kind in ('consumer','recovery','deletion'):
            for action in ('no-op','update','delete'):
                plan,p=fixture()
                row=next(r for r in plan['resource_changes'] if r['address']==f'aws_lambda_function.runtime["{kind}"]')
                row['change']['after']['timeout']+=1;row['change']['actions']=[action]
                with self.subTest(kind=kind,action=action),self.assertRaises(ValueError):gate.review(plan,REVISION,p)
        for address in ('aws_iam_role_policy.new','aws_apigatewayv2_route.new','aws_scheduler_schedule.new'):
            plan,p=fixture();plan['resource_changes'].append({'mode':'managed','provider_name':'registry.terraform.io/hashicorp/aws','address':address,'change':{'actions':['create'],'before':None,'after':{}}})
            with self.subTest(address=address),self.assertRaises(ValueError):gate.review(plan,REVISION,p)

    def test_plan_rejects_wrong_packages_limits_and_alias(self):
        for field,value in [('source_code_hash',base64.b64encode(bytes(32)).decode()),('s3_object_version','other'),('timeout',11),('reserved_concurrent_executions',3),('handler','other.handler'),('function_name','trustcheckradar-prod-v1-entitlements')]:
            plan,p=fixture();row=next(r for r in plan['resource_changes'] if r['address']==gate.FUNCTION);row['change']['after'][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):gate.review(plan,REVISION,p)
        for replacement in ('other','14'):
            plan,p=fixture();next(r for r in plan['resource_changes'] if r['address']==gate.ALIAS)['change']['after']['function_version']=replacement
            with self.subTest(replacement=replacement),self.assertRaises(ValueError):gate.review(plan,REVISION,p)
        plan,p=fixture();plan['configuration']['root_module']['resources'][0]['expressions']['function_version']['references']=['var.unreviewed_version']
        with self.assertRaises(ValueError):gate.review(plan,REVISION,p)

    def test_plan_rejects_incomplete_drift_output_or_scope(self):
        for kind in ('drift','duplicate','missing','outputs','prod','broad','checks'):
            plan,p=fixture()
            if kind=='drift':plan['resource_drift']=[{'mode':'managed'}]
            elif kind=='duplicate':plan['resource_changes'].append(copy.deepcopy(plan['resource_changes'][0]))
            elif kind=='missing':plan['resource_changes']=[r for r in plan['resource_changes'] if r['address']!='aws_lambda_function.runtime["deletion"]']
            elif kind=='outputs':plan['output_changes']['candidate_contract']['after']['recovery_enabled']=True
            elif kind=='prod':plan['variables']['environment']['value']='prod'
            elif kind=='broad':plan['variables']['activate_access_engineering']['value']=True
            elif kind=='checks':plan['checks']=[{'status':'unknown'}]
            with self.subTest(kind=kind),self.assertRaises(ValueError):gate.review(plan,REVISION,p)

    def test_digest_binds_revision_selection_package_and_config(self):
        plan,p=fixture();original=gate.review(plan,REVISION,p)[1]
        self.assertNotEqual(original,gate.review(plan,'d'*40,p)[1])
        plan2=copy.deepcopy(plan);new='00000000-0000-4000-8000-000000000003'
        plan2['variables']['dev_access_snapshot_extra_subjects']['value']=[new]
        next(r for r in plan2['resource_changes'] if r['address']==gate.FUNCTION)['change']['after']['environment'][0]['variables'][prepare.EXTRA_GATE]=json.dumps([new],separators=(',',':'))
        self.assertNotEqual(original,gate.review(plan2,REVISION,p)[1])

    def test_runtime_inventory_excludes_only_entitlements(self):
        names=[prepare.FUNCTION_NAME,'trustcheckradar-dev-governed-history','trustcheckradar-dev-v1-play-handoff']
        seen=[]
        def read(service,operation,*args):
            if service=='sts':return {'Account':prepare.ACCOUNT}
            if operation=='list-functions':return {'Functions':[{'FunctionName':n} for n in names]}
            name=args[args.index('--function-name')+1];seen.append(name)
            if operation=='list-aliases':return {'Aliases':[{'Name':'live'}]}
            if operation=='get-function-concurrency':return {'ReservedConcurrentExecutions':2}
            return {'Version':'1','CodeSha256':'synthetic','Environment':{'Variables':{'gate':'false'}}}
        result=snapshot('access-snapshot',read)
        self.assertEqual(set(result),set(names)-{prepare.FUNCTION_NAME})
        self.assertNotIn(prepare.FUNCTION_NAME,seen)

    def test_readback_checks_selected_alias_and_original_gates(self):
        plan,p=fixture();row=next(r for r in plan['resource_changes'] if r['address']==gate.FUNCTION)
        def read(service,operation,*args):
            if service=='sts':return {'Account':prepare.ACCOUNT}
            if operation=='get-function-concurrency':return {'ReservedConcurrentExecutions':2}
            if operation=='get-alias':return {'FunctionVersion':'15'}
            v=row['change']['after'];fields={'FunctionName':'function_name','CodeSha256':'source_code_hash','Role':'role','Handler':'handler','Runtime':'runtime','Architectures':'architectures','Timeout':'timeout','MemorySize':'memory_size'}
            return {**{k:v[f] for k,f in fields.items()},'Environment':{'Variables':v['environment'][0]['variables']},'State':'Active','LastUpdateStatus':'Successful','Version':'15'}
        self.assertTrue(readback.verify_selected(plan,read=read)['snapshotConfigurationVerified'])
        def wrong(*args):
            value=copy.deepcopy(read(*args))
            if 'Environment' in value:value['Environment']['Variables']['TRIAL_AUTHORITY_RETENTION_APPROVED']='false'
            return value
        with self.assertRaises(ValueError):readback.verify_selected(plan,read=wrong)

    def test_previous_access_transition_rejects_removing_snapshot_selection(self):
        plan=governed_fixture()
        row=next(r for r in plan['resource_changes'] if r['address']==gate.FUNCTION)
        row['change']['before']['environment'][0]['variables'][prepare.EXTRA_GATE]=json.dumps([EXTRA])
        with self.assertRaises(ValueError):previous_gate.review(plan,REVISION,'trial')
