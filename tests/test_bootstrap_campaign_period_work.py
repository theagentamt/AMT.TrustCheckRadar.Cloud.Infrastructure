"""Offline bootstrap containment; actual source planner + SDK transactions only."""
import base64
from copy import deepcopy
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

PATH=Path(__file__).resolve().parents[1]/'scripts/bootstrap_campaign_period_work.py'
spec=importlib.util.spec_from_file_location('bootstrap_operator',PATH);q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
SOURCE=Path(os.environ.get('AMT_LAMBDA_SOURCE','/tmp/amt-campaign-metadata-repair'))
HAS_SOURCE=False
try:
    import boto3
    from moto import mock_aws
    sys.path.insert(0,str(SOURCE/'src'))
    from shared_campaign_work import bootstrap as B,configuration as C
    from shared_campaign_locators import period as P,core as L
    HAS_SOURCE=True
except ImportError:pass
PERIOD=1480;NOW=PERIOD*1209600+1000
GEN='11111111-1111-4111-8111-111111111111'


def manifest():
    return {'schemaVersion':1,'accountId':q.ACCOUNT,'region':q.REGION,'environment':'dev','sourceCommit':'a'*40,'sourceTreeSha256':'a'*64,
      'resources':{k:{'tableName':v,'tableId':str(__import__('uuid').UUID(int=n+1))} for n,(k,v) in enumerate(q.TABLES.items())},
      'functions':{k:{'codeSha256':'a'*64,'roleArn':f'arn:aws:iam::{q.ACCOUNT}:role/trustcheckradar-dev-fixture-role','configurationSha256':'b'*64} for k in q.FUNCTIONS},
      'marker':{},'locatorSha256':'c'*64,'retiredRegistrySha256':'d'*64,'retiredExclusionReference':'review-existing-retired-metadata-only','expectedCounts':q.COUNTS.copy()}


def fixture():
    m=manifest();resources={k:m['resources'][k] for k in ('pipeline','outbox')}
    marker={'PK':'INVENTORY#dev','SK':'CAMPAIGN_PERIOD_WORK','recordType':'CAMPAIGN_PERIOD_WORK_INVENTORY','schemaVersion':1,
      'environment':'dev','coverage':'VERIFIED_COMPLETE','revision':1,'manifestSha256':'e'*64,'approvedAtEpoch':NOW-10,
      'admissionGeneration':GEN,'locatorManifestSha256':'f'*64,'locatorInventoryRevision':1,'minimumPeriodId':PERIOD-1,
      'resources':resources,'writers':C.WRITERS,'baseline':'EXACT_ALL_TARGETS_INDEXED','restoreInvalidation':'REQUIRES_NEW_GENERATION'}
    m['marker']=marker
    def registry(n):return {'PK':f'PERIOD#{n}','SK':'HMAC_KEY','periodId':n,'keyArn':f'arn:aws:kms:{q.REGION}:{q.ACCOUNT}:key/11111111-1111-4111-8111-111111111111','status':'ENABLED','retireAfterEpoch':(n+1)*P.PERIOD_SECONDS+P.RECOVERY_SECONDS}
    retired=registry(PERIOD-2)|{'status':'RETIRED','retiredAtEpoch':NOW-2000};rows=[retired]
    for n in (PERIOD-1,PERIOD):rows.append(registry(n)|{'admissionSchemaVersion':1,'admissionGeneration':GEN,'admissionState':'CLOSING',
      'admissionRevision':2,'admissionManifestSha256':'f'*64,'admissionInventoryRevision':1,'admissionChangedAtEpoch':NOW-100})
    for i in range(3):
        n=PERIOD-1+i%2;token=base64.urlsafe_b64encode(bytes([i])*32).decode().rstrip('=')
        rows.append({'PK':f'CONTRIB#{n}#{token}','SK':'TOMBSTONE','recordType':'CAMPAIGN_DELETION_TOMBSTONE','schemaVersion':2,'environment':'dev','periodId':n,
          'createdAtEpoch':NOW-1000,'deletionDeadlineEpoch':NOW+100,'GSI3PK':'EXPIRY#dev','GSI3SK':NOW+100,'locatorCleanupRevision':1,
          'locatorCleanupState':{'operationId':GEN,'phase':'SEEK','cursor':None},'retainedPeriodSweepRevision':1,
          'retainedPeriodSweep':{'schemaVersion':1,'operationId':GEN,'inventoryRevision':1,'minimumPeriodId':n,'maximumPeriodId':n,'nextPeriodId':n}})
    locator={'PK':'INVENTORY#dev','SK':'CAMPAIGN_LOCATORS','recordType':'CAMPAIGN_LOCATOR_INVENTORY','schemaVersion':1,'revision':1,'environment':'dev',
      'coverage':'VERIFIED_COMPLETE','manifestSha256':'f'*64,'approvedAtEpoch':NOW-100,'locatorSchemaVersion':1,'minimumPeriodId':PERIOD-1,'priorPeriodsErased':True,'writers':L.WRITERS}
    rows.append(locator);m['locatorSha256']=q.digest(C.wire(locator));m['retiredRegistrySha256']=q.digest(C.wire(retired))
    return m,{'pipeline':sorted([json.loads(q.canonical(C.wire(r))) for r in rows],key=q.canonical),'outbox':[],'intelligence':[]}


class Containment(unittest.TestCase):
    def test_exact_dev_manifest_scope_and_inventory(self):
        q.validate_manifest(manifest())
        for field,value in [('accountId','000000000000'),('region','us-west-2'),('environment','prod'),('expectedCounts',{})]:
            m=manifest();m[field]=value
            with self.subTest(field=field),self.assertRaises(q.Refusal):q.validate_manifest(m)
        m=manifest();m['resources']['pipeline']['tableName']='foreign'
        with self.assertRaises(q.Refusal):q.validate_manifest(m)
    def test_strong_scan_complete_and_stable_field_order(self):
        class DDB:
            def scan(self,**kw):
                self_outer.assertTrue(kw['ConsistentRead']);self_outer.assertNotIn('ProjectionExpression',kw)
                return {'Items':[{'SK':{'S':'s'},'PK':{'S':'p'}}]}
        self_outer=self;result=q.scan(DDB(),'table');self.assertEqual(list(result[0]),['PK','SK'])
    def test_scan_truncation_cursor_repeat_and_unknown_shape_refuse(self):
        class DDB:
            def __init__(self,kind):self.kind=kind;self.n=0
            def scan(self,**kw):
                self.n+=1
                if self.kind=='shape':return {'Items':None}
                return {'Items':[],'LastEvaluatedKey':{'PK':{'S':str(self.n if self.kind=='truncated' else 0)}}}
        for kind in ('shape','repeat','truncated'):
            with self.subTest(kind=kind),self.assertRaises(q.Refusal):q.scan(DDB(kind),'table')
    def test_duplicate_scan_records_refuse(self):
        class DDB:
            def scan(self,**kw):return {'Items':[{'PK':{'S':'p'},'SK':{'S':'s'}}]*2}
        with self.assertRaises(q.Refusal):q.scan(DDB(),'table')
    def test_source_hash_or_unfrozen_source_refuses_before_import(self):
        m=manifest()
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder)/'src').mkdir();(Path(folder)/'src/x.py').write_text('value=1\n')
            with patch.object(q.subprocess,'check_output',side_effect=['a'*40,' M src/x.py']),self.assertRaises(q.Refusal):q.load_source(folder,m)
            with patch.object(q.subprocess,'check_output',side_effect=['a'*40,'']),self.assertRaises(q.Refusal):q.load_source(folder,m)
    def test_read_budget_stops_before_sdk_call(self):
        from unittest.mock import Mock
        client=Mock()
        with patch.object(q.time,'monotonic',return_value=5),self.assertRaises(q.Refusal):q.ReadBudget(client,4).scan(TableName='synthetic')
        client.scan.assert_not_called()
    def test_review_writer_has_no_invented_work_gate(self):
        self.assertEqual(q.FUNCTIONS['campaign_review'],'trustcheckradar-dev-campaign-review')
        self.assertEqual(q.GATES['campaign_review'],[]);self.assertEqual(len(q.FUNCTIONS),8)
    def test_output_new_nofollow_and_real_symlink_parent(self):
        with tempfile.TemporaryDirectory() as folder:
            actual=Path(folder)/'real';actual.mkdir();link=Path(folder)/'link';link.symlink_to(actual,target_is_directory=True)
            q.write_new(link/'plan',{'only':'metadata'})
            with self.assertRaises(FileExistsError):q.write_new(link/'plan',{})
            (actual/'leaf').symlink_to(actual/'plan')
            with self.assertRaises(FileExistsError):q.write_new(link/'leaf',{})
            self.assertEqual(json.loads((actual/'plan').read_text()),{'only':'metadata'})
    def test_closed_writer_reserved_concurrency_required(self):
        class Lambda:
            def get_function_configuration(self,FunctionName):return {'FunctionArn':f'arn:aws:lambda:{q.REGION}:{q.ACCOUNT}:function:{FunctionName}','State':'Active','LastUpdateStatus':'Successful'}
            def get_function_concurrency(self,**kw):return {'ReservedConcurrentExecutions':1}
        with self.assertRaises(q.Refusal):q.closed_writers(Lambda(),None,manifest())
    def test_complete_writer_closure_and_mapping_schedule_config_refusals(self):
        m=manifest();configs={}
        for kind,name in q.FUNCTIONS.items():
            cfg={'FunctionArn':f'arn:aws:lambda:{q.REGION}:{q.ACCOUNT}:function:{name}','State':'Active','LastUpdateStatus':'Successful',
              'Environment':{'Variables':{k:'false' for k in q.GATES[kind]}|{'PRIVATE_VALUE':'must-not-appear'}},
              'Runtime':'python3.14','Handler':'app.lambda_handler','Architectures':['arm64'],'Timeout':30,'MemorySize':128,
              'RevisionId':'revision','Role':m['functions'][kind]['roleArn'],'CodeSha256':base64.b64encode(bytes.fromhex('a'*64)).decode()}
            configs[name]=cfg
            summary={k:cfg.get(k) for k in ('Runtime','Handler','Architectures','Timeout','MemorySize','RevisionId','Role','CodeSha256')}
            summary['closedGates']={k:'false' for k in q.GATES[kind]};m['functions'][kind]['configurationSha256']=q.digest(summary)
        class Lambda:
            mapping='Disabled'
            def get_function_configuration(self,FunctionName):return configs[FunctionName]
            def get_function_concurrency(self,**kw):return {'ReservedConcurrentExecutions':0}
            def list_aliases(self,**kw):return {'Aliases':[]}
            def list_versions_by_function(self,**kw):return {'Versions':[]}
            def list_event_source_mappings(self,**kw):return {'EventSourceMappings':[{'UUID':'known','State':self.mapping}]}
        class Scheduler:
            state='DISABLED'
            def list_schedule_groups(self):return {'ScheduleGroups':[{'Name':'group'}]}
            def list_schedules(self,**kw):return {'Schedules':[{'Name':'tick','Target':{'Arn':configs[q.FUNCTIONS['campaign_lifecycle']]['FunctionArn']}}]}
            def get_schedule(self,**kw):return {'Name':'tick','GroupName':'group','State':self.state,'CreationDate':object()}
        lam=Lambda();scheduler=Scheduler();report=q.closed_writers(lam,scheduler,m)
        self.assertEqual(len(report['functions']),8);self.assertNotIn('must-not-appear',json.dumps(report))
        scheduler.state='ENABLED'
        with self.assertRaises(q.Refusal):q.closed_writers(lam,scheduler,m)
        scheduler.state='DISABLED';lam.mapping='Enabling'
        with self.assertRaises(q.Refusal):q.closed_writers(lam,scheduler,m)
        lam.mapping='Disabled';configs[next(iter(configs))]['RevisionId']='changed'
        with self.assertRaises(q.Refusal):q.closed_writers(lam,scheduler,m)
    def test_apply_approval_and_fresh_snapshot_fail_before_transaction(self):
        m=manifest();observation={'writers':{'maximumTimeoutSeconds':1},'resources':{},'counts':{}}
        plan={'observedAtEpoch':NOW,'manifestSha256':q.digest(m),'helperSha256':q.digest(PATH.read_bytes()),'observation':observation}
        approval={'schemaVersion':1,'planSha256':q.digest(plan),'manifestSha256':q.digest(m),'reviewReference':'review1','serializedWriterBoundary':True,'approvalExpiresAtEpoch':NOW+500}
        from unittest.mock import Mock
        ddb=Mock()
        for change in ({'planSha256':'0'*64},{'serializedWriterBoundary':False},{'approvalExpiresAtEpoch':NOW-1}):
            with self.subTest(change=change),self.assertRaises(q.Refusal):q.reviewed_apply(ddb,None,None,m,None,plan,approval|change,'unused',now=lambda:NOW+100)
        with patch.object(q,'capture',return_value=({'different':True},[])),self.assertRaises(q.Refusal):q.reviewed_apply(ddb,None,None,m,None,plan,approval,'unused',now=lambda:NOW+100)
        ddb.transact_write_items.assert_not_called()
    def test_apply_drain_and_lost_ack_preserves_intent(self):
        m=manifest();observation={'writers':{'maximumTimeoutSeconds':1},'resources':{}}
        plan={'observedAtEpoch':NOW,'manifestSha256':q.digest(m),'helperSha256':q.digest(PATH.read_bytes()),'observation':observation}
        approval={'schemaVersion':1,'planSha256':q.digest(plan),'manifestSha256':q.digest(m),'reviewReference':'review1','serializedWriterBoundary':True,'approvalExpiresAtEpoch':NOW+500}
        from unittest.mock import Mock
        ddb=Mock();ddb.transact_write_items.side_effect=TimeoutError('do-not-print')
        with self.assertRaises(q.Refusal):q.reviewed_apply(ddb,None,None,m,None,plan,approval,'unused',now=lambda:NOW+10)
        with tempfile.TemporaryDirectory() as folder:
            journal=str(Path(folder)/'intent.json')
            with patch.object(q,'recheck_source'),patch.object(q,'capture',return_value=(observation,[{'synthetic':'action'}])),patch.object(q,'resources',return_value={}),patch.object(q,'closed_writers',return_value=observation['writers']),self.assertRaisesRegex(q.Refusal,'apply_unconfirmed'):
                q.reviewed_apply(ddb,None,None,m,None,plan,approval,journal,now=lambda:NOW+100)
            intent=json.loads(Path(journal).read_text());self.assertEqual(intent['state'],'APPLY_INTENT_ONLY');self.assertNotIn('synthetic',Path(journal).read_text())
        self.assertEqual(ddb.transact_write_items.call_count,1)


@unittest.skipUnless(HAS_SOURCE,'SDK and reviewed Lambda source needed')
class PlannerIntegration(unittest.TestCase):
    def test_real_planner_exact_baseline_preserves_terminal_tombstones(self):
        m,snapshot=fixture()
        with q.planner_environment(m):actions,counts=q.classify(snapshot,m,(B,C,P,L),NOW)
        self.assertEqual(counts,q.COUNTS);self.assertLessEqual(len(actions),100)
        puts=[C.plain(a['Put']['Item']) for a in actions if 'Put' in a]
        self.assertEqual(sum(r.get('pendingCount',0) for r in puts),3)
        self.assertEqual(len([r for r in puts if r['PK'].startswith('WORK_LOOKUP#')]),3)
        self.assertFalse(any(r['PK'].startswith('CONTRIB#') for r in puts))
        self.assertEqual(puts[-1],m['marker'])
    def test_independent_minima_require_every_global_to_current_registry(self):
        m,snapshot=fixture();locator=next(r for r in snapshot['pipeline'] if r['SK']['S']=='CAMPAIGN_LOCATORS')
        locator['minimumPeriodId']={'N':str(PERIOD)};m['locatorSha256']=q.digest(locator)
        with q.planner_environment(m):actions,_=q.classify(snapshot,m,(B,C,P,L),NOW)
        self.assertTrue(actions)
        for minimum in (PERIOD-2,PERIOD+1):
            changed=deepcopy(snapshot);row=next(r for r in changed['pipeline'] if r['SK']['S']=='CAMPAIGN_LOCATORS');row['minimumPeriodId']={'N':str(minimum)}
            other=deepcopy(m);other['locatorSha256']=q.digest(row)
            with self.subTest(minimum=minimum),q.planner_environment(other),self.assertRaises(q.Refusal):q.classify(changed,other,(B,C,P,L),NOW)
        # Current-period rollover requires a fresh baseline; old counts cannot
        # hide a missing newly current registry behind locator minimum.
        with q.planner_environment(m),self.assertRaises(q.Refusal):q.classify(snapshot,m,(B,C,P,L),(PERIOD+1)*P.PERIOD_SECONDS+1)
    def test_legacy_admission_uses_fixed_review_timestamp_not_apply_time(self):
        m,snapshot=fixture();old=next(r for r in snapshot['pipeline'] if r['PK']['S']==f'PERIOD#{PERIOD-1}')
        for name in list(old):
            if name not in P.BASE_FIELDS:old.pop(name)
        with q.planner_environment(m):
            first,_=q.classify(snapshot,m,(B,C,P,L),NOW)
            later,_=q.classify(snapshot,m,(B,C,P,L),NOW+300)
        self.assertEqual(first,later)
        modern=next(C.plain(a['Put']['Item']) for a in first if 'Put' in a and a['Put']['Item']['PK']==old['PK'])
        self.assertEqual(modern['admissionChangedAtEpoch'],m['marker']['approvedAtEpoch'])
        self.assertEqual(modern['admissionState'],'CLOSING')
        self.assertTrue(all(C.wire(modern)[k]==v for k,v in old.items()))
    def test_excluded_retired_timestamp_is_exact_validated_and_condition_only(self):
        m,snapshot=fixture();retired=next(r for r in snapshot['pipeline'] if r['PK']['S']==f'PERIOD#{PERIOD-2}')
        with q.planner_environment(m):actions,_=q.classify(snapshot,m,(B,C,P,L),NOW)
        affected=[a for a in actions if next(iter(a.values())).get('Key',next(iter(a.values())).get('Item'))['PK']==retired['PK']]
        self.assertEqual(len(affected),1);self.assertIn('ConditionCheck',affected[0])
        check=affected[0]['ConditionCheck'];self.assertIn('retiredAtEpoch',check['ExpressionAttributeNames'].values())
        self.assertEqual(retired['retiredAtEpoch'],{'N':str(NOW-2000)})
        for mutation in ('extra','missing','future','backdated','boolean','fraction'):
            other=deepcopy(m);changed=deepcopy(snapshot);row=next(r for r in changed['pipeline'] if r['PK']==retired['PK'])
            if mutation=='extra':row['unknown']={'S':'reject'}
            if mutation=='missing':row.pop('retiredAtEpoch')
            if mutation=='future':row['retiredAtEpoch']={'N':str(NOW+1)}
            if mutation=='backdated':row['retiredAtEpoch']={'N':str(int(row['retireAfterEpoch']['N'])-1)}
            if mutation=='boolean':row['retiredAtEpoch']={'BOOL':True}
            if mutation=='fraction':row['retiredAtEpoch']={'N':str(NOW-2000)+'.5'}
            other['retiredRegistrySha256']=q.digest(row)
            with self.subTest(mutation=mutation),q.planner_environment(other),self.assertRaises(Exception):q.classify(changed,other,(B,C,P,L),NOW)
    def test_unknown_fields_rows_nonempty_intelligence_and_hash_drift_refuse(self):
        for kind in ('unknown','extra','locator','retired','intelligence','partial'):
            m,snapshot=fixture()
            if kind=='unknown':snapshot['pipeline'].append(C.wire({'PK':'UNKNOWN','SK':'STATE'}))
            if kind=='extra':next(r for r in snapshot['pipeline'] if r['PK']['S'].startswith('CONTRIB#'))['unexpected']={'S':'do-not-persist'}
            if kind in ('locator','retired'):m['locatorSha256' if kind=='locator' else 'retiredRegistrySha256']='0'*64
            if kind=='intelligence':snapshot['intelligence']=[{'PK':{'S':'present'}}]
            if kind=='partial':snapshot['pipeline'].pop()
            with self.subTest(kind=kind),q.planner_environment(m),self.assertRaises(Exception):q.classify(snapshot,m,(B,C,P,L),NOW)
    def test_actual_dynamodb_locator_and_tombstone_races_rollback_everything(self):
        for race in ('locator','tombstone'):
            with self.subTest(race=race),mock_aws():
                m,snapshot=fixture();ddb=boto3.client('dynamodb',region_name=q.REGION)
                table=q.TABLES['pipeline'];ddb.create_table(TableName=table,BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':'PK','KeyType':'HASH'},{'AttributeName':'SK','KeyType':'RANGE'}],AttributeDefinitions=[{'AttributeName':k,'AttributeType':'S'} for k in ('PK','SK')])
                for row in snapshot['pipeline']:ddb.put_item(TableName=table,Item=row)
                with q.planner_environment(m):actions,_=q.classify(snapshot,m,(B,C,P,L),NOW)
                changed=next(deepcopy(r) for r in snapshot['pipeline'] if r['PK']['S'].startswith('CONTRIB#' if race=='tombstone' else 'INVENTORY#'))
                changed['locatorCleanupRevision' if race=='tombstone' else 'revision']={'N':'999'};ddb.put_item(TableName=table,Item=changed)
                with self.assertRaises(ddb.exceptions.TransactionCanceledException):ddb.transact_write_items(TransactItems=actions)
                rows=[C.plain(r) for r in ddb.scan(TableName=table)['Items']]
                self.assertEqual(len(rows),7);self.assertFalse(any(r['SK']=='CAMPAIGN_PERIOD_WORK' for r in rows))
                self.assertTrue(all(r.get('admissionSchemaVersion',1)==1 for r in rows))
    def test_actual_dynamodb_migration_then_duplicate_refuses_no_clock_refresh(self):
        with mock_aws():
            m,snapshot=fixture();ddb=boto3.client('dynamodb',region_name=q.REGION);table=q.TABLES['pipeline']
            ddb.create_table(TableName=table,BillingMode='PAY_PER_REQUEST',KeySchema=[{'AttributeName':'PK','KeyType':'HASH'},{'AttributeName':'SK','KeyType':'RANGE'}],AttributeDefinitions=[{'AttributeName':k,'AttributeType':'S'} for k in ('PK','SK')])
            for row in snapshot['pipeline']:ddb.put_item(TableName=table,Item=row)
            with q.planner_environment(m):actions,_=q.classify(snapshot,m,(B,C,P,L),NOW)
            ddb.transact_write_items(TransactItems=actions)
            before=q.scan(ddb,table)
            with self.assertRaises(ddb.exceptions.TransactionCanceledException):ddb.transact_write_items(TransactItems=actions)
            self.assertEqual(q.scan(ddb,table),before)

if __name__=='__main__':unittest.main()
