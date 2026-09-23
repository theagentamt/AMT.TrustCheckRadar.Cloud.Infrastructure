# Storage foundation only. Runtime selection and activation remain separate.
aws_region = "us-east-1"
project_name = "trustcheckradar"
environment = "dev"
enabled = true
backup_role_names = []
tags = {
  Application = "TrustCheckRadar"
  Owner = "AMT"
  Environment = "dev"
  ManagedBy = "terraform"
  Stack = "play-lifecycle"
}
