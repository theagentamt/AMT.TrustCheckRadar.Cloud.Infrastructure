mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  aws_region                  = "us-east-1"
  project_name                = "trustcheckradar"
  environment                 = "dev"
  state_bucket_name           = "synthetic-state"
  state_bucket_region         = "us-east-1"
  campaign_processing_enabled = true
  kill_switch_enabled         = true
  artifact_release            = "existing-release"
  log_retention_days          = 14
  account_privacy_artifacts = {
    release_id         = "privacy-candidate"
    approval_reference = "synthetic-test-not-user-approval"
    promotion_approved = false
    workers = {
      publisher = { object_version = "publisher-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      cluster   = { object_version = "cluster-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      deletion  = { object_version = "deletion-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      lifecycle = { object_version = "lifecycle-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
    }
  }
}
override_data {
  target = data.terraform_remote_state.foundation
  values = {
    outputs = {
      downstream_contract = {
        schema_version             = 1
        artifact_bucket_name       = "artifact-example"
        deletion_ledger_stream_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/1"
        deletion_ledger_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
        deletion_ledger_table_name = "trustcheckradar-dev-deletion-ledger"
        users_table_arn            = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
        users_table_name           = "trustcheckradar-dev-users"
      }
    }
  }
}
override_data {
  target = data.terraform_remote_state.campaign_data[0]
  values = {
    outputs = {
      downstream_contract = {
        schema_version          = 1
        environment             = "dev"
        enabled                 = true
        outbox_table_name       = "trustcheckradar-dev-campaign-outbox"
        outbox_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox"
        outbox_stream_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox/stream/1"
        pipeline_table_name     = "trustcheckradar-dev-campaign-pipeline"
        pipeline_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-pipeline"
        expiration_index_name   = "ExpirationIndex"
        intelligence_table_name = "trustcheckradar-dev-campaign-intelligence"
        intelligence_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-intelligence"
        cluster_queue_url       = "https://sqs.us-east-1.amazonaws.com/107827791950/campaign-cluster"
        cluster_queue_arn       = "arn:aws:sqs:us-east-1:107827791950:campaign-cluster"
        cluster_dlq_arn         = "arn:aws:sqs:us-east-1:107827791950:campaign-cluster-dlq"
        transient_kms_key_arn   = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111"
        persistent_kms_key_arn  = "arn:aws:kms:us-east-1:107827791950:key/22222222-2222-2222-2222-222222222222"
        budget_alert_topic_arn  = "arn:aws:sns:us-east-1:107827791950:campaign-alerts"
      }
    }
  }
}

run "privacy_bundle_is_immutable_and_inactive" {
  command = plan
  assert {
    condition = (
      alltrue([for name, worker in aws_lambda_function.worker :
        worker.runtime == "python3.14" && worker.architectures == tolist(["arm64"]) &&
        worker.environment[0].variables["CAMPAIGN_LOCATOR_MANIFEST_SHA256"] == "" &&
        worker.environment[0].variables["CAMPAIGN_LOCATOR_INVENTORY_REVISION"] == "0" &&
        worker.s3_key == "releases/privacy-candidate/${local.functions[name].artifact}" &&
        worker.s3_object_version == "${name}-version" &&
        worker.source_code_hash == var.account_privacy_artifacts.workers[name].source_hash
      ]) &&
      aws_lambda_function.worker["publisher"].environment[0].variables["DELETION_LEDGER_TABLE_NAME"] == "trustcheckradar-dev-deletion-ledger" &&
      aws_lambda_function.worker["lifecycle"].environment[0].variables["CAMPAIGN_LIFECYCLE_CANDIDATE_ENABLED"] == "false" &&
      !local.active && !aws_lambda_event_source_mapping.publisher[0].enabled &&
      !aws_lambda_event_source_mapping.cluster[0].enabled && !aws_lambda_event_source_mapping.deletion[0].enabled &&
      alltrue([for schedule in aws_scheduler_schedule.lifecycle : schedule.state == "DISABLED"])
    )
    error_message = "All four privacy workers must be pinned on Python 3.14 without active event sources or schedules."
  }
}
run "cleanup_writes_are_transaction_scoped_and_cannot_complete" {
  command = plan
  assert {
    condition = (
      one([for s in data.aws_iam_policy_document.deletion_runtime[0].statement : s if s.sid == "CompleteDeletionLedgerCommand"]).actions == toset(["dynamodb:GetItem"]) &&
      one([for s in data.aws_iam_policy_document.deletion_runtime[0].statement : s if s.sid == "CompleteParticipationWithdrawal"]).actions == toset(["dynamodb:GetItem"]) &&
      one([for s in data.aws_iam_policy_document.deletion_runtime[0].statement : s if s.sid == "DeleteActiveContributions"]).actions == toset(["dynamodb:GetItem", "dynamodb:Query"]) &&
      alltrue([for sid in ["GuardedRepairWrites", "GuardedDeletionCommand"] :
        anytrue([for c in one([for s in data.aws_iam_policy_document.deletion_runtime[0].statement : s if s.sid == sid]).condition :
          c.variable == "dynamodb:EnclosingOperation" && c.test == "StringEquals" && toset(c.values) == toset(["TransactWriteItems"])
        ])
      ]) &&
      one([for s in data.aws_iam_policy_document.deletion_runtime[0].statement : s if s.sid == "GuardedDeletionCommand"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"]) &&
      alltrue([for policy in [data.aws_iam_policy_document.publisher_runtime[0], data.aws_iam_policy_document.cluster_runtime[0]] :
        anytrue([for c in one([for s in policy.statement : s if s.sid == "CheckContributorTombstoneTransaction"]).condition :
          c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(["CONTRIB#*"])
        ])
      ])
    )
    error_message = "Producer tombstones and cleanup command guards must be transaction-scoped, and the candidate must not write completion states."
  }
}
run "privacy_bundle_preserves_default_workers" {
  command = plan
  variables { account_privacy_artifacts = null }
  assert {
    condition = (
      alltrue([for name, worker in aws_lambda_function.worker : worker.runtime == "python3.13" && worker.s3_key == "releases/existing-release/${local.functions[name].artifact}"]) &&
      alltrue([for policy in [data.aws_iam_policy_document.publisher_runtime[0], data.aws_iam_policy_document.cluster_runtime[0], data.aws_iam_policy_document.deletion_runtime[0]] :
        alltrue([for s in policy.statement : !contains(["CheckContributorTombstoneTransaction", "GuardedRepairWrites", "GuardedDeletionCommand"], s.sid)])
      ])
    )
    error_message = "Null privacy candidates must preserve existing packages, runtimes and IAM."
  }
}
run "privacy_bundle_rejects_active_consumers" {
  command = plan
  variables {
    kill_switch_enabled = false
    activation_approved = true
  }
  expect_failures = [var.account_privacy_artifacts]
}
run "privacy_bundle_rejects_conflicting_publisher" {
  command = plan
  variables {
    publisher_fence_artifact = {
      release_id         = "other", object_version = "other", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic", promotion_approved = false
    }
  }
  expect_failures = [var.account_privacy_artifacts]
}

run "privacy_bundle_rejects_foreign_account_resources" {
  command = plan
  override_data {
    target = data.aws_caller_identity.current
    values = { account_id = "999999999999" }
  }
  expect_failures = [aws_lambda_function.worker]
}

run "privacy_bundle_rejects_missing_worker_pin" {
  command = plan
  variables {
    account_privacy_artifacts = {
      release_id         = "privacy-candidate"
      approval_reference = "synthetic-test-not-user-approval"
      promotion_approved = false
      workers = {
        publisher = { object_version = "v", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        cluster   = { object_version = "v", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        deletion  = { object_version = "v", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      }
    }
  }
  expect_failures = [var.account_privacy_artifacts]
}

run "workers_cannot_approve_locator_inventory" {
  command = plan
  assert {
    condition = alltrue([for policy in [data.aws_iam_policy_document.publisher_runtime[0], data.aws_iam_policy_document.cluster_runtime[0], data.aws_iam_policy_document.deletion_runtime[0], data.aws_iam_policy_document.lifecycle_runtime[0]] :
      alltrue([for s in policy.statement :
        !contains(s.resources, local.campaign.pipeline_table_arn) ||
        !anytrue([for action in s.actions : contains(["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:BatchWriteItem"], action)]) ||
        anytrue([for c in s.condition :
          c.variable == "dynamodb:LeadingKeys" && startswith(c.test, "ForAllValues:") &&
          alltrue([for prefix in c.values : contains(["PERIOD#*", "EVENT#*", "CONTRIB#*", "CANDIDATE#*", "BUCKET#*"], prefix)])
        ])
      ])
    ])
    error_message = "Pipeline inventory approval markers must never be writable by any campaign runtime role."
  }
}

run "cluster_checks_candidate_lifecycle_only_in_transactions" {
  command = plan
  assert {
    condition = (
      one([for s in data.aws_iam_policy_document.cluster_runtime[0].statement : s if s.sid == "CheckCandidateLifecycleTransaction"]).actions == toset(["dynamodb:ConditionCheckItem"]) &&
      one([for s in data.aws_iam_policy_document.cluster_runtime[0].statement : s if s.sid == "CheckCandidateLifecycleTransaction"]).resources == toset([local.campaign.pipeline_table_arn]) &&
      anytrue([for c in one([for s in data.aws_iam_policy_document.cluster_runtime[0].statement : s if s.sid == "CheckCandidateLifecycleTransaction"]).condition : c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(["CANDIDATE#*"])]) &&
      anytrue([for c in one([for s in data.aws_iam_policy_document.cluster_runtime[0].statement : s if s.sid == "CheckCandidateLifecycleTransaction"]).condition : c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])])
    )
    error_message = "The capped-contributor path must check candidate lifecycle state within the guarded transaction only."
  }
}

run "research_candidate_checks_current_consent_and_remains_paused" {
  command = plan
  variables { research_consent_migration = true }
  assert {
    condition     = output.research_consent_migration_contract.selected && output.research_consent_migration_contract.consumers_paused && !output.research_consent_migration_contract.live_qualified && !aws_lambda_event_source_mapping.cluster[0].enabled && alltrue([for name in ["publisher", "cluster"] : aws_lambda_function.worker[name].environment[0].variables.CAMPAIGN_PARTICIPATION_NOTICE_VERSION == "research-consent-2026-09-21-v2" && aws_lambda_function.worker[name].environment[0].variables.DELETION_LEDGER_TABLE_NAME == "trustcheckradar-dev-deletion-ledger"])
    error_message = "Research candidates must share current notice/deletion fences and remain paused."
  }
  assert {
    condition     = length([for st in data.aws_iam_policy_document.cluster_runtime[0].statement : st if startswith(st.sid, "ReadResearchEligibility")]) == 3 && length([for st in data.aws_iam_policy_document.cluster_runtime[0].statement : st if startswith(st.sid, "CheckResearchEligibility")]) == 3 && alltrue([for st in data.aws_iam_policy_document.cluster_runtime[0].statement : !startswith(st.sid, "CheckResearchEligibility") || anytrue([for c in st.condition : c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])])])
    error_message = "Cluster must read owned outbox evidence and transact with current consent/deletion checks."
  }
}
run "research_candidate_requires_immutable_workers" {
  command = plan
  variables {
    research_consent_migration = true
    account_privacy_artifacts  = null
  }
  expect_failures = [var.research_consent_migration]
}

run "research_candidate_rejects_foreign_outbox" {
  command = plan
  variables { research_consent_migration = true }
  override_data {
    target = data.terraform_remote_state.campaign_data[0]
    values = {
      outputs = {
        downstream_contract = {
          schema_version          = 1
          environment             = "dev"
          enabled                 = true
          outbox_table_name       = "trustcheckradar-dev-campaign-outbox"
          outbox_table_arn        = "arn:aws:dynamodb:us-east-1:000000000000:table/trustcheckradar-dev-campaign-outbox"
          outbox_stream_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox/stream/1"
          pipeline_table_name     = "trustcheckradar-dev-campaign-pipeline"
          pipeline_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-pipeline"
          expiration_index_name   = "ExpirationIndex"
          intelligence_table_name = "trustcheckradar-dev-campaign-intelligence"
          intelligence_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-intelligence"
          cluster_queue_url       = "https://sqs.us-east-1.amazonaws.com/107827791950/campaign-cluster"
          cluster_queue_arn       = "arn:aws:sqs:us-east-1:107827791950:campaign-cluster"
          cluster_dlq_arn         = "arn:aws:sqs:us-east-1:107827791950:campaign-cluster-dlq"
          transient_kms_key_arn   = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111"
          persistent_kms_key_arn  = "arn:aws:kms:us-east-1:107827791950:key/22222222-2222-2222-2222-222222222222"
          budget_alert_topic_arn  = "arn:aws:sns:us-east-1:107827791950:campaign-alerts"
        }
      }
    }
  }

  expect_failures = [aws_lambda_function.worker]
}
