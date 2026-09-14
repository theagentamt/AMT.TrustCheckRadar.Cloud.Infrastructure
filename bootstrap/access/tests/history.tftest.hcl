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

run "history_rule_permissions_are_exact_and_environment_scoped" {
  command = plan

  assert {
    condition = alltrue([for environment, document in data.aws_iam_policy_document.history_lifecycle_deploy :
      length(document.statement) == 1 && alltrue([for statement in document.statement :
        statement.sid == "ManageHistoryLifecycleRule" && statement.effect == "Allow" &&
        toset(statement.resources) == toset(["arn:aws:events:us-east-1:107827791950:rule/trustcheckradar-${environment}-history-lifecycle-sweep"]) &&
        toset(statement.actions) == toset([
          "events:DescribeRule", "events:ListTagsForResource", "events:ListTargetsByRule",
          "events:PutRule", "events:PutTargets", "events:RemoveTargets", "events:DeleteRule",
          "events:EnableRule", "events:DisableRule", "events:TagResource", "events:UntagResource",
        ])
      ]) &&
      aws_iam_role_policy.history_lifecycle_deploy[environment].role == "trustcheckradar-${environment}-github-deploy"
    ])
    error_message = "Deployment roles need the exact same-environment History rule API permissions, never events:* or wildcard resources."
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
      length(aws_iam_role_policy.history_lifecycle_deploy) == 1 &&
      alltrue([for statement in data.aws_iam_policy_document.history_lifecycle_deploy["uat"].statement :
        toset(statement.resources) == toset(["arn:aws:events:us-west-2:107827791950:rule/trustcheckradar-uat-history-lifecycle-sweep"])
      ])
    )
    error_message = "A UAT-only configuration must not grant Dev or another region's rule access."
  }
}
