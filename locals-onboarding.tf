locals {
  capability_catalogue = {
    "chat-completions-v1" = {
      display_name  = "Chat Completions"
      path          = "ai/v1"
      revision      = "1"
      spec          = "chat-completions-v1.yaml"
      policy        = "api-chat-completions-v1.xml"
      api_version   = "2024-10-21"
      request_shape = "chat"
    }
  }

  capabilities = { for name in var.enabled_capabilities : name => local.capability_catalogue[name] }

  model_routing = length(var.model_routing) > 0 ? var.model_routing : { for k, v in var.model_deployments : k => k }

  # A fixed order, so a rendered policy does not churn between plans. The key is
  # ours; the name is what the content-safety policy expects.
  content_safety_categories = [
    { key = "hate", name = "Hate" },
    { key = "sexual", name = "Sexual" },
    { key = "self_harm", name = "SelfHarm" },
    { key = "violence", name = "Violence" },
  ]

  # The YAML spelling of a content-safety category, mapped to ours. Only selfHarm
  # differs, but going through the map keeps an unknown key from passing silently.
  yaml_category_keys = {
    hate     = "hate"
    sexual   = "sexual"
    selfHarm = "self_harm"
    violence = "violence"
  }

  # applications_yaml carries the shape teams edit. Translating it here rather than
  # in the consumer's repository means every consumer gets the same behaviour, and a
  # correction reaches them with the module version. A key absent from the YAML
  # becomes null, so it inherits rather than overriding.
  applications_from_yaml = var.applications_yaml == null ? {} : {
    for app in var.applications_yaml.applications : app.application => {
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
          local.yaml_category_keys[k] => { enabled = try(v.enabled, true), threshold = try(v.threshold, 4) }
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
              local.yaml_category_keys[k] => { enabled = try(v.enabled, true), threshold = try(v.threshold, 4) }
            }
          }
        }
      }
    }
  }

  # One shape from here on, whichever way it arrived.
  onboarded_applications = var.applications_yaml != null ? local.applications_from_yaml : var.applications

  applications = {
    for name, app in local.onboarded_applications : name => {
      owner                 = app.owner
      service_principal_ids = sort(distinct(app.access.service_principal_ids))
      group_ids             = sort(distinct(app.access.group_ids))

      limits = {
        requests_per_minute = coalesce(app.limits.requests_per_minute, var.onboarding_defaults.limits.requests_per_minute)
        requests_per_day    = coalesce(app.limits.requests_per_day, var.onboarding_defaults.limits.requests_per_day)
        tokens_per_minute   = coalesce(app.limits.tokens_per_minute, var.onboarding_defaults.limits.tokens_per_minute)
        daily_token_quota   = coalesce(app.limits.daily_token_quota, var.onboarding_defaults.limits.daily_token_quota)
      }

      alerting = {
        enabled           = coalesce(app.alerting.enabled, var.onboarding_defaults.alerting.enabled)
        threshold_percent = coalesce(app.alerting.threshold_percent, var.onboarding_defaults.alerting.threshold_percent)
        notify_email      = try(coalesce(app.alerting.notify_email, var.onboarding_defaults.alerting.notify_email), null)
      }

      content_safety = {
        enabled = coalesce(app.content_safety.enabled, var.onboarding_defaults.content_safety.enabled)
        categories = {
          for c in local.content_safety_categories : c.key => {
            enabled   = try(app.content_safety.categories[c.key].enabled, try(var.onboarding_defaults.content_safety.categories[c.key].enabled, true))
            threshold = try(app.content_safety.categories[c.key].threshold, try(var.onboarding_defaults.content_safety.categories[c.key].threshold, 4))
          }
        }
      }
    }
  }

  services = { for s in flatten([
    for app_name, app in local.onboarded_applications : [
      for svc_name, svc in app.services : {
        key         = "${app_name}-${svc_name}"
        application = app_name
        service     = svc_name
        owner       = app.owner

        # The subscription name identifies the service at runtime: the product policy
        # matches on it and the metric dimensions carry it.
        subscription_name = "${app_name}-${svc_name}"

        capability    = svc.capability
        request_shape = local.capability_catalogue[svc.capability].request_shape
        allow_tracing = svc.allow_tracing

        models = { for m in svc.allowed_models : m => lookup(local.model_routing, m, m) }

        # Only what the service overrides. Anything unset draws on the application's
        # shared pool rather than getting a limit of its own.
        limits = { for k, v in {
          requests_per_minute = svc.limits.requests_per_minute
          requests_per_day    = svc.limits.requests_per_day
          tokens_per_minute   = svc.limits.tokens_per_minute
          daily_token_quota   = svc.limits.daily_token_quota
        } : k => v if v != null }

        alerting = {
          enabled           = coalesce(svc.alerting.enabled, false)
          threshold_percent = coalesce(svc.alerting.threshold_percent, local.applications[app_name].alerting.threshold_percent)
          notify_email      = try(coalesce(svc.alerting.notify_email, local.applications[app_name].alerting.notify_email), null)
          daily_token_quota = svc.limits.daily_token_quota
        }

        content_safety = {
          enabled = coalesce(svc.content_safety.enabled, local.applications[app_name].content_safety.enabled)
          categories = {
            for c in local.content_safety_categories : c.key => {
              enabled   = try(svc.content_safety.categories[c.key].enabled, local.applications[app_name].content_safety.categories[c.key].enabled)
              threshold = try(svc.content_safety.categories[c.key].threshold, local.applications[app_name].content_safety.categories[c.key].threshold)
            }
          }
        }
      }
    ]
  ]) : s.key => s }

  # One link per application and capability: a product grants only what its services
  # actually use.
  product_apis = { for pair in flatten([
    for app_name, app in local.onboarded_applications : [
      for capability in distinct([for svc in values(app.services) : svc.capability]) : {
        key         = "${app_name}-${capability}"
        application = app_name
        capability  = capability
      }
    ]
  ]) : pair.key => pair }

  # Scoped per secret, not per vault, so one team cannot read another's key.
  service_secret_readers = { for r in flatten([
    for key, svc in local.services : concat(
      [for id in local.applications[svc.application].service_principal_ids : {
        key = "${key}-sp-${id}", service_key = key, principal_id = id, principal_type = "ServicePrincipal"
      }],
      [for id in local.applications[svc.application].group_ids : {
        key = "${key}-group-${id}", service_key = key, principal_id = id, principal_type = "Group"
      }],
    )
  ]) : r.key => r }

  alerting_applications = {
    for name, app in local.applications : name => {
      notify_email      = app.alerting.notify_email
      threshold_percent = app.alerting.threshold_percent
      daily_token_quota = app.limits.daily_token_quota
      threshold_tokens  = ceil(app.limits.daily_token_quota * app.alerting.threshold_percent / 100)
    }
    if app.alerting.enabled && app.alerting.notify_email != null
  }

  alerting_services = {
    for key, svc in local.services : key => {
      application       = svc.application
      service           = svc.service
      subscription_name = svc.subscription_name
      notify_email      = svc.alerting.notify_email
      threshold_percent = svc.alerting.threshold_percent
      threshold_tokens  = ceil(svc.alerting.daily_token_quota * svc.alerting.threshold_percent / 100)
    }
    if svc.alerting.enabled && svc.alerting.notify_email != null && svc.alerting.daily_token_quota != null
  }
}
