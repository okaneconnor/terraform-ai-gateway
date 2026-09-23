# The reference validates its onboarding file in CI, before any plan runs. A published
# module has no CI of its own, so the same rules run here at plan time, against the
# applications whichever way they arrived. Each application collects every problem it
# has, so one plan reports them all, and the precondition in onboarding.tf fails the
# plan on any of them.
locals {
  onboarding_name_pattern = "^[a-z0-9]+(-[a-z0-9]+)*$"
  object_id_pattern       = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
  minutes_per_day         = 1440

  # Each daily cap, and the per-minute limit that bounds it.
  daily_caps = {
    requests_per_day  = "requests_per_minute"
    daily_token_quota = "tokens_per_minute"
  }

  application_services = { for name in keys(local.applications) : name => [
    for svc in values(local.services) : svc if svc.application == name
  ] }

  # A service's own limits over its application's, as the gateway applies them.
  service_effective_limits = { for key, svc in local.services : key => merge(local.applications[svc.application].limits, svc.limits) }

  # What an application's services claim for themselves, per limit, against its pool.
  service_limit_totals = { for name, app in local.applications : name => {
    for limit in keys(app.limits) : limit => sum(concat([0], [for svc in local.application_services[name] : lookup(svc.limits, limit, 0)]))
  } }

  # Every principal granted anywhere, to catch one identity claimed by two owners.
  principal_claims = flatten([for name, app in local.applications : [
    for id in concat(app.service_principal_ids, app.group_ids) : { id = id, application = name, owner = app.owner }
  ]])
  all_service_principal_ids = flatten([for app in values(local.applications) : app.service_principal_ids])
  all_group_ids             = flatten([for app in values(local.applications) : app.group_ids])

  category_keys = [for c in local.content_safety_categories : c.key]

  content_safety_configured = { for name, app in local.onboarded_applications : name => anytrue(concat(
    [app.content_safety.enabled != null, length(app.content_safety.categories) > 0],
    [for svc in values(app.services) : svc.content_safety.enabled != null || length(svc.content_safety.categories) > 0],
  )) }

  onboarding_problems = { for name, app in local.applications : name => distinct(flatten([
    # Names become product ids, subscription names and secret names.
    [for value in concat([name, app.owner], [for svc in local.application_services[name] : svc.service]) :
      "'${value}' is not a valid name: use 2 to 40 lowercase letters, digits and single hyphens"
      if length(regexall(local.onboarding_name_pattern, value)) == 0 || length(value) < 2 || length(value) > 40
    ],
    length(local.application_services[name]) == 0 ? ["it declares no services"] : [],

    # Access.
    length(app.service_principal_ids) + length(app.group_ids) == 0 ? ["it grants access to no principal, so nobody could use it"] : [],
    [for id in concat(app.service_principal_ids, app.group_ids) :
      "'${id}' is not an object id" if length(regexall(local.object_id_pattern, id)) == 0
    ],
    [for id in concat(app.service_principal_ids, app.group_ids) :
      "'${id}' is a placeholder: use the real object id" if id == "00000000-0000-0000-0000-000000000000"
    ],
    [for claim in local.principal_claims :
      "${claim.id} is also granted by '${claim.application}', owned by '${claim.owner}': an identity cannot be shared between owners"
      if claim.owner != app.owner && contains(concat(app.service_principal_ids, app.group_ids), claim.id)
    ],
    [for id in app.service_principal_ids :
      "${id} is listed as both a service principal and a group: an object id is one or the other" if contains(local.all_group_ids, id)
    ],
    [for id in app.group_ids :
      "${id} is listed as both a service principal and a group: an object id is one or the other" if contains(local.all_service_principal_ids, id)
    ],

    # Capabilities and models. A model the gateway does not serve would apply cleanly
    # and then fail every call.
    [for svc in local.application_services[name] :
      "service '${svc.service}' names capability '${svc.capability}', which is not enabled (enabled: ${join(", ", var.enabled_capabilities)})"
      if !contains(var.enabled_capabilities, svc.capability)
    ],
    [for svc in local.application_services[name] :
      "service '${svc.service}' allows no models: list at least one" if length(svc.models) == 0
    ],
    [for svc in local.application_services[name] : [
      for model in keys(svc.models) :
      "service '${svc.service}' allows model '${model}', which this gateway does not serve (serves: ${join(", ", sort(keys(local.model_routing)))})"
      if !contains(keys(local.model_routing), model)
    ]],

    # Limits. A daily cap its per-minute limit can never reach is dead configuration.
    [for limit, value in app.limits : "limits.${limit} must be at least 1, not ${value}" if value < 1],
    [for daily, per_minute in local.daily_caps :
      "limits.${daily} of ${app.limits[daily]} is unreachable: limits.${per_minute} of ${app.limits[per_minute]} caps a day at ${app.limits[per_minute] * local.minutes_per_day}"
      if app.limits[daily] > app.limits[per_minute] * local.minutes_per_day
    ],
    [for svc in local.application_services[name] : [
      for limit, value in svc.limits : "service '${svc.service}': limits.${limit} must be at least 1, not ${value}" if value < 1
    ]],
    [for svc in local.application_services[name] : [
      for daily, per_minute in local.daily_caps :
      "service '${svc.service}': limits.${daily} of ${local.service_effective_limits[svc.key][daily]} is unreachable: limits.${per_minute} of ${local.service_effective_limits[svc.key][per_minute]} caps a day at ${local.service_effective_limits[svc.key][per_minute] * local.minutes_per_day}"
      # Only a pair the service sets a side of, or the application's own problem repeats per service.
      if local.service_effective_limits[svc.key][daily] > local.service_effective_limits[svc.key][per_minute] * local.minutes_per_day
      && (contains(keys(svc.limits), daily) || contains(keys(svc.limits), per_minute))
    ]],
    [for limit, total in local.service_limit_totals[name] :
      "the services' own limits.${limit} add up to ${total}, more than the application's ${app.limits[limit]}"
      if total > app.limits[limit]
    ],

    # Alerting. Without these, an alert asked for is silently never created.
    app.alerting.enabled && app.alerting.notify_email == null ? ["alerting is enabled but has no notify_email"] : [],
    app.alerting.enabled && (app.alerting.threshold_percent < 1 || app.alerting.threshold_percent > 100) ? ["alerting.threshold_percent must be 1 to 100"] : [],
    [for svc in local.application_services[name] :
      "service '${svc.service}': alerting is enabled but has no notify_email" if svc.alerting.enabled && svc.alerting.notify_email == null
    ],
    [for svc in local.application_services[name] :
      "service '${svc.service}': alerting is enabled but the service sets no daily_token_quota of its own to alert against"
      if svc.alerting.enabled && svc.alerting.daily_token_quota == null
    ],
    [for svc in local.application_services[name] :
      "service '${svc.service}': alerting.threshold_percent must be 1 to 100"
      if svc.alerting.enabled && (svc.alerting.threshold_percent < 1 || svc.alerting.threshold_percent > 100)
    ],

    # Content safety.
    !var.enable_content_safety && local.content_safety_configured[name] ? ["content safety is configured, but enable_content_safety is false, so it would be silently ignored"] : [],
    [for category in keys(local.onboarded_applications[name].content_safety.categories) :
      "content safety category '${category}' is not one of hate, sexual, self_harm or violence (selfHarm in YAML)"
      if !contains(local.category_keys, category)
    ],
    [for svc_name, svc in local.onboarded_applications[name].services : [
      for category in keys(svc.content_safety.categories) :
      "service '${svc_name}': content safety category '${category}' is not one of hate, sexual, self_harm or violence (selfHarm in YAML)"
      if !contains(local.category_keys, category)
    ]],
    [for c in local.content_safety_categories :
      "content safety category '${c.key}' has threshold ${app.content_safety.categories[c.key].threshold}: it must be 0 to 7"
      if app.content_safety.categories[c.key].threshold < 0 || app.content_safety.categories[c.key].threshold > 7
    ],
    [for svc in local.application_services[name] : [
      for c in local.content_safety_categories :
      "service '${svc.service}': content safety category '${c.key}' has threshold ${svc.content_safety.categories[c.key].threshold}: it must be 0 to 7"
      # Only where the service sets its own, or an application's bad value repeats per service.
      if svc.content_safety.categories[c.key].threshold != app.content_safety.categories[c.key].threshold
      && (svc.content_safety.categories[c.key].threshold < 0 || svc.content_safety.categories[c.key].threshold > 7)
    ]],
  ])) }
}
