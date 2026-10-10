#!/usr/bin/env python3
"""Reviewed metadata-only Dev billing audit permission, installed only by CI/CD."""
import argparse
import hashlib
import json
import subprocess

from prepare_billing_dev_configuration import ACCOUNT, require
from verify_message_consumer_transition import aws

ROLE = 'trustcheckradar-dev-github-deploy'
NAME = 'read-dev-billing-backup-inventory'
GROUP = 'trustcheckradar-dev-play-lifecycle'
SCHEDULES = ('trustcheckradar-dev-play-token-deletion', 'trustcheckradar-dev-play-lifecycle-worker')


def document():
    return {'Version': '2012-10-17', 'Statement': [
        {'Sid': 'ReadBillingBackupInventory', 'Effect': 'Allow',
         'Action': ['backup:ListRecoveryPointsByResource', 'backup:ListBackupPlans', 'backup:ListBackupSelections', 'backup:GetBackupSelection'],
         'Resource': '*', 'Condition': {'StringEquals': {'aws:RequestedRegion': 'us-east-1'}}},
        {'Sid': 'ReadBackupExecutionRoleTrust', 'Effect': 'Allow', 'Action': 'iam:ListRoles', 'Resource': '*'},
        {'Sid': 'ReadBillingLifecycleSchedules', 'Effect': 'Allow', 'Action': 'scheduler:GetSchedule',
         'Resource': [
             f'arn:aws:scheduler:us-east-1:{ACCOUNT}:schedule/trustcheckradar-dev-play-lifecycle/trustcheckradar-dev-play-token-deletion',
             f'arn:aws:scheduler:us-east-1:{ACCOUNT}:schedule/trustcheckradar-dev-play-lifecycle/trustcheckradar-dev-play-lifecycle-worker',
         ], 'Condition': {'StringEquals': {'aws:RequestedRegion': 'us-east-1'}}},
        {'Sid': 'ReadBillingLifecycleScheduleGroup', 'Effect': 'Allow',
         'Action': ['scheduler:GetScheduleGroup', 'scheduler:ListTagsForResource'],
         'Resource': f'arn:aws:scheduler:us-east-1:{ACCOUNT}:schedule-group/trustcheckradar-dev-play-lifecycle',
         'Condition': {'StringEquals': {'aws:RequestedRegion': 'us-east-1'}}},
    ]}


def digest(revision):
    return hashlib.sha256(json.dumps({'revision': revision, 'role': ROLE, 'policy': document()}, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def qualify(identity):
    require(identity.get('Arn', '').startswith(f'arn:aws:sts::{ACCOUNT}:assumed-role/{ROLE}/'),
            'Actual Dev deployment role required for qualification.')
    require(aws('iam', 'get-role-policy', '--role-name', ROLE, '--policy-name', NAME).get('PolicyDocument') == document(),
            'Installed audit policy differs from reviewed source.')
    states = {}
    for name in SCHEDULES:
        schedule = aws('scheduler', 'get-schedule', '--name', name, '--group-name', GROUP)
        require(schedule.get('Arn') == f'arn:aws:scheduler:us-east-1:{ACCOUNT}:schedule/{GROUP}/{name}'
                and schedule.get('Name') == name and schedule.get('GroupName') == GROUP
                and schedule.get('State') in ('ENABLED', 'DISABLED'), 'Exact Dev schedule metadata required.')
        states[name] = schedule['State']
    group_arn = f'arn:aws:scheduler:us-east-1:{ACCOUNT}:schedule-group/{GROUP}'
    group = aws('scheduler', 'get-schedule-group', '--name', GROUP)
    require(group.get('Arn') == group_arn and group.get('Name') == GROUP and group.get('State') == 'ACTIVE',
            'Exact active Dev schedule group required.')
    tags = aws('scheduler', 'list-tags-for-resource', '--resource-arn', group_arn).get('Tags')
    require(type(tags) is list and all(type(tag) is dict and type(tag.get('Key')) is str
                                     and type(tag.get('Value')) is str for tag in tags), 'Schedule group tag read required.')
    return {'actualDeploymentRoleReadsVerified': True, 'schedulerMetadataReadCount': 4,
            'observedScheduleStates': states, 'scheduleGroupState': group['State'], 'scheduleGroupTagCount': len(tags)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--revision', required=True); parser.add_argument('--mode', choices=['plan', 'apply', 'qualify'], required=True)
    parser.add_argument('--expected-digest'); args = parser.parse_args()
    try:
        import re
        require(re.fullmatch(r'[a-f0-9]{40}', args.revision), 'Exact reviewed source required.')
        head = subprocess.run(['git', 'rev-parse', 'HEAD'], check=True, capture_output=True, text=True).stdout.strip()
        require(head == args.revision, 'Source changed since review.')
        identity = aws('sts', 'get-caller-identity')
        require(identity.get('Account') == ACCOUNT, 'Dev account required.')
        review_digest = digest(args.revision)
        if args.mode in ('apply', 'qualify'):
            require(args.expected_digest == review_digest, 'Exact reviewed metadata policy digest required.')
        if args.mode == 'apply':
            subprocess.run(['aws', 'iam', 'put-role-policy', '--role-name', ROLE, '--policy-name', NAME,
                            '--policy-document', json.dumps(document()), '--region', 'us-east-1'],
                           check=True, capture_output=True, text=True)
            require(aws('iam', 'get-role-policy', '--role-name', ROLE, '--policy-name', NAME).get('PolicyDocument') == document(), 'Installed audit policy readback mismatch.')
        qualification = qualify(identity) if args.mode == 'qualify' else {}
        print(json.dumps({'revision': args.revision, 'role': ROLE, 'policyName': NAME, 'mode': args.mode, 'reviewedPolicyDigest': review_digest, 'metadataOnly': True, 'runtimeActivation': False, **qualification}))
    except Exception:
        raise SystemExit('Billing audit-access transition rejected; private AWS output was not printed.') from None


if __name__ == '__main__':
    main()
