#!/usr/bin/env python3
"""Read-only full base-table key metadata traversal; no erasure approval."""
import argparse
from datetime import datetime, timezone
from decimal import Decimal
import json
from pathlib import Path
import re
import time

ACCOUNT='107827791950'
REGION='us-east-1'
TABLES=tuple('trustcheckradar-dev-campaign-'+x for x in ('pipeline','outbox','intelligence'))
FIELDS=('PK','SK','periodId','recordType','schemaVersion','environment','status','keyArn','retireAfterEpoch','retiredAtEpoch')
PERIOD=1209600
KEY=re.compile(r'arn:aws:kms:us-east-1:107827791950:key/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}')


def integer(value):
    return type(value) in (int,Decimal) and value == int(value) and 0 <= value <= 10**12


def classify(table,row,target):
    if not isinstance(row,dict) or not set(row)<=set(FIELDS):return 'unknown'
    if table.endswith('-pipeline'):
        pk=row.get('PK');sk=row.get('SK')
        if isinstance(pk,str) and re.fullmatch(r'PERIOD#(0|[1-9][0-9]{0,6})',pk) and sk=='HMAC_KEY':
            period=int(pk.split('#')[1])
            if not integer(row.get('periodId')) or row['periodId']!=period:return 'unknown'
            if row.get('status') not in ('ENABLED','RETIRED') or not isinstance(row.get('keyArn'),str) or not KEY.fullmatch(row['keyArn']):return 'unknown'
            if row.get('retireAfterEpoch')!=(period+1)*PERIOD+604800:return 'unknown'
            if row.get('status')=='RETIRED' and (not integer(row.get('retiredAtEpoch')) or row['retiredAtEpoch']<row['retireAfterEpoch']):return 'unknown'
            if row.get('status')=='ENABLED' and 'retiredAtEpoch' in row:return 'unknown'
            if any(k in row for k in ('recordType','schemaVersion','environment')):return 'unknown'
            return 'targetPeriodRegistry' if period==target else 'otherPeriodRegistry'
        if pk=='INVENTORY#dev' and sk=='CAMPAIGN_LOCATORS':
            if row.get('recordType')=='CAMPAIGN_LOCATOR_INVENTORY' and type(row.get('schemaVersion')) in (int,Decimal) and row['schemaVersion']==1 and row.get('environment')=='dev':
                return 'locatorInventoryKey'
            return 'unknown'
    # Deliberately conservative: every data, protective, legacy or unknown key
    # outside these exact metadata families blocks the empty-live-surface claim.
    return 'nonControlOrUnknown'


def collect(ddb, *, target=1478,max_pages=10,page_size=100,seconds=60,clock=time.monotonic):
    from boto3.dynamodb.types import TypeDeserializer
    if target!=1478 or not 1<=max_pages<=10 or not 1<=page_size<=100 or not 1<=seconds<=60:raise ValueError('INVALID_BOUND')
    deadline=clock()+seconds;decode=TypeDeserializer()
    r={'schemaVersion':1,'observedAtUtc':datetime.now(timezone.utc).isoformat(),'accountId':ACCOUNT,'region':REGION,'targetPeriod':target,'tables':{},'allTraversalsComplete':True,'onlyRecognizedControlKeysObserved':False,'erasureVerified':False,'inventoryApproved':False,'bounds':{'maxPagesPerTable':max_pages,'pageSize':page_size,'callStartSeconds':seconds},'limitations':['Full strongly consistent base-table scans are separate observations, not one snapshot or a range lock.','Physically present expired data and tombstones are blockers; TTL/age is not erasure.','Projection classifies keys and selected metadata, not unprojected attributes or all record schemas.','Non-control rows are conservatively unassigned blockers, including every legacy/unknown key family.','No source content, tokens, keys or pagination values are retained; key ARNs are used in memory only.','Current live-table observations do not prove historical erasure, writer/restore safety, or inventory approval.']}
    def call(fn,**kw):
        if clock()>=deadline:raise TimeoutError('TIME_BOUND')
        return fn(**kw)
    for table in TABLES:
        counts={k:0 for k in ('targetPeriodRegistry','otherPeriodRegistry','locatorInventoryKey','nonControlOrUnknown','unknown')}
        entry={'pages':0,'rows':0,'complete':False,'categories':counts};r['tables'][table]=entry
        try:
            meta=call(ddb.describe_table,TableName=table)['Table']
            if meta['TableArn']!=f'arn:aws:dynamodb:{REGION}:{ACCOUNT}:table/{table}':raise ValueError('WRONG_TABLE')
            cursor=None
            for _ in range(max_pages):
                names={f'#f{i}':name for i,name in enumerate(FIELDS)}
                page=call(ddb.scan,TableName=table,ConsistentRead=True,Select='SPECIFIC_ATTRIBUTES',Limit=page_size,ProjectionExpression=','.join(names),ExpressionAttributeNames=names,**({'ExclusiveStartKey':cursor} if cursor else {}))
                rows=page['Items']
                if not isinstance(rows,list) or type(page.get('Count')) is not int or page['Count']!=len(rows):raise ValueError('INVALID_RESPONSE')
                entry['pages']+=1;entry['rows']+=len(rows)
                for raw in rows:
                    try:category=classify(table,{k:decode.deserialize(v) for k,v in raw.items()},target)
                    except Exception:category='unknown'
                    counts[category]+=1
                cursor=page.get('LastEvaluatedKey')
                if not cursor:entry['complete']=True;break
        except Exception:entry['reason']='OBSERVATION_UNAVAILABLE'
        if not entry['complete']:r['allTraversalsComplete']=False
    r['onlyRecognizedControlKeysObserved']=r['allTraversalsComplete'] and all(e['categories']['unknown']==0 and e['categories']['nonControlOrUnknown']==0 for e in r['tables'].values())
    return r


def main():
    import boto3
    from botocore.config import Config
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--profile',default='trustcheckradar');parser.add_argument('--output',required=True);args=parser.parse_args()
    try:
        s=boto3.Session(profile_name=args.profile,region_name=REGION);c=Config(connect_timeout=5,read_timeout=10,retries={'total_max_attempts':1})
        if s.client('sts',config=c).get_caller_identity()['Account']!=ACCOUNT:raise ValueError('WRONG_ACCOUNT')
        r=collect(s.client('dynamodb',config=c));Path(args.output).write_text(json.dumps(r,indent=2)+'\n')
        print(json.dumps({'allTraversalsComplete':r['allTraversalsComplete'],'onlyRecognizedControlKeysObserved':r['onlyRecognizedControlKeysObserved'],'erasureVerified':False}));return 0 if r['allTraversalsComplete'] else 2
    except Exception:print('{"allTraversalsComplete":false,"reason":"AUDIT_UNAVAILABLE"}');return 1

if __name__=='__main__':raise SystemExit(main())
