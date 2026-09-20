# Token consumption exists only as a metric the policies emit, so an alert is a
# scheduled query against Application Insights rather than a metric alert.
resource "azurerm_monitor_action_group" "application_quota" {
  for_each = local.alerting_applications

  name                = "ag-${each.key}-quota-${local.name_base}"
  resource_group_name = local.resource_group_name
  short_name          = substr(each.key, 0, 12)

  email_receiver {
    name                    = "application-email"
    email_address           = each.value.notify_email
    use_common_alert_schema = true
  }

  lifecycle {
    precondition {
      condition     = length(distinct([for k in keys(local.alerting_applications) : substr(k, 0, 12)])) == length(keys(local.alerting_applications))
      error_message = "Two applications with alerting enabled share the first 12 characters of their name, which Azure caps an action group's short name at. Rename one."
    }
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "application_quota" {
  for_each = local.alerting_applications

  name                = "alert-${each.key}-quota-${local.name_base}"
  resource_group_name = local.resource_group_name
  location            = var.location

  evaluation_frequency = "PT1H"
  window_duration      = "P1D"
  scopes               = [azurerm_log_analytics_workspace.platform.id]
  severity             = 4

  criteria {
    query                   = <<-QUERY
      AppMetrics
      | where _ResourceId =~ '${azurerm_application_insights.gateway.id}'
      | where TimeGenerated >= startofday(now())
      | where Name == 'Total Tokens'
      | where tostring(Properties['Application']) == '${each.key}'
      | summarize TotalTokens = sum(Sum)
    QUERY
    metric_measure_column   = "TotalTokens"
    time_aggregation_method = "Total"
    operator                = "GreaterThanOrEqual"
    threshold               = each.value.threshold_tokens

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.application_quota[each.key].id]
  }

  auto_mitigation_enabled = true
  display_name            = "${each.key} daily token quota"
  description             = "${each.key} has reached ${each.value.threshold_percent}% of its daily quota of ${each.value.daily_token_quota} tokens."
}

resource "azurerm_monitor_action_group" "service_quota" {
  for_each = local.alerting_services

  name                = "ag-${each.key}-quota-${local.name_base}"
  resource_group_name = local.resource_group_name
  short_name          = substr(each.key, 0, 12)

  email_receiver {
    name                    = "service-email"
    email_address           = each.value.notify_email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "service_quota" {
  for_each = local.alerting_services

  name                = "alert-${each.key}-quota-${local.name_base}"
  resource_group_name = local.resource_group_name
  location            = var.location

  evaluation_frequency = "PT1H"
  window_duration      = "P1D"
  scopes               = [azurerm_log_analytics_workspace.platform.id]
  severity             = 4

  criteria {
    query                   = <<-QUERY
      AppMetrics
      | where _ResourceId =~ '${azurerm_application_insights.gateway.id}'
      | where TimeGenerated >= startofday(now())
      | where Name == 'Total Tokens'
      | where tostring(Properties['Application']) == '${each.value.application}'
      | where tostring(Properties['Subscription Name']) == '${each.value.subscription_name}'
      | summarize TotalTokens = sum(Sum)
    QUERY
    metric_measure_column   = "TotalTokens"
    time_aggregation_method = "Total"
    operator                = "GreaterThanOrEqual"
    threshold               = each.value.threshold_tokens

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.service_quota[each.key].id]
  }

  auto_mitigation_enabled = true
  display_name            = "${each.value.application} ${each.value.service} daily token quota"
  description             = "${each.value.service} has reached ${each.value.threshold_percent}% of its daily token quota."
}
