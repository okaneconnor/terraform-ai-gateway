locals {
  # Template inputs for the per-application product policy. Every list is sorted so a
  # rendered policy is stable between plans.
  application_policy_inputs = { for name, app in local.applications : name => {
    application = name
    team        = app.owner
    env         = coalesce(var.environment, "default")

    # The token's object id is matched against this, so a key alone is not enough to
    # use an application another team owns.
    allowed_principals = app.service_principal_ids

    requests_per_minute = app.limits.requests_per_minute
    requests_per_day    = app.limits.requests_per_day
    tokens_per_minute   = app.limits.tokens_per_minute
    daily_token_quota   = app.limits.daily_token_quota

    enable_content_safety              = var.enable_content_safety
    application_content_safety_enabled = app.content_safety.enabled
    application_categories = [
      for c in local.content_safety_categories : { name = c.name, threshold = app.content_safety.categories[c.key].threshold }
      if app.content_safety.categories[c.key].enabled
    ]

    capabilities = [
      for key in sort([for k, s in local.services : k if s.application == name]) : {
        subscription_name = local.services[key].subscription_name
        api               = local.services[key].capability
        request_shape     = local.services[key].request_shape
        models = [
          for m in sort(keys(local.services[key].models)) : { client_name = m, deployment = local.services[key].models[m] }
        ]
      }
    ]

    application_services = [
      for key in sort([for k, s in local.services : k if s.application == name]) : {
        key                    = key
        subscription_name      = local.services[key].subscription_name
        request_shape          = local.services[key].request_shape
        content_safety_enabled = local.services[key].content_safety.enabled
        categories = [
          for c in local.content_safety_categories : { name = c.name, threshold = local.services[key].content_safety.categories[c.key].threshold }
          if local.services[key].content_safety.categories[c.key].enabled
        ]
      }
    ]

    chat_subscriptions = sort([
      for k, s in local.services : s.subscription_name if s.application == name && s.request_shape == "chat"
    ])

    # A subscription is matched with the API it was granted, so a chat key presented to
    # another API reaches the capability check (403) instead of the chat request checks.
    chat_match_conditions = [
      for k, s in local.services :
      "context.Subscription.Name == &quot;${s.subscription_name}&quot; &amp;&amp; (context.Api.Id == &quot;${s.capability}&quot; || context.Api.Name == &quot;${s.capability}&quot;)"
      if s.application == name && s.request_shape == "chat"
    ]

    document_subscriptions = sort([
      for k, s in local.services : s.subscription_name if s.application == name && s.request_shape == "document"
    ])

    service_limits = [
      for key in sort([for k, s in local.services : k if s.application == name && length(s.limits) > 0]) : {
        subscription_name = local.services[key].subscription_name
        limits            = local.services[key].limits
      }
    ]
  } }
}
