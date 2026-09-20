mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::107827791950:role/synthetic-test-only" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::107827791950:policy/synthetic-test-only" }
  }
}
variables {
  state_bucket_name                 = "synthetic-state"
  existing_github_oidc_provider_arn = "arn:aws:iam::107827791950:oidc-provider/token.actions.githubusercontent.com"
}
run "only_dev_existing_resources_can_be_inspected" {
  command = plan
  assert {
    condition = (
      toset(keys(aws_iam_role_policy.resolver_release_reads)) == toset(["dev"]) &&
      aws_iam_role_policy.resolver_release_reads["dev"].role == "trustcheckradar-dev-github-deploy" &&
      alltrue([for statement in jsondecode(aws_iam_role_policy.resolver_release_reads["dev"].policy).Statement :
        statement.Effect == "Allow" && alltrue([for action in statement.Action : can(regex("^[a-z0-9]+:(Describe|Get|List)[A-Za-z]+$", action))])
      ]) &&
      jsondecode(aws_iam_role_policy.resolver_release_reads["dev"].policy).Statement[0].Condition.StringEquals["aws:RequestedRegion"] == "us-east-1" &&
      jsondecode(aws_iam_role_policy.resolver_release_reads["dev"].policy).Statement[1].Resource == "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts" &&
      jsondecode(aws_iam_role_policy.resolver_release_reads["dev"].policy).Statement[2].Resource == "arn:aws:cloudwatch:us-east-1:107827791950:alarm:trustcheckradar-dev-url-resolver-*"
    )
    error_message = "The resolver supplement must grant only region-bounded inspection to the Dev role and exact resolver notification resources."
  }
}
run "no_uat_or_prod_supplement" {
  command = plan
  variables { environments = ["uat", "prod"] }
  assert {
    condition     = length(aws_iam_role_policy.resolver_release_reads) == 0
    error_message = "This Dev release workflow must not expand UAT/Prod access."
  }
}
