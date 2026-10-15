#!/usr/bin/env python3
"""Prevent ordinary foundation deployments from changing the governed History index."""
import argparse
import json
from pathlib import Path


def review(plan):
    if plan.get('complete') is not True or plan.get('errored'):
        raise ValueError('Foundation plan is incomplete or failed.')
    for item in plan.get('resource_changes', []):
        if item.get('address') != 'aws_dynamodb_table.purchase_entitlements' or item.get('mode') != 'managed':
            continue
        change = item['change']
        def governed(value):
            value = value or {}
            return {'index': [v for v in value.get('global_secondary_index', []) if v.get('name') == 'GSI2'], 'attributes': sorted([v for v in value.get('attribute', []) if v.get('name') in {'GSI2PK', 'GSI2SK'}], key=lambda v: v['name'])}
        before, after = governed(change.get('before')), governed(change.get('after'))
        if before != after or change.get('actions') in (['delete', 'create'], ['create', 'delete']) and before['index']:
            raise ValueError('GSI2 changes require the separately reviewed governed History workflow; ordinary deployment refused.')
    return {'governedHistoryIndexTransition': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(review(json.loads(args.plan.read_text()))))
    except (ValueError, KeyError, TypeError, OSError) as exc:
        raise SystemExit(f'Ordinary foundation deployment rejected: {exc}')
