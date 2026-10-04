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

run "no_rules_means_no_nsg_and_policies_stay_off" {
  command = plan

  assert {
    condition     = length(azurerm_network_security_group.private_endpoints) == 0
    error_message = "No NSG should be created without rules."
  }

  assert {
    condition     = azurerm_subnet.private_endpoints.private_endpoint_network_policies == "Disabled"
    error_message = "Network policies are left as they were when no rules are given."
  }
}

# An NSG on a private endpoint subnet has no effect while the subnet's private endpoint
# network policy is Disabled, so supplying rules must also turn the policy on.
run "rules_turn_on_nsg_enforcement_for_private_endpoints" {
  command = plan

  variables {
    private_endpoint_nsg_rules = {
      deny-other-inbound = {
        priority                   = 4000
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      }
    }
  }

  assert {
    condition     = length(azurerm_network_security_group.private_endpoints) == 1
    error_message = "An NSG should be created when rules are given."
  }

  assert {
    condition     = azurerm_subnet.private_endpoints.private_endpoint_network_policies == "NetworkSecurityGroupEnabled"
    error_message = "Rules on the private endpoint subnet only apply if NSG enforcement is enabled for private endpoints."
  }
}
