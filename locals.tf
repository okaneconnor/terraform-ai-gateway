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

  application_insights = {
    id                  = azurerm_application_insights.gateway.id
    instrumentation_key = azurerm_application_insights.gateway.instrumentation_key
    connection_string   = azurerm_application_insights.gateway.connection_string
  }
}
