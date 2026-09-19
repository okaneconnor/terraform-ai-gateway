variable "ai_services" {
  description = <<-EOT
    The shared AI Services account the gateway routes to.

    The account is keyless and private: local authentication is disabled, public
    network access is off and the firewall denies by default, so it is reachable only
    through its private endpoint and only by an Entra identity. A custom subdomain is
    set because Entra authentication requires one.

    private_dns_zone_ids attaches a central privatelink.cognitiveservices.azure.com
    zone to the endpoint. Leave it empty when a central pipeline registers the record
    instead, as with the Key Vault.
  EOT
  type = object({
    kind                               = optional(string, "AIServices")
    sku_name                           = optional(string, "S0")
    local_auth_enabled                 = optional(bool, false)
    public_network_access_enabled      = optional(bool, false)
    network_acls_default_action        = optional(string, "Deny")
    outbound_network_access_restricted = optional(bool, true)
    private_dns_zone_ids               = optional(list(string), [])
  })
  default = {}
}

variable "model_deployments" {
  description = "Models to deploy on the account, keyed by the deployment name a caller asks for. The module ships no default: choose models current in your region."
  type = map(object({
    model_name             = string
    model_version          = string
    model_format           = optional(string, "OpenAI")
    sku_name               = optional(string, "Standard")
    sku_capacity           = optional(number, 1)
    version_upgrade_option = optional(string, "NoAutoUpgrade")
  }))
  default = {}
}

variable "enable_content_safety" {
  description = "Deploy a Content Safety account alongside the AI Services account, for the gateway's prompt screening policies."
  type        = bool
  default     = false
}

variable "content_safety_sku_name" {
  description = "SKU for the Content Safety account when enabled."
  type        = string
  default     = "S0"
}
