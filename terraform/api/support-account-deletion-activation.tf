# Explicit scoped Dev activation; source deployment/transport alone never enables it.
variable "support_account_deletion_activation" {
  description = "Reviewed canonical runtime pins and readiness for exact disposable Dev subjects. Null remains disabled. References/hashes are operator attestations, not automatic readiness checks."
  type = object({
    source_sha         = string
    config_json        = string
    approval_reference = string
  })
  default = null

}
locals {
  support_admission_config = try(jsondecode(var.support_account_deletion_activation.config_json), {})
  support_admission_fields = toset([
    "environment", "accountId", "region", "functionArn", "apiId", "stage",
    "operatorRoleArn", "operatorRoleId", "kmsKeyArn", "generation",
    "verificationPolicySha256", "readinessSha256", "maximumVerificationAgeSeconds",
    "cognitoPoolId", "usersTable", "usersTableId", "ledgerTable", "ledgerTableId",
    "inventoryManifestSha256", "inventoryRevision", "allowedSubjects"
  ])
  support_account_deletion_activation_valid = try(
    var.environment == "dev" && var.support_account_deletion_deployment != null &&
    var.support_account_deletion_gateway != null && local.account_deletion_workers_enabled &&
    var.support_account_deletion_activation.source_sha == var.support_account_deletion_deployment.release_id &&
    length(trimspace(var.support_account_deletion_activation.approval_reference)) > 0 &&
    length(var.support_account_deletion_activation.config_json) <= 8192 &&
    var.support_account_deletion_activation.config_json == jsonencode(local.support_admission_config) &&
    toset(keys(local.support_admission_config)) == local.support_admission_fields &&
    local.support_admission_config.environment == "dev" && local.support_admission_config.accountId == "107827791950" &&
    local.support_admission_config.region == "us-east-1" &&
    local.support_admission_config.functionArn == "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion" &&
    local.support_admission_config.apiId == var.support_account_deletion_gateway.api_id &&
    local.support_admission_config.stage == var.support_account_deletion_gateway.stage &&
    local.support_admission_config.operatorRoleArn == "arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator" &&
    can(regex("^AROA[A-Z0-9]{17}$", local.support_admission_config.operatorRoleId)) &&
    can(regex("^arn:aws:kms:us-east-1:107827791950:key/[a-f0-9-]{36}$", local.support_admission_config.kmsKeyArn)) &&
    alltrue([for value in [local.support_admission_config.generation, local.support_admission_config.usersTableId, local.support_admission_config.ledgerTableId, split("/", local.support_admission_config.kmsKeyArn)[1]] : can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", value))]) &&
    alltrue([for value in [local.support_admission_config.verificationPolicySha256, local.support_admission_config.readinessSha256, local.support_admission_config.inventoryManifestSha256] : can(regex("^[a-f0-9]{64}$", value))]) &&
    local.support_admission_config.cognitoPoolId == local.cognito_user_pool_id &&
    local.support_admission_config.usersTable == local.users_table_name &&
    local.support_admission_config.ledgerTable == local.deletion_ledger_table_name &&
    local.support_admission_config.inventoryManifestSha256 == var.account_data_finalization_candidate.manifest_sha256 &&
    local.support_admission_config.inventoryRevision == var.account_data_finalization_candidate.inventory_revision &&
    local.support_admission_config.maximumVerificationAgeSeconds >= 1 &&
    local.support_admission_config.maximumVerificationAgeSeconds <= 300 &&
    floor(local.support_admission_config.maximumVerificationAgeSeconds) == local.support_admission_config.maximumVerificationAgeSeconds &&
    length(local.support_admission_config.allowedSubjects) >= 1 && length(local.support_admission_config.allowedSubjects) <= 10 &&
    length(toset(local.support_admission_config.allowedSubjects)) == length(local.support_admission_config.allowedSubjects) &&
    alltrue([for sub in local.support_admission_config.allowedSubjects : can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", sub))]), false
  )
  support_admission_enabled    = var.support_account_deletion_activation != null && local.support_account_deletion_activation_valid
  support_admission_configured = local.support_admission_enabled ? { selected = local.support_admission_config } : {}
  support_admission_statements = flatten([for c in local.support_admission_configured : [
    { Sid = "VerifyExactSupportKey", Effect = "Allow", Action = ["kms:Verify"], Resource = c.kmsKeyArn,
    Condition = { StringEquals = { "kms:SigningAlgorithm" = "RSASSA_PSS_SHA_256", "kms:MessageType" = "RAW" } } },
    { Sid = "ReadCurrentSupportIdentity", Effect = "Allow", Action = ["cognito-idp:AdminGetUser"], Resource = "arn:aws:cognito-idp:us-east-1:107827791950:userpool/${c.cognitoPoolId}" },
    { Sid = "DescribeSupportTables", Effect = "Allow", Action = ["dynamodb:DescribeTable"], Resource = [local.users_table_arn, local.deletion_ledger_table_arn] },
    { Sid = "ReadSupportProfiles", Effect = "Allow", Action = ["dynamodb:GetItem"], Resource = local.users_table_arn,
    Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = [for sub in c.allowedSubjects : "USER#${sub}"] }, Null = { "dynamodb:LeadingKeys" = "false" } } },
    { Sid = "ReadSupportReceiptsAndInventory", Effect = "Allow", Action = ["dynamodb:GetItem"], Resource = local.deletion_ledger_table_arn,
    Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = concat(["INVENTORY#dev"], [for sub in c.allowedSubjects : "ACCOUNT#${sub}"]) }, Null = { "dynamodb:LeadingKeys" = "false" } } },
    { Sid = "FindSupportRecovery", Effect = "Allow", Action = ["dynamodb:Query"], Resource = local.deletion_ledger_table_arn,
    Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = [for sub in c.allowedSubjects : "ACCOUNT#${sub}"] }, Null = { "dynamodb:LeadingKeys" = "false" } } },
    { Sid = "FenceSupportProfileTransaction", Effect = "Allow", Action = ["dynamodb:UpdateItem"], Resource = local.users_table_arn,
    Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = [for sub in c.allowedSubjects : "USER#${sub}"] }, "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] }, "StringEqualsIfExists" = { "dynamodb:ReturnValues" = "NONE" }, Null = { "dynamodb:LeadingKeys" = "false" } } },
    { Sid = "AdmitSupportCommandAndRecoveryTransaction", Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:UpdateItem"], Resource = local.deletion_ledger_table_arn,
    Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = [for sub in c.allowedSubjects : "ACCOUNT#${sub}"] }, "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] }, "StringEqualsIfExists" = { "dynamodb:ReturnValues" = "NONE" }, Null = { "dynamodb:LeadingKeys" = "false" } } },
    { Sid = "CheckSupportInventoryAndAbsentFence", Effect = "Allow", Action = ["dynamodb:ConditionCheckItem"], Resource = local.deletion_ledger_table_arn,
    Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = concat(["INVENTORY#dev"], [for sub in c.allowedSubjects : "ACCOUNT#${sub}"]) }, "StringEqualsIfExists" = { "dynamodb:ReturnValues" = "NONE" }, Null = { "dynamodb:LeadingKeys" = "false" } } }
  ]])
}
