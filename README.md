# terraform-ai-gateway

A Terraform module for a multi-capability Azure AI gateway with per-application team onboarding.

Status: in development. The base infrastructure layer is implemented; API Management,
capabilities and onboarding follow.

Licensed under the [MIT License](LICENSE).

## Key Vault

The vault holding teams' subscription keys is private: no public access, reachable
only through its private endpoint. The module creates no private DNS zone, because
that zone is usually shared across an organisation, and Azure grants no access to
secrets by default.

Both need setting up before anyone can read a secret. See
[docs/key-vault-access.md](docs/key-vault-access.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.0, >= 4.40 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 4.0, >= 4.40 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_application_insights.gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights) | resource |
| [azurerm_key_vault.platform](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_log_analytics_workspace.platform](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_network_security_group.apim](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_group.private_endpoints](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_rule.apim](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.private_endpoints](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_private_endpoint.key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_resource_group.gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.gateway_secrets_officer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.key_vault_readers](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.key_vault_secrets_officers](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.key_vault_secrets_users](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.private_dns_linker](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_route.apim](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route) | resource |
| [azurerm_route_table.apim](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) | resource |
| [azurerm_subnet.apim](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.private_endpoints](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.apim](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_subnet_network_security_group_association.private_endpoints](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_subnet_route_table_association.apim](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) | resource |
| [azurerm_user_assigned_identity.gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_virtual_network.gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | CIDR for the virtual network. A /22 or larger lets the module derive both subnet prefixes; anything smaller needs subnet\_prefixes set explicitly. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region for every resource this module creates. Also supplies the region token in generated names. Required: the module takes no view on where your infrastructure belongs. | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Workload name, used in every generated resource name after the CAF type abbreviation. | `string` | n/a | yes |
| <a name="input_apim_nsg_additional_rules"></a> [apim\_nsg\_additional\_rules](#input\_apim\_nsg\_additional\_rules) | Extra security rules for the API Management subnet, merged over the mandatory baseline. Reusing a baseline rule name replaces that rule. | <pre>map(object({<br/>    priority                     = number<br/>    direction                    = string<br/>    access                       = string<br/>    protocol                     = string<br/>    source_port_range            = optional(string)<br/>    source_port_ranges           = optional(list(string))<br/>    destination_port_range       = optional(string)<br/>    destination_port_ranges      = optional(list(string))<br/>    source_address_prefix        = optional(string)<br/>    source_address_prefixes      = optional(list(string))<br/>    destination_address_prefix   = optional(string)<br/>    destination_address_prefixes = optional(list(string))<br/>    description                  = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_apim_nsg_baseline_rules"></a> [apim\_nsg\_baseline\_rules](#input\_apim\_nsg\_baseline\_rules) | Inbound rules Azure documents as the minimum for API Management injected into a<br/>virtual network, in both external and internal mode: TCP 3443 from the<br/>ApiManagement service tag for the management endpoint, and TCP 6390 from<br/>AzureLoadBalancer for the infrastructure load balancer. Without them the instance<br/>cannot provision or goes unhealthy, which is why they are on by default.<br/><br/>They do not apply to every deployment. API Management v2 tiers integrated for<br/>private outbound access do not enforce inbound rules at all, and a gateway not<br/>injected into a virtual network needs none of this. Set to {} to create the<br/>security group with no baseline, or override an individual rule by reusing its<br/>key in apim\_nsg\_additional\_rules. | <pre>map(object({<br/>    priority                     = number<br/>    direction                    = string<br/>    access                       = string<br/>    protocol                     = string<br/>    source_port_range            = optional(string)<br/>    source_port_ranges           = optional(list(string))<br/>    destination_port_range       = optional(string)<br/>    destination_port_ranges      = optional(list(string))<br/>    source_address_prefix        = optional(string)<br/>    source_address_prefixes      = optional(list(string))<br/>    destination_address_prefix   = optional(string)<br/>    destination_address_prefixes = optional(list(string))<br/>    description                  = optional(string)<br/>  }))</pre> | <pre>{<br/>  "apim-load-balancer": {<br/>    "access": "Allow",<br/>    "description": "Azure infrastructure load balancer health probe. Required by Azure for virtual network injection.",<br/>    "destination_address_prefix": "VirtualNetwork",<br/>    "destination_port_range": "6390",<br/>    "direction": "Inbound",<br/>    "priority": 110,<br/>    "protocol": "Tcp",<br/>    "source_address_prefix": "AzureLoadBalancer",<br/>    "source_port_range": "*"<br/>  },<br/>  "apim-management-endpoint": {<br/>    "access": "Allow",<br/>    "description": "API Management management endpoint. Required by Azure for virtual network injection.",<br/>    "destination_address_prefix": "VirtualNetwork",<br/>    "destination_port_range": "3443",<br/>    "direction": "Inbound",<br/>    "priority": 100,<br/>    "protocol": "Tcp",<br/>    "source_address_prefix": "ApiManagement",<br/>    "source_port_range": "*"<br/>  }<br/>}</pre> | no |
| <a name="input_custom_names"></a> [custom\_names](#input\_custom\_names) | Explicit name for individual resources, replacing the generated CAF name. Use when an existing naming convention must be matched, or when a generated name would exceed an Azure length limit. | <pre>object({<br/>    resource_group             = optional(string)<br/>    virtual_network            = optional(string)<br/>    apim_subnet                = optional(string)<br/>    private_endpoint_subnet    = optional(string)<br/>    apim_nsg                   = optional(string)<br/>    private_endpoint_nsg       = optional(string)<br/>    route_table                = optional(string)<br/>    key_vault                  = optional(string)<br/>    key_vault_private_endpoint = optional(string)<br/>    identity                   = optional(string)<br/>    log_analytics              = optional(string)<br/>    application_insights       = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment token in generated names, for example dev, test or prod. Omit it and it drops out of the name entirely. | `string` | `null` | no |
| <a name="input_instance"></a> [instance](#input\_instance) | Instance token appended last in generated names, for example 002. Omit it and it drops out of the name entirely. | `string` | `null` | no |
| <a name="input_key_vault"></a> [key\_vault](#input\_key\_vault) | Settings for the Key Vault the module creates.<br/><br/>The vault is always private: public network access is disabled and the firewall<br/>denies by default, so it is reachable only through its private endpoint from<br/>inside the network. There is no option to expose it publicly.<br/><br/>Private access only works once the vault hostname resolves to the endpoint,<br/>which needs a privatelink.vaultcore.azure.net zone linked to the network doing<br/>the lookup. The module does not own that zone: in most estates it is central and<br/>shared. Attach one with private\_dns\_zone\_ids, or leave it empty and let whatever<br/>manages your zones register the record, granting it access to the network with<br/>private\_dns\_linker\_principal\_ids. | <pre>object({<br/>    sku_name                   = optional(string, "standard")<br/>    purge_protection_enabled   = optional(bool, true) # irreversible once applied: Azure forbids turning it back off, and a destroyed vault's name stays reserved for the soft-delete retention period<br/>    soft_delete_retention_days = optional(number, 90)<br/>    create_private_endpoint    = optional(bool, true)<br/>    private_dns_zone_ids       = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_key_vault_grant_deployer_secrets_officer"></a> [key\_vault\_grant\_deployer\_secrets\_officer](#input\_key\_vault\_grant\_deployer\_secrets\_officer) | Grant the principal running Terraform Key Vault Secrets Officer on the vault. Required for the module to write API Management subscription keys into it, because role-based access control grants no data-plane access implicitly. Set false only when that role is granted out of band. | `bool` | `true` | no |
| <a name="input_key_vault_reader_principal_ids"></a> [key\_vault\_reader\_principal\_ids](#input\_key\_vault\_reader\_principal\_ids) | Object IDs granted Key Vault Reader on the vault: see the vault and enumerate secret names, without access to any secret value. This is what an operator needs to find a secret before a separate role lets them read it. | `list(string)` | `[]` | no |
| <a name="input_key_vault_secrets_officer_principal_ids"></a> [key\_vault\_secrets\_officer\_principal\_ids](#input\_key\_vault\_secrets\_officer\_principal\_ids) | Object IDs granted Key Vault Secrets Officer, which can read, write and delete secret values. Put your own user or group object ID here to be able to inspect the subscription keys the gateway stores. Object IDs only: the module performs no directory lookups and needs no directory permission. | `list(string)` | `[]` | no |
| <a name="input_key_vault_secrets_user_principal_ids"></a> [key\_vault\_secrets\_user\_principal\_ids](#input\_key\_vault\_secrets\_user\_principal\_ids) | Object IDs granted Key Vault Secrets User, read-only on secret values. NOTE: this is vault-wide, so every listed principal can read EVERY secret. It is intended for operators and platform components. Per-team access to a single subscription key is granted per-secret by the onboarding layer instead. | `list(string)` | `[]` | no |
| <a name="input_log_analytics"></a> [log\_analytics](#input\_log\_analytics) | Settings for the Log Analytics workspace the module creates. | <pre>object({<br/>    sku               = optional(string, "PerGB2018")<br/>    retention_in_days = optional(number, 30)<br/>  })</pre> | `{}` | no |
| <a name="input_private_dns_linker_principal_ids"></a> [private\_dns\_linker\_principal\_ids](#input\_private\_dns\_linker\_principal\_ids) | Object IDs granted Network Contributor on the virtual network so a central private-DNS pipeline can link its zones to it. Leave empty when the module's own network is not used, or when zones are linked by other means. | `list(string)` | `[]` | no |
| <a name="input_private_endpoint_nsg_rules"></a> [private\_endpoint\_nsg\_rules](#input\_private\_endpoint\_nsg\_rules) | Security rules for the private endpoint subnet. Empty means no network security group is attached to it. | <pre>map(object({<br/>    priority                     = number<br/>    direction                    = string<br/>    access                       = string<br/>    protocol                     = string<br/>    source_port_range            = optional(string)<br/>    source_port_ranges           = optional(list(string))<br/>    destination_port_range       = optional(string)<br/>    destination_port_ranges      = optional(list(string))<br/>    source_address_prefix        = optional(string)<br/>    source_address_prefixes      = optional(list(string))<br/>    destination_address_prefix   = optional(string)<br/>    destination_address_prefixes = optional(list(string))<br/>    description                  = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_routes"></a> [routes](#input\_routes) | Routes for the API Management subnet, for example forced tunnelling to a firewall. Empty means no route table is created. | <pre>map(object({<br/>    address_prefix         = string<br/>    next_hop_type          = string<br/>    next_hop_in_ip_address = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_subnet_prefixes"></a> [subnet\_prefixes](#input\_subnet\_prefixes) | Explicit CIDRs for the subnets the module creates. When null they are derived from address\_space. The API Management subnet must be a /26 or larger. | <pre>object({<br/>    apim              = optional(string)<br/>    private_endpoints = optional(string)<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_application_insights_id"></a> [application\_insights\_id](#output\_application\_insights\_id) | Resource ID of the Application Insights component. |
| <a name="output_identity"></a> [identity](#output\_identity) | The gateway's user-assigned managed identity: resource id, principal id and client id. |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | Resource ID of the Key Vault holding subscription keys. |
| <a name="output_key_vault_private_endpoint_ip"></a> [key\_vault\_private\_endpoint\_ip](#output\_key\_vault\_private\_endpoint\_ip) | Private IP of the Key Vault's endpoint, for registering an A record in a private DNS zone the module does not own. |
| <a name="output_key_vault_uri"></a> [key\_vault\_uri](#output\_key\_vault\_uri) | Vault URI. Reachable only from a network that resolves it to the private endpoint. |
| <a name="output_log_analytics_workspace_id"></a> [log\_analytics\_workspace\_id](#output\_log\_analytics\_workspace\_id) | Resource ID of the Log Analytics workspace. |
| <a name="output_resource_group_id"></a> [resource\_group\_id](#output\_resource\_group\_id) | Resource ID of the resource group holding the gateway. |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Name of the resource group holding the gateway. |
| <a name="output_resource_names"></a> [resource\_names](#output\_resource\_names) | Every generated resource name. Consume these rather than rebuilding a name. |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnet resource IDs, keyed by purpose. |
| <a name="output_virtual_network_id"></a> [virtual\_network\_id](#output\_virtual\_network\_id) | Resource ID of the virtual network. Peer to a hub, or link a private DNS zone, using this. |
<!-- END_TF_DOCS -->
