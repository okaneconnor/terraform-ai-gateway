resource "azurerm_network_security_group" "apim" {
  name                = local.names.apim_nsg
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_rule" "apim" {
  for_each = local.apim_nsg_rules

  name                        = each.key
  resource_group_name         = local.resource_group_name
  network_security_group_name = azurerm_network_security_group.apim.name

  priority                     = each.value.priority
  direction                    = each.value.direction
  access                       = each.value.access
  protocol                     = each.value.protocol
  source_port_range            = each.value.source_port_range
  source_port_ranges           = each.value.source_port_ranges
  destination_port_range       = each.value.destination_port_range
  destination_port_ranges      = each.value.destination_port_ranges
  source_address_prefix        = each.value.source_address_prefix
  source_address_prefixes      = each.value.source_address_prefixes
  destination_address_prefix   = each.value.destination_address_prefix
  destination_address_prefixes = each.value.destination_address_prefixes
  description                  = each.value.description
}

resource "azurerm_subnet_network_security_group_association" "apim" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim.id
}

resource "azurerm_network_security_group" "private_endpoints" {
  for_each            = length(var.private_endpoint_nsg_rules) > 0 ? { private_endpoints = {} } : {}
  name                = local.names.private_endpoint_nsg
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_rule" "private_endpoints" {
  for_each = var.private_endpoint_nsg_rules

  name                        = each.key
  resource_group_name         = local.resource_group_name
  network_security_group_name = azurerm_network_security_group.private_endpoints["private_endpoints"].name

  priority                     = each.value.priority
  direction                    = each.value.direction
  access                       = each.value.access
  protocol                     = each.value.protocol
  source_port_range            = each.value.source_port_range
  source_port_ranges           = each.value.source_port_ranges
  destination_port_range       = each.value.destination_port_range
  destination_port_ranges      = each.value.destination_port_ranges
  source_address_prefix        = each.value.source_address_prefix
  source_address_prefixes      = each.value.source_address_prefixes
  destination_address_prefix   = each.value.destination_address_prefix
  destination_address_prefixes = each.value.destination_address_prefixes
  description                  = each.value.description
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  for_each                  = length(var.private_endpoint_nsg_rules) > 0 ? { private_endpoints = {} } : {}
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints["private_endpoints"].id
}

resource "azurerm_route_table" "apim" {
  for_each            = length(var.routes) > 0 ? { apim = {} } : {}
  name                = local.names.route_table
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_route" "apim" {
  for_each = var.routes

  name                   = each.key
  resource_group_name    = local.resource_group_name
  route_table_name       = azurerm_route_table.apim["apim"].name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
}

resource "azurerm_subnet_route_table_association" "apim" {
  for_each       = length(var.routes) > 0 ? { apim = {} } : {}
  subnet_id      = azurerm_subnet.apim.id
  route_table_id = azurerm_route_table.apim["apim"].id
}
