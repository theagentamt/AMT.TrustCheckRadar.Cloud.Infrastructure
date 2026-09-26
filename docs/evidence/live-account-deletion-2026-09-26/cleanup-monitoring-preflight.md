# Cleanup preactivation monitoring and invocation readiness

Observed 2026-09-26T15:10:59.879523+00:00. Read-only metadata; no notification, invoke, record read, marker or resource mutation. Six existing cleanup workers, five stream mappings, EventBridge rules and two Scheduler execution roles were inspected. This is preactivation configuration evidence, not proof of delivered mail or live handler processing.

Both exact topics have one confirmed email subscription to support@andmorethings.com and zero pending subscriptions for that address:
- trustcheckradar-dev-url-resolver-alerts
- trustcheckradar-dev-campaign-budget-alerts

Neither topic reports a KMS master key, so no topic-encryption grant is needed for this observed delivery path.

## Required changes before activation

1. **SNS publish authorization:** 19 of the 37 inspected alarms target a confirmed topic but their CloudWatch SourceArn is not allowed by its current policy. The URL-resolver topic exact allowlist lacks 13 account-data alarms and six Play cleanup alarms. The campaign topic already authorizes account-data, History and campaign prefixes. Either move account-data alarm actions to that existing allowed campaign topic, or explicitly extend the current URL topic allowlist. Add the six exact Play cleanup alarm ARNs before activating their worker; the existing play-notification flag only covers handoff errors/throttles. No successful notification delivery is inferred from a confirmed subscription alone.

2. **Campaign stream discovery:** campaign-deletion-bridge role ReadDeletionLedgerStream combines DescribeStream/GetRecords/GetShardIterator/ListStreams under the exact stream ARN. The first three match its actual mapping; ListStreams requires Resource `*`. Split only discovery to its own statement with aws:RequestedRegion=us-east-1, preserving exact-stream resources for the other actions. The other four stream workers already have that regional discovery split. No wider DynamoDB grants are needed by this finding.

## Dependencies already installed

- All five mappings use the same exact Dev deletion-ledger stream. They are Disabled at observation. All mapped roles permit the exact three stream-read actions. History lifecycle is schedule-only and does not need a stream grant.
- Account-data, History bridge, History lifecycle and V1 authority deletion have resource-based InvokeFunction grants bound to their exact EventBridge rule; authority permission is on its current live alias.
- Campaign recovery Scheduler and Play token cleanup Scheduler roles trust scheduler.amazonaws.com with exact SourceAccount and schedule-group ARN. Each allows InvokeFunction on its actual target (campaign unqualified worker; Play exact live alias). Neither has a permissions boundary. The Play worker execution-role deny on outbound lambda:InvokeFunction does not deny the separate Scheduler role invoking it.
- Current alarms retain the intended paused heartbeat/action state; activation must arm heartbeat/full-pass/recovery actions alongside the exact workers. History lifecycle and reconciliation alarms are created when lifecycle_active/account_deletion_active become true; the existing campaign topic prefix already covers their names. Confirm their creation in the root saved plan/readback.
- Campaign recovery heartbeat and Play deletion heartbeat currently show ALARM with actions disabled; this is compatible with paused workers. No state transition or test alert was requested here.

## Evidence

- `/tmp/amt-cleanup-monitoring-readiness.json`: subscriptions as counts, exact topic policies, 37 alarm configurations, worker hashes/gates, complete relevant role stream/invoke statements, function permission policies and schedule bindings.
- `/tmp/amt-cleanup-monitoring-checks.json`: explicit per-alarm SNS source authorization and per-mapping stream/action checks.
- Source locations: `terraform/url-resolver/operations.tf` exact alarm allowlist; `terraform/campaign-processing/main.tf` ReadDeletionLedgerStream; `terraform/history-processing/monitoring.tf` activation-created alarms.

No other invoke/stream dependency gap was found in this bounded metadata review. IAM conditions and service behavior were not exercised by live invocation; do not treat this as successful alert delivery. Root owns proposed changes and activation-plan verification.
