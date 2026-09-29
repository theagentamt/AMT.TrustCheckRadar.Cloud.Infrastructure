aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"
# Private operator validation only. No consumer API or allowance authority.
enabled                = true
secret_arn             = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/web-risk-api-key-F4iAc8"
resolver_alias_arn     = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-resolver:live"
alert_topic_arn        = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
dev_test_principal_arn = "arn:aws:iam::107827791950:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_6659317f1273c022"
artifact = {
  "bucket" : "trustcheckradar-dev-107827791950-artifacts",
  "key" : "releases/27ba230f6a96fe5bf1c96719903c3c7016765bbb/url_assessment.zip",
  "object_version" : "To2TAUBYug9ZbA76hilSW39qQXhirMy8",
  "source_hash" : "ZR2IfD7e51zdXQPhdA1rCp0KzD4gdYLK7VlHRTUQaVA="
}
tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
