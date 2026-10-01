import boto3,json
from pathlib import Path
from datetime import datetime,timezone
from botocore.config import Config
s=boto3.Session(profile_name='trustcheckradar',region_name='us-east-1');cfg=Config(connect_timeout=5,read_timeout=15,retries={'total_max_attempts':1});iam=s.client('iam',config=cfg);sts=s.client('sts',config=cfg)
assert sts.get_caller_identity()['Account']=='107827791950'
names=['trustcheckradar-dev-campaign-observation-publisher-role','trustcheckradar-dev-campaign-cluster-aggregator-role','trustcheckradar-dev-campaign-lifecycle-role']
report={'observedAtUtc':datetime.now(timezone.utc).isoformat(),'roles':{}}
for name in names:
 r=iam.get_role(RoleName=name)['Role'];inline=iam.list_role_policies(RoleName=name);attached=iam.list_attached_role_policies(RoleName=name);assert not inline.get('IsTruncated') and not attached.get('IsTruncated')
 item={'arn':r['Arn'],'permissionsBoundary':r.get('PermissionsBoundary'),'inline':{},'managed':{}}
 for p in inline['PolicyNames']:item['inline'][p]=iam.get_role_policy(RoleName=name,PolicyName=p)['PolicyDocument']
 for p in attached['AttachedPolicies']:
  m=iam.get_policy(PolicyArn=p['PolicyArn'])['Policy'];item['managed'][p['PolicyArn']]=iam.get_policy_version(PolicyArn=m['Arn'],VersionId=m['DefaultVersionId'])['PolicyVersion']['Document']
 report['roles'][name]=item
Path('/tmp/amt-period-fence-role-audit.json').write_text(json.dumps(report,indent=2)+'\n')
for name,r in report['roles'].items():print(name,'inline',list(r['inline']),'managed',list(r['managed']),'boundary',bool(r['permissionsBoundary']))
