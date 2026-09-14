locals {
  table_pitr_days = {
    content = try(var.storage_policy.content_pitr_days, 0)
    control = try(var.storage_policy.control_pitr_days, 0)
  }
  tables = var.history_data_enabled ? local.table_pitr_days : {}
  common_tags = merge(var.tags, {
    Project      = var.project_name
    Environment  = var.environment
    ManagedBy    = "terraform"
    Stack        = "history-data"
    CostCategory = "history-badges"
  })
}

resource "aws_dynamodb_table" "history" {
  for_each = local.tables

  name                        = "${var.project_name}-${var.environment}-history-${each.key}"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "PK"
  range_key                   = "SK"
  deletion_protection_enabled = var.environment == "prod"
  stream_enabled              = false

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "expiryBucket"
    type = "S"
  }

  attribute {
    name = "expiresAt"
    type = "N"
  }

  dynamic "attribute" {
    for_each = each.key == "control" ? ["lifecycleBucket", "lifecycleAt"] : []
    content {
      name = attribute.value
      type = attribute.value == "lifecycleBucket" ? "S" : "N"
    }
  }

  # Purge workers query bounded expiry buckets then conditionally delete the
  # current base item. The index must never duplicate assessment content.
  global_secondary_index {
    name            = "ExpirationIndex"
    hash_key        = "expiryBucket"
    range_key       = "expiresAt"
    projection_type = "KEYS_ONLY"

    on_demand_throughput {
      max_read_request_units  = var.max_read_request_units
      max_write_request_units = var.max_write_request_units
    }
  }

  dynamic "global_secondary_index" {
    for_each = each.key == "control" ? [true] : []
    content {
      name            = "PendingLifecycleIndex"
      hash_key        = "lifecycleBucket"
      range_key       = "lifecycleAt"
      projection_type = "KEYS_ONLY"

      on_demand_throughput {
        max_read_request_units  = var.max_read_request_units
        max_write_request_units = var.max_write_request_units
      }
    }
  }

  on_demand_throughput {
    max_read_request_units  = var.max_read_request_units
    max_write_request_units = var.max_write_request_units
  }

  server_side_encryption {
    # False selects DynamoDB's AWS-owned key, not unencrypted storage.
    enabled = false
  }

  point_in_time_recovery {
    enabled                 = each.value > 0
    recovery_period_in_days = each.value > 0 ? each.value : null
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  tags = merge(local.common_tags, {
    DataClass = each.key == "content" ? "private-assessment" : "private-control-progress"
  })
}
