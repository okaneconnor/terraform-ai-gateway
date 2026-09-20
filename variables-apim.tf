variable "apim" {
  description = <<-EOT
    The API Management instance fronting the AI services.

    virtual_network_type Internal injects the gateway into the API Management subnet
    with no public endpoint, which is what a private gateway wants and what the
    classic Developer and Premium tiers support. None deploys it outside the network,
    which is faster to create and useful while iterating.

    A Developer or Premium instance takes 30 to 45 minutes to create. That is Azure,
    not this module.

    Developer_1 carries no SLA. Azure takes its management endpoint down during
    platform upgrades, and while it is down Terraform cannot create, change or delete
    anything inside the gateway: policies, fragments, APIs and backends all fail with
    "Failed to connect to Management endpoint Port 3443". Applies hang, and a destroy
    can leave the instance half-removed. Fine for trying the module out; use a tier
    with an SLA for anything a team depends on.
  EOT
  type = object({
    sku_name                  = optional(string, "Developer_1")
    virtual_network_type      = optional(string, "Internal")
    publisher_name            = string
    publisher_email           = string
    notification_sender_email = optional(string)
    zones                     = optional(list(string))

    # Off by default: an Internal gateway is meant to be fully private, and Azure
    # handles its own outbound and management traffic without one. Turn it on when a
    # firewall downstream needs a stable address to allow-list, or when Azure needs
    # it, which External mode does.
    create_public_ip       = optional(bool, false)
    public_ip_domain_label = optional(string)

    # Off unless a consumer has a reason: these exist for old clients that cannot
    # negotiate anything better.
    enable_weak_tls_ciphers = optional(bool, false)
  })

  validation {
    condition     = contains(["None", "Internal", "External"], var.apim.virtual_network_type)
    error_message = "apim.virtual_network_type must be one of: None, Internal, External."
  }

  validation {
    condition     = var.apim.virtual_network_type != "External" || var.apim.create_public_ip
    error_message = "apim.virtual_network_type = \"External\" requires apim.create_public_ip = true; Azure will not provision an externally-injected gateway without one."
  }
}

variable "apim_gateway_hostnames" {
  description = <<-EOT
    Custom hostnames for the gateway, replacing the default *.azure-api.net. Each
    needs a certificate: supply key_vault_secret_id pointing at a certificate in a
    vault the gateway's identity can read.

    Empty means the default hostname, which is fine for development and wrong for
    anything a team will call.
  EOT
  type = list(object({
    host_name                    = string
    key_vault_secret_id          = string
    negotiate_client_certificate = optional(bool, false)
    default_ssl_binding          = optional(bool, true)
  }))
  default = []
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
