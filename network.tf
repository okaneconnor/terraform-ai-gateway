resource "azurerm_virtual_network" "gateway" {
  name                = local.names.virtual_network
  resource_group_name = local.resource_group_name
  location            = var.location
  address_space       = [var.address_space]
  tags                = var.tags

  lifecycle {
    precondition {
      condition = (
        (var.subnet_prefixes.apim != null && var.subnet_prefixes.private_endpoints != null) ||
        tonumber(split("/", var.address_space)[1]) <= 22
      )
      error_message = "The module derives subnet prefixes from address_space and needs a /22 or larger to do so. Either widen address_space, or set both subnet_prefixes entries explicitly and any size will do."
    }
  }
}

resource "azurerm_subnet" "apim" {
  name                 = local.names.apim_subnet
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.gateway.name
  address_prefixes     = [local.apim_subnet_prefix]

  lifecycle {
    precondition {
      condition     = tonumber(split("/", local.apim_subnet_prefix)[1]) <= 26
      error_message = "The API Management subnet must be a /26 or larger; got ${local.apim_subnet_prefix}."
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = local.names.private_endpoint_subnet
  resource_group_name               = local.resource_group_name
  virtual_network_name              = azurerm_virtual_network.gateway.name
  address_prefixes                  = [local.private_endpoint_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
}

# Private DNS zones for the endpoints in this network are usually central and owned
# elsewhere. This lets whatever manages them link those zones to this network.
resource "azurerm_role_assignment" "private_dns_linker" {
  for_each = toset(var.private_dns_linker_principal_ids)

  scope                = azurerm_virtual_network.gateway.id
  role_definition_name = "Network Contributor"
  principal_id         = each.value
  description          = "Allow a central private-DNS pipeline to link private DNS zones to this network"
}
