output "post_confirmation_lambda_name" {
  description = "PostConfirmation Lambda function name"
  value       = aws_lambda_function.post_confirmation.function_name
}

output "post_confirmation_lambda_arn" {
  description = "PostConfirmation Lambda function ARN"
  value       = aws_lambda_function.post_confirmation.arn
}

output "post_confirmation_lambda_role_arn" {
  description = "PostConfirmation Lambda execution role ARN"
  value       = aws_iam_role.post_confirmation.arn
}
