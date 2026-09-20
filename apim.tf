resource "azurerm_public_ip" "apim" {
  for_each = var.apim.create_public_ip && var.apim.virtual_network_type != "None" ? { apim = {} } : {}

  name                = local.names.apim_public_ip
  resource_group_name = local.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.apim.zones
  domain_name_label   = var.apim.public_ip_domain_label
}

resource "azurerm_api_management" "gateway" {
  name                = local.names.apim
  resource_group_name = local.resource_group_name
  location            = var.location
  publisher_name      = var.apim.publisher_name
  publisher_email     = var.apim.publisher_email
  sku_name            = var.apim.sku_name
  zones               = var.apim.zones

  notification_sender_email = var.apim.notification_sender_email
  virtual_network_type      = var.apim.virtual_network_type
  public_ip_address_id      = try(azurerm_public_ip.apim["apim"].id, null)

  # Policies fetch tokens for the AI account as this identity, so it must be the one
  # holding the data-plane roles.
  identity {
    type         = "UserAssigned"
    identity_ids = [local.identity.id]
  }

  dynamic "virtual_network_configuration" {
    for_each = var.apim.virtual_network_type == "None" ? [] : [1]
    content {
      subnet_id = azurerm_subnet.apim.id
    }
  }

  # The gateway's identity reads the certificate from the vault holding it.
  dynamic "hostname_configuration" {
    for_each = length(var.apim_gateway_hostnames) > 0 ? [1] : []
    content {
      dynamic "proxy" {
        for_each = var.apim_gateway_hostnames
        content {
          host_name                    = proxy.value.host_name
          key_vault_id                 = proxy.value.key_vault_secret_id
          negotiate_client_certificate = proxy.value.negotiate_client_certificate
          default_ssl_binding          = proxy.value.default_ssl_binding
        }
      }
    }
  }

  security {
    tls_rsa_with_aes256_cbc_sha_ciphers_enabled = var.apim.enable_weak_tls_ciphers
    tls_rsa_with_aes128_cbc_sha_ciphers_enabled = var.apim.enable_weak_tls_ciphers
    triple_des_ciphers_enabled                  = var.apim.enable_weak_tls_ciphers
  }

  # The rules, not just the association. Azure requires the management-endpoint rule
  # on port 3443 for a gateway in a virtual network, and without this edge Terraform
  # is free to delete that rule first on destroy, cutting the control plane off
  # before its own policies and APIs can be removed.
  depends_on = [
    azurerm_network_security_rule.apim,
    azurerm_subnet_network_security_group_association.apim,
    azurerm_subnet_route_table_association.apim,
  ]
}

resource "azurerm_api_management_logger" "app_insights" {
  name                = "appi-logger"
  api_management_name = azurerm_api_management.gateway.name
  resource_group_name = local.resource_group_name
  resource_id         = azurerm_application_insights.gateway.id

  application_insights {
    connection_string = azurerm_application_insights.gateway.connection_string
  }
}

resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                           = "diag-apim"
  target_resource_id             = azurerm_api_management.gateway.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.platform.id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = toset(var.apim_diagnostic_log_categories)
    content {
      category = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
