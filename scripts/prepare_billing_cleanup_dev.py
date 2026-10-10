#!/usr/bin/env python3
"""Prepare a private cleanup-only Dev plan input; never activate a runtime."""
import argparse
import copy
import json
import os
from pathlib import Path

import verify_billing_cleanup_prerequisite as prerequisite
from prepare_access_snapshot_dev import unique_pairs
from verify_message_consumer_transition import aws

SOURCE = '9123459a5c2bc9503d56235b2cb1f1e162c00da1'
ERROR = 'Billing cleanup planning rejected; private configuration was not printed.'


def require(condition):
    if not condition:
        raise ValueError(ERROR)


def load(path):
    return json.loads(Path(path).read_text(), object_pairs_hook=unique_pairs)


def artifact():
    root = Path(__file__).resolve().parents[1]
    provenance = load(root / 'docs/evidence/sec332-deletion-packages.json')
    require(provenance['overrideSourceCommit'] == SOURCE)
    published = provenance['artifacts']['play_token_deletion']['publishedObject']
    return {key: published[key] for key in ('bucket', 'key', 'object_version', 'source_hash')}


def capture(read=aws):
    identity = read('sts', 'get-caller-identity')
    require(identity.get('Account') == prerequisite.ACCOUNT)
    return {
        'identity': identity,
        'function': read('lambda', 'get-function-configuration', '--function-name', prerequisite.FUNCTION, '--qualifier', 'live'),
        'alias': read('lambda', 'get-alias', '--function-name', prerequisite.FUNCTION, '--name', 'live'),
        'concurrency': read('lambda', 'get-function-concurrency', '--function-name', prerequisite.FUNCTION),
        'schedule': read('scheduler', 'get-schedule', '--name', prerequisite.FUNCTION, '--group-name', prerequisite.GROUP),
        'mappings': read('lambda', 'list-event-source-mappings', '--function-name', prerequisite.ALIAS),
    }


def admitted(metadata):
    result = json.loads(metadata['function']['Environment']['Variables']['DEV_SUBJECT_ALLOWLIST_JSON'], object_pairs_hook=unique_pairs)
    prerequisite.validate_subjects(result, 10)
    return result


def variables(plan):
    require(plan.get('complete') is True and not plan.get('errored') and plan.get('terraform_version') == '1.12.1')
    require(not plan.get('resource_drift'))
    require(all(check.get('status') == 'pass' for check in plan.get('checks', [])))
    values = {key: entry.get('value') for key, entry in plan['variables'].items()}
    require(values.get('environment') == 'dev' and values.get('aws_region') == prerequisite.REGION and
            values.get('project_name') == 'trustcheckradar' and values.get('enabled') is True)
    activation = values.get('deletion_activation')
    require(type(activation) is dict and set(activation) == {
        'source_sha', 'subjects', 'inventory_reference', 'runtime_reference', 'permissions_reference'})
    require(activation['source_sha'] == SOURCE)
    require(all(isinstance(activation[key], str) and activation[key].strip() for key in
                ('inventory_reference', 'runtime_reference', 'permissions_reference')))
    pin = values.get('deletion_artifact_override') or {}
    require(pin.get('source_sha') == SOURCE and pin.get('artifact') == artifact())
    return values


def build(baseline, selected, metadata):
    """Preserve all currently admitted subjects, including additions absent from source."""
    prerequisite.validate_subjects(selected, 1)
    previous = admitted(metadata)
    prerequisite.verify_metadata([previous[0]], metadata, artifact()['source_hash'])
    activation = copy.deepcopy(variables(baseline)['deletion_activation'])
    activation['subjects'] = sorted(set(previous) | set(selected))
    prerequisite.validate_subjects(activation['subjects'], 10)
    return {'deletion_activation': activation}


def write_private(path, data):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        json.dump(data, stream, sort_keys=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-plan', type=Path, required=True)
    args = parser.parse_args()
    try:
        selected = json.loads(os.environ.get('BILLING_ENGINEERING_SUBJECTS_JSON') or '[]', object_pairs_hook=unique_pairs)
        prerequisite.validate_subjects(selected, 1)
        baseline = load(args.baseline_plan)
        variables(baseline)
        metadata = capture()
        result = build(baseline, selected, metadata)
        root = Path(os.environ['RUNNER_TEMP'])
        write_private(root / 'billing-cleanup.tfvars.json', result)
        write_private(root / 'billing-cleanup-baseline.json', {'selected': selected, 'metadata': metadata})
        print('Private cleanup union prepared; no runtime change or behavioral qualification.')
    except Exception:
        raise SystemExit(ERROR) from None


if __name__ == '__main__':
    main()
