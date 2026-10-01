import base64,boto3,hashlib,json,re,subprocess,sys,zipfile
from pathlib import Path
from botocore.config import Config
source,archive_path,manifest_path,repository,output=sys.argv[1:]
def need(v):
 if not v:raise ValueError('PUBLICATION_VERIFICATION_FAILED')
need(re.fullmatch('[0-9a-f]{40}',source))
manifest=json.loads(Path(manifest_path).read_text());need(manifest['sourceSha']==source)
archive=Path(archive_path);raw=archive.read_bytes();digest=hashlib.sha256(raw).digest();checksum=base64.b64encode(digest).decode()
need(digest.hex()==manifest['productionZipSha256'])
with zipfile.ZipFile(archive) as z:
 names=z.namelist();need('app.py' in names and len(names)==len(set(names)))
 for name in names:
  need(name.endswith('.py') and not name.startswith('/') and '..' not in Path(name).parts)
  path='src/'+name if '/' in name else 'src/campaign_deletion_bridge/'+name
  need(z.read(name)==subprocess.check_output(['git','show',source+':'+path],cwd=repository))
  compile(z.read(name),name,'exec')
s=boto3.Session(profile_name='trustcheckradar',region_name='us-east-1');cfg=Config(connect_timeout=5,read_timeout=30,retries={'total_max_attempts':1})
need(s.client('sts',config=cfg).get_caller_identity()['Account']=='107827791950');c=s.client('s3',config=cfg)
bucket='trustcheckradar-dev-107827791950-artifacts';key='releases/'+source+'/campaign_deletion_bridge.zip'
need(c.get_bucket_versioning(Bucket=bucket)['Status']=='Enabled')
try:
 h=c.head_object(Bucket=bucket,Key=key,ChecksumMode='ENABLED');need(h.get('ChecksumSHA256')==checksum and h.get('Metadata',{}).get('sha256')==digest.hex());version=h['VersionId']
except c.exceptions.ClientError as e:
 if e.response['Error']['Code'] not in ('404','NoSuchKey','NotFound'):raise
 p=c.put_object(Bucket=bucket,Key=key,Body=raw,ContentType='application/zip',IfNoneMatch='*',ChecksumSHA256=checksum,Metadata={'sha256':digest.hex(),'source-sha':source,'target-runtime':'python3.14','target-architecture':'arm64'});version=p['VersionId']
need(version and version!='null');h=c.head_object(Bucket=bucket,Key=key,VersionId=version,ChecksumMode='ENABLED')
need(h['ContentLength']==len(raw) and h['ChecksumSHA256']==checksum and h['Metadata']['source-sha']==source)
p=c.get_object(Bucket=bucket,Key=key,VersionId=version);need(hashlib.sha256(p['Body'].read()).digest()==digest)
r={'sourceSha':source,'bucket':bucket,'key':key,'objectVersion':version,'sourceCodeHash':checksum,'sha256':digest.hex(),'bytes':len(raw),'runtime':'python3.14','architecture':'arm64','handler':'app.lambda_handler','publicationComplete':True,'runtimeUpdated':False,'activationApproved':False}
Path(output).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
