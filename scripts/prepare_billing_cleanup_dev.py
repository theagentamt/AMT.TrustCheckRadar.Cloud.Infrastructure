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
CODES = frozenset({
    'internal', 'boundary', 'selection_json', 'selection_shape', 'baseline_json',
    'baseline_validation', 'plan_complete', 'plan_version', 'plan_drift', 'plan_checks',
    'scope', 'activation_schema', 'activation_source', 'evidence', 'artifact_pin',
    'artifact_source', 'metadata_account', 'metadata_capture', 'union_validation', 'private_output',
})


class PlanningRejected(ValueError):
    """A fixed public category, never an input value or underlying exception."""
    def __init__(self, code):
        self.code = public_code(code)
        super().__init__(ERROR)


def public_code(code):
    return code if isinstance(code, str) and code in CODES else 'internal'


def require(condition, code='boundary'):
    if not condition:
        raise PlanningRejected(code)


def load(path):
    return json.loads(Path(path).read_text(), object_pairs_hook=unique_pairs)


def artifact():
    root = Path(__file__).resolve().parents[1]
    provenance = load(root / 'docs/evidence/sec332-deletion-packages.json')
    require(provenance['overrideSourceCommit'] == SOURCE, 'artifact_source')
    published = provenance['artifacts']['play_token_deletion']['publishedObject']
    return {key: published[key] for key in ('bucket', 'key', 'object_version', 'source_hash')}


def capture(read=aws):
    identity = read('sts', 'get-caller-identity')
    require(identity.get('Account') == prerequisite.ACCOUNT, 'metadata_account')
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
    require(plan.get('complete') is True and not plan.get('errored'), 'plan_complete')
    require(plan.get('terraform_version') == '1.12.1', 'plan_version')
    require(not plan.get('resource_drift'), 'plan_drift')
    require(all(check.get('status') == 'pass' for check in plan.get('checks', [])), 'plan_checks')
    values = {key: entry.get('value') for key, entry in plan['variables'].items()}
    require(values.get('environment') == 'dev' and values.get('aws_region') == prerequisite.REGION and
            values.get('project_name') == 'trustcheckradar' and values.get('enabled') is True, 'scope')
    activation = values.get('deletion_activation')
    require(type(activation) is dict and set(activation) == {
        'source_sha', 'subjects', 'inventory_reference', 'runtime_reference', 'permissions_reference'}, 'activation_schema')
    require(activation['source_sha'] == SOURCE, 'activation_source')
    require(all(isinstance(activation[key], str) and activation[key].strip() for key in
                ('inventory_reference', 'runtime_reference', 'permissions_reference')), 'evidence')
    pin = values.get('deletion_artifact_override') or {}
    require(pin.get('source_sha') == SOURCE and pin.get('artifact') == artifact(), 'artifact_pin')
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
    stage = 'selection_json'
    try:
        selected = json.loads(os.environ.get('BILLING_ENGINEERING_SUBJECTS_JSON') or '[]', object_pairs_hook=unique_pairs)
        stage = 'selection_shape'
        prerequisite.validate_subjects(selected, 1)
        stage = 'baseline_json'
        baseline = load(args.baseline_plan)
        stage = 'baseline_validation'
        variables(baseline)
        stage = 'metadata_capture'
        metadata = capture()
        stage = 'union_validation'
        result = build(baseline, selected, metadata)
        stage = 'private_output'
        root = Path(os.environ['RUNNER_TEMP'])
        write_private(root / 'billing-cleanup.tfvars.json', result)
        write_private(root / 'billing-cleanup-baseline.json', {'selected': selected, 'metadata': metadata})
        print('Private cleanup union prepared; no runtime change or behavioral qualification.')
    except Exception as error:
        code = error.code if isinstance(error, PlanningRejected) else stage
        raise SystemExit(public_code(code)) from None


if __name__ == '__main__':
    main()
