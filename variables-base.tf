variable "address_space" {
  description = "CIDR for the virtual network. A /22 or larger lets the module derive both subnet prefixes; anything smaller needs subnet_prefixes set explicitly."
  type        = string

  validation {
    condition     = can(cidrhost(var.address_space, 0))
    error_message = "address_space must be a valid CIDR block, for example 10.60.0.0/22."
  }
}

variable "subnet_prefixes" {
  description = "Explicit CIDRs for the subnets the module creates. When null they are derived from address_space. The API Management subnet must be a /26 or larger."
  type = object({
    apim              = optional(string)
    private_endpoints = optional(string)
  })
  default = {}

  validation {
    condition     = var.subnet_prefixes.apim == null || can(cidrhost(var.subnet_prefixes.apim, 0))
    error_message = "subnet_prefixes.apim must be a valid CIDR block when set, for example 10.60.0.0/26."
  }

  validation {
    condition     = var.subnet_prefixes.private_endpoints == null || can(cidrhost(var.subnet_prefixes.private_endpoints, 0))
    error_message = "subnet_prefixes.private_endpoints must be a valid CIDR block when set, for example 10.60.1.0/26."
  }
}

variable "apim_nsg_baseline_rules" {
  description = <<-EOT
    Inbound rules Azure documents as the minimum for API Management injected into a
    virtual network, in both external and internal mode: TCP 3443 from the
    ApiManagement service tag for the management endpoint, and TCP 6390 from
    AzureLoadBalancer for the infrastructure load balancer. Without them the instance
    cannot provision or goes unhealthy, which is why they are on by default.

    They do not apply to every deployment. API Management v2 tiers integrated for
    private outbound access do not enforce inbound rules at all, and a gateway not
    injected into a virtual network needs none of this. Set to {} to create the
    security group with no baseline, or override an individual rule by reusing its
    key in apim_nsg_additional_rules.
  EOT
  type = map(object({
    priority                     = number
    direction                    = string
    access                       = string
    protocol                     = string
    source_port_range            = optional(string)
    source_port_ranges           = optional(list(string))
    destination_port_range       = optional(string)
    destination_port_ranges      = optional(list(string))
    source_address_prefix        = optional(string)
    source_address_prefixes      = optional(list(string))
    destination_address_prefix   = optional(string)
    destination_address_prefixes = optional(list(string))
    description                  = optional(string)
  }))
  default = {
    apim-management-endpoint = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3443"
      source_address_prefix      = "ApiManagement"
      destination_address_prefix = "VirtualNetwork"
      description                = "API Management management endpoint. Required by Azure for virtual network injection."
    }
    apim-load-balancer = {
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "6390"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "VirtualNetwork"
      description                = "Azure infrastructure load balancer health probe. Required by Azure for virtual network injection."
    }
  }
}

variable "apim_nsg_additional_rules" {
  description = "Extra security rules for the API Management subnet, merged over the mandatory baseline. Reusing a baseline rule name replaces that rule."
  type = map(object({
    priority                     = number
    direction                    = string
    access                       = string
    protocol                     = string
    source_port_range            = optional(string)
    source_port_ranges           = optional(list(string))
    destination_port_range       = optional(string)
    destination_port_ranges      = optional(list(string))
    source_address_prefix        = optional(string)
    source_address_prefixes      = optional(list(string))
    destination_address_prefix   = optional(string)
    destination_address_prefixes = optional(list(string))
    description                  = optional(string)
  }))
  default = {}
}

variable "private_endpoint_nsg_rules" {
  description = "Security rules for the private endpoint subnet. Empty means no network security group is attached to it."
  # This object type is deliberately identical to apim_nsg_additional_rules above.
  # HCL has no type alias, so keep the two in step by hand if either one changes.
  type = map(object({
    priority                     = number
    direction                    = string
    access                       = string
    protocol                     = string
    source_port_range            = optional(string)
    source_port_ranges           = optional(list(string))
    destination_port_range       = optional(string)
    destination_port_ranges      = optional(list(string))
    source_address_prefix        = optional(string)
    source_address_prefixes      = optional(list(string))
    destination_address_prefix   = optional(string)
    destination_address_prefixes = optional(list(string))
    description                  = optional(string)
  }))
  default = {}
}

variable "routes" {
  description = "Routes for the API Management subnet, for example forced tunnelling to a firewall. Empty means no route table is created."
  type = map(object({
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = optional(string)
  }))
  default = {}
}

variable "key_vault" {
  description = <<-EOT
    Settings for the Key Vault the module creates.

    The vault is always private: public network access is disabled and the firewall
    denies by default, so it is reachable only through its private endpoint from
    inside the network. There is no option to expose it publicly.

    Private access only works once the vault hostname resolves to the endpoint,
    which needs a privatelink.vaultcore.azure.net zone linked to the network doing
    the lookup. The module does not own that zone: in most estates it is central and
    shared. Attach one with private_dns_zone_ids, or leave it empty and let whatever
    manages your zones register the record, granting it access to the network with
    private_dns_linker_principal_ids.
  EOT
  type = object({
    sku_name                   = optional(string, "standard")
    purge_protection_enabled   = optional(bool, true) # irreversible once applied: Azure forbids turning it back off, and a destroyed vault's name stays reserved for the soft-delete retention period
    soft_delete_retention_days = optional(number, 90)
    create_private_endpoint    = optional(bool, true)
    private_dns_zone_ids       = optional(list(string), [])
  })
  default = {}
}

variable "key_vault_reader_principal_ids" {
  description = "Object IDs granted Key Vault Reader on the vault: see the vault and enumerate secret names, without access to any secret value. This is what an operator needs to find a secret before a separate role lets them read it."
  type        = list(string)
  default     = []
}

variable "private_dns_linker_principal_ids" {
  description = "Object IDs granted Network Contributor on the virtual network so a central private-DNS pipeline can link its zones to it. Leave empty when the module's own network is not used, or when zones are linked by other means."
  type        = list(string)
  default     = []
}

variable "key_vault_secrets_officer_principal_ids" {
  description = "Object IDs granted Key Vault Secrets Officer, which can read, write and delete secret values. Put your own user or group object ID here to be able to inspect the subscription keys the gateway stores. Object IDs only: the module performs no directory lookups and needs no directory permission."
  type        = list(string)
  default     = []
}

variable "key_vault_secrets_user_principal_ids" {
  description = "Object IDs granted Key Vault Secrets User, read-only on secret values. NOTE: this is vault-wide, so every listed principal can read EVERY secret. It is intended for operators and platform components. Per-team access to a single subscription key is granted per-secret by the onboarding layer instead."
  type        = list(string)
  default     = []
}

variable "key_vault_grant_deployer_secrets_officer" {
  description = "Grant the principal running Terraform Key Vault Secrets Officer on the vault. Required for the module to write API Management subscription keys into it, because role-based access control grants no data-plane access implicitly. Set false only when that role is granted out of band."
  type        = bool
  default     = true
}

variable "application_insights" {
  description = "Application Insights settings. sampling_percentage below 100 reduces ingestion cost by dropping a proportion of telemetry, at the cost of exact per-request detail."
  type = object({
    sampling_percentage = optional(number, 100)
  })
  default = {}

  validation {
    condition     = var.application_insights.sampling_percentage > 0 && var.application_insights.sampling_percentage <= 100
    error_message = "application_insights.sampling_percentage must be greater than 0 and at most 100."
  }
}

variable "log_analytics" {
  description = "Settings for the Log Analytics workspace the module creates."
  type = object({
    sku               = optional(string, "PerGB2018")
    retention_in_days = optional(number, 30)
  })
  default = {}
}
