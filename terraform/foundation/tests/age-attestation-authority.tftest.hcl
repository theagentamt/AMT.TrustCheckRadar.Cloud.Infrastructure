mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  project_name                    = "trustcheckradar"
  environment                     = "dev"
  aws_region                      = "us-east-1"
  backend_assume_role_principals  = ["lambda.amazonaws.com"]
  deletion_assume_role_principals = ["lambda.amazonaws.com"]
  age_attestation_contract = {
    approval_reference = "synthetic-test-not-user-approval"
    promotion_approved = false
  }
}

run "mobile_client_cannot_assert_adult_authority" {
  command = plan

  assert {
    condition = (
      aws_cognito_user_pool_client.mobile.write_attributes == toset(["email", "family_name", "given_name", "phone_number"]) &&
      contains(aws_cognito_user_pool_client.mobile.read_attributes, "custom:over_18") &&
      !contains(aws_cognito_user_pool_client.mobile.write_attributes, "custom:over_18") &&
      output.age_attestation_authority_contract.enabled &&
      !output.age_attestation_authority_contract.custom_over_18_client_writable &&
      output.downstream_contract.age_attestation_authority.contract_version == "1.0.0-candidate.1"
    )
    error_message = "The mobile client must retain required signup attributes while adult status becomes server-authoritative."
  }
}

run "legacy_default_preserves_existing_client_permissions" {
  command = plan
  variables { age_attestation_contract = null }

  assert {
    condition = (
      !output.age_attestation_authority_contract.enabled &&
      output.age_attestation_authority_contract.custom_over_18_client_writable &&
      output.age_attestation_authority_contract.required_signup_write_attributes == null
    )
    error_message = "Unselected environments must preserve the existing client boundary until separately promoted."
  }
}

run "production_requires_separate_promotion_approval" {
  command = plan
  variables { environment = "prod" }
  expect_failures = [var.age_attestation_contract]
}
