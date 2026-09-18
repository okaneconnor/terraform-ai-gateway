resource "azurerm_key_vault" "platform" {
  for_each            = local.create_key_vault ? { platform = {} } : {}
  name                = local.names.key_vault
  resource_group_name = local.resource_group_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.key_vault.sku_name
  tags                = var.tags

  rbac_authorization_enabled    = true
  purge_protection_enabled      = var.key_vault.purge_protection_enabled
  soft_delete_retention_days    = var.key_vault.soft_delete_retention_days
  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  lifecycle {
    precondition {
      condition     = length(local.names.key_vault) >= 3 && length(local.names.key_vault) <= 24
      error_message = "Key Vault name '${local.names.key_vault}' is ${length(local.names.key_vault)} characters; Azure allows 3 to 24. Set custom_names.key_vault."
    }
    precondition {
      condition     = can(regex("^[a-zA-Z0-9-]+$", local.names.key_vault))
      error_message = "Key Vault name '${local.names.key_vault}' may contain only letters, digits and hyphens. Set custom_names.key_vault."
    }
  }
}

resource "azurerm_private_endpoint" "key_vault" {
  for_each            = local.key_vault_private_endpoint ? { key_vault = {} } : {}
  name                = local.names.key_vault_private_endpoint
  resource_group_name = local.resource_group_name
  location            = var.location
  subnet_id           = local.subnet_ids.private_endpoints
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.platform["platform"].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = length(local.key_vault_private_dns_zone_ids) > 0 ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = local.key_vault_private_dns_zone_ids
    }
  }
}

# principal_type avoids a transient "principal not found" error for a new identity.
resource "azurerm_role_assignment" "gateway_secrets_officer" {
  for_each = local.create_key_vault ? { gateway = {} } : {}

  scope                = azurerm_key_vault.platform["platform"].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = local.identity.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "key_vault_secrets_officers" {
  for_each = local.create_key_vault ? toset(local.key_vault_secrets_officers) : toset([])

  scope                = azurerm_key_vault.platform["platform"].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "key_vault_secrets_users" {
  for_each = local.create_key_vault ? toset(var.key_vault_secrets_user_principal_ids) : toset([])

  scope                = azurerm_key_vault.platform["platform"].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}

# Without this the vault hostname resolves to its public address, which is disabled,
# so the vault is unreachable from anywhere. The zone name is fixed by Azure.
resource "azurerm_private_dns_zone" "key_vault" {
  for_each = local.key_vault_dns_zone ? { key_vault = {} } : {}

  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = local.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  for_each = local.key_vault_dns_zone ? { key_vault = {} } : {}

  name                  = local.names.key_vault_private_dns_link
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault["key_vault"].name
  virtual_network_id    = local.private_endpoint_virtual_network_id
  tags                  = var.tags
}
