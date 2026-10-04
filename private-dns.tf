# Off by default: in most estates these zones are central and shared, and a second copy
# would collide with them or leave an orphan. Turn it on for a standalone gateway.
locals {
  private_dns_zones = var.create_private_dns_zones ? {
    key_vault   = "privatelink.vaultcore.azure.net"
    ai_services = "privatelink.cognitiveservices.azure.com"
  } : {}

  # Content Safety shares the AI Services zone.
  key_vault_dns_zone_ids = concat(
    var.key_vault.private_dns_zone_ids,
    [for k, z in azurerm_private_dns_zone.gateway : z.id if k == "key_vault"],
  )
  ai_services_dns_zone_ids = concat(
    var.ai_services.private_dns_zone_ids,
    [for k, z in azurerm_private_dns_zone.gateway : z.id if k == "ai_services"],
  )
}

resource "azurerm_private_dns_zone" "gateway" {
  for_each = local.private_dns_zones

  name                = each.value
  resource_group_name = local.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "gateway" {
  for_each = local.private_dns_zones

  name                  = "link-${azurerm_virtual_network.gateway.name}"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.gateway[each.key].name
  virtual_network_id    = azurerm_virtual_network.gateway.id
}
