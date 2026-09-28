# SEC333: optional Dev signer plane. No API route, mail access or deletion activation.
variable "deployment" {
  description = "Reviewed exact identities and Dev scope. Null creates nothing; no credentials or customer content."
  type = object({
    environment              = string
    source_commit            = string
    approval_reference       = string
    verifier_source_role_arn = string
    operator_source_role_arn = string
    key_admin_role_arn       = string
    cognito_pool_id          = string
    users_table_name         = string
    ledger_table_name        = string
    allowed_subjects         = set(string)
    admission_api_arn        = string
  })
  default = null
  validation {
    condition = var.deployment == null ? true : try(
      var.deployment.environment == "dev" &&
      can(regex("^[a-f0-9]{40}$", var.deployment.source_commit)) &&
      length(trimspace(var.deployment.approval_reference)) > 0 &&
      alltrue([for arn in [var.deployment.verifier_source_role_arn, var.deployment.operator_source_role_arn, var.deployment.key_admin_role_arn] :
        can(regex("^arn:aws:iam::107827791950:role/[A-Za-z0-9_+=,.@/-]+$", arn)) &&
        !contains(["arn:aws:iam::107827791950:role/trustcheckradar-dev-support-verifier", "arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator", "arn:aws:iam::107827791950:role/trustcheckradar-dev-support-account-deletion-role"], arn)
      ]) &&
      can(regex("^us-east-1_[A-Za-z0-9]+$", var.deployment.cognito_pool_id)) &&
      var.deployment.users_table_name == "trustcheckradar-dev-users" &&
      var.deployment.ledger_table_name == "trustcheckradar-dev-deletion-ledger" &&
      length(var.deployment.allowed_subjects) >= 1 && length(var.deployment.allowed_subjects) <= 10 &&
      alltrue([for sub in var.deployment.allowed_subjects : can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", sub))]) &&
      can(regex("^arn:aws:execute-api:us-east-1:107827791950:[a-z0-9]{10}/(dev|\\$default)/POST/support/account-deletion$", var.deployment.admission_api_arn)),
      false
    )
    error_message = "Require reviewed Dev source/approval, exact same-account source/admin roles, Dev resources, 1-10 exact subjects and one support POST API ARN."
  }
}
locals {
  selected           = var.deployment == null ? {} : { dev = var.deployment }
  account_root       = "arn:aws:iam::107827791950:root"
  verifier_arn       = "arn:aws:iam::107827791950:role/trustcheckradar-dev-support-verifier"
  operator_arn       = "arn:aws:iam::107827791950:role/trustcheckradar-dev-support-operator"
  admission_role_arn = "arn:aws:iam::107827791950:role/trustcheckradar-dev-support-account-deletion-role"
  crypto_conditions  = { StringEquals = { "kms:SigningAlgorithm" = "RSASSA_PSS_SHA_256", "kms:MessageType" = "RAW" } }
  tags               = { Project = "trustcheckradar", Environment = "dev", Story = "SECUR4ALL-333" }
}
resource "aws_kms_key" "approval" {
  for_each                 = local.selected
  description              = "Dev supervised support-deletion approvals; no customer encryption"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "RSA_3072"
  multi_region             = false
  deletion_window_in_days  = 30
  # Key policy delegates cryptographic use only to these exact role ARNs. Identity
  # policy and boundary must also allow it; no session-principal wildcard grant.
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "KeyAdministration", Effect = "Allow", Principal = { AWS = each.value.key_admin_role_arn },
    Action = ["kms:DescribeKey", "kms:GetKeyPolicy", "kms:PutKeyPolicy", "kms:EnableKey", "kms:DisableKey", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion", "kms:TagResource", "kms:UntagResource", "kms:ListResourceTags"], Resource = "*" },
    { Sid = "DelegateExactVerifierDescribe", Effect = "Allow", Principal = { AWS = local.account_root }, Action = ["kms:DescribeKey"], Resource = "*", Condition = { ArnEquals = { "aws:PrincipalArn" = local.verifier_arn } } },
    { Sid = "DelegateExactVerifierSign", Effect = "Allow", Principal = { AWS = local.account_root }, Action = ["kms:Sign"], Resource = "*",
    Condition = merge(local.crypto_conditions, { ArnEquals = { "aws:PrincipalArn" = local.verifier_arn } }) },
    { Sid = "DelegateExactAdmissionVerify", Effect = "Allow", Principal = { AWS = local.account_root }, Action = ["kms:Verify"], Resource = "*",
    Condition = merge(local.crypto_conditions, { ArnEquals = { "aws:PrincipalArn" = local.admission_role_arn } }) }
  ] })
  tags = local.tags
}
locals {
  verifier_statements = { for k, d in local.selected : k => [
    { Sid = "DescribeExactKey", Effect = "Allow", Action = ["kms:DescribeKey"], Resource = aws_kms_key.approval[k].arn },
    { Sid = "SignExactApproval", Effect = "Allow", Action = ["kms:Sign"], Resource = aws_kms_key.approval[k].arn, Condition = local.crypto_conditions },
    { Sid = "ReadCurrentIdentity", Effect = "Allow", Action = ["cognito-idp:AdminGetUser"], Resource = "arn:aws:cognito-idp:us-east-1:107827791950:userpool/${d.cognito_pool_id}" },
    { Sid = "DescribePinnedTables", Effect = "Allow", Action = ["dynamodb:DescribeTable"], Resource = ["arn:aws:dynamodb:us-east-1:107827791950:table/${d.users_table_name}", "arn:aws:dynamodb:us-east-1:107827791950:table/${d.ledger_table_name}"] },
    { Sid = "ReadAllowedProfiles", Effect = "Allow", Action = ["dynamodb:GetItem"], Resource = "arn:aws:dynamodb:us-east-1:107827791950:table/${d.users_table_name}",
    Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = [for sub in sort(tolist(d.allowed_subjects)) : "USER#${sub}"] }, Null = { "dynamodb:LeadingKeys" = "false" } } },
    { Sid = "ReadInventoryAndOriginalCommand", Effect = "Allow", Action = ["dynamodb:GetItem"], Resource = "arn:aws:dynamodb:us-east-1:107827791950:table/${d.ledger_table_name}",
    Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = concat(["INVENTORY#dev"], [for sub in sort(tolist(d.allowed_subjects)) : "ACCOUNT#${sub}"]) }, Null = { "dynamodb:LeadingKeys" = "false" } } },
    { Sid = "NoOtherActions", Effect = "Deny", NotAction = ["kms:DescribeKey", "kms:Sign", "cognito-idp:AdminGetUser", "dynamodb:GetItem", "dynamodb:DescribeTable", "sts:GetCallerIdentity"], Resource = "*" }
  ] }
  operator_statements = { for k, d in local.selected : k => [
    { Sid = "SubmitExactSupportRoute", Effect = "Allow", Action = ["execute-api:Invoke"], Resource = d.admission_api_arn },
    { Sid = "NoOtherActions", Effect = "Deny", NotAction = ["execute-api:Invoke", "sts:GetCallerIdentity"], Resource = "*" }
  ] }
  roles = merge(
    { for k, d in local.selected : "verifier" => { name = "trustcheckradar-dev-support-verifier", source = d.verifier_source_role_arn, statements = local.verifier_statements[k] } },
    { for k, d in local.selected : "operator" => { name = "trustcheckradar-dev-support-operator", source = d.operator_source_role_arn, statements = local.operator_statements[k] } }
  )
}
resource "aws_iam_policy" "boundary" {
  for_each = local.roles
  name     = "${each.value.name}-boundary"
  policy   = jsonencode({ Version = "2012-10-17", Statement = each.value.statements })
  tags     = local.tags
}
resource "aws_iam_role" "human" {
  for_each             = local.roles
  name                 = each.value.name
  max_session_duration = 3600
  permissions_boundary = aws_iam_policy.boundary[each.key].arn
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = "sts:AssumeRole", Principal = { AWS = each.value.source } }
  ] })
  tags = local.tags
}
resource "aws_iam_role_policy" "human" {
  for_each = local.roles
  name     = "scoped-support-${each.key}"
  role     = aws_iam_role.human[each.key].id
  policy   = jsonencode({ Version = "2012-10-17", Statement = each.value.statements })
}
output "candidate" {
  value = {
    provisioned              = var.deployment != null
    email_deletion_available = false
    route_created            = false
    mailbox_access           = false
    audit_store_created      = false
    key_arn                  = try(aws_kms_key.approval["dev"].arn, null)
    verifier_role_arn        = try(aws_iam_role.human["verifier"].arn, null)
    verifier_role_id         = try(aws_iam_role.human["verifier"].unique_id, null)
    operator_role_arn        = try(aws_iam_role.human["operator"].arn, null)
    operator_role_id         = try(aws_iam_role.human["operator"].unique_id, null)
    source_commit            = try(var.deployment.source_commit, null)
  }
}
