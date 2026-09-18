resource "azurerm_resource_group" "gateway" {
  name     = local.names.resource_group
  location = var.location
  tags     = var.tags
}
