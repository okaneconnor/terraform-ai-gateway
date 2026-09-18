variable "name_prefix" {
  description = "Workload name, used in every generated resource name after the CAF type abbreviation."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.name_prefix))
    error_message = "name_prefix must be lower-case letters, digits and hyphens, starting and ending with a letter or digit. Per-resource length limits are enforced where they apply, so a long prefix fails with a message naming the custom_names key to set."
  }
}

variable "environment" {
  description = "Environment token in generated names, for example dev, test or prod. Omit it and it drops out of the name entirely."
  type        = string
  default     = null

  validation {
    condition     = var.environment == null || can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.environment))
    error_message = "environment must be lower-case letters, digits and hyphens, starting and ending with a letter or digit."
  }
}

variable "instance" {
  description = "Instance token appended last in generated names, for example 002. Omit it and it drops out of the name entirely."
  type        = string
  default     = null

  validation {
    condition     = var.instance == null || can(regex("^[a-z0-9]+$", var.instance))
    error_message = "instance must be lower-case letters or digits."
  }
}

variable "location" {
  description = "Azure region for every resource this module creates. Also supplies the region token in generated names. Required: the module takes no view on where your infrastructure belongs."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource that supports them. The module adds none of its own."
  type        = map(string)
  default     = {}
}

variable "custom_names" {
  description = "Explicit name for individual resources, replacing the generated CAF name. Use when an existing naming convention must be matched, or when a generated name would exceed an Azure length limit."
  type = object({
    resource_group             = optional(string)
    virtual_network            = optional(string)
    apim_subnet                = optional(string)
    private_endpoint_subnet    = optional(string)
    apim_nsg                   = optional(string)
    private_endpoint_nsg       = optional(string)
    route_table                = optional(string)
    key_vault                  = optional(string)
    key_vault_private_endpoint = optional(string)
    key_vault_private_dns_link = optional(string)
    identity                   = optional(string)
    log_analytics              = optional(string)
    application_insights       = optional(string)
  })
  default = {}
}
