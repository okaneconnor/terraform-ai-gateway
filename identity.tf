resource "azurerm_user_assigned_identity" "gateway" {
  name                = local.names.identity
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = var.tags
}
