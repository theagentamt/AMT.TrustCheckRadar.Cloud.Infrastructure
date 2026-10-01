#!/usr/bin/env python3
"""Read-only bounded period registry and KMS metadata audit; never derive MACs."""
import datetime
from decimal import Decimal
import json
import re
import time
from pathlib import Path

ACCOUNT = '107827791950'
REGION = 'us-east-1'
TABLE = 'trustcheckradar-dev-campaign-pipeline'
PERIOD = 14 * 86400
RECOVERY = 7 * 86400
FIELDS = ('PK', 'SK', 'periodId', 'status', 'keyArn', 'retireAfterEpoch', 'retiredAtEpoch')
ARN = re.compile(r'arn:aws:kms:us-east-1:107827791950:key/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')


def require(value):
    if not value: raise ValueError('UNVERIFIED_METADATA')


def collect(ddb, kms, *, monotonic=time.monotonic, max_pages=10, max_keys=100, seconds=60):
    from boto3.dynamodb.types import TypeDeserializer
    require(1 <= max_pages <= 10 and 1 <= max_keys <= 100 and 1 <= seconds <= 60)
    deadline = monotonic() + seconds
    report = {'schemaVersion': 1, 'observedAtUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'accountId': ACCOUNT, 'region': REGION, 'table': TABLE, 'pages': 0,
              'scannedCount': 0, 'registryRows': 0, 'periods': [], 'reasons': [],
              'traversalComplete': False, 'metadataComplete': True,
              'inventoryApproved': False, 'erasureVerified': False,
              'bounds': {'maxPages': max_pages, 'maxKeys': max_keys, 'callStartSeconds': seconds}}
    def within():
        if monotonic() >= deadline:
            report['reasons'].append('TIME_BUDGET'); report['metadataComplete'] = False
            return False
        return True
    if not within():
        return report
    if ddb.describe_table(TableName=TABLE)['Table']['TableArn'] != f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{TABLE}':
        raise ValueError('TABLE_IDENTITY_MISMATCH')
    names = {f'#f{i}': field for i, field in enumerate(FIELDS)}
    cursor = None
    decoder = TypeDeserializer()
    for _ in range(max_pages):
        if not within(): break
        args = dict(TableName=TABLE, ConsistentRead=True, Select='SPECIFIC_ATTRIBUTES', Limit=1000,
                    ProjectionExpression=','.join(names), ExpressionAttributeNames=names,
                    FilterExpression='begins_with(#f0,:prefix) AND #f1=:kind',
                    ExpressionAttributeValues={':prefix': {'S': 'PERIOD#'}, ':kind': {'S': 'HMAC_KEY'}})
        if cursor: args['ExclusiveStartKey'] = cursor
        page = ddb.scan(**args)
        report['pages'] += 1
        report['scannedCount'] += page['ScannedCount']
        for raw in page.get('Items', []):
            if report['registryRows'] >= max_keys:
                report['reasons'].append('KEY_BUDGET'); report['metadataComplete'] = False
                return report
            report['registryRows'] += 1
            row = {k: decoder.deserialize(v) for k, v in raw.items()}
            try:
                require(set(row) <= set(FIELDS))
                p = row['periodId']; period = int(p)
                require(not isinstance(p, bool))
                require(p == period and 0 <= period <= 1000000)
                require(row['PK'] == f'PERIOD#{period}' and row['SK'] == 'HMAC_KEY')
                require(row['status'] in ('ENABLED', 'RETIRED'))
                require(row['retireAfterEpoch'] == (period + 1) * PERIOD + RECOVERY)
                require(isinstance(row['keyArn'], str) and ARN.fullmatch(row['keyArn']))
                if row['status'] == 'RETIRED':
                    require(type(row.get('retiredAtEpoch')) in (int, Decimal))
                    require(row['retiredAtEpoch'] == int(row['retiredAtEpoch']) and row['retireAfterEpoch'] <= row['retiredAtEpoch'] <= 10**12)
                else:
                    require('retiredAtEpoch' not in row)
            except (AssertionError, KeyError, ValueError, TypeError, ArithmeticError):
                report['reasons'].append('REGISTRY_RECORD_UNVERIFIED'); report['metadataComplete'] = False
                continue
            entry = {'periodId': period, 'registryStatus': row['status'], 'keyArn': row['keyArn'],
                     'retireAfterEpoch': int(row['retireAfterEpoch'])}
            if 'retiredAtEpoch' in row: entry['retiredAtEpoch'] = int(row['retiredAtEpoch'])
            report['periods'].append(entry)
            if not within(): return report
            try:
                meta = kms.describe_key(KeyId=row['keyArn'])['KeyMetadata']
                require(meta['Arn'] == row['keyArn'] and meta['AWSAccountId'] == ACCOUNT)
                entry['hmac256'] = meta.get('KeySpec') == 'HMAC_256'
                entry['generateVerifyMac'] = meta.get('KeyUsage') == 'GENERATE_VERIFY_MAC'
                entry['state'] = meta['KeyState'] if meta.get('KeyState') in ('Enabled', 'Disabled', 'PendingDeletion', 'PendingImport', 'Unavailable', 'Creating', 'Updating', 'PendingReplicaDeletion') else 'UNKNOWN'
                if not within(): return report
                tags = kms.list_resource_tags(KeyId=row['keyArn'], Limit=50)
                observed = {t['TagKey']: t['TagValue'] for t in tags['Tags']}
                entry['registryStateMatches'] = ((row['status'] == 'ENABLED' and entry['state'] == 'Enabled')
                    or (row['status'] == 'RETIRED' and entry['state'] in ('Disabled', 'PendingDeletion')))
                entry['tagsComplete'] = not tags.get('Truncated', False)
                entry['tagMatches'] = {k: observed.get(k) == v for k, v in {
                    'Project': 'trustcheckradar', 'Environment': 'dev',
                    'Purpose': 'campaign-contributor-token', 'PeriodId': str(period)}.items()}
                if not entry['registryStateMatches'] or not entry['tagsComplete'] or not all(entry['tagMatches'].values()) or not entry['hmac256'] or not entry['generateVerifyMac']:
                    report['metadataComplete'] = False; report['reasons'].append('KEY_METADATA_UNVERIFIED')
            except Exception:
                entry['metadataUnavailable'] = True; report['metadataComplete'] = False
                report['reasons'].append('KEY_METADATA_UNAVAILABLE')
        cursor = page.get('LastEvaluatedKey')
        if not cursor:
            report['traversalComplete'] = True
            break
    if cursor and not report['traversalComplete']: report['reasons'].append('PAGE_OR_TIME_BUDGET')
    report['reasons'] = sorted(set(report['reasons']))
    report['limitations'] = [
        'Projected registry and key metadata are separate observations, not a frozen snapshot or full schema validation.',
        'No account data, MACs, key material, arbitrary tag values or pagination identifiers are retained.',
        'No key creation, disablement, retirement, deletion, inventory marker or application write occurred.',
        'Missing or empty current registry cannot prove historical key destruction, restore coverage or erasure.',
    ]
    return report


def main():
    import argparse
    import boto3
    from botocore.config import Config
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', default='trustcheckradar'); parser.add_argument('--output', required=True)
    args = parser.parse_args()
    try:
        session = boto3.Session(profile_name=args.profile, region_name=REGION)
        config = Config(connect_timeout=5, read_timeout=15, retries={'total_max_attempts': 1})
        if session.client('sts', config=config).get_caller_identity()['Account'] != ACCOUNT: raise ValueError('ACCOUNT_MISMATCH')
        result = collect(session.client('dynamodb', config=config), session.client('kms', config=config))
        Path(args.output).write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
        complete = result['traversalComplete'] and result['metadataComplete']
        print(json.dumps({'auditComplete': complete, 'registryRows': result['registryRows']}))
        return 0 if complete else 2
    except Exception:
        print(json.dumps({'auditComplete': False, 'reason': 'PERIOD_AUDIT_FAILED'})); return 1


if __name__ == '__main__':
    raise SystemExit(main())
