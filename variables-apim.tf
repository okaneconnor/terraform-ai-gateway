variable "apim" {
  description = <<-EOT
    The API Management instance fronting the AI services.

    virtual_network_type Internal injects the gateway into the API Management subnet
    with no public endpoint, which is what a private gateway wants and what the
    classic Developer and Premium tiers support. None deploys it outside the network,
    which is faster to create and useful while iterating.

    A Developer or Premium instance takes 30 to 45 minutes to create. That is Azure,
    not this module.
  EOT
  type = object({
    sku_name             = optional(string, "Developer_1")
    virtual_network_type = optional(string, "Internal")
    publisher_name       = string
    publisher_email      = string
    zones                = optional(list(string))
  })

  validation {
    condition     = contains(["None", "Internal", "External"], var.apim.virtual_network_type)
    error_message = "apim.virtual_network_type must be one of: None, Internal, External."
  }
}

variable "apim_diagnostic_log_categories" {
  description = "Diagnostic log categories sent to Log Analytics. GatewayLlmLogs carries the per-request model and token detail the gateway's metrics rely on."
  type        = list(string)
  default     = ["GatewayLogs", "GatewayLlmLogs"]
}

variable "apim_circuit_breaker" {
  description = "When a backend is taken out of rotation. failure_count failures within interval trip it for trip_duration."
  type = object({
    failure_count = optional(number, 5)
    interval      = optional(string, "PT1M")
    trip_duration = optional(string, "PT1M")
  })
  default = {}
}

variable "jwt" {
  description = <<-EOT
    Entra token validation applied to every call through the gateway.

    audiences are the accepted `aud` values, normally the gateway app registration's
    client ID. required_roles are app roles of which the caller's token must carry at
    least one. The app registration is not created here: it needs directory permission
    and has its own lifecycle.
  EOT
  type = object({
    tenant_id      = optional(string)
    audiences      = list(string)
    required_roles = optional(list(string), ["AI.Gateway.Standard"])
  })
}

variable "health_api_path" {
  description = "URL suffix of the unauthenticated health endpoint."
  type        = string
  default     = "health"
}
