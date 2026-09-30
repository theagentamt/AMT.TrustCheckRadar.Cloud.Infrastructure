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

output "age_attestation_post_confirmation_candidate" {
  description = "Immutable PostConfirmation half of the coordinated age-attestation release"
  value = {
    enabled          = var.age_attestation_contract != null
    contract_version = "1.0.0-candidate.1"
    artifact_pins    = try(var.age_attestation_contract.artifacts, null)
    installed_post_confirmation = var.age_attestation_contract == null ? null : {
      release_id     = var.age_attestation_contract.artifacts.post_confirmation.release_id
      object_version = aws_lambda_function.post_confirmation.s3_object_version
      source_hash    = aws_lambda_function.post_confirmation.source_code_hash
    }
  }
}
