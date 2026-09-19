resource "azurerm_log_analytics_workspace" "platform" {
  name                = local.names.log_analytics
  resource_group_name = local.resource_group_name
  location            = var.location
  sku                 = var.log_analytics.sku
  retention_in_days   = var.log_analytics.retention_in_days
  tags                = var.tags
}

resource "azurerm_application_insights" "gateway" {
  name                = local.names.application_insights
  resource_group_name = local.resource_group_name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.platform.id
  application_type    = "web"
  tags                = var.tags
}
