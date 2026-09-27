#!/usr/bin/env python3
"""Owned two-table/one-key retirement fixture; never uses application resources."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

ACCOUNT = '107827791950'
REGION = 'us-east-1'
PERIOD_SECONDS = 14 * 86400
CASES = ('guards_and_complete_replay', 'lost_ack')


def need(value):
    if not value:
        raise ValueError('RETIREMENT_FIXTURE_BOUNDARY_REJECTED')


def identity(run):
    need(type(run) is str and re.fullmatch('[0-9a-f]{12}', run))
    prefix = 'amt-campaign-retirement-qual-' + run
    return prefix, {'Project': 'trustcheckradar', 'Environment': 'dev',
                    'Purpose': 'campaign-retirement-qualification', 'QualificationRunId': run}


def key_tags(period):
    need(type(period) is int and period >= 0)
    return {'Project': 'trustcheckradar', 'Environment': 'dev',
            'Purpose': 'campaign-contributor-token', 'PeriodId': str(period)}


def validate(doc, run):
    prefix, tags = identity(run)
    need(type(doc.get('schemaVersion')) is int and doc.get('schemaVersion') == 1 and doc.get('runId') == run
         and doc.get('account') == ACCOUNT and doc.get('region') == REGION
         and doc.get('prefix') == prefix and doc.get('tags') == tags
         and doc.get('tables') == {k: prefix + '-' + k for k in ('pipeline', 'outbox')}
         and doc.get('keyTags') == key_tags(doc.get('period')))
    arn = doc.get('keyArn')
    need(arn is None or re.fullmatch(rf'arn:aws:kms:{REGION}:{ACCOUNT}:key/[0-9a-f]{{8}}(?:-[0-9a-f]{{4}}){{3}}-[0-9a-f]{{12}}', arn))
    return doc


def verify_key(metadata, observed, doc):
    need(metadata['Arn'] == doc['keyArn'] and metadata['Description'] == doc['prefix']
         and metadata['KeySpec'] == 'HMAC_256' and metadata['KeyUsage'] == 'GENERATE_VERIFY_MAC'
         and metadata['KeyManager'] == 'CUSTOMER' and metadata['Origin'] == 'AWS_KMS'
         and metadata['MultiRegion'] is False and not observed.get('Truncated')
         and not observed.get('NextMarker') and len(observed['Tags']) == 4
         and {t['TagKey']: t['TagValue'] for t in observed['Tags']} == doc['keyTags'])
    return metadata


def verify_source(root, source):
    need(re.fullmatch('[0-9a-f]{40}', source))
    def git(*args):
        return subprocess.check_output(['git', '-C', str(root), *args])
    need(git('rev-parse', 'HEAD').decode().strip() == source)
    need(not git('status', '--porcelain', '--untracked-files=all').strip())
    origins = ['scripts/qualification/period_retirement.py']
    for package in ('shared_campaign_work', 'shared_campaign_locators', 'shared_campaign_contracts'):
        origins += [str(p.relative_to(root)) for p in sorted((root/'src'/package).glob('*.py'))]
    need(len(origins) >= 4)
    hashes = {}
    for origin in origins:
        data = (root/origin).read_bytes()
        need(data == git('show', source + ':' + origin))
        compile(data, origin, 'exec')
        hashes[origin] = hashlib.sha256(data).hexdigest()
    return hashes


def error_code(exc):
    return getattr(exc, 'response', {}).get('Error', {}).get('Code')


def durable_journal(path, doc, *, create=False):
    """Keep the preceding ownership journal intact until a full update is durable."""
    path = Path(path)
    payload = (json.dumps(doc, sort_keys=True, indent=2) + '\n').encode()
    temporary = None
    try:
        if create:
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        else:
            fd, temporary = tempfile.mkstemp(prefix=path.name+'.', dir=path.parent)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(payload); stream.flush(); os.fsync(stream.fileno())
        if temporary is not None:
            os.replace(temporary, path); temporary = None
        directory = os.open(path.parent, os.O_RDONLY)
        try: os.fsync(directory)
        finally: os.close(directory)
    finally:
        if temporary is not None:
            try: os.unlink(temporary)
            except FileNotFoundError: pass


def main():
    import boto3
    from botocore.config import Config
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('prepare', 'run', 'cleanup'))
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--journal', required=True)
    parser.add_argument('--profile', default='trustcheckradar')
    parser.add_argument('--case', choices=CASES)
    parser.add_argument('--source-root')
    parser.add_argument('--source-sha')
    parser.add_argument('--output')
    args = parser.parse_args()
    prefix, tags = identity(args.run_id)
    path = Path(args.journal)
    session = boto3.Session(profile_name=args.profile, region_name=REGION)
    config = Config(connect_timeout=5, read_timeout=15, retries={'total_max_attempts': 1})
    sts, ddb, kms = [session.client(s, config=config) for s in ('sts', 'dynamodb', 'kms')]
    need(sts.get_caller_identity()['Account'] == ACCOUNT)
    deadline = time.monotonic() + 180
    def save(doc):
        durable_journal(path, doc)
    def wait_table(name, present):
        while time.monotonic() < deadline:
            try:
                table = ddb.describe_table(TableName=name)['Table']
                if present and table['TableStatus'] == 'ACTIVE': return
            except Exception as exc:
                if error_code(exc) == 'ResourceNotFoundException' and not present: return
                if error_code(exc) != 'ResourceNotFoundException': raise
            time.sleep(2)
        raise TimeoutError('FIXTURE_TABLE_WAIT_EXPIRED')
    def check_key(doc):
        need(doc.get('keyArn'))
        value = kms.describe_key(KeyId=doc['keyArn'])['KeyMetadata']
        observed = kms.list_resource_tags(KeyId=doc['keyArn'])
        verify_key(value, observed, doc)
        return value
    if args.operation == 'prepare':
        need(not path.exists())
        period = int(time.time()) // PERIOD_SECONDS - 2
        doc = {'schemaVersion': 1, 'runId': args.run_id, 'account': ACCOUNT, 'region': REGION,
               'prefix': prefix, 'tags': tags, 'period': period, 'keyTags': key_tags(period),
               'tables': {k: prefix+'-'+k for k in ('pipeline','outbox')},
               'createdAtUtc': datetime.now(timezone.utc).isoformat(), 'tableCreateAttempts': []}
        # Exclusive journal creation precedes any AWS mutation.
        durable_journal(path, doc, create=True)
        for name in doc['tables'].values():
            doc['tableCreateAttempts'].append(name); save(doc)
            ddb.create_table(TableName=name, BillingMode='PAY_PER_REQUEST',
                KeySchema=[{'AttributeName': 'PK', 'KeyType': 'HASH'}, {'AttributeName': 'SK', 'KeyType': 'RANGE'}],
                AttributeDefinitions=[{'AttributeName': 'PK', 'AttributeType': 'S'}, {'AttributeName': 'SK', 'AttributeType': 'S'}],
                StreamSpecification={'StreamEnabled': False}, Tags=[{'Key': k, 'Value': v} for k,v in tags.items()])
            wait_table(name, True)
            need(ddb.describe_continuous_backups(TableName=name)['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['PointInTimeRecoveryStatus'] == 'DISABLED')
        doc['keyCreateAttempted'] = True; save(doc)
        key = kms.create_key(KeySpec='HMAC_256', KeyUsage='GENERATE_VERIFY_MAC',
            Description=prefix, Tags=[{'TagKey': k, 'TagValue': v} for k,v in doc['keyTags'].items()])
        doc['keyArn'] = key['KeyMetadata']['Arn']; save(doc)
        need(check_key(doc)['KeyState'] == 'Enabled')
        doc['prepared'] = True; save(doc)
        print(json.dumps({'prepared': True, 'runId': args.run_id})); return
    doc = validate(json.loads(path.read_text()), args.run_id)
    if args.operation == 'run':
        need(doc.get('prepared') is True and not doc.get('invocationAttempted') and not doc.get('cleanup'))
        need(args.source_root and args.source_sha and args.case and args.output)
        source_root = Path(args.source_root).resolve()
        hashes = verify_source(source_root, args.source_sha)
        need(check_key(doc)['KeyState'] == 'Enabled' and doc['period'] == int(time.time())//PERIOD_SECONDS-2)
        import sys
        sys.path.insert(0, str(source_root/'src'))
        module_path = source_root/'scripts/qualification/period_retirement.py'
        spec = importlib.util.spec_from_file_location('approved_retirement_fixture', module_path)
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        report = {'schemaVersion':1, 'runId':args.run_id,'sourceSha':args.source_sha,
                  'memberSha256':hashes,'case':args.case,'cloudExecuted':True,'fixtureOnly':True,
                  'syntheticProof':True,'productionActivation':False,'passed':False,
                  'runnerSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
        with Path(args.output).open('x') as output:
            json.dump(report,output);output.flush();os.fsync(output.fileno())
            doc.update(invocationAttempted=True, sourceSha=args.source_sha, case=args.case);save(doc)
            started=time.monotonic()
            result=module.run(ddb,kms,run_id=args.run_id,pipeline_table=doc['tables']['pipeline'],
                outbox_table=doc['tables']['outbox'],key_arn=doc['keyArn'],case=args.case,
                now=time.time,remaining_ms=lambda:max(0,int((180-(time.monotonic()-started))*1000)))
            need(result.get('passed') is True and result.get('syntheticProof') is True and result.get('productionActivation') is False)
            report.update(result, sourceVerified=True,elapsedSeconds=round(time.monotonic()-started,3),
                observedAtUtc=datetime.now(timezone.utc).isoformat(),execution='local Python 3.14 with actual AWS DynamoDB and KMS; not a deployed Lambda or production-role test')
            output.seek(0);json.dump(report,output,indent=2);output.write('\n');output.truncate();output.flush();os.fsync(output.fileno())
        print(json.dumps({k:v for k,v in report.items() if k!='memberSha256'})); return
    # Cleanup refuses an unknown key after an ambiguous creation. An operator must
    # first recover the exact ARN by unique Description plus all four tags.
    need(not doc.get('keyCreateAttempted') or doc.get('keyArn'))
    result = {'tablesAbsent': {}, 'keyDestroyed': False}
    if doc.get('keyArn'):
        key = check_key(doc)
        if key['KeyState'] != 'PendingDeletion':
            need(key['KeyState'] in ('Enabled','Disabled'))
            kms.schedule_key_deletion(KeyId=doc['keyArn'], PendingWindowInDays=7)
        key=check_key(doc);need(key['KeyState']=='PendingDeletion')
        result.update(keyState='PendingDeletion',keyDeletionDate=key['DeletionDate'].isoformat())
    for family,name in doc['tables'].items():
        try:
            arn=ddb.describe_table(TableName=name)['Table']['TableArn']
            observed=ddb.list_tags_of_resource(ResourceArn=arn)
            need(not observed.get('NextToken') and len(observed['Tags'])==len(tags)
                 and {t['Key']:t['Value'] for t in observed['Tags']}==tags)
            ddb.delete_table(TableName=name)
        except Exception as exc:
            if error_code(exc)!='ResourceNotFoundException': raise
        wait_table(name,False);result['tablesAbsent'][family]=True
    result['observedAtUtc']=datetime.now(timezone.utc).isoformat()
    doc['cleanup']=result;save(doc);print(json.dumps(result))


if __name__ == '__main__':
    try:main()
    except Exception as exc:
        print(json.dumps({'passed':False,'reason':type(exc).__name__,'cleanupRequired':True}))
        raise SystemExit(1)
