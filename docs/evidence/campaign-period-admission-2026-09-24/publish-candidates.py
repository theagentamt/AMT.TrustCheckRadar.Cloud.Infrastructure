import base64,boto3,hashlib,json,re,subprocess,sys,zipfile
from pathlib import Path
from botocore.config import Config
source,directory,repository,manifest_path,output=sys.argv[1:]
def need(v):
 if not v:raise ValueError('PUBLICATION_VERIFICATION_FAILED')
need(re.fullmatch('[0-9a-f]{40}',source));directory=Path(directory)
names={'publisher':'campaign_observation_publisher','cluster':'campaign_cluster_aggregator','deletion':'campaign_deletion_bridge','lifecycle':'campaign_lifecycle'}
manifest=json.loads(Path(manifest_path).read_text());need(manifest['sourceSha']==source and set(manifest['productionArchives'])==set(names.values()))
# Validate every production member before publishing any archive.
packages={}
for kind,function in names.items():
 raw=(directory/(function+'.zip')).read_bytes();digest=hashlib.sha256(raw).digest()
 need(manifest['productionArchives'][function]['sha256']==digest.hex() and manifest['productionArchives'][function]['sizeBytes']==len(raw))
 with zipfile.ZipFile(directory/(function+'.zip')) as z:
  members=z.namelist();need('app.py' in members and len(members)==len(set(members)))
  for name in members:
   need(name.endswith('.py') and not name.startswith('/') and '..' not in Path(name).parts)
   path='src/'+name if '/' in name else 'src/'+function+'/'+name
   need(z.read(name)==subprocess.check_output(['git','show',source+':'+path],cwd=repository));compile(z.read(name),name,'exec')
 packages[kind]=(function,raw,digest)
s=boto3.Session(profile_name='trustcheckradar',region_name='us-east-1');cfg=Config(connect_timeout=5,read_timeout=30,retries={'total_max_attempts':1})
need(s.client('sts',config=cfg).get_caller_identity()['Account']=='107827791950');c=s.client('s3',config=cfg);bucket='trustcheckradar-dev-107827791950-artifacts'
need(c.get_bucket_versioning(Bucket=bucket)['Status']=='Enabled')
r={'sourceSha':source,'publicationComplete':False,'runtimeUpdated':False,'activationApproved':False,'artifacts':{}}
Path(output).write_text(json.dumps(r,indent=2)+'\n')
for kind,(function,raw,digest) in packages.items():
 key='releases/'+source+'/'+function+'.zip';checksum=base64.b64encode(digest).decode()
 try:
  h=c.head_object(Bucket=bucket,Key=key,ChecksumMode='ENABLED');need(h.get('ChecksumSHA256')==checksum and h.get('Metadata',{}).get('sha256')==digest.hex());version=h['VersionId']
 except c.exceptions.ClientError as e:
  if e.response['Error']['Code'] not in ('404','NoSuchKey','NotFound'):raise
  x=c.put_object(Bucket=bucket,Key=key,Body=raw,ContentType='application/zip',IfNoneMatch='*',ChecksumSHA256=checksum,Metadata={'sha256':digest.hex(),'source-sha':source,'target-runtime':'python3.14','target-architecture':'arm64'});version=x['VersionId']
 need(version and version!='null');h=c.head_object(Bucket=bucket,Key=key,VersionId=version,ChecksumMode='ENABLED')
 need(h['ContentLength']==len(raw) and h['ChecksumSHA256']==checksum and h['Metadata']['source-sha']==source)
 x=c.get_object(Bucket=bucket,Key=key,VersionId=version);need(hashlib.sha256(x['Body'].read()).digest()==digest)
 r['artifacts'][kind]={'function':function,'bucket':bucket,'key':key,'objectVersion':version,'sourceCodeHash':checksum,'sha256':digest.hex(),'bytes':len(raw),'runtime':'python3.14','architecture':'arm64','handler':'app.lambda_handler'}
 Path(output).write_text(json.dumps(r,indent=2)+'\n')
r['publicationComplete']=True;Path(output).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'publicationComplete':True,'sourceSha':source,'artifacts':4}))
