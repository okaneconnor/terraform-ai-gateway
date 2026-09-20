variable "name_prefix" {
  description = "Workload name used in every generated resource name."
  type        = string
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

variable "deliver_keys_to_key_vault" {
  description = "Write subscription keys into the platform vault. Needs Terraform to run inside the network, because the vault is private."
  type        = bool
  default     = true
}
