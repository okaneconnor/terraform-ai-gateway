output "resource_names" {
  description = "Every generated resource name. Consume these rather than rebuilding a name."
  value       = local.names
}

output "resource_group_name" {
  description = "Name of the resource group holding the gateway, whether created here or supplied."
  value       = local.resource_group_name
}

output "resource_group_id" {
  description = "Resource ID of the resource group holding the gateway."
  value       = local.resource_group_id
}

output "virtual_network_id" {
  description = "Resource ID of the virtual network, or null when existing subnets were supplied. Peer to a hub using this."
  value       = local.create_network ? azurerm_virtual_network.gateway["gateway"].id : null
}

output "subnet_ids" {
  description = "Subnet resource IDs in use, whether created here or supplied."
  value       = local.subnet_ids
}

output "identity" {
  description = "The gateway's user-assigned managed identity: resource id, principal id and client id."
  value       = local.identity
}

output "key_vault_id" {
  description = "Resource ID of the Key Vault holding subscription keys, whether created here or supplied."
  value       = local.key_vault_id
}

output "key_vault_uri" {
  description = "Vault URI, or null when an existing vault was supplied by ID."
  value       = local.key_vault_uri
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace in use, whether created here or supplied."
  value       = local.log_analytics_workspace_id
}

output "application_insights_id" {
  description = "Resource ID of the Application Insights component."
  value       = local.application_insights.id
}
