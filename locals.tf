locals {
  resource_group_name = azurerm_resource_group.gateway.name
  resource_group_id   = azurerm_resource_group.gateway.id

  # The API Management subnet takes the first /26 of the address space and the
  # private endpoint subnet the first /26 of the second /24, unless either is
  # given explicitly.
  apim_subnet_prefix = coalesce(
    var.subnet_prefixes.apim,
    cidrsubnet(var.address_space, 26 - tonumber(split("/", var.address_space)[1]), 0),
  )

  private_endpoint_subnet_prefix = coalesce(
    var.subnet_prefixes.private_endpoints,
    cidrsubnet(var.address_space, 26 - tonumber(split("/", var.address_space)[1]), 4),
  )

  subnet_ids = {
    apim              = azurerm_subnet.apim.id
    private_endpoints = azurerm_subnet.private_endpoints.id
  }

  # Last write wins, so a caller rule reusing a baseline name replaces it.
  apim_nsg_rules = merge(var.apim_nsg_baseline_rules, var.apim_nsg_additional_rules)

  identity = {
    id           = azurerm_user_assigned_identity.gateway.id
    principal_id = azurerm_user_assigned_identity.gateway.principal_id
    client_id    = azurerm_user_assigned_identity.gateway.client_id
  }

  # RBAC grants no data-plane access implicitly, so without this the module cannot
  # write subscription keys into the vault it just created.
  key_vault_secrets_officers = distinct(concat(
    var.key_vault_secrets_officer_principal_ids,
    var.key_vault_grant_deployer_secrets_officer ? [data.azurerm_client_config.current.object_id] : [],
  ))

  ai_services = {
    id               = azurerm_cognitive_account.ai_services.id
    name             = azurerm_cognitive_account.ai_services.name
    endpoint         = trimsuffix(azurerm_cognitive_account.ai_services.endpoint, "/")
    custom_subdomain = azurerm_cognitive_account.ai_services.custom_subdomain_name
  }

  content_safety_endpoint = var.enable_content_safety ? trimsuffix(azurerm_cognitive_account.content_safety["content_safety"].endpoint, "/") : null

  apim = {
    id          = azurerm_api_management.gateway.id
    name        = azurerm_api_management.gateway.name
    gateway_url = azurerm_api_management.gateway.gateway_url
  }

  policy_fragments = {
    ai-model-allowlist  = file("${path.module}/policies/ai-model-allowlist.xml")
    ai-error-handling   = file("${path.module}/policies/ai-error-handling.xml")
    ai-header-scrub     = file("${path.module}/policies/ai-header-scrub.xml")
    ai-token-metrics    = file("${path.module}/policies/ai-token-metrics.xml")
    ai-document-metrics = file("${path.module}/policies/ai-document-metrics.xml")

    ai-auth-entra-jwt = templatefile("${path.module}/policies/ai-auth-entra-jwt.xml", {
      tenant_id      = coalesce(var.jwt.tenant_id, data.azurerm_client_config.current.tenant_id)
      audiences      = var.jwt.audiences
      required_roles = join(", ", [for r in var.jwt.required_roles : "&quot;${r}&quot;"])
    })

    ai-observability = templatefile("${path.module}/policies/ai-observability.xml", {
      env = coalesce(var.environment, "default")
    })

    ai-backend-managed-identity = templatefile("${path.module}/policies/ai-backend-managed-identity.xml", {
      uami_client_id = local.identity.client_id
    })
  }

  application_insights = {
    id                  = azurerm_application_insights.gateway.id
    instrumentation_key = azurerm_application_insights.gateway.instrumentation_key
    connection_string   = azurerm_application_insights.gateway.connection_string
  }
}
