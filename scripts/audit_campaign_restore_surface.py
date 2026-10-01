#!/usr/bin/env python3
"""Bounded Dev storage metadata audit. Never read table items or restore data."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path
import time

ACCOUNT = '107827791950'
REGION = 'us-east-1'
TABLES = {
    'trustcheckradar-dev-campaign-outbox': 'transient',
    'trustcheckradar-dev-campaign-pipeline': 'transient',
    'trustcheckradar-dev-campaign-intelligence': 'aggregate',
    'trustcheckradar-dev-deletion-ledger': 'account-control',
    'trustcheckradar-dev-users': 'account-control',
}


def collect(ddb, backup, *, clock=time.monotonic, max_pages=10, seconds=120):
    if not 1 <= max_pages <= 10 or not 1 <= seconds <= 120:
        raise ValueError('INVALID_BOUND')
    deadline = clock() + seconds
    report = {'schemaVersion': 1, 'observedAtUtc': datetime.now(timezone.utc).isoformat(),
              'accountId': ACCOUNT, 'region': REGION, 'tables': {}, 'metadataComplete': True,
              'historicalCoverageVerified': False, 'restoreApproved': False,
              'bounds': {'maxPagesPerList': max_pages, 'callStartSeconds': seconds},
              'limitations': [
                  'Current control-plane observations are not a frozen snapshot or historical erasure proof.',
                  'No table items, backup contents, export objects, key material or customer identifiers read.',
                  'Exact five tables only; other names, regions/accounts, deleted copies and manual dumps are unqualified.',
                  'ListExports covers its service history window (90 days), not all surviving S3 copies.',
                  'A missing or denied observation remains unavailable, never an empty successful inventory.',
                  'No restore, backup, key change, approval marker or application mutation performed.']}

    def call(method, **args):
        if clock() >= deadline:
            raise TimeoutError('TIME_BUDGET')
        return method(**args)

    def inventory(method, args, rows_key, next_key, input_key, category_key, allowed):
        counts = Counter(); cursor = None; seen = set(); understood = True
        for page in range(max_pages):
            response = call(method, **args, **({input_key: cursor} if cursor else {}))
            rows = response[rows_key]
            if not isinstance(rows, list): raise ValueError('INVALID_RESPONSE')
            for row in rows:
                value = row.get(category_key)
                counts[value if value in allowed else 'UNKNOWN'] += 1
                understood = understood and value in allowed
            cursor = response.get(next_key)
            if not cursor:
                return {'complete': understood, 'pages': page + 1, 'count': sum(counts.values()), 'categories': dict(counts)}
            if not isinstance(cursor, str) or cursor in seen: break
            seen.add(cursor)
        return {'complete': False, 'pages': page + 1, 'count': sum(counts.values()), 'categories': dict(counts), 'reason': 'PAGINATION_BOUND'}

    for table, data_class in TABLES.items():
        arn = f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{table}'
        entry = {'dataClass': data_class, 'observations': {}}; report['tables'][table] = entry
        try:
            meta = call(ddb.describe_table, TableName=table)['Table']
            if meta['TableArn'] != arn or meta['TableName'] != table:
                raise ValueError('TABLE_IDENTITY_MISMATCH')
            entry['tableIdentityVerified'] = True
            entry['currentTableWasRestored'] = bool(meta.get('RestoreSummary'))
            entry['hasReplicas'] = bool(meta.get('Replicas'))
            entry['streamEnabled'] = meta.get('StreamSpecification', {}).get('StreamEnabled', False)
            entry['tableStatus'] = meta['TableStatus'] if meta.get('TableStatus') in ('ACTIVE', 'CREATING', 'UPDATING', 'DELETING', 'ARCHIVING', 'ARCHIVED') else 'UNKNOWN'
        except Exception:
            entry['tableIdentityVerified'] = False; report['metadataComplete'] = False
            continue
        if entry['tableStatus'] == 'UNKNOWN': report['metadataComplete'] = False
        operations = {
            'pitr': lambda: call(ddb.describe_continuous_backups, TableName=table)['ContinuousBackupsDescription']['PointInTimeRecoveryDescription'],
            'ttl': lambda: call(ddb.describe_time_to_live, TableName=table)['TimeToLiveDescription'],
            'nativeBackups': lambda: inventory(ddb.list_backups, {'TableName': table, 'BackupType': 'ALL', 'Limit': 100}, 'BackupSummaries', 'LastEvaluatedBackupArn', 'ExclusiveStartBackupArn', 'BackupType', {'USER', 'SYSTEM', 'AWS_BACKUP'}),
            'awsBackup': lambda: inventory(backup.list_recovery_points_by_resource, {'ResourceArn': arn, 'MaxResults': 100}, 'RecoveryPoints', 'NextToken', 'NextToken', 'Status', {'COMPLETED', 'DELETING', 'EXPIRED', 'PARTIAL', 'CREATING', 'STOPPED'}),
            'exports': lambda: inventory(ddb.list_exports, {'TableArn': arn, 'MaxResults': 25}, 'ExportSummaries', 'NextToken', 'NextToken', 'ExportStatus', {'IN_PROGRESS', 'COMPLETED', 'FAILED'}),
        }
        for name, op in operations.items():
            try:
                value = op()
                if name == 'pitr':
                    status = value['PointInTimeRecoveryStatus']
                    if status not in ('ENABLED', 'DISABLED'): raise ValueError('UNKNOWN_STATUS')
                    value = {'complete': True, 'status': status, 'recoveryPeriodDays': value.get('RecoveryPeriodInDays'),
                             'hasEarliestRestoreTime': bool(value.get('EarliestRestorableDateTime')), 'hasLatestRestoreTime': bool(value.get('LatestRestorableDateTime'))}
                elif name == 'ttl':
                    status = value['TimeToLiveStatus']
                    if status not in ('ENABLED', 'ENABLING', 'DISABLED', 'DISABLING'): raise ValueError('UNKNOWN_STATUS')
                    value = {'complete': True, 'status': status, 'expiresAtAttribute': value.get('AttributeName') == 'expiresAt'}
                entry['observations'][name] = value
                if not value['complete']: report['metadataComplete'] = False
            except Exception:
                entry['observations'][name] = {'complete': False, 'reason': 'OBSERVATION_UNAVAILABLE'}
                report['metadataComplete'] = False
        obs = entry['observations']
        if data_class == 'transient':
            entry['currentBackupPolicyMatches'] = (obs['pitr'].get('status') == 'DISABLED' and all(obs[x].get('complete') and obs[x].get('count') == 0 for x in ('nativeBackups', 'awsBackup', 'exports')))
    return report


def main():
    import boto3
    from botocore.config import Config
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', default='trustcheckradar'); parser.add_argument('--output', required=True)
    args = parser.parse_args()
    try:
        session = boto3.Session(profile_name=args.profile, region_name=REGION)
        cfg = Config(connect_timeout=5, read_timeout=10, retries={'total_max_attempts': 1})
        if session.client('sts', config=cfg).get_caller_identity()['Account'] != ACCOUNT:
            raise ValueError('ACCOUNT_MISMATCH')
        report = collect(session.client('dynamodb', config=cfg), session.client('backup', config=cfg))
        Path(args.output).write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
        print(json.dumps({'metadataComplete': report['metadataComplete'], 'tables': len(report['tables']), 'historicalCoverageVerified': False}))
        return 0 if report['metadataComplete'] else 2
    except Exception:
        print('{"metadataComplete":false,"reason":"AUDIT_UNAVAILABLE"}')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
