aws_region         = "us-east-1"
project_name       = "trustcheckradar"
environment        = "dev"
notification_email = "support@andmorethings.com"

# Owner-authorized Dev deployment, 2026-09-20. Independent of the URL analyzer.
enabled                = true
caller_role_names      = []
alarm_action_arns      = []
dev_test_principal_arn = "arn:aws:iam::107827791950:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_6659317f1273c022"
artifact = {
  bucket         = "trustcheckradar-dev-107827791950-artifacts"
  key            = "releases/url-resolver-py314-dev-20260920-d107988b4412/url_redirect_resolver.zip"
  object_version = "zKohCq1dfkcQb5f2IPscPfiYv9RoIFYB"
  source_hash    = "0QeYi0QSW0hfQ5Z4stNK5968KHovT00yoXq1MrBmbmw="
}

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}

assessment_alarm_notifications_enabled = true
consumer_alarm_notifications_enabled   = true

play_alarm_notifications_enabled = true

account_cleanup_alarm_notifications_enabled = true
