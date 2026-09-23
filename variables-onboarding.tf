variable "applications" {
  description = <<-EOT
    Applications onboarded to the gateway, keyed by name.

    An application owns one or more services, and each service gets its own API
    Management subscription: that is the unit of attribution, revocation and rate
    limiting. Settings cascade, with a service overriding its application, which
    overrides onboarding_defaults. A setting left unset inherits, except that a
    service's alerting is opt-in, as in the reference: it must set enabled itself.

    access lists the identities that may use the application, by object id. Both
    kinds are granted read access to the application's own subscription secrets,
    and to no other.

    service_principal_ids are workloads: managed identities and service principals.
    They are bound into the product policy, so a token from any other identity is
    refused even with a valid key.

    group_ids are for people calling as themselves. The binding holds object ids of
    service principals only, so a person's call passes it only in an application
    that lists no service principals: give people and workloads separate
    applications.

    The rules in locals-onboarding-checks.tf are checked at plan time, whichever of
    this or applications_yaml is set.
  EOT
  type = map(object({
    owner         = string
    allow_tracing = optional(bool)

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
        enabled   = optional(bool)
        threshold = optional(number)
      })), {})
    }), {})

    services = map(object({
      capability     = string
      allowed_models = optional(list(string), [])
      allow_tracing  = optional(bool)

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
          enabled   = optional(bool)
          threshold = optional(number)
        })), {})
      }), {})
    }))
  }))
  default = {}
}

variable "onboarding_defaults" {
  description = "Settings every application inherits unless it overrides them. Limits apply across all of an application's services combined."
  type = object({
    allow_tracing = optional(bool, false)

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

  validation {
    condition = alltrue(concat(
      [for v in values(var.onboarding_defaults.limits) : v >= 1],
      [for k in keys(var.onboarding_defaults.content_safety.categories) : contains(["hate", "sexual", "self_harm", "violence"], k)],
      [for c in values(var.onboarding_defaults.content_safety.categories) : c.threshold >= 0 && c.threshold <= 7],
      [var.onboarding_defaults.alerting.threshold_percent >= 1 && var.onboarding_defaults.alerting.threshold_percent <= 100],
    ))
    error_message = "Every default limit must be at least 1, content-safety categories must be hate, sexual, self_harm or violence with thresholds 0 to 7, and alerting.threshold_percent must be 1 to 100."
  }
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
