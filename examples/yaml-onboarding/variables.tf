variable "name_prefix" {
  description = "Workload name used in every generated resource name."
  type        = string
}

variable "environment" {
  description = "Environment token in generated names. Omit it and it drops out."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "address_space" {
  description = "CIDR for the gateway's virtual network."
  type        = string
}

variable "publisher_name" {
  description = "API Management publisher name."
  type        = string
}

variable "publisher_email" {
  description = "API Management publisher email."
  type        = string
}

variable "gateway_app_id" {
  description = "Client id of the Entra app registration whose app role the gateway requires. Not created by the module: assigning app roles needs directory permission."
  type        = string
}
