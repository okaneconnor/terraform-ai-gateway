variable "enabled_capabilities" {
  description = "Capabilities to publish, by name, from the module's built-in catalogue. Each becomes an API with its own OpenAPI document and policy."
  type        = list(string)
  default     = ["chat-completions-v1"]

  validation {
    condition     = length(setsubtract(toset(var.enabled_capabilities), toset(["chat-completions-v1", "document-intelligence-v1", "speech-to-text-fast-v1"]))) == 0
    error_message = "enabled_capabilities supports: chat-completions-v1, document-intelligence-v1, speech-to-text-fast-v1."
  }
}

variable "model_routing" {
  description = "Model name a caller asks for, mapped to the deployment that serves it. Defaults to the deployments themselves, so a caller asks for the deployment name unless a different public name is mapped."
  type        = map(string)
  default     = {}
}

variable "document_models" {
  description = "Document Intelligence model IDs a service may analyse with, for the document-intelligence-v1 capability. A service's allowedModels must name models on this list, so a custom model you build is added here before a team can use it."
  type        = list(string)
  default = [
    "prebuilt-read",
    "prebuilt-layout",
    "prebuilt-document",
    "prebuilt-invoice",
    "prebuilt-receipt",
    "prebuilt-idDocument",
    "prebuilt-businessCard",
  ]
}

variable "speech_max_audio_bytes" {
  description = "Largest audio upload the speech-to-text-fast-v1 capability accepts, checked against the declared Content-Length before the request reaches the backend. Microsoft's pages give different limits for fast transcription (250 to 500 MB); the default is the middle one. A chunked upload declares no length and is not checked here."
  type        = number
  default     = 314572800

  validation {
    condition     = var.speech_max_audio_bytes >= 1
    error_message = "speech_max_audio_bytes must be at least 1."
  }
}
