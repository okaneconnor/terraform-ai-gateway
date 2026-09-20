# Maps the YAML contract onto the module's typed applications variable.
#
# The module takes typed HCL so Terraform can validate it, while teams keep writing
# YAML and raising pull requests against it. This file is the whole translation:
# copy it, point it at your own file, and the two stay in step.
locals {
  onboarding = yamldecode(file("${path.module}/onboarding.yaml"))

  # camelCase in YAML, snake_case in Terraform. Null entries drop out, so an
  # unset key inherits rather than overriding with null.
  applications = {
    for app in local.onboarding.applications : app.application => {
      owner = app.owner

      access = {
        service_principal_ids = try(app.accessType["service-principal"].ids, [])
        group_ids             = try(app.accessType["aad-group"].ids, [])
      }

      limits = {
        requests_per_minute = try(app.limits.requestsPerMinute, null)
        requests_per_day    = try(app.limits.requestsPerDay, null)
        tokens_per_minute   = try(app.limits.tokensPerMinute, null)
        daily_token_quota   = try(app.limits.dailyTokenQuota, null)
      }

      alerting = {
        enabled           = try(app.alerting.enabled, null)
        threshold_percent = try(app.alerting.thresholdPercent, null)
        notify_email      = try(app.alerting.notifyEmail, null)
      }

      content_safety = {
        enabled = try(app.contentSafety.enabled, null)
        categories = {
          for k, v in try(app.contentSafety.categories, {}) :
          local.category_keys[k] => { enabled = try(v.enabled, true), threshold = try(v.threshold, 4) }
        }
      }

      services = {
        for svc in app.services : svc.service => {
          capability     = svc.capability.api
          allowed_models = try(svc.capability.allowedModels, [])
          allow_tracing  = try(svc.allowTracing, false)

          limits = {
            requests_per_minute = try(svc.limits.requestsPerMinute, null)
            requests_per_day    = try(svc.limits.requestsPerDay, null)
            tokens_per_minute   = try(svc.limits.tokensPerMinute, null)
            daily_token_quota   = try(svc.limits.dailyTokenQuota, null)
          }

          alerting = {
            enabled           = try(svc.alerting.enabled, null)
            threshold_percent = try(svc.alerting.thresholdPercent, null)
            notify_email      = try(svc.alerting.notifyEmail, null)
          }

          content_safety = {
            enabled = try(svc.contentSafety.enabled, null)
            categories = {
              for k, v in try(svc.contentSafety.categories, {}) :
              local.category_keys[k] => { enabled = try(v.enabled, true), threshold = try(v.threshold, 4) }
            }
          }
        }
      }
    }
  }

  # The one category whose YAML spelling differs from the module's.
  category_keys = {
    hate     = "hate"
    sexual   = "sexual"
    selfHarm = "self_harm"
    violence = "violence"
  }
}
