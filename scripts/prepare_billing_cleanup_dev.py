#!/usr/bin/env python3
"""Prepare a private cleanup-only Dev plan input; never activate a runtime."""
import argparse
import copy
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID

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
MAPPING_ADDRESS = 'aws_lambda_event_source_mapping.deletion[0]'
MAPPING_PROVIDER = 'registry.terraform.io/hashicorp/aws'


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


def has_unknown(value):
    if isinstance(value, dict):
        return any(has_unknown(child) for child in value.values())
    if isinstance(value, list):
        return any(has_unknown(child) for child in value)
    return value is True


def timestamp(value):
    require(isinstance(value, str) and re.fullmatch(
        r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})', value), 'plan_drift')
    return datetime.fromisoformat(value.replace('Z', '+00:00')).astimezone(timezone.utc)


def empty_configuration(value):
    if isinstance(value, dict):
        return all(empty_configuration(child) for child in value.values())
    if isinstance(value, list):
        return all(empty_configuration(child) for child in value)
    return value is None


def mapping_drift_structure(plan):
    """Qualify only the proposed timestamp shape; fresh AWS proof is still required."""
    try:
        drift = plan.get('resource_drift')
        require(type(drift) is list and len(drift) == 1, 'plan_drift')
        row = drift[0]
        require(row.get('address') == MAPPING_ADDRESS and row.get('mode') == 'managed' and
                row.get('type') == 'aws_lambda_event_source_mapping' and
                row.get('provider_name') == MAPPING_PROVIDER, 'plan_drift')
        change = row['change']
        require(change['actions'] == ['update'] and not has_unknown(change.get('before_unknown', {})) and
                not has_unknown(change.get('after_unknown', {})), 'plan_drift')
        before, after = change['before'], change['after']
        require(type(before) is dict and type(after) is dict and set(before) == set(after), 'plan_drift')
        require({key for key in before if before[key] != after[key]} == {'last_modified'}, 'plan_drift')
        require(timestamp(before['last_modified']) != timestamp(after['last_modified']), 'plan_drift')
        rows = [entry for entry in plan['resource_changes'] if entry.get('address') == MAPPING_ADDRESS]
        require(len(rows) == 1, 'plan_drift')
        counterpart = rows[0]
        require(all(counterpart.get(key) == row.get(key) for key in ('mode', 'type', 'provider_name')), 'plan_drift')
        planned = counterpart['change']
        require(planned['actions'] == ['no-op'] and planned['before'] == planned['after'] == after and
                not has_unknown(planned.get('before_unknown', {})) and
                not has_unknown(planned.get('after_unknown', {})), 'plan_drift')
        configs = [entry for entry in plan['configuration']['root_module']['resources']
                   if entry.get('address') == 'aws_lambda_event_source_mapping.deletion']
        require(len(configs) == 1, 'plan_drift')
        expressions = configs[0]['expressions']
        require('last_modified' not in expressions, 'plan_drift')
        allowed_references = {
            'event_source_arn': {'var.deployment.deletion_stream_arn', 'var.deployment'},
            'function_name': {'aws_lambda_alias.runtime["deletion"].arn',
                              'aws_lambda_alias.runtime["deletion"]', 'aws_lambda_alias.runtime'},
        }
        for field, allowed in allowed_references.items():
            expression = expressions[field]
            refs = expression.get('references')
            required = 'var.deployment.deletion_stream_arn' if field == 'event_source_arn' else 'aws_lambda_alias.runtime["deletion"].arn'
            require(set(expression) == {'references'} and type(refs) is list and required in refs and
                    len(refs) == len(set(refs)) and set(refs) <= allowed, 'plan_drift')
        return after
    except Exception:
        raise PlanningRejected('plan_drift') from None


def qualify_mapping_drift(plan, metadata):
    """A single computed timestamp refresh is admitted only with matching live metadata."""
    try:
        after = mapping_drift_structure(plan)
        require(type(metadata) is dict and metadata['identity'].get('Account') == prerequisite.ACCOUNT, 'plan_drift')
        mappings = metadata['mappings']['EventSourceMappings']
        require(type(mappings) is list and len(mappings) == 1, 'plan_drift')
        live = mappings[0]
        identifier = after['uuid']
        require(isinstance(identifier, str) and str(UUID(identifier)) == identifier and
                after.get('id') == identifier == live.get('UUID'), 'plan_drift')
        mapping_arn = f'arn:aws:lambda:{prerequisite.REGION}:{prerequisite.ACCOUNT}:event-source-mapping:{identifier}'
        require(after.get('arn') == mapping_arn == live.get('EventSourceMappingArn'), 'plan_drift')
        stream = metadata['function']['Environment']['Variables']['DELETION_LEDGER_STREAM_ARN']
        declared_stream = plan['variables']['deployment']['value']['deletion_stream_arn']
        require(isinstance(stream, str) and re.fullmatch(
            rf'arn:aws:dynamodb:{prerequisite.REGION}:{prerequisite.ACCOUNT}:table/{prerequisite.PREFIX}-deletion-ledger/stream/[0-9T:.\-]+', stream) and
                declared_stream == stream, 'plan_drift')
        require(after.get('function_arn') == after.get('function_name') == live.get('FunctionArn') == prerequisite.ALIAS and
                after.get('event_source_arn') == live.get('EventSourceArn') == stream, 'plan_drift')
        require(timestamp(after['last_modified']) == timestamp(live['LastModified']), 'plan_drift')
        require(after.get('enabled') is True and after.get('state') == live.get('State') == 'Enabled', 'plan_drift')
        fields = {'batch_size': 'BatchSize', 'maximum_batching_window_in_seconds': 'MaximumBatchingWindowInSeconds',
                  'parallelization_factor': 'ParallelizationFactor', 'maximum_retry_attempts': 'MaximumRetryAttempts',
                  'maximum_record_age_in_seconds': 'MaximumRecordAgeInSeconds',
                  'bisect_batch_on_function_error': 'BisectBatchOnFunctionError',
                  'tumbling_window_in_seconds': 'TumblingWindowInSeconds', 'function_response_types': 'FunctionResponseTypes'}
        require(all(key in after and value in live and after[key] == live[value] for key, value in fields.items()), 'plan_drift')
        require(after.get('starting_position') == 'TRIM_HORIZON' and
                live.get('StartingPosition') == 'TRIM_HORIZON', 'plan_drift')
        absent_configuration = {
            'destination_config': 'DestinationConfig', 'source_access_configuration': 'SourceAccessConfigurations',
            'self_managed_event_source': 'SelfManagedEventSource', 'topics': 'Topics', 'queues': 'Queues',
            'amazon_managed_kafka_event_source_config': 'AmazonManagedKafkaEventSourceConfig',
            'self_managed_kafka_event_source_config': 'SelfManagedKafkaEventSourceConfig',
            'scaling_config': 'ScalingConfig', 'document_db_event_source_config': 'DocumentDBEventSourceConfig',
            'metrics_config': 'MetricsConfig', 'provisioned_poller_config': 'ProvisionedPollerConfig',
        }
        require(all(empty_configuration(after.get(key)) and empty_configuration(live.get(value))
                    for key, value in absent_configuration.items()), 'plan_drift')
        # The provider represents these two absent optional strings as "".
        # AWS must omit both; no other optional value receives this normalization.
        require(all(after.get(key) in (None, '') and value not in live for key, value in {
            'kms_key_arn': 'KMSKeyArn', 'starting_position_timestamp': 'StartingPositionTimestamp'}.items()), 'plan_drift')
        require(empty_configuration(live.get('FilterCriteriaError')), 'plan_drift')
        filters = after.get('filter_criteria')
        live_filters = live.get('FilterCriteria', {}).get('Filters')
        require(type(filters) is list and len(filters) == 1 and set(filters[0]) == {'filter'} and
                type(live_filters) is list and len(live_filters) == 1, 'plan_drift')
        actual_filters = filters[0]['filter']
        require(type(actual_filters) is list and len(actual_filters) == 1 and set(actual_filters[0]) == {'pattern'} and
                set(live_filters[0]) == {'Pattern'}, 'plan_drift')
        require(json.loads(actual_filters[0]['pattern'], object_pairs_hook=unique_pairs) ==
                json.loads(live_filters[0]['Pattern'], object_pairs_hook=unique_pairs), 'plan_drift')
    except Exception:
        raise PlanningRejected('plan_drift') from None


def baseline_variables(plan):
    """Pure input checks run before any metadata discovery; this does not admit drift."""
    require(plan.get('complete') is True and not plan.get('errored'), 'plan_complete')
    require(plan.get('terraform_version') == '1.12.1', 'plan_version')
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


def variables(plan, metadata=None):
    values = baseline_variables(plan)
    if plan.get('resource_drift'):
        qualify_mapping_drift(plan, metadata)
    return values


def build(baseline, selected, metadata):
    """Preserve all currently admitted subjects, including additions absent from source."""
    prerequisite.validate_subjects(selected, 1)
    previous = admitted(metadata)
    prerequisite.verify_metadata([previous[0]], metadata, artifact()['source_hash'])
    activation = copy.deepcopy(variables(baseline, metadata)['deletion_activation'])
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
        baseline_variables(baseline)
        if baseline.get('resource_drift'):
            mapping_drift_structure(baseline)
        stage = 'metadata_capture'
        metadata = capture()
        stage = 'baseline_validation'
        variables(baseline, metadata)
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
