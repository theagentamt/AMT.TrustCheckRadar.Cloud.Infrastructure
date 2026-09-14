mock_provider "aws" {}

variables {
  aws_region   = "us-east-1"
  project_name = "trustcheckradar"
  environment  = "dev"
}

run "disabled_environment_has_no_resources" {
  command = plan

  assert {
    condition = (
      length(aws_dynamodb_table.history) == 0 &&
      !output.downstream_contract.enabled &&
      output.downstream_contract.content_table_arn == null &&
      output.downstream_contract.control_table_name == null &&
      output.downstream_contract.storage_policy == null &&
      !output.downstream_contract.storage_monitoring_enabled &&
      length(aws_cloudwatch_metric_alarm.storage_throttles) == 0 &&
      length(aws_cloudwatch_dashboard.history_storage) == 0
    )
    error_message = "Disabled History must create no tables or expose active storage configuration."
  }
}

run "enable_without_policy_is_a_hard_failure" {
  command = plan
  variables {
    history_data_enabled = true
  }
  expect_failures = [var.history_data_enabled]
}

run "disabled_uat_is_empty" {
  command = plan
  variables {
    environment = "uat"
  }
  assert {
    condition     = length(aws_dynamodb_table.history) == 0 && output.downstream_contract.environment == "uat"
    error_message = "UAT must remain empty while disabled, without any promotion or policy defaults."
  }
}

run "disabled_prod_is_empty" {
  command = plan
  variables {
    environment = "prod"
  }
  assert {
    condition     = length(aws_dynamodb_table.history) == 0 && output.downstream_contract.environment == "prod"
    error_message = "Production must remain empty while disabled, without any promotion or policy defaults."
  }
}

run "approval_requires_a_reference" {
  command = plan
  variables {
    history_data_enabled = true
    storage_policy = {
      approved                    = true
      approval_reference          = " "
      content_pitr_days           = 0
      control_pitr_days           = 7
      dedup_retention_seconds     = 86400
      tombstone_retention_seconds = 86400
    }
  }
  expect_failures = [var.history_data_enabled]
}

run "explicit_null_retention_is_rejected" {
  command = plan
  variables {
    storage_policy = {
      approved                    = true
      approval_reference          = "synthetic-test-only"
      content_pitr_days           = null
      control_pitr_days           = 7
      dedup_retention_seconds     = 86400
      tombstone_retention_seconds = 86400
    }
  }
  expect_failures = [var.storage_policy]
}

run "unapproved_policy_is_a_hard_failure" {
  command = plan
  variables {
    history_data_enabled = true
    storage_policy = {
      approved                    = false
      approval_reference          = "synthetic-test-only"
      content_pitr_days           = 0
      control_pitr_days           = 7
      dedup_retention_seconds     = 86400
      tombstone_retention_seconds = 86400
    }
  }
  expect_failures = [var.history_data_enabled]
}

run "enabled_synthetic_dev_contract" {
  # Mock apply resolves computed set identities without contacting AWS.
  command = apply
  variables {
    history_data_enabled = true
    # Fixture values are not product policy or an approved production window.
    storage_policy = {
      approved                    = true
      approval_reference          = "synthetic-test-only"
      content_pitr_days           = 0
      control_pitr_days           = 7
      dedup_retention_seconds     = 86400
      tombstone_retention_seconds = 172800
    }
  }

  assert {
    condition = (
      length(aws_dynamodb_table.history) == 2 &&
      aws_dynamodb_table.history["content"].name == "trustcheckradar-dev-history-content" &&
      aws_dynamodb_table.history["control"].name == "trustcheckradar-dev-history-control"
    )
    error_message = "Content and control/progress storage must be distinct and environment-scoped."
  }

  assert {
    condition = alltrue([
      for table in aws_dynamodb_table.history :
      table.billing_mode == "PAY_PER_REQUEST" &&
      table.hash_key == "PK" && table.range_key == "SK" &&
      !table.server_side_encryption[0].enabled && !table.stream_enabled &&
      table.ttl[0].enabled && table.ttl[0].attribute_name == "expiresAt" &&
      table.on_demand_throughput[0].max_read_request_units == 25 &&
      table.on_demand_throughput[0].max_write_request_units == 10
    ])
    error_message = "Tables require encryption, bounded on-demand capacity and TTL; no unapproved streams."
  }

  assert {
    condition = alltrue(flatten([
      for table in aws_dynamodb_table.history : [
        for index in table.global_secondary_index :
        index.projection_type == "KEYS_ONLY" &&
        index.on_demand_throughput[0].max_write_request_units == 10
      ]
    ]))
    error_message = "Lifecycle indexes must be key-only, expiry-addressable and throughput capped."
  }

  assert {
    condition = (
      length(aws_dynamodb_table.history["content"].global_secondary_index) == 1 &&
      length(aws_dynamodb_table.history["control"].global_secondary_index) == 2 &&
      length([
        for index in aws_dynamodb_table.history["control"].global_secondary_index : index
        if index.name == "PendingLifecycleIndex" && index.hash_key == "lifecycleBucket" && index.range_key == "lifecycleAt"
      ]) == 1 &&
      alltrue([
        for table in aws_dynamodb_table.history : length([
          for index in table.global_secondary_index : index
          if index.name == "ExpirationIndex" && index.hash_key == "expiryBucket" && index.range_key == "expiresAt"
        ]) == 1
      ])
    )
    error_message = "Each table needs ExpirationIndex; only control needs PendingLifecycleIndex."
  }

  assert {
    condition = (
      !aws_dynamodb_table.history["content"].point_in_time_recovery[0].enabled &&
      aws_dynamodb_table.history["control"].point_in_time_recovery[0].recovery_period_in_days == 7 &&
      output.downstream_contract.history_retention_seconds == 7776000 &&
      output.downstream_contract.active_deletion_sla_seconds == 86400 &&
      !output.downstream_contract.snippets_enabled && !output.downstream_contract.points_enabled &&
      output.downstream_contract.badge_milestones == [1, 5, 20]
    )
    error_message = "Explicit backup policy and approved 90-day/24-hour/no-snippet/badges-only baseline must be preserved."
  }
}

run "uat_requires_promotion" {
  command = plan
  variables {
    environment          = "uat"
    history_data_enabled = true
    storage_policy       = run.enabled_synthetic_dev_contract.downstream_contract.storage_policy
  }
  expect_failures = [var.history_data_enabled]
}

run "prod_requires_promotion" {
  command = plan
  variables {
    environment          = "prod"
    history_data_enabled = true
    storage_policy       = run.enabled_synthetic_dev_contract.downstream_contract.storage_policy
  }
  expect_failures = [var.history_data_enabled]
}

run "promoted_prod_has_distinct_names_and_deletion_protection" {
  command = plan
  variables {
    environment          = "prod"
    history_data_enabled = true
    promotion_approved   = true
    storage_policy       = run.enabled_synthetic_dev_contract.downstream_contract.storage_policy
  }
  assert {
    condition = alltrue([
      for table in aws_dynamodb_table.history :
      startswith(table.name, "trustcheckradar-prod-history-") &&
      table.deletion_protection_enabled && table.tags.Environment == "prod"
    ])
    error_message = "Production storage must be separately named, tagged and deletion-protected."
  }
}

run "invalid_backup_retention_rejected" {
  command = plan
  variables {
    storage_policy = {
      approved                    = true
      approval_reference          = "synthetic-test-only"
      content_pitr_days           = 36
      control_pitr_days           = 1.5
      dedup_retention_seconds     = 1
      tombstone_retention_seconds = 1
    }
  }
  expect_failures = [var.storage_policy]
}

run "invalid_metadata_retention_rejected" {
  command = plan
  variables {
    storage_policy = {
      approved                    = true
      approval_reference          = "synthetic-test-only"
      content_pitr_days           = 0
      control_pitr_days           = 0
      dedup_retention_seconds     = 0
      tombstone_retention_seconds = -1
    }
  }
  expect_failures = [var.storage_policy]
}

run "unbounded_throughput_rejected" {
  command = plan
  variables {
    max_read_request_units  = -1
    max_write_request_units = 51
  }
  expect_failures = [var.max_read_request_units, var.max_write_request_units]
}

run "monitoring_requires_provisioned_data" {
  command = plan
  variables {
    monitoring = {
      alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-test-only"
    }
  }
  expect_failures = [var.monitoring]
}

run "monitoring_requires_valid_same_region_topic" {
  command = plan
  variables {
    history_data_enabled = true
    storage_policy       = run.enabled_synthetic_dev_contract.downstream_contract.storage_policy
    monitoring = {
      alarm_topic_arn = "arn:aws:sns:us-west-2:107827791950:synthetic-test-only"
    }
  }
  expect_failures = [var.monitoring]
}

run "monitoring_rejects_missing_notification_target" {
  command = plan
  variables {
    history_data_enabled = true
    storage_policy       = run.enabled_synthetic_dev_contract.downstream_contract.storage_policy
    monitoring = {
      alarm_topic_arn = null
    }
  }
  expect_failures = [var.monitoring]
}

run "monitoring_covers_tables_and_indexes_without_account_data" {
  command = apply
  variables {
    history_data_enabled = true
    storage_policy       = run.enabled_synthetic_dev_contract.downstream_contract.storage_policy
    monitoring = {
      alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-test-only"
    }
  }

  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.storage_throttles) == 2 &&
      length(aws_cloudwatch_dashboard.history_storage) == 1 &&
      length(local.storage_metric_dimensions) == 5 &&
      output.downstream_contract.storage_monitoring_enabled
    )
    error_message = "Monitoring must expose read/write alarms covering both tables and all three GSIs."
  }

  assert {
    condition = alltrue([
      for direction, alarm in aws_cloudwatch_metric_alarm.storage_throttles :
      alarm.alarm_name == "trustcheckradar-dev-history-${direction}-throttles" &&
      toset(alarm.alarm_actions) == toset([var.monitoring.alarm_topic_arn]) &&
      toset(alarm.ok_actions) == toset([var.monitoring.alarm_topic_arn]) &&
      alarm.treat_missing_data == "notBreaching" &&
      alarm.threshold == 0 &&
      length(alarm.metric_query) == 6 &&
      length([for query in alarm.metric_query : query if query.return_data]) == 1 &&
      alltrue([
        for query in alarm.metric_query : query.id == "total" ? query.expression == "SUM(METRICS())" : alltrue([
          for metric in query.metric :
          metric.metric_name == local.throttle_metrics[direction] &&
          metric.namespace == "AWS/DynamoDB" && metric.period == 300 && metric.stat == "Sum" &&
          startswith(metric.dimensions.TableName, "trustcheckradar-dev-history-") &&
          length(setsubtract(toset(keys(metric.dimensions)), toset(["TableName", "GlobalSecondaryIndexName"]))) == 0
        ])
      ])
    ])
    error_message = "Alarm math, environment dimensions, notification actions and privacy boundary must stay exact."
  }

  assert {
    condition = (
      local.storage_metric_dimensions.content_expiry.GlobalSecondaryIndexName == "ExpirationIndex" &&
      local.storage_metric_dimensions.control_expiry.GlobalSecondaryIndexName == "ExpirationIndex" &&
      local.storage_metric_dimensions.control_lifecycle.GlobalSecondaryIndexName == "PendingLifecycleIndex" &&
      length(jsondecode(aws_cloudwatch_dashboard.history_storage[0].dashboard_body).widgets) == 2 &&
      alltrue([
        for widget in jsondecode(aws_cloudwatch_dashboard.history_storage[0].dashboard_body).widgets :
        widget.properties.region == "us-east-1" && length(widget.properties.metrics) == 5
      ])
    )
    error_message = "The dashboard and alarms must include lifecycle/expiry indexes, not only base-table metrics."
  }
}

run "monitoring_isolated_in_promoted_uat" {
  command = apply
  variables {
    environment          = "uat"
    history_data_enabled = true
    promotion_approved   = true
    storage_policy       = run.enabled_synthetic_dev_contract.downstream_contract.storage_policy
    monitoring = {
      alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-uat-only"
    }
  }
  assert {
    condition = (
      output.downstream_contract.storage_dashboard_name == "trustcheckradar-uat-history-storage" &&
      alltrue([
        for dimensions in values(local.storage_metric_dimensions) :
        startswith(dimensions.TableName, "trustcheckradar-uat-history-")
      ]) &&
      alltrue([
        for alarm in aws_cloudwatch_metric_alarm.storage_throttles :
        startswith(alarm.alarm_name, "trustcheckradar-uat-history-") && alarm.tags.Environment == "uat"
      ])
    )
    error_message = "Promoted UAT monitoring must never use Dev data dimensions or alarm names."
  }
}
