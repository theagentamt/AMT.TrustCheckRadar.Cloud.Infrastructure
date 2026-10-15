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

run "authority_maintenance_permissions_are_exact_and_environment_scoped" {
  command = plan

  assert {
    condition = alltrue([for environment, document in data.aws_iam_policy_document.v1_authority_maintenance_deploy :
      length(document.statement) == 1 && alltrue([for statement in document.statement :
        statement.sid == "ManageV1AuthorityMaintenanceRules" && statement.effect == "Allow" &&
        toset(statement.resources) == toset([
          "arn:aws:events:us-east-1:107827791950:rule/trustcheckradar-${environment}-url-lease-recovery",
          "arn:aws:events:us-east-1:107827791950:rule/trustcheckradar-${environment}-v1-authority-deletion",
        ]) &&
        toset(statement.actions) == toset([
          "events:DescribeRule", "events:ListTagsForResource", "events:ListTargetsByRule",
          "events:PutRule", "events:PutTargets", "events:RemoveTargets", "events:DeleteRule",
          "events:EnableRule", "events:DisableRule", "events:TagResource", "events:UntagResource",
        ])
      ]) &&
      aws_iam_role_policy.v1_authority_maintenance_deploy[environment].role == "trustcheckradar-${environment}-github-deploy"
    ])
    error_message = "Deployment roles need exact same-environment access to only the two V1 authority maintenance rules."
  }
}

run "nondefault_region_and_environment_stay_isolated" {
  command = plan
  variables {
    aws_region   = "us-west-2"
    environments = ["uat"]
  }

  assert {
    condition = (
      length(aws_iam_role_policy.v1_authority_maintenance_deploy) == 1 &&
      alltrue([for statement in data.aws_iam_policy_document.v1_authority_maintenance_deploy["uat"].statement :
        toset(statement.resources) == toset([
          "arn:aws:events:us-west-2:107827791950:rule/trustcheckradar-uat-url-lease-recovery",
          "arn:aws:events:us-west-2:107827791950:rule/trustcheckradar-uat-v1-authority-deletion",
        ])
      ])
    )
    error_message = "A UAT-only configuration must not grant Dev or another region's authority-rule access."
  }
}
