output "resource_names" {
  description = "Every generated resource name. Consume these rather than rebuilding a name."
  value       = local.names
}

output "resource_group_name" {
  description = "Name of the resource group holding the gateway."
  value       = local.resource_group_name
}

output "resource_group_id" {
  description = "Resource ID of the resource group holding the gateway."
  value       = local.resource_group_id
}

output "virtual_network_id" {
  description = "Resource ID of the virtual network. Peer to a hub, or link a private DNS zone, using this."
  value       = azurerm_virtual_network.gateway.id
}

output "subnet_ids" {
  description = "Subnet resource IDs, keyed by purpose."
  value       = local.subnet_ids
}

output "identity" {
  description = "The gateway's user-assigned managed identity: resource id, principal id and client id."
  value       = local.identity
}

output "key_vault_id" {
  description = "Resource ID of the Key Vault holding subscription keys."
  value       = azurerm_key_vault.platform.id
}

output "key_vault_uri" {
  description = "Vault URI. Reachable only from a network that resolves it to the private endpoint."
  value       = azurerm_key_vault.platform.vault_uri
}

output "key_vault_private_endpoint_ip" {
  description = "Private IP of the Key Vault's endpoint, for registering an A record in a private DNS zone the module does not own."
  value       = try(azurerm_private_endpoint.key_vault["key_vault"].private_service_connection[0].private_ip_address, null)
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.platform.id
}

output "application_insights_id" {
  description = "Resource ID of the Application Insights component."
  value       = local.application_insights.id
}
