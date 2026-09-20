aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "prod"

# Enable only with a published, version-pinned resolver artifact and reviewed plan.
# This stack is independent of api and does not modify the URL analyzer.
enabled           = false
caller_role_names = []
alarm_action_arns = []

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
