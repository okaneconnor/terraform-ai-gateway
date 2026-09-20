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

  # The same two rules reach the YAML path through a precondition in
  # onboarding.tf, because a variable validation can only see its own variable.
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

variable "applications_yaml" {
  description = <<-EOT
    The same onboarding declaration as `applications`, in the YAML shape teams
    prefer to edit, passed decoded:

        applications_yaml = yamldecode(file("onboarding.yaml"))

    The module translates it: camelCase to snake_case, the accessType shape to
    access, lists to maps keyed by name, and selfHarm to self_harm. A key left out
    inherits rather than overriding, exactly as in `applications`.

    The YAML lives in your repository, and teams raise pull requests against you to
    add themselves. A published module cannot read a file from a consumer's
    repository, which is why the decoding happens on your side and the decoded value
    is what comes in.

    Set this or `applications`, not both.
  EOT
  type        = any
  default     = null

  validation {
    condition     = var.applications_yaml == null || length(var.applications) == 0
    error_message = "Set applications or applications_yaml, not both."
  }

  validation {
    condition     = var.applications_yaml == null || can([for a in var.applications_yaml.applications : a.application])
    error_message = "applications_yaml must decode to an object with an applications list, each entry having an application name."
  }
}
