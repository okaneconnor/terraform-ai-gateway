locals {
  resource_group_name = azurerm_resource_group.gateway.name
  resource_group_id   = azurerm_resource_group.gateway.id

  create_network = var.existing_subnet_ids == null

  # cidrsubnet and split must not be reached with a null address_space, or the caller
  # gets a raw function error instead of the virtual network's precondition message.
  apim_subnet_prefix = !local.create_network ? null : (
    var.subnet_prefixes.apim != null ? var.subnet_prefixes.apim : (
      var.address_space != null ? cidrsubnet(var.address_space, 26 - tonumber(split("/", var.address_space)[1]), 0) : null
    )
  )

  private_endpoint_subnet_prefix = !local.create_network ? null : (
    var.subnet_prefixes.private_endpoints != null ? var.subnet_prefixes.private_endpoints : (
      var.address_space != null ? cidrsubnet(var.address_space, 26 - tonumber(split("/", var.address_space)[1]), 4) : null
    )
  )

  subnet_ids = local.create_network ? {
    apim              = azurerm_subnet.apim["apim"].id
    private_endpoints = azurerm_subnet.private_endpoints["private_endpoints"].id
    } : {
    apim              = var.existing_subnet_ids.apim
    private_endpoints = var.existing_subnet_ids.private_endpoints
  }

  # Last write wins, so a caller rule reusing a baseline name replaces it.
  apim_nsg_rules = merge(var.apim_nsg_baseline_rules, var.apim_nsg_additional_rules)

  create_private_endpoint_nsg = local.create_network && length(var.private_endpoint_nsg_rules) > 0
  create_route_table          = local.create_network && length(var.routes) > 0

  identity = var.existing_identity == null ? {
    id           = azurerm_user_assigned_identity.gateway["gateway"].id
    principal_id = azurerm_user_assigned_identity.gateway["gateway"].principal_id
    client_id    = azurerm_user_assigned_identity.gateway["gateway"].client_id
  } : var.existing_identity

  create_key_vault = var.existing_key_vault_id == null

  key_vault_private_endpoint = local.create_key_vault && var.key_vault.create_private_endpoint

  # A subnet id always ends /subnets/<name>, so trimming that gives the network's id
  # whether the module created the network or the caller supplied it.
  private_endpoint_virtual_network_id = replace(local.subnet_ids.private_endpoints, "/\\/subnets\\/[^/]+$/", "")

  # RBAC grants no data-plane access implicitly, so without this the module cannot
  # write subscription keys into the vault it just created.
  key_vault_secrets_officers = distinct(concat(
    var.key_vault_secrets_officer_principal_ids,
    var.key_vault_grant_deployer_secrets_officer ? [data.azurerm_client_config.current.object_id] : [],
  ))

  key_vault_id  = local.create_key_vault ? azurerm_key_vault.platform["platform"].id : var.existing_key_vault_id
  key_vault_uri = local.create_key_vault ? azurerm_key_vault.platform["platform"].vault_uri : null

  create_log_analytics       = var.existing_log_analytics_workspace_id == null
  log_analytics_workspace_id = local.create_log_analytics ? azurerm_log_analytics_workspace.platform["platform"].id : var.existing_log_analytics_workspace_id

  application_insights = var.existing_application_insights == null ? {
    id                  = azurerm_application_insights.gateway["gateway"].id
    instrumentation_key = azurerm_application_insights.gateway["gateway"].instrumentation_key
    connection_string   = azurerm_application_insights.gateway["gateway"].connection_string
  } : var.existing_application_insights
}
