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
  jwt = { audiences = ["api://test"] }
  model_deployments = {
    "gpt-4o" = { model_name = "gpt-4o", model_version = "2024-11-20" }
  }
  enabled_capabilities = ["chat-completions-v1", "speech-to-text-fast-v1"]
}

run "the_api_is_published_with_its_own_path_and_policy" {
  command = plan

  assert {
    condition     = azurerm_api_management_api.capability["speech-to-text-fast-v1"].path == "ai/v1/speech-to-text/fast/transcriptions:transcribe"
    error_message = "Speech should be published at ai/v1/speech-to-text/fast/transcriptions:transcribe, with the colon in the API path."
  }

  assert {
    condition     = strcontains(azurerm_api_management_api_policy.capability["speech-to-text-fast-v1"].xml_content, "/speechtotext/transcriptions:transcribe?api-version=2025-10-15")
    error_message = "The policy must rewrite to the fast transcription backend path and set its own api-version."
  }
}

run "the_size_limit_is_enforced_and_configurable" {
  command = plan

  variables {
    speech_max_audio_bytes = 1000
  }

  assert {
    condition     = strcontains(azurerm_api_management_api_policy.capability["speech-to-text-fast-v1"].xml_content, "declaredLength &gt; 1000")
    error_message = "The configured limit must be the one the policy enforces."
  }
}

run "the_gateway_identity_can_call_speech" {
  command = plan

  assert {
    condition     = length(azurerm_role_assignment.gateway_cognitive_services_user) == 1
    error_message = "The OpenAI role does not cover Speech, so Cognitive Services User must be granted."
  }
}

run "an_audio_service_is_onboarded_without_models_and_skips_the_model_allowlist" {
  command = plan

  variables {
    applications = {
      calls = {
        owner = "contact-centre"
        access = {
          service_principal_ids = ["11111111-1111-1111-1111-111111111111"]
        }
        services = {
          transcripts = {
            capability = "speech-to-text-fast-v1"
          }
        }
      }
    }
  }

  assert {
    condition     = !strcontains(azurerm_api_management_product_policy.application["calls"].xml_content, "ai-model-allowlist")
    error_message = "A capability that takes no model must not run the model allowlist, which would refuse every call."
  }

  assert {
    condition     = !strcontains(azurerm_api_management_product_policy.application["calls"].xml_content, "llm-content-safety")
    error_message = "Prompt content safety is chat-only."
  }
}

run "naming_a_model_on_an_audio_service_is_refused_at_plan_time" {
  command = plan

  variables {
    applications = {
      calls = {
        owner = "contact-centre"
        access = {
          service_principal_ids = ["11111111-1111-1111-1111-111111111111"]
        }
        services = {
          transcripts = {
            capability     = "speech-to-text-fast-v1"
            allowed_models = ["whisper"]
          }
        }
      }
    }
  }

  expect_failures = [azurerm_api_management_product.application["calls"]]
}
