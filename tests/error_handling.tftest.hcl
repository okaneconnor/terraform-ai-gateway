# Plan-only: no Azure credentials or resources are needed.
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000001"
      subscription_id = "00000000-0000-0000-0000-000000000002"
      object_id       = "00000000-0000-0000-0000-000000000003"
      client_id       = "00000000-0000-0000-0000-000000000004"
    }
  }
}
mock_provider "azapi" {}

variables {
  name_prefix   = "aigw"
  environment   = "test"
  location      = "uksouth"
  address_space = "10.60.0.0/22"
  apim = {
    publisher_name  = "Platform Team"
    publisher_email = "platform@example.com"
  }
  jwt                   = { audiences = ["api://test"] }
  enable_content_safety = true
}

# The API-level on-error block runs after the global ai-error-handling fragment and
# can return a response of its own. It must only turn a verdict from the content safety
# policy into 400 content_filtered. A failure to reach the service
# (Reason == ContentSafetyPolicyViolated) belongs to the fragment, which answers 503, and
# must not be rewritten here as though the caller's prompt were blocked.
run "chat_api_does_not_report_a_content_safety_outage_as_a_block" {
  command = plan

  assert {
    condition     = !strcontains(azurerm_api_management_api_policy.capability["chat-completions-v1"].xml_content, "ContentSafetyPolicyViolated")
    error_message = "The chat API on-error block must not match Reason == ContentSafetyPolicyViolated: that is the service being unreachable, answered with 503 by ai-error-handling."
  }

  assert {
    condition     = strcontains(azurerm_api_management_api_policy.capability["chat-completions-v1"].xml_content, "context.LastError.Source == &quot;llm-content-safety&quot;")
    error_message = "The chat API on-error block must still turn a content safety verdict into content_filtered."
  }
}
