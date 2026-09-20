resource "azurerm_api_management_api" "capability" {
  for_each = local.capabilities

  name                = each.key
  resource_group_name = local.resource_group_name
  api_management_name = azurerm_api_management.gateway.name
  revision            = each.value.revision
  display_name        = each.value.display_name
  path                = each.value.path
  protocols           = ["https"]

  # Products are linked by the onboarding layer, so an API no application is
  # onboarded to is reachable by nobody.
  subscription_required = true

  import {
    content_format = "openapi"
    content_value  = file("${path.module}/specs/${each.value.spec}")
  }
}

resource "azurerm_api_management_api_policy" "capability" {
  for_each = local.capabilities

  api_name            = azurerm_api_management_api.capability[each.key].name
  api_management_name = azurerm_api_management.gateway.name
  resource_group_name = local.resource_group_name

  xml_content = templatefile("${path.module}/policies/${each.value.policy}", {
    api_version           = each.value.api_version
    backend_id            = azurerm_api_management_backend.ai_services.name
    model_routing         = local.model_routing
    enable_content_safety = var.enable_content_safety
  })

  depends_on = [azurerm_api_management_policy_fragment.baseline]
}

# azurerm cannot set the metrics flag on an API diagnostic, and without it the token
# metrics the policies emit never reach Application Insights.
resource "azapi_resource" "capability_diagnostic" {
  for_each = local.capabilities

  type      = "Microsoft.ApiManagement/service/apis/diagnostics@2024-05-01"
  name      = "applicationinsights"
  parent_id = azurerm_api_management_api.capability[each.key].id

  body = {
    properties = {
      loggerId = azurerm_api_management_logger.app_insights.id
      metrics  = true
      sampling = {
        samplingType = "fixed"
        percentage   = var.application_insights.sampling_percentage
      }
    }
  }
}
