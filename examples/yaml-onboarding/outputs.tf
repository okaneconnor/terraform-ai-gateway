output "gateway_url" {
  description = "Gateway base URL. Internal by default, so reachable from inside the network."
  value       = module.ai_gateway.apim.gateway_url
}

output "gateway_private_ip" {
  description = "Private address of the gateway."
  value       = module.ai_gateway.apim_private_ip
}

output "subscriptions" {
  description = "Subscription id per application-service. A team reads its key from here with listSecrets when vault delivery is off."
  value       = module.ai_gateway.subscriptions
}

output "subscription_secret_names" {
  description = "Vault secret per service when vault delivery is on."
  value       = module.ai_gateway.subscription_secret_names
}
