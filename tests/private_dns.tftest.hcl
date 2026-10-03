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
}

run "zones_are_off_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_private_dns_zone.gateway) == 0
    error_message = "No private DNS zone should be created unless create_private_dns_zones is true."
  }

  assert {
    condition     = length(azurerm_private_dns_zone_virtual_network_link.gateway) == 0
    error_message = "No network link should be created unless create_private_dns_zones is true."
  }
}

run "zones_are_created_and_linked_when_enabled" {
  command = plan

  variables {
    create_private_dns_zones = true
  }

  assert {
    condition = toset([for z in azurerm_private_dns_zone.gateway : z.name]) == toset([
      "privatelink.vaultcore.azure.net",
      "privatelink.cognitiveservices.azure.com",
    ])
    error_message = "Expected exactly the Key Vault and cognitive services privatelink zones."
  }

  assert {
    condition     = length(azurerm_private_dns_zone_virtual_network_link.gateway) == 2
    error_message = "Each created zone must be linked to the module's network."
  }
}

run "caller_zone_ids_are_still_honoured_when_the_flag_is_off" {
  command = plan

  variables {
    key_vault = {
      private_dns_zone_ids = ["/subscriptions/00000000-0000-0000-0000-000000000009/resourceGroups/hub/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"]
    }
  }

  assert {
    condition     = length(local.key_vault_dns_zone_ids) == 1 && length(azurerm_private_dns_zone.gateway) == 0
    error_message = "A zone ID supplied by the caller must be used and no zone created."
  }
}

run "flag_and_caller_zone_ids_together_are_refused" {
  command = plan

  variables {
    create_private_dns_zones = true
    ai_services = {
      private_dns_zone_ids = ["/subscriptions/00000000-0000-0000-0000-000000000009/resourceGroups/hub/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com"]
    }
  }

  expect_failures = [var.create_private_dns_zones]
}
