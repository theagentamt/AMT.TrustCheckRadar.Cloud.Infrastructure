aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}

artifact_bucket_force_destroy = true
hosted_ui_enabled             = false
users_status_gsi_enabled      = true

backend_assume_role_principals  = ["lambda.amazonaws.com"]
deletion_assume_role_principals = ["lambda.amazonaws.com"]
