mock_provider "aws" {
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:107827791950:key/22222222-2222-4222-8222-222222222222" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::107827791950:policy/synthetic-boundary" }
  }
}
run "no_resources_by_default" {
  command = plan
  assert {
    condition     = length(aws_kms_key.approval) == 0 && length(aws_iam_role.human) == 0 && length(aws_iam_policy.boundary) == 0 && !output.candidate.provisioned
    error_message = "Default must create nothing."
  }
}
run "scoped_candidate" {
  command = apply
  variables {
    deployment = {
      environment              = "dev"
      source_commit            = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference       = "synthetic-only-not-approval"
      verifier_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      operator_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      key_admin_role_arn       = "arn:aws:iam::107827791950:role/deployment-admin"
      cognito_pool_id          = "us-east-1_example"
      users_table_name         = "trustcheckradar-dev-users"
      ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
      allowed_subjects         = ["11111111-1111-4111-8111-111111111111"]
      admission_api_arn        = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/dev/POST/support/account-deletion"
    }
  }
  assert {
    condition     = aws_kms_key.approval["dev"].key_usage == "SIGN_VERIFY" && aws_kms_key.approval["dev"].customer_master_key_spec == "RSA_3072" && !aws_kms_key.approval["dev"].multi_region
    error_message = "Only the fixed asymmetric signing key is permitted."
  }
  assert {
    condition     = alltrue([for name, role in aws_iam_role.human : role.permissions_boundary == aws_iam_policy.boundary[name].arn && role.max_session_duration == 3600 && jsondecode(role.assume_role_policy).Statement[0].Principal.AWS == "arn:aws:iam::107827791950:role/owner-session"])
    error_message = "Both separate roles must have restricted boundaries and exact owner trust."
  }
  assert {
    condition     = alltrue([for name, p in aws_iam_role_policy.human : p.policy == aws_iam_policy.boundary[name].policy])
    error_message = "Effective permissions and their boundaries must agree."
  }
  assert {
    condition     = alltrue([for p in aws_iam_role_policy.human : anytrue([for s in jsondecode(p.policy).Statement : s.Effect == "Deny" && try(!contains(s.NotAction, "lambda:InvokeFunction") && !contains(s.NotAction, "sts:AssumeRole") && !contains(s.NotAction, "iam:PassRole") && !contains(s.NotAction, "dynamodb:PutItem"), false)])])
    error_message = "Neither human role may invoke Lambda, chain roles, mutate IAM or write data."
  }
  assert {
    condition     = alltrue([for s in jsondecode(aws_iam_role_policy.human["operator"].policy).Statement : s.Effect != "Allow" || (s.Action == ["execute-api:Invoke"] && s.Resource == "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/dev/POST/support/account-deletion")])
    error_message = "Operator may only submit to the exact route, never Sign or read accounts."
  }
  assert {
    condition     = anytrue([for s in jsondecode(aws_iam_role_policy.human["verifier"].policy).Statement : s.Sid == "SignExactApproval" && s.Resource == aws_kms_key.approval["dev"].arn && try(s.Condition.StringEquals["kms:SigningAlgorithm"] == "RSASSA_PSS_SHA_256" && s.Condition.StringEquals["kms:MessageType"] == "RAW", false)]) && anytrue([for s in jsondecode(aws_iam_role_policy.human["verifier"].policy).Statement : s.Sid == "ReadAllowedProfiles" && try(s.Condition["ForAllValues:StringEquals"]["dynamodb:LeadingKeys"] == ["USER#11111111-1111-4111-8111-111111111111"] && s.Condition.Null["dynamodb:LeadingKeys"] == "false", false)])
    error_message = "Signer key, algorithm and profile partitions must be pinned."
  }
  assert {
    condition     = alltrue([for s in jsondecode(aws_kms_key.approval["dev"].policy).Statement : !contains(s.Action, "kms:CreateGrant") && !contains(s.Action, "kms:*")]) && anytrue([for s in jsondecode(aws_kms_key.approval["dev"].policy).Statement : s.Sid == "DelegateExactAdmissionVerify" && s.Action == ["kms:Verify"] && try(s.Condition.ArnEquals["aws:PrincipalArn"] == "arn:aws:iam::107827791950:role/trustcheckradar-dev-support-account-deletion-role", false)])
    error_message = "Key policy must not allow grants or general cryptographic delegation."
  }
  assert {
    condition     = alltrue([for s in jsondecode(aws_kms_key.approval["dev"].policy).Statement : s.Sid != "KeyAdministration" || (!contains(s.Action, "kms:Sign") && !contains(s.Action, "kms:Verify") && s.Principal.AWS == "arn:aws:iam::107827791950:role/deployment-admin")]) && anytrue([for s in jsondecode(aws_kms_key.approval["dev"].policy).Statement : s.Sid == "DelegateExactVerifierSign" && s.Principal.AWS == "arn:aws:iam::107827791950:root" && s.Action == ["kms:Sign"] && try(s.Condition.ArnEquals["aws:PrincipalArn"] == "arn:aws:iam::107827791950:role/trustcheckradar-dev-support-verifier" && s.Condition.StringEquals["kms:SigningAlgorithm"] == "RSASSA_PSS_SHA_256" && s.Condition.StringEquals["kms:MessageType"] == "RAW", false)])
    error_message = "Key admin must not be a signing authority; Sign delegates only to the pinned verifier role and algorithm."
  }
  assert {
    condition     = !output.candidate.email_deletion_available && !output.candidate.route_created && !output.candidate.mailbox_access && !output.candidate.audit_store_created
    error_message = "Role preparation cannot advertise activation or create mail/audit stores."
  }
}
run "reject_wrong_environment" {
  command = plan
  variables {
    deployment = {
      environment              = "prod"
      source_commit            = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference       = "synthetic-only-not-approval"
      verifier_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      operator_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      key_admin_role_arn       = "arn:aws:iam::107827791950:role/deployment-admin"
      cognito_pool_id          = "us-east-1_example"
      users_table_name         = "trustcheckradar-dev-users"
      ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
      allowed_subjects         = ["11111111-1111-4111-8111-111111111111"]
      admission_api_arn        = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/dev/POST/support/account-deletion"
    }
  }
  expect_failures = [var.deployment]
}
run "reject_source_not_pinned" {
  command = plan
  variables {
    deployment = {
      environment              = "dev"
      source_commit            = "release-V01"
      approval_reference       = "synthetic-only-not-approval"
      verifier_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      operator_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      key_admin_role_arn       = "arn:aws:iam::107827791950:role/deployment-admin"
      cognito_pool_id          = "us-east-1_example"
      users_table_name         = "trustcheckradar-dev-users"
      ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
      allowed_subjects         = ["11111111-1111-4111-8111-111111111111"]
      admission_api_arn        = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/dev/POST/support/account-deletion"
    }
  }
  expect_failures = [var.deployment]
}
run "reject_wildcard_trust" {
  command = plan
  variables {
    deployment = {
      environment              = "dev"
      source_commit            = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference       = "synthetic-only-not-approval"
      verifier_source_role_arn = "arn:aws:iam::107827791950:role/*"
      operator_source_role_arn = "arn:aws:iam::107827791950:role/*"
      key_admin_role_arn       = "arn:aws:iam::107827791950:role/deployment-admin"
      cognito_pool_id          = "us-east-1_example"
      users_table_name         = "trustcheckradar-dev-users"
      ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
      allowed_subjects         = ["11111111-1111-4111-8111-111111111111"]
      admission_api_arn        = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/dev/POST/support/account-deletion"
    }
  }
  expect_failures = [var.deployment]
}
run "reject_self_trust" {
  command = plan
  variables {
    deployment = {
      environment              = "dev"
      source_commit            = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference       = "synthetic-only-not-approval"
      verifier_source_role_arn = "arn:aws:iam::107827791950:role/trustcheckradar-dev-support-verifier"
      operator_source_role_arn = "arn:aws:iam::107827791950:role/trustcheckradar-dev-support-verifier"
      key_admin_role_arn       = "arn:aws:iam::107827791950:role/deployment-admin"
      cognito_pool_id          = "us-east-1_example"
      users_table_name         = "trustcheckradar-dev-users"
      ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
      allowed_subjects         = ["11111111-1111-4111-8111-111111111111"]
      admission_api_arn        = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/dev/POST/support/account-deletion"
    }
  }
  expect_failures = [var.deployment]
}
run "reject_wrong_account" {
  command = plan
  variables {
    deployment = {
      environment              = "dev"
      source_commit            = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference       = "synthetic-only-not-approval"
      verifier_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      operator_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      key_admin_role_arn       = "arn:aws:iam::999999999999:role/deployment-admin"
      cognito_pool_id          = "us-east-1_example"
      users_table_name         = "trustcheckradar-dev-users"
      ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
      allowed_subjects         = ["11111111-1111-4111-8111-111111111111"]
      admission_api_arn        = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/dev/POST/support/account-deletion"
    }
  }
  expect_failures = [var.deployment]
}
run "reject_no_subjects" {
  command = plan
  variables {
    deployment = {
      environment              = "dev"
      source_commit            = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference       = "synthetic-only-not-approval"
      verifier_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      operator_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      key_admin_role_arn       = "arn:aws:iam::107827791950:role/deployment-admin"
      cognito_pool_id          = "us-east-1_example"
      users_table_name         = "trustcheckradar-dev-users"
      ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
      allowed_subjects         = []
      admission_api_arn        = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/dev/POST/support/account-deletion"
    }
  }
  expect_failures = [var.deployment]
}
run "reject_unrelated_table" {
  command = plan
  variables {
    deployment = {
      environment              = "dev"
      source_commit            = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference       = "synthetic-only-not-approval"
      verifier_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      operator_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      key_admin_role_arn       = "arn:aws:iam::107827791950:role/deployment-admin"
      cognito_pool_id          = "us-east-1_example"
      users_table_name         = "trustcheckradar-prod-users"
      ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
      allowed_subjects         = ["11111111-1111-4111-8111-111111111111"]
      admission_api_arn        = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/dev/POST/support/account-deletion"
    }
  }
  expect_failures = [var.deployment]
}
run "reject_wildcard_api" {
  command = plan
  variables {
    deployment = {
      environment              = "dev"
      source_commit            = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference       = "synthetic-only-not-approval"
      verifier_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      operator_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      key_admin_role_arn       = "arn:aws:iam::107827791950:role/deployment-admin"
      cognito_pool_id          = "us-east-1_example"
      users_table_name         = "trustcheckradar-dev-users"
      ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
      allowed_subjects         = ["11111111-1111-4111-8111-111111111111"]
      admission_api_arn        = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/*/*/*"
    }
  }
  expect_failures = [var.deployment]
}
run "reject_no_approval" {
  command = plan
  variables {
    deployment = {
      environment              = "dev"
      source_commit            = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference       = " "
      verifier_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      operator_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      key_admin_role_arn       = "arn:aws:iam::107827791950:role/deployment-admin"
      cognito_pool_id          = "us-east-1_example"
      users_table_name         = "trustcheckradar-dev-users"
      ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
      allowed_subjects         = ["11111111-1111-4111-8111-111111111111"]
      admission_api_arn        = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/dev/POST/support/account-deletion"
    }
  }
  expect_failures = [var.deployment]
}
run "allow_default_stage_exact_route" {
  command = plan
  variables {
    deployment = {
      environment              = "dev"
      source_commit            = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference       = "synthetic-only-not-approval"
      verifier_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      operator_source_role_arn = "arn:aws:iam::107827791950:role/owner-session"
      key_admin_role_arn       = "arn:aws:iam::107827791950:role/deployment-admin"
      cognito_pool_id          = "us-east-1_example"
      users_table_name         = "trustcheckradar-dev-users"
      ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
      allowed_subjects         = ["11111111-1111-4111-8111-111111111111"]
      admission_api_arn        = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/$default/POST/support/account-deletion"
    }
  }
  assert {
    condition     = output.candidate.provisioned && !output.candidate.email_deletion_available
    error_message = "Exact default stage route is valid without activation."
  }
}
