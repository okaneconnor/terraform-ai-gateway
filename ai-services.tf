resource "azurerm_cognitive_account" "ai_services" {
  name                = local.names.ai_services
  resource_group_name = local.resource_group_name
  location            = var.location
  kind                = var.ai_services.kind
  sku_name            = var.ai_services.sku_name

  # Entra authentication requires a custom subdomain; a regional endpoint cannot do it.
  custom_subdomain_name = local.names.ai_services

  local_auth_enabled                 = var.ai_services.local_auth_enabled
  public_network_access_enabled      = var.ai_services.public_network_access_enabled
  outbound_network_access_restricted = var.ai_services.outbound_network_access_restricted

  network_acls {
    default_action = var.ai_services.network_acls_default_action
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cognitive_deployment" "model" {
  for_each = var.model_deployments

  name                   = each.key
  cognitive_account_id   = azurerm_cognitive_account.ai_services.id
  version_upgrade_option = each.value.version_upgrade_option

  model {
    format  = each.value.model_format
    name    = each.value.model_name
    version = each.value.model_version
  }

  sku {
    name     = each.value.sku_name
    capacity = each.value.sku_capacity
  }
}

resource "azurerm_private_endpoint" "ai_services" {
  name                = local.names.ai_services_private_endpoint
  resource_group_name = local.resource_group_name
  location            = var.location
  subnet_id           = azurerm_subnet.private_endpoints.id

  # Deployments go through the account's control plane, which the endpoint can race.
  depends_on = [azurerm_cognitive_deployment.model]

  private_service_connection {
    name                           = "psc-aif"
    private_connection_resource_id = azurerm_cognitive_account.ai_services.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.ai_services.private_dns_zone_ids) > 0 ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = var.ai_services.private_dns_zone_ids
    }
  }
}

resource "azurerm_cognitive_account" "content_safety" {
  for_each = var.enable_content_safety ? { content_safety = {} } : {}

  name                  = local.names.content_safety
  resource_group_name   = local.resource_group_name
  location              = var.location
  kind                  = "ContentSafety"
  sku_name              = var.content_safety_sku_name
  custom_subdomain_name = local.names.content_safety

  local_auth_enabled                 = var.ai_services.local_auth_enabled
  public_network_access_enabled      = var.ai_services.public_network_access_enabled
  outbound_network_access_restricted = var.ai_services.outbound_network_access_restricted

  network_acls {
    default_action = var.ai_services.network_acls_default_action
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_private_endpoint" "content_safety" {
  for_each = var.enable_content_safety ? { content_safety = {} } : {}

  name                = local.names.content_safety_private_endpoint
  resource_group_name = local.resource_group_name
  location            = var.location
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-cs"
    private_connection_resource_id = azurerm_cognitive_account.content_safety["content_safety"].id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.ai_services.private_dns_zone_ids) > 0 ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = var.ai_services.private_dns_zone_ids
    }
  }
}

# The gateway reaches the models as itself. Local auth is off, so these grants are
# the only way in.
resource "azurerm_role_assignment" "gateway_openai_user" {
  scope                = azurerm_cognitive_account.ai_services.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = local.identity.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "gateway_content_safety_user" {
  for_each = var.enable_content_safety ? { content_safety = {} } : {}

  scope                = azurerm_cognitive_account.content_safety["content_safety"].id
  role_definition_name = "Cognitive Services User"
  principal_id         = local.identity.principal_id
  principal_type       = "ServicePrincipal"
}
