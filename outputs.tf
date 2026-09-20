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

output "ai_services" {
  description = "The shared AI Services account: resource id, name, endpoint and custom subdomain."
  value       = local.ai_services
}

output "model_deployment_names" {
  description = "Names of the deployed models, which are what a caller asks for by name."
  value       = keys(var.model_deployments)
}

output "ai_services_private_endpoint_ip" {
  description = "Private IP of the AI Services endpoint, for registering an A record in a zone the module does not own."
  value       = try(azurerm_private_endpoint.ai_services.private_service_connection[0].private_ip_address, null)
}

output "apim" {
  description = "The API Management instance: resource id, name and gateway URL."
  value       = local.apim
}

output "apim_private_ip" {
  description = "Private IP of the gateway when injected into the network, for a DNS record pointing at it."
  value       = try(azurerm_api_management.gateway.private_ip_addresses[0], null)
}

output "policy_fragment_ids" {
  description = "Policy fragment names. Capability API policies include these by name, so renaming one is a breaking change."
  value       = keys(local.policy_fragments)
}

output "backend_ids" {
  description = "API Management backend names. Capability policies select a backend by name, so renaming one is a breaking change."
  value       = compact(["ai-services", var.enable_content_safety ? "content-safety" : ""])
}

output "health_url" {
  description = "The unauthenticated health endpoint."
  value       = "${azurerm_api_management.gateway.gateway_url}/${var.health_api_path}"
}

output "apim_public_ip" {
  description = "The gateway's public address when one was requested, otherwise null. An Internal gateway is private by default and has none."
  value       = try(azurerm_public_ip.apim["apim"].ip_address, null)
}

output "capability_api_names" {
  description = "Published capability API names. Onboarded products are linked to these."
  value       = keys(local.capabilities)
}

output "products" {
  description = "API Management product id per onboarded application."
  value       = { for k, p in azurerm_api_management_product.application : k => p.product_id }
}

output "subscriptions" {
  description = "Subscription resource id per application-service. A team reads its key from the vault, or from this resource with listSecrets."
  value       = { for k, s in azurerm_api_management_subscription.service : k => s.id }
}

output "subscription_secret_names" {
  description = "Vault secret holding each service's subscription key. Empty when deliver_keys_to_key_vault is off, in which case teams read their key from the subscription with listSecrets."
  value       = { for k, s in azurerm_key_vault_secret.subscription_key : k => s.name }
}
