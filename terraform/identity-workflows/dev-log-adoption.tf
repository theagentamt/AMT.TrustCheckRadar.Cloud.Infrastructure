# The Dev group predates Terraform log management. Import it without recreation.
# UAT/Prod have no adoption or retention selection implied by this migration.
import {
  for_each = var.environment == "dev" && var.post_confirmation_log_policy != null ? toset(["/aws/lambda/${local.lambda_name}"]) : toset([])
  to       = aws_cloudwatch_log_group.post_confirmation[0]
  id       = each.value
}
