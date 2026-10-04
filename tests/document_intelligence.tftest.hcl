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
  enabled_capabilities = ["chat-completions-v1", "document-intelligence-v1"]
}

run "the_api_is_published_with_its_own_path_and_policy" {
  command = plan

  assert {
    condition     = azurerm_api_management_api.capability["document-intelligence-v1"].path == "ai/v1/document-intelligence"
    error_message = "Document Intelligence should be published at ai/v1/document-intelligence."
  }

  assert {
    condition     = strcontains(azurerm_api_management_api_policy.capability["document-intelligence-v1"].xml_content, "/documentintelligence/documentModels/")
    error_message = "The policy must rewrite to the Document Intelligence backend path."
  }

  assert {
    condition     = strcontains(azurerm_api_management_api_policy.capability["document-intelligence-v1"].xml_content, "api-version=2024-11-30")
    error_message = "The policy must set the backend api-version itself."
  }

  assert {
    condition     = strcontains(azurerm_api_management_api_policy.capability["document-intelligence-v1"].xml_content, "Operation-Location")
    error_message = "The policy must rewrite Operation-Location so the backend host never reaches the caller."
  }
}

run "the_gateway_identity_can_call_document_intelligence" {
  command = plan

  assert {
    condition     = length(azurerm_role_assignment.gateway_cognitive_services_user) == 1
    error_message = "The OpenAI role does not cover Document Intelligence, so Cognitive Services User must be granted."
  }
}

run "chat_only_gateway_gets_no_extra_role" {
  command = plan

  variables {
    enabled_capabilities = ["chat-completions-v1"]
  }

  assert {
    condition     = length(azurerm_role_assignment.gateway_cognitive_services_user) == 0
    error_message = "The extra role is only needed when a non-OpenAI capability is published."
  }
}

run "a_document_service_is_onboarded_with_document_models" {
  command = plan

  variables {
    applications = {
      orders = {
        owner = "payments-team"
        access = {
          service_principal_ids = ["11111111-1111-1111-1111-111111111111"]
        }
        services = {
          scans = {
            capability     = "document-intelligence-v1"
            allowed_models = ["prebuilt-layout"]
          }
        }
      }
    }
  }

  assert {
    condition     = strcontains(azurerm_api_management_product_policy.application["orders"].xml_content, "MatchedParameters.GetValueOrDefault(&quot;modelId&quot;")
    error_message = "The product policy must take the model from the path for a document service."
  }

  assert {
    condition     = !strcontains(azurerm_api_management_product_policy.application["orders"].xml_content, "streaming_not_supported")
    error_message = "A document-only application must not carry the chat request checks."
  }
}

run "a_model_the_gateway_does_not_permit_is_refused_at_plan_time" {
  command = plan

  variables {
    applications = {
      orders = {
        owner = "payments-team"
        access = {
          service_principal_ids = ["11111111-1111-1111-1111-111111111111"]
        }
        services = {
          scans = {
            capability     = "document-intelligence-v1"
            allowed_models = ["prebuilt-nonsense"]
          }
        }
      }
    }
  }

  expect_failures = [azurerm_api_management_product.application["orders"]]
}

# The chat request checks parse the body as JSON, so they must only run for the API the
# chat subscription was granted: a chat key on another API has to reach the capability
# check (403), not fail parsing a document, and a body that is not JSON has to be
# refused with 400 rather than raise.
run "chat_request_checks_are_tied_to_the_chat_api_and_survive_a_bad_body" {
  command = plan

  variables {
    applications = {
      orders = {
        owner = "payments-team"
        access = {
          service_principal_ids = ["11111111-1111-1111-1111-111111111111"]
        }
        services = {
          chat = {
            capability     = "chat-completions-v1"
            allowed_models = ["gpt-4o"]
          }
          scans = {
            capability     = "document-intelligence-v1"
            allowed_models = ["prebuilt-read"]
          }
        }
      }
    }
  }

  assert {
    condition     = strcontains(azurerm_api_management_product_policy.application["orders"].xml_content, "context.Subscription.Name == &quot;orders-chat&quot; &amp;&amp; (context.Api.Id == &quot;chat-completions-v1&quot;")
    error_message = "The chat request checks must be conditioned on the subscription's own API."
  }

  assert {
    condition     = strcontains(azurerm_api_management_product_policy.application["orders"].xml_content, "catch (Exception)")
    error_message = "A body that is not JSON must be handled, not raise."
  }
}
