# Getting at the Key Vault

The vault holds the subscription keys issued to onboarded teams. It is private: no
public access, firewall set to deny. Reaching it takes two things, and you need both.

1. **DNS** — something must point the vault's hostname at its private endpoint.
2. **A role** — Azure grants no access to secrets by default, not even to whoever
   created the vault.

Miss either one and every call fails with `Forbidden`.

## 1. DNS

The module does not create the `privatelink.vaultcore.azure.net` zone. In most
organisations that zone is shared, and a module creating its own would collide with
it. Pick whichever fits you.

**You already have the zone.** Hand it over and Azure writes the record for you.

```hcl
key_vault = {
  private_dns_zone_ids = ["/subscriptions/.../privateDnsZones/privatelink.vaultcore.azure.net"]
}
```

**A central pipeline manages your zones.** Give it access to the network and let it
do the work. Use the `key_vault_private_endpoint_ip` output for the record.

```hcl
private_dns_linker_principal_ids = ["<object-id-of-that-pipeline>"]
```

**You have neither.** Create the zone yourself, next to the module:

```hcl
resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = module.ai_gateway.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
  name                  = "link-vault"
  resource_group_name   = module.ai_gateway.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = module.ai_gateway.virtual_network_id
}
```

Then pass its `id` as `private_dns_zone_ids` above.

## 2. Roles

Everyone is an object ID. The module never looks anyone up by name, so it needs no
directory permission.

| Who | Input | What they get |
| --- | --- | --- |
| Terraform itself | `key_vault_grant_deployer_secrets_officer` (on by default) | writes subscription keys |
| Platform operators | `key_vault_secrets_officer_principal_ids` | read and write any secret |
| Anyone who needs to find a secret | `key_vault_reader_principal_ids` | sees the vault and secret names, no values |
| A service that reads everything | `key_vault_secrets_user_principal_ids` | reads every secret |

```hcl
key_vault_reader_principal_ids          = ["<your-group-object-id>"]
key_vault_secrets_officer_principal_ids = ["<your-group-object-id>"]
```

Onboarded teams get none of these. Vault-wide read would let one team read another
team's key, so the onboarding layer grants access to each team's own secret only.

Role changes take a few minutes to take effect. A `Forbidden` straight after an
apply is usually just that.

## Reading a secret yourself

This is by design: the vault is private, so a laptop on the internet cannot read it,
whatever roles it holds. You need to be on the network. Cheapest first:

- **A temporary container shell.** An Azure Container Instance in a spare subnet of
  `virtual_network_id`, opened with `az container exec`. Nothing to pay once it is
  deleted.
- **A jump host with Azure Bastion.** A small VM in the same network. Bastion
  Developer is free in supported regions.
- **A VPN through your hub.** Peer `virtual_network_id` to the hub and have its DNS
  answer for `vault.azure.net` and `vaultcore.azure.net`. The portal and `az keyvault`
  then work from your laptop.

On every route the name must resolve (section 1) and you need a role (section 2). A
team reads its own keys through the onboarding grant; operators use
`key_vault_secrets_officer_principal_ids` or `key_vault_reader_principal_ids`.

Operators can also read a key from API Management with `az rest` against the
subscription's `listSecrets` action. That needs no path to the vault, but it does need
rights on the API Management instance, so it is not a route for teams.
