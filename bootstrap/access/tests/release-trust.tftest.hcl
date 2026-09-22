mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::107827791950:role/synthetic-test-only" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::107827791950:policy/synthetic-test-only" }
  }

  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
}
variables {
  state_bucket_name                 = "synthetic-state"
  existing_github_oidc_provider_arn = "arn:aws:iam::107827791950:oidc-provider/token.actions.githubusercontent.com"
}
run "release_trust_is_dev_only" {
  command = plan
  assert {
    condition = alltrue(flatten([for policy in [data.aws_iam_policy_document.github_assume_role, data.aws_iam_policy_document.lambda_publish_assume_role] : [
      for env, document in policy : alltrue([
        for condition in tolist(document.statement)[0].condition :
        condition.variable != "token.actions.githubusercontent.com:ref" ||
        toset(condition.values) == toset(env == "dev" ? ["refs/heads/main", "refs/heads/release-V01"] : ["refs/heads/main"])
      ])
    ]]))
    error_message = "Only Dev may trust the exact release-V01 branch; UAT and Prod must remain main-only."
  }
  assert {
    condition = alltrue(flatten([for policy in [data.aws_iam_policy_document.github_assume_role, data.aws_iam_policy_document.lambda_publish_assume_role] : [
      for env, document in policy : length(tolist(document.statement)[0].condition) == 3 && alltrue([
        for condition in tolist(document.statement)[0].condition :
        condition.test == "StringEquals" && (condition.variable != "token.actions.githubusercontent.com:aud" || toset(condition.values) == toset(["sts.amazonaws.com"])) && (condition.variable != "token.actions.githubusercontent.com:sub" || toset(condition.values) == toset([
          policy == data.aws_iam_policy_document.github_assume_role ?
          "repo:theagentamt@286777212/AMT.TrustCheckRadar.Cloud.Infrastructure@1355413242:environment:${env}" :
          "repo:theagentamt@286777212/AMT.TrustCheckRadar.Lambdas@1355411973:environment:${env}"
        ]))
      ])
    ]]))
    error_message = "Audience and immutable repository/environment subject restrictions must remain exact."
  }
}
