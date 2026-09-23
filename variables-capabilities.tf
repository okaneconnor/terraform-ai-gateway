variable "enabled_capabilities" {
  description = "Capabilities to publish, by name, from the module's built-in catalogue. Each becomes an API with its own OpenAPI document and policy."
  type        = list(string)
  default     = ["chat-completions-v1"]

  validation {
    condition     = length(setsubtract(toset(var.enabled_capabilities), toset(["chat-completions-v1"]))) == 0
    error_message = "enabled_capabilities currently supports: chat-completions-v1."
  }
}

variable "model_routing" {
  description = "Model name a caller asks for, mapped to the deployment that serves it. Defaults to the deployments themselves, so a caller asks for the deployment name unless a different public name is mapped."
  type        = map(string)
  default     = {}
}
