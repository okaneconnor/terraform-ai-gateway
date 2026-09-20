variable "applications" {
  description = <<-EOT
    Applications onboarded to the gateway, keyed by name.

    An application owns one or more services, and each service gets its own API
    Management subscription: that is the unit of attribution, revocation and rate
    limiting. Settings cascade, with a service overriding its application, which
    overrides onboarding_defaults.

    access lists the identities that may use the application. service_principal_ids
    are bound into the product policy, so a token from any other identity is refused
    even with a valid key. Both kinds are granted read access to their own
    subscription secret, and to no other.
  EOT
  type = map(object({
    owner = string

    access = object({
      service_principal_ids = optional(list(string), [])
      group_ids             = optional(list(string), [])
    })

    limits = optional(object({
      requests_per_minute = optional(number)
      requests_per_day    = optional(number)
      tokens_per_minute   = optional(number)
      daily_token_quota   = optional(number)
    }), {})

    alerting = optional(object({
      enabled           = optional(bool)
      threshold_percent = optional(number)
      notify_email      = optional(string)
    }), {})

    content_safety = optional(object({
      enabled = optional(bool)
      categories = optional(map(object({
        enabled   = optional(bool, true)
        threshold = optional(number, 4)
      })), {})
    }), {})

    services = map(object({
      capability     = string
      allowed_models = optional(list(string), [])
      allow_tracing  = optional(bool, false)

      limits = optional(object({
        requests_per_minute = optional(number)
        requests_per_day    = optional(number)
        tokens_per_minute   = optional(number)
        daily_token_quota   = optional(number)
      }), {})

      alerting = optional(object({
        enabled           = optional(bool)
        threshold_percent = optional(number)
        notify_email      = optional(string)
      }), {})

      content_safety = optional(object({
        enabled = optional(bool)
        categories = optional(map(object({
          enabled   = optional(bool, true)
          threshold = optional(number, 4)
        })), {})
      }), {})
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for app in var.applications : alltrue([
        for svc in values(app.services) : contains(var.enabled_capabilities, svc.capability)
      ])
    ])
    error_message = "Every service must name a capability listed in enabled_capabilities."
  }

  validation {
    condition = alltrue([
      for app in var.applications :
      length(app.access.service_principal_ids) + length(app.access.group_ids) > 0
    ])
    error_message = "Every application must grant access to at least one principal, or nobody can use it."
  }
}

variable "onboarding_defaults" {
  description = "Settings every application inherits unless it overrides them. Limits apply across all of an application's services combined."
  type = object({
    limits = optional(object({
      requests_per_minute = optional(number, 30)
      requests_per_day    = optional(number, 1000)
      tokens_per_minute   = optional(number, 10000)
      daily_token_quota   = optional(number, 250000)
    }), {})

    alerting = optional(object({
      enabled           = optional(bool, false)
      threshold_percent = optional(number, 80)
      notify_email      = optional(string)
    }), {})

    content_safety = optional(object({
      enabled = optional(bool, true)
      categories = optional(map(object({
        enabled   = optional(bool, true)
        threshold = optional(number, 4)
      })), {})
    }), {})
  })
  default = {}
}

variable "deliver_keys_to_key_vault" {
  description = <<-EOT
    Write each service's subscription key into the platform vault, and grant that
    service's principals read access to that secret alone.

    Requires Terraform to run somewhere the vault's private endpoint is reachable,
    because the vault has no public access. The reference implementation runs its
    onboarding stage on a self-hosted agent inside the network for exactly this
    reason, while the rest of its deployment runs on hosted agents.

    Turn it off when Terraform runs outside the network. Teams then read their key
    from the subscription itself, which is an ARM call needing no network access:

      az rest --method post --url "https://management.azure.com<subscription id>/listSecrets?api-version=2024-05-01"

    The subscription ids are in the `subscriptions` output.
  EOT
  type        = bool
  default     = true
}
