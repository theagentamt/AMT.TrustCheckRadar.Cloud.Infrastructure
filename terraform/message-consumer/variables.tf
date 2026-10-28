variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Unknown environment."
  }
}
variable "project_name" {
  type    = string
  default = "trustcheckradar"
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "enabled" {
  description = "Provision the isolated Dev runtimes and authenticated routes. Execution remains separately gated."
  type        = bool
  default     = false
  validation {
    condition     = !var.enabled || (var.environment == "dev" && var.project_name == "trustcheckradar" && var.aws_region == "us-east-1" && var.deployment != null)
    error_message = "Only a version-pinned TrustCheckRadar Dev candidate in us-east-1 can be provisioned."
  }
}

variable "engineering_subjects" {
  description = "Exact synthetic Dev Cognito subjects allowed during bounded rules-only qualification. Empty never means public access."
  type        = set(string)
  default     = []
  validation {
    condition     = length(var.engineering_subjects) <= 3 && alltrue([for subject in var.engineering_subjects : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", subject))])
    error_message = "Supply at most three exact synthetic Cognito UUID subjects."
  }
}

variable "preserved_engineering_subjects_json" {
  description = "Exact existing rules-only allowlist bytes. Membership must equal engineering_subjects; this never admits another subject. Null keeps canonical encoding."
  type        = string
  default     = null
  validation {
    condition = var.preserved_engineering_subjects_json == null ? true : try(
      var.enabled && var.environment == "dev" && var.candidate3_rules_only_enabled && !var.message_ai_primary_enabled &&
      length(var.preserved_engineering_subjects_json) <= 512 &&
      length(jsondecode(var.preserved_engineering_subjects_json)) == 2 &&
      toset(jsondecode(var.preserved_engineering_subjects_json)) == var.engineering_subjects &&
    length(jsondecode(var.preserved_engineering_subjects_json)) == length(var.engineering_subjects), false)
    error_message = "Preserved JSON must contain each admitted rules-only Dev subject exactly once; AI and other environments cannot use it."
  }
}

variable "authority_configuration" {
  description = "Explicit V1 authority horizons; receipts and counters retain the approved seven-day boundary."
  type = object({
    operation_validity_seconds = number
    worker_settlement_seconds  = number
    reconciliation_seconds     = number
    counter_retention_seconds  = number
  })
  default = null
  validation {
    condition = var.authority_configuration == null ? true : (
      alltrue([for value in values(var.authority_configuration) : value > 0 && value == floor(value)]) &&
      var.authority_configuration.operation_validity_seconds + var.authority_configuration.worker_settlement_seconds + var.authority_configuration.reconciliation_seconds <= 604800 &&
      var.authority_configuration.counter_retention_seconds == 604800
    )
    error_message = "Authority horizons must be integral and bounded by the seven-day receipt policy."
  }
}

variable "provider_budget" {
  description = "Aggregate Dev provider circuit limits. These cap service attempts and do not change customer allowances."
  type = object({
    window_seconds          = number
    max_attempts_per_window = number
    max_failures_per_window = number
  })
  default = null
  validation {
    condition = var.provider_budget == null ? true : (
      var.provider_budget.window_seconds == floor(var.provider_budget.window_seconds) &&
      var.provider_budget.window_seconds >= 60 && var.provider_budget.window_seconds <= 86400 &&
      var.provider_budget.max_attempts_per_window == floor(var.provider_budget.max_attempts_per_window) &&
      var.provider_budget.max_attempts_per_window >= 1 && var.provider_budget.max_attempts_per_window <= 100000 &&
      var.provider_budget.max_failures_per_window == floor(var.provider_budget.max_failures_per_window) &&
      var.provider_budget.max_failures_per_window >= 1 &&
      var.provider_budget.max_failures_per_window <= var.provider_budget.max_attempts_per_window
    )
    error_message = "Provider limits must be positive bounded integers and failures cannot exceed attempts."
  }
}

variable "api_gateway" {
  description = "Existing Dev HTTP API and shared reviewed JWT authorizer; this root owns only the message routes."
  type = object({
    api_id        = string
    execution_arn = string
    authorizer_id = string
  })
  default = null
  validation {
    condition = var.api_gateway == null ? true : (
      can(regex("^[a-z0-9]{10}$", var.api_gateway.api_id)) &&
      var.api_gateway.execution_arn == "arn:aws:execute-api:us-east-1:107827791950:${var.api_gateway.api_id}" &&
      can(regex("^[a-z0-9]+$", var.api_gateway.authorizer_id))
    )
    error_message = "Use the exact same-account Dev API and existing JWT authorizer."
  }
}

variable "activate_rules_engineering" {
  description = "Existing allowlisted Dev route admission. AI execution requires its separate default-off qualified configuration."
  type        = bool
  default     = false
  validation {
    condition = !var.activate_rules_engineering || (
      var.enabled && var.environment == "dev" && length(var.engineering_subjects) > 0 &&
      var.authority_configuration != null && var.provider_budget != null && var.api_gateway != null &&
      local.authority_maintenance_ready
    )
    error_message = "Message admission requires provisioned Dev routes, exact subjects, horizons/caps and same-table versioned shared maintenance with worker and schedule enabled and the explicit Dev alarm-removal policy."
  }
}
variable "deployment" {
  description = "Immutable reviewed packages and existing authority dependencies; never secret values."
  type = object({
    artifacts = map(object({
      bucket         = string
      key            = string
      object_version = string
      source_hash    = string
    }))
    users_table_arn           = string
    devices_table_arn         = string
    deletion_table_arn        = string
    authority_table_arn       = string
    authority_hmac_secret_arn = string
    assessment_alias_arn      = string
    cognito_issuer            = string
    cognito_app_client_id     = string
  })
  default = null
  validation {
    condition = var.deployment == null ? true : try(
      toset(keys(var.deployment.artifacts)) == toset(["consumer", "evaluator"]) &&
      length(toset([for a in values(var.deployment.artifacts) : split("/", a.key)[1]])) == 1 &&
      alltrue([for name, a in var.deployment.artifacts :
        a.bucket == "${var.project_name}-${var.environment}-${split(":", var.deployment.authority_table_arn)[4]}-artifacts" &&
        can(regex("^releases/[a-f0-9]{40}/${ { consumer = "message_consumer", evaluator = "message_evaluator" }[name]}\\.zip$", a.key)) &&
        length(trimspace(a.object_version)) > 0 && a.object_version != "null" &&
        can(regex("^[A-Za-z0-9+/]{43}=$", a.source_hash))
      ]) &&
      alltrue([for suffix, arn in { users = var.deployment.users_table_arn, device-bindings = var.deployment.devices_table_arn, deletion-ledger = var.deployment.deletion_table_arn, purchase-entitlements = var.deployment.authority_table_arn } :
        can(regex("^arn:aws:dynamodb:${var.aws_region}:[0-9]{12}:table/${var.project_name}-${var.environment}-${suffix}$", arn))
      ]) &&
      can(regex("^arn:aws:secretsmanager:${var.aws_region}:[0-9]{12}:secret:${var.project_name}/${var.environment}/v1-authority-hmac-[A-Za-z0-9]{6}$", var.deployment.authority_hmac_secret_arn)) &&
      can(regex("^arn:aws:lambda:${var.aws_region}:[0-9]{12}:function:${var.project_name}-${var.environment}-url-assessment:live$", var.deployment.assessment_alias_arn)) &&
      can(regex("^https://cognito-idp\\.${var.aws_region}\\.amazonaws\\.com/${var.aws_region}_[A-Za-z0-9]+$", var.deployment.cognito_issuer)) &&
    can(regex("^[a-z0-9]+$", var.deployment.cognito_app_client_id)), false)
    error_message = "Use exact environment-scoped dependencies and message consumer/evaluator packages from one immutable release."
  }
}

variable "candidate3_rules_only_enabled" {
  description = "Trusted candidate.3 deterministic execution; AI, Google and the provider circuit remain closed."
  type        = bool
  default     = false
  validation {
    condition = !var.candidate3_rules_only_enabled || (var.activate_rules_engineering && (length(var.engineering_subjects) == 1 || (
      length(var.engineering_subjects) == 2 &&
      sha256(jsonencode(sort(tolist(var.engineering_subjects)))) == "ea905c7184be88586e8a0a5745319bf0fdeef29734b57af80c9c048cd8e353d1"
    )))
    error_message = "Candidate.3 requires one qualified subject or the exact existing two-subject Dev scope; no new cohort is admitted."
  }
}
variable "governed_history_settlement_enabled" {
  description = "Project typed content-free History in the existing atomic receipt settlement; enable only after the index and source are qualified."
  type        = bool
  default     = false
  validation {
    condition     = !var.governed_history_settlement_enabled || var.activate_rules_engineering
    error_message = "History settlement requires existing authority admission/maintenance. Its configuration may remain while AI is paused so settled/reconciling receipts retain History semantics; it never enables an execution profile."
  }
}

variable "message_ai_primary_enabled" {
  description = "Normal AI-primary application behavior; default off. Activation, spending and secret/IAM application need separate approval."
  type        = bool
  default     = false
  validation {
    condition = !var.message_ai_primary_enabled || (
      var.activate_rules_engineering && !var.candidate3_rules_only_enabled && var.ai_configuration != null &&
      (length(var.engineering_subjects) == 1 || (length(var.engineering_subjects) == 2 &&
      sha256(jsonencode(sort(tolist(var.engineering_subjects)))) == "7dfa1b8193c7721659824436665ce800edc740fe396b89547725df371aafc09c"))
    )
    error_message = "AI-primary needs explicit complete configuration, existing admission/maintenance, no rules-only conflict and the unchanged qualified subject scope."
  }
}

variable "dev_staging_secret_arn" {
  description = "Separately approved Dev IAM preparation for the existing OpenAI secret and three budget attributes. Does not activate AI, choose runtime configuration or attest qualification."
  type        = string
  default     = null
  validation {
    condition = var.dev_staging_secret_arn == null ? true : (
      var.enabled && !var.message_ai_primary_enabled &&
      var.environment == "dev" && var.project_name == "trustcheckradar" && var.aws_region == "us-east-1" &&
      data.aws_caller_identity.current.account_id == "107827791950" &&
      var.dev_staging_secret_arn == "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/openai-uHKddW"
    )
    error_message = "Staged permissions require the enabled, AI-off Dev deployment in account 107827791950/us-east-1 and its exact existing OpenAI secret. Clear staging permission selection before AI activation."
  }
}

variable "ai_configuration" {
  description = "Nonsecret normal provider configuration. No model, monetary budget or qualification is chosen by default; artifacts must independently contain the matching accepted qualification evidence."
  type = object({
    secret_arn                    = string
    qualification_id              = string
    qualification_evidence_sha256 = string
    timeout_ms                    = number
    max_nano_usd_per_window       = number
    cost_policy = object({
      model                 = string
      contextTokens         = number
      maxOutputTokens       = number
      inputNanoUsdPerToken  = number
      outputNanoUsdPerToken = number
    })
  })
  default = null
  validation {
    condition = var.ai_configuration == null ? true : (
      can(regex("^arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/openai-[A-Za-z0-9]{6}$", var.ai_configuration.secret_arn)) &&
      can(regex("^[A-Za-z0-9_-]{1,64}$", var.ai_configuration.qualification_id)) &&
      can(regex("^[a-f0-9]{64}$", var.ai_configuration.qualification_evidence_sha256)) &&
      can(regex("^[A-Za-z0-9._-]+-20[0-9]{2}-[0-9]{2}-[0-9]{2}$", var.ai_configuration.cost_policy.model)) &&
      alltrue([for n in [var.ai_configuration.timeout_ms, var.ai_configuration.max_nano_usd_per_window,
        var.ai_configuration.cost_policy.contextTokens, var.ai_configuration.cost_policy.maxOutputTokens,
      var.ai_configuration.cost_policy.inputNanoUsdPerToken, var.ai_configuration.cost_policy.outputNanoUsdPerToken] : n == floor(n)]) &&
      var.ai_configuration.timeout_ms >= 250 && var.ai_configuration.timeout_ms <= 8000 &&
      var.ai_configuration.cost_policy.contextTokens >= 1 && var.ai_configuration.cost_policy.contextTokens <= 2000000 &&
      var.ai_configuration.cost_policy.maxOutputTokens >= 128 && var.ai_configuration.cost_policy.maxOutputTokens <= 512 &&
      var.ai_configuration.cost_policy.maxOutputTokens <= var.ai_configuration.cost_policy.contextTokens &&
      var.ai_configuration.cost_policy.inputNanoUsdPerToken >= 1 && var.ai_configuration.cost_policy.inputNanoUsdPerToken <= 1000000000 &&
      var.ai_configuration.cost_policy.outputNanoUsdPerToken >= 1 && var.ai_configuration.cost_policy.outputNanoUsdPerToken <= 1000000000 &&
      var.ai_configuration.max_nano_usd_per_window >= (
        var.ai_configuration.cost_policy.contextTokens * var.ai_configuration.cost_policy.inputNanoUsdPerToken +
      var.ai_configuration.cost_policy.maxOutputTokens * var.ai_configuration.cost_policy.outputNanoUsdPerToken) &&
      var.ai_configuration.max_nano_usd_per_window <= 1000000000000000000
    )
    error_message = "Supply exact same-account secret metadata, accepted evidence identity, dated model, bounded integral cost/timeout values and enough currency for one full-context reservation."
  }
}

variable "url_assessment_enabled" {
  description = "Independent URL invocation permission. Message AI never opens this gate; default deny."
  type        = bool
  default     = false
  validation {
    condition     = !var.url_assessment_enabled || (var.activate_rules_engineering && !var.candidate3_rules_only_enabled)
    error_message = "URL access requires its separate reviewed admission; rules-only mode cannot invoke it."
  }
}
