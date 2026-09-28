mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  aws_region                    = "us-east-1"
  project_name                  = "trustcheckradar"
  environment                   = "dev"
  state_bucket_name             = "synthetic-state"
  state_bucket_region           = "us-east-1"
  artifact_release              = "existing-release"
  campaign_intelligence_enabled = true
  campaign_recovery_preparation = { review_reference = "synthetic-engineering-review" }
  campaign_participation_fence_deployment = {
    release_id         = "existing-participation", object_version = "participation-version"
    source_hash        = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    approval_reference = "existing-synthetic-review", promotion_approved = false
  }
  account_data_deployment = {
    release_id         = "1111111111111111111111111111111111111111"
    object_version     = "synthetic-version"
    source_hash        = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    approval_reference = "synthetic-test-not-user-approval"
    promotion_approved = false
  }
  account_data_finalization_candidate = {
    manifest_sha256    = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    inventory_revision = 1
    approval_reference = "synthetic-inventory"
  }
  account_data_monitoring = { alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-alerts" }
  account_deletion_activation = {
    phase               = "workers"
    source_sha          = "1111111111111111111111111111111111111111"
    policy_reference    = "synthetic-policy"
    inventory_reference = "synthetic-inventory"
    identity_reference  = "synthetic-identity"
    component_reference = "synthetic-components"
  }

  support_account_deletion_deployment = { release_id = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", object_version = "synthetic-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", approval_reference = "synthetic-only" }
  support_account_deletion_gateway    = { api_id = "abcdefghij", stage = "$default", approval_reference = "synthetic-only" }
  support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic-only", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[\"66666666-6666-4666-8666-666666666666\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":300,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" }

}

override_data {
  target = data.terraform_remote_state.foundation
  values = { outputs = { downstream_contract = {
    campaign_recovery = {
      schema_version     = 1
      enabled            = true
      environment        = "dev"
      table_name         = "trustcheckradar-dev-deletion-ledger"
      table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
      index_name         = "CampaignRecoveryDueIndex"
      index_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/index/CampaignRecoveryDueIndex"
      partition_key      = "campaignRecoveryPartition"
      sort_key           = "nextAttemptAtEpoch"
      projection         = "KEYS_ONLY"
      shard_count        = 16
      writes_enabled     = false
      coverage_qualified = false
    }
    schema_version                    = 1
    artifact_bucket_name              = "synthetic-artifacts"
    cognito_user_pool_id              = "us-east-1_example"
    cognito_app_client_id             = "synthetic-client"
    users_table_name                  = "trustcheckradar-dev-users"
    users_table_arn                   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
    deletion_ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
    deletion_ledger_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
    deletion_ledger_stream_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/2026-09-14T00:00:00.000"
    analysis_abuse_control_table_name = "trustcheckradar-dev-analysis-abuse-control"
    analysis_abuse_control_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-analysis-abuse-control"
    purchase_entitlements_table_name  = "trustcheckradar-dev-purchase-entitlements"
    purchase_entitlements_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
    device_bindings_table_name        = "trustcheckradar-dev-device-bindings"
    device_bindings_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
    web_risk_cache_table_name         = "web-risk-cache"
    web_risk_cache_table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/web-risk-cache"
    device_recovery_control = {
      schema_version = 1
      enabled        = true
      environment    = "dev"
      table_name     = "trustcheckradar-dev-device-recovery-control"
      table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-recovery-control"
      ttl_attribute  = "expiresAt"
      policy = {
        approved               = true
        approval_reference     = "synthetic-test-not-user-approval"
        audit_retention_days   = 90
        receipt_retention_days = 7
        rate_retention_hours   = 24
        pitr_days              = 7
      }
    }
  } } }
}

override_data {
  target = data.terraform_remote_state.campaign_data[0]
  values = { outputs = { downstream_contract = {
    schema_version        = 1, environment = "dev", enabled = true
    outbox_table_name     = "trustcheckradar-dev-campaign-outbox"
    outbox_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox"
    transient_kms_key_arn = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111"
  } } }
}



override_resource {
  target          = aws_apigatewayv2_api.age_attestation
  override_during = plan
  values          = { id = "abcdefghij", execution_arn = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij" }
}
run "scoped_signed_admission" {
  command = plan
  assert {
    condition     = local.support_admission_enabled && aws_lambda_function.support_account_deletion[0].environment[0].variables["SUPPORT_ACCOUNT_DELETION_ENABLED"] == "true" && aws_lambda_function.support_account_deletion[0].environment[0].variables["SUPPORT_ACCOUNT_DELETION_CONFIG_JSON"] == var.support_account_deletion_activation.config_json && !output.support_account_deletion_candidate_contract.email_deletion_available
    error_message = "Only explicit scoped config may enable runtime; operational availability is still unqualified."
  }
  assert {
    condition     = alltrue([for s in local.support_admission_statements : !contains(s.Action, "kms:Sign") && !contains(s.Action, "dynamodb:DeleteItem") && !contains(s.Action, "cognito-idp:AdminDeleteUser")]) && anytrue([for s in local.support_admission_statements : s.Sid == "VerifyExactSupportKey" && s.Action == ["kms:Verify"] && s.Resource == "arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222"])
    error_message = "Admission must verify only and leave erasure to existing workers."
  }
  assert {
    condition     = alltrue([for s in local.support_admission_statements : !contains(s.Action, "dynamodb:UpdateItem") && !contains(s.Action, "dynamodb:PutItem") || try(s.Condition["ForAnyValue:StringEquals"]["dynamodb:EnclosingOperation"] == ["TransactWriteItems"] && s.Condition.Null["dynamodb:LeadingKeys"] == "false" && length(s.Condition["ForAllValues:StringEquals"]["dynamodb:LeadingKeys"]) == 1 && !contains(s.Condition["ForAllValues:StringEquals"]["dynamodb:LeadingKeys"], "INVENTORY#dev"), false)])
    error_message = "Writes must be transactional, limited to selected account partitions and exclude inventory."
  }
  assert {
    condition     = anytrue([for s in local.support_admission_statements : s.Sid == "CheckSupportInventoryAndAbsentFence" && try(!contains(keys(s.Condition), "ForAnyValue:StringEquals") && s.Condition["StringEqualsIfExists"]["dynamodb:ReturnValues"] == "NONE", false)])
    error_message = "Condition checks must omit unsupported enclosing-operation constraints and forbid returned data."
  }
}
run "null_activation_remains_closed" {
  command = plan
  variables { support_account_deletion_activation = null }
  assert {
    condition     = !local.support_admission_enabled && length(local.support_admission_statements) == 0 && aws_lambda_function.support_account_deletion[0].environment[0].variables == tomap({ APP_ENVIRONMENT = "dev", SUPPORT_ACCOUNT_DELETION_ENABLED = "false" })
    error_message = "Default transport must not gain data grants or enabled environment."
  }
}

run "reject_wrong_operator" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic-only", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[\"66666666-6666-4666-8666-666666666666\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":300,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/other\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_wrong_account" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic-only", config_json = "{\"accountId\":\"999999999999\",\"allowedSubjects\":[\"66666666-6666-4666-8666-666666666666\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":300,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_wrong_pool" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic-only", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[\"66666666-6666-4666-8666-666666666666\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_other\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":300,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_wrong_inventory" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic-only", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[\"66666666-6666-4666-8666-666666666666\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":300,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_empty_subjects" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic-only", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":300,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_wildcard_subject" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic-only", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[\"*\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":300,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_duplicate_subject" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic-only", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[\"66666666-6666-4666-8666-666666666666\",\"66666666-6666-4666-8666-666666666666\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":300,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_expired_bound" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic-only", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[\"66666666-6666-4666-8666-666666666666\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":301,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_missing_readiness" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic-only", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[\"66666666-6666-4666-8666-666666666666\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":300,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":null,\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_extra_field" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic-only", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[\"66666666-6666-4666-8666-666666666666\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":300,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"unexpected\":\"invalid\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}
run "reject_disabled_workers" {
  command = plan
  variables { account_deletion_activation = null }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_activation_without_deployment_or_gateway" {
  command = plan
  variables {
    support_account_deletion_deployment = null
    support_account_deletion_gateway    = null
  }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_duplicate_json_key" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[\"66666666-6666-4666-8666-666666666666\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":300,\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\",\"environment\":\"dev\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}

run "reject_string_age" {
  command = plan
  variables { support_account_deletion_activation = { source_sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", approval_reference = "synthetic", config_json = "{\"accountId\":\"107827791950\",\"allowedSubjects\":[\"66666666-6666-4666-8666-666666666666\"],\"apiId\":\"abcdefghij\",\"cognitoPoolId\":\"us-east-1_example\",\"environment\":\"dev\",\"functionArn\":\"arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion\",\"generation\":\"33333333-3333-4333-8333-333333333333\",\"inventoryManifestSha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"inventoryRevision\":1,\"kmsKeyArn\":\"arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222\",\"ledgerTable\":\"trustcheckradar-dev-deletion-ledger\",\"ledgerTableId\":\"55555555-5555-4555-8555-555555555555\",\"maximumVerificationAgeSeconds\":\"300\",\"operatorRoleArn\":\"arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator\",\"operatorRoleId\":\"AROAABCDEFGHIJKLMNOPQ\",\"readinessSha256\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"region\":\"us-east-1\",\"stage\":\"$default\",\"usersTable\":\"trustcheckradar-dev-users\",\"usersTableId\":\"44444444-4444-4444-8444-444444444444\",\"verificationPolicySha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" } }
  expect_failures = [output.support_account_deletion_candidate_contract]
}
