import hashlib,importlib.util,json,sys
from pathlib import Path
plan_path,publication_path,mode,out=sys.argv[1:]
p=json.loads(Path(plan_path).read_text());a=json.loads(Path(publication_path).read_text())
def need(x):
 if not x:raise ValueError('PLAN_VERIFICATION_FAILED')
need(mode in ('full','target'))
changes=[r for r in p['resource_changes'] if r['mode']=='managed' and r['change']['actions']!=['no-op']]
expected={'aws_iam_role_policy.completion_runtime[0]','aws_lambda_function.worker["deletion"]'}
if mode=='full':expected|={'aws_iam_role_policy.recovery_scheduler_invoke[0]','aws_iam_role_policy.scheduler_invoke[0]'}
need({r['address'] for r in changes}==expected)
for r in changes:
 c=r['change'];addr=r['address'];before=c['before'];after=c['after']
 if addr=='aws_iam_role_policy.completion_runtime[0]':
  need(c['actions']==['create'] and before is None and after['role']=='trustcheckradar-dev-campaign-deletion-bridge-role')
  policy=json.loads(after['policy']);digest=hashlib.sha256(json.dumps(policy,sort_keys=True,separators=(',',':')).encode()).hexdigest()
  need(digest=='17c0ba3a26fd3b4610dc0deb995a3ce2b07b467e37240922524c814d38e060d0')
 elif addr=='aws_lambda_function.worker["deletion"]':
  need(c['actions']==['update'])
  delta={k for k in before.keys()|after.keys() if before.get(k)!=after.get(k)}
  need(delta<= {'s3_key','s3_object_version','source_code_hash','last_modified','qualified_arn','qualified_invoke_arn','version','environment'})
  need(after['function_name']=='trustcheckradar-dev-campaign-deletion-bridge' and after['runtime']=='python3.14' and after['architectures']==['arm64'] and after['handler']=='app.lambda_handler')
  need(after['s3_bucket']==a['bucket'] and after['s3_key']==a['key'] and after['s3_object_version']==a['objectVersion'] and after['source_code_hash']==a['sourceCodeHash'])
  old=before['environment'][0]['variables'];new=after['environment'][0]['variables']
  need(new==old|{'CAMPAIGN_DELETION_STREAM_ENABLED':'false','CAMPAIGN_COMPLETION_ENABLED':'false','CAMPAIGN_COMPLETION_MANIFEST_SHA256':'','CAMPAIGN_COMPLETION_INVENTORY_REVISION':'0'})
  need(new['CAMPAIGN_RECOVERY_ENABLED']=='false' and new['CAMPAIGN_LOCATOR_MANIFEST_SHA256']=='' and new['CAMPAIGN_RECOVERY_MANIFEST_SHA256']=='')
 else:
  need(mode=='full' and c['actions']==['update'] and c['after_unknown'].get('policy') is True)
  need({k for k in before.keys()|after.keys() if before.get(k)!=after.get(k)}=={'policy'})
variables={k:v['value'] for k,v in p['variables'].items()}
need(variables['environment']=='dev' and variables['kill_switch_enabled'] is True and variables['research_consent_migration'] is True)
need(variables['campaign_completion_artifact']['release_id']==a['sourceSha'])
r={'planSha256':hashlib.sha256(Path(plan_path).read_bytes()).hexdigest(),'verified':True,'mode':mode,'changes':[{'address':r['address'],'actions':r['change']['actions']} for r in changes],'publicationSource':a['sourceSha'],'completionPolicySha256':digest,'allGatesDisabled':True,'note':'Full plan contains deferred scheduler policy rendering; apply only separately verified target plan, then require full zero-change verification.'}
Path(out).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
