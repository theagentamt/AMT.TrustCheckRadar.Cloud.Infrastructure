import hashlib,importlib.util,json,sys
from pathlib import Path
plan_path,publication_path,audit_path,iam_result_path,mode,output=sys.argv[1:]
p=json.loads(Path(plan_path).read_text());pub=json.loads(Path(publication_path).read_text());qualified=json.loads(Path(iam_result_path).read_text())
def need(x):
 if not x:raise ValueError('PERIOD_PLAN_VERIFICATION_FAILED')
need(mode in ('full','target') and pub['publicationComplete'] and qualified['passed'] and qualified['cleanupComplete'])
spec=importlib.util.spec_from_file_location('period_iam',Path.cwd()/'scripts/qualify_campaign_period_admission_iam.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
_,_,bound=m.load_union(plan_path,audit_path);need(bound['fullSourcePolicySha256']==qualified['fullSourcePolicySha256'])
roles=('publisher','cluster','deletion','lifecycle');expected={f'aws_lambda_function.worker["{r}"]' for r in roles}|{f'aws_iam_role_policy.period_admission["{r}"]' for r in ('publisher','cluster','lifecycle')}|{'aws_iam_role_policy.lifecycle_runtime[0]'}
if mode=='full':expected|={'aws_iam_role_policy.scheduler_invoke[0]','aws_iam_role_policy.recovery_scheduler_invoke[0]'}
changed=[r for r in p['resource_changes'] if r['mode']=='managed' and r['change']['actions']!=['no-op']];need({r['address'] for r in changed}==expected)
for r in changed:
 addr=r['address'];c=r['change'];old=c['before'];new=c['after']
 if r['type']=='aws_lambda_function':
  kind=next(k for k in roles if addr==f'aws_lambda_function.worker["{k}"]');a=pub['artifacts'][kind];need(c['actions']==['update'])
  delta={k for k in old.keys()|new.keys() if old.get(k)!=new.get(k)};need(delta<={'s3_key','s3_object_version','source_code_hash','last_modified','qualified_arn','qualified_invoke_arn','version','environment'})
  need(new['runtime']=='python3.14' and new['architectures']==['arm64'] and new['handler']=='app.lambda_handler')
  need(new['function_name']=='trustcheckradar-dev-'+a['function'].replace('_','-') and new['s3_bucket']==a['bucket'] and new['s3_key']==a['key'] and new['s3_object_version']==a['objectVersion'] and new['source_code_hash']==a['sourceCodeHash'])
  before=old['environment'][0]['variables'];after=new['environment'][0]['variables'];need(after==before|{'CAMPAIGN_PERIOD_ADMISSION_ENABLED':'false','CAMPAIGN_PERIOD_ADMISSION_GENERATION':'','CAMPAIGN_PERIOD_ADMISSION_ACCOUNT_ID':'107827791950'})
  need(after['CAMPAIGN_LOCATOR_MANIFEST_SHA256']=='' and after['CAMPAIGN_LOCATOR_INVENTORY_REVISION']=='0')
  if kind=='deletion':
   need(all(after[name]=='false' for name in ('CAMPAIGN_DELETION_STREAM_ENABLED','CAMPAIGN_RECOVERY_ENABLED','CAMPAIGN_COMPLETION_ENABLED')))
   need(all(after[name]=='' for name in ('CAMPAIGN_COMPLETION_MANIFEST_SHA256','CAMPAIGN_RECOVERY_MANIFEST_SHA256')) and all(after[name]=='0' for name in ('CAMPAIGN_COMPLETION_INVENTORY_REVISION','CAMPAIGN_RECOVERY_INVENTORY_REVISION')))
  if kind=='lifecycle':need(after['CAMPAIGN_LIFECYCLE_CANDIDATE_ENABLED']=='false')

 elif 'scheduler_invoke' in addr:
  need(mode=='full' and c['actions']==['update'] and c['after_unknown'].get('policy') is True and {k for k in old.keys()|new.keys() if old.get(k)!=new.get(k)}=={'policy'})
 # Other IAM changes already bound to exact independently qualified policy union.
v={k:x['value'] for k,x in p['variables'].items()};need(v['environment']=='dev' and v['kill_switch_enabled'] is True and v['research_consent_migration'] is True)
need(v['account_privacy_artifacts']['release_id']==pub['sourceSha']==v['campaign_completion_artifact']['release_id'])
need(v['campaign_period_fence_preparation']['review_reference']=='docs/CAMPAIGN-PERIOD-ADMISSION.md')
r={'verified':True,'mode':mode,'planJsonSha256':hashlib.sha256(Path(plan_path).read_bytes()).hexdigest(),'sourceSha':pub['sourceSha'],'allGatesClosed':True,'changes':[{'address':r['address'],'actions':r['change']['actions']} for r in changed],'fullSourcePolicySha256':bound['fullSourcePolicySha256']}
Path(output).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
