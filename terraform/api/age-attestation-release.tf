data "terraform_remote_state" "age_attestation_identity" {
  count   = local.age_attestation_authority_enabled ? 1 : 0
  backend = "s3"

  config = {
    bucket       = var.state_bucket_name
    key          = "${var.state_key_prefix}/${var.environment}/identity-workflows.tfstate"
    region       = var.state_bucket_region
    encrypt      = true
    use_lockfile = true
  }
}

