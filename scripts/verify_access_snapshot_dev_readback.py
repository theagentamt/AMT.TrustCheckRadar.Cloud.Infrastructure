#!/usr/bin/env python3
"""Read-only GET snapshot qualification and preservation of other live runtimes."""
import argparse
import json
import os
from pathlib import Path
from prepare_access_snapshot_dev import ACCOUNT, FUNCTION_NAME, require
from verify_access_snapshot_dev_plan import FUNCTION, environment
from verify_billing_dev_readback import snapshot
from verify_message_consumer_transition import aws


def verify_selected(plan, *, before=False, read=aws):
    require(read('sts','get-caller-identity').get('Account') == ACCOUNT, 'Only Dev readback permitted.')
    row=next(r for r in plan['resource_changes'] if r['address']==FUNCTION)
    expected=row['change']['before' if before else 'after']
    actual=read('lambda','get-function-configuration','--function-name',FUNCTION_NAME,'--qualifier','live')
    fields={'FunctionName':'function_name','CodeSha256':'source_code_hash','Role':'role','Handler':'handler',
        'Runtime':'runtime','Architectures':'architectures','Timeout':'timeout','MemorySize':'memory_size'}
    require(all(actual.get(k)==expected[v] for k,v in fields.items()) and actual.get('Environment',{}).get('Variables',{})==environment(expected), 'Selected runtime changed or does not match the reviewed plan.')
    require(actual.get('State')=='Active' and actual.get('LastUpdateStatus')=='Successful', 'Qualified runtime state required.')
    alias=read('lambda','get-alias','--function-name',FUNCTION_NAME,'--name','live')
    require(alias.get('FunctionVersion')==actual.get('Version') and not alias.get('RoutingConfig',{}).get('AdditionalVersionWeights'), 'Unweighted qualified alias required.')
    if before:
        require(alias.get('FunctionVersion')==expected.get('version'), 'Previous live version changed since plan.')
    require(read('lambda','get-function-concurrency','--function-name',FUNCTION_NAME).get('ReservedConcurrentExecutions')==2, 'Existing concurrency must remain fixed.')
    return {'snapshotConfigurationVerified':True,'behavioralQualification':False}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot',type=Path,required=True);parser.add_argument('--plan',type=Path)
    parser.add_argument('--pre-apply',action='store_true');args=parser.parse_args()
    try:
        current=snapshot('access-snapshot')
        if args.plan is None:
            descriptor=os.open(args.snapshot,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
            with os.fdopen(descriptor,'w') as stream:json.dump(current,stream,sort_keys=True)
            print('Protected Dev live-runtime baseline captured; no account data read.')
        else:
            require(current==json.loads(args.snapshot.read_text()), 'A protected Dev live runtime changed; do not apply or claim preservation.')
            result=verify_selected(json.loads(args.plan.read_text()),before=args.pre_apply)
            result['protectedRuntimeCount']=len(current)
            result['phase']='pre-apply' if args.pre_apply else 'post-apply'
            print(json.dumps(result))
    except Exception:
        raise SystemExit('Snapshot readback rejected; private metadata was not printed.') from None


if __name__=='__main__':main()
