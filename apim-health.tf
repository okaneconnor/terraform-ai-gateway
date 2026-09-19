resource "azurerm_api_management_api" "health" {
  name                  = "health"
  resource_group_name   = local.resource_group_name
  api_management_name   = azurerm_api_management.gateway.name
  revision              = "1"
  display_name          = "Health"
  path                  = var.health_api_path
  protocols             = ["https"]
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "health_get" {
  operation_id        = "health-get"
  api_name            = azurerm_api_management_api.health.name
  api_management_name = azurerm_api_management.gateway.name
  resource_group_name = local.resource_group_name
  display_name        = "Health"
  method              = "GET"
  url_template        = "/"
}

resource "azurerm_api_management_api_policy" "health" {
  api_name            = azurerm_api_management_api.health.name
  api_management_name = azurerm_api_management.gateway.name
  resource_group_name = local.resource_group_name
  xml_content         = file("${path.module}/policies/api-health-policy.xml")
}
