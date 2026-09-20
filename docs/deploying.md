# Deploying the gateway, end to end

What it takes to go from nothing to a team making an authenticated model call. Every
step here has been run against a real subscription; the refusals at the end are actual
responses, not intentions.

## Before you start

### Permissions the deploying principal needs

| Scope | Role | Why |
| --- | --- | --- |
| Resource group | Contributor | creates everything |
| Resource group | Role Based Access Control Administrator | the module grants data-plane roles, and Contributor does **not** include `Microsoft.Authorization/roleAssignments/write` |
| Subscription | ability to register resource providers | Cognitive Services, API Management, Key Vault |

Missing the second one fails partway through with `AuthorizationFailed` on
`roleAssignments/write`, after the infrastructure is already built.

### Where Terraform runs

The Key Vault holding teams' subscription keys is private, so **Terraform must run
somewhere its private endpoint resolves**. In practice that is a self-hosted build
agent, a container, or a virtual machine inside the network. The reference
implementation runs its onboarding stage on a self-hosted agent for exactly this
reason while the rest runs on hosted agents.

Running from outside fails with:

```
Public network access is disabled and request is not from a trusted service
nor via an approved private link.
```

### Private DNS zones the module does not create

The module creates private endpoints but no zones, because in most estates the zones
are central and shared, and a module creating its own would either collide with them
or leave an orphan. Two are needed, each linked to the gateway's network with an A
record pointing at the endpoint:

| Zone | For | Without it |
| --- | --- | --- |
| `privatelink.vaultcore.azure.net` | Key Vault | Terraform cannot write subscription keys, even from inside the network |
| `privatelink.cognitiveservices.azure.com` | AI Services | the gateway reaches the model's public endpoint, which is disabled, and calls fail at the backend |

Attach zones you already own with `key_vault.private_dns_zone_ids` and
`ai_services.private_dns_zone_ids`. If a central pipeline manages them instead, give
it access to the network with `private_dns_linker_principal_ids` and use the
`key_vault_private_endpoint_ip` and `ai_services_private_endpoint_ip` outputs to
register the records.

If you have neither, create them next to the module:

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

and the same for `privatelink.cognitiveservices.azure.com`.

### The Entra app registration

The gateway validates tokens against an app registration the module does not create,
because creating one and assigning its roles needs directory permission and has its
own lifecycle. You need:

1. An app registration with an Application app role, for example `AI.Gateway.Standard`.
2. An Application ID URI set on it, `api://<client id>`. Without this a client cannot
   request a token for it and gets `invalid_resource`.
3. A service principal for the app.

Pass its identifier as `jwt.audiences`, matching whatever the client asks for as its
scope. If clients request `api://<client id>/.default`, the audience is
`api://<client id>`.

## Deploying

```hcl
module "ai_gateway" {
  source = "github.com/okaneconnor/terraform-ai-gateway"

  name_prefix   = "acme"
  environment   = "dev"
  location      = "uksouth"
  address_space = "10.90.0.0/22"

  model_deployments = {
    "gpt-4o" = { model_name = "gpt-4o", model_version = "2024-11-20" }
  }

  apim = {
    publisher_name  = "Platform Team"
    publisher_email = "platform@example.com"
  }

  jwt = { audiences = ["api://<gateway app client id>"] }

  applications_yaml = yamldecode(file("${path.module}/onboarding.yaml"))
}
```

API Management takes 30 to 45 minutes to create. Note that the Developer tier carries
no SLA: Azure takes its management endpoint offline during platform upgrades, and
while it is down Terraform cannot manage anything inside the gateway. See
[the gateway](gateway.md).

## Onboarding a team

A team adds itself to your `onboarding.yaml` by pull request:

```yaml
applications:
  - application: orders
    owner: payments-team
    accessType:
      service-principal:
        ids: [<their workload identity object id>]
    limits:
      requestsPerMinute: 60
      dailyTokenQuota: 50000
    services:
      - service: chat
        capability: { api: chat-completions-v1, allowedModels: [gpt-4o] }
```

That creates a product carrying their policy, a subscription per service, a key per
subscription in the vault, and a grant letting only their identity read it.

**Separately, grant their workload identity the gateway's app role.** This is not in
the YAML because it happens in your directory:

```bash
az rest --method post \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/<their sp>/appRoleAssignments" \
  --body '{"principalId":"<their sp>","resourceId":"<gateway sp>","appRoleId":"<role id>"}'
```

Without it every call is refused with `missing_role`, whatever the YAML says.

## What a team does

Acquire a token, read the key, call the gateway:

```bash
TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token" \
  -d "client_id=<their app id>" -d "client_secret=<secret>" \
  -d "scope=api://<gateway app id>/.default" -d "grant_type=client_credentials" \
  | jq -r .access_token)

KEY=$(az keyvault secret show --vault-name <vault> \
  --name apim-subscription-orders-chat --query value -o tsv)

curl "https://<gateway>/ai/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Ocp-Apim-Subscription-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Say OK"}]}'
```

Reading the key needs network access to the vault. A team outside the network can
read it from the subscription instead, which is an ARM call:

```bash
az rest --method post \
  --url "https://management.azure.com<subscription id>/listSecrets?api-version=2024-05-01" \
  --query primaryKey -o tsv
```

The subscription ids are in the `subscriptions` output.

## What the gateway refuses

Verified against a live deployment with two teams onboarded from one YAML file:

| Request | Response |
| --- | --- |
| Correct token, correct key, permitted model | the completion |
| Permitted identity asking for another team's model | 403 `model_not_permitted` |
| Onboarded identity without the app role | 403 `missing_role` |
| Valid token used with another team's key | 403 `identity_not_permitted` |
| No token | 401 `missing_token` |
| Invalid token | 401 `invalid_token` |
| A path matching no API | 404 `route_not_found` |

The fourth is the subtlest: a leaked key alone gets nothing, because the product
policy matches the token's object id against the identities that application declared.

## Things that cost time if you hit them cold

- **A model version can be deprecating.** Deploying one fails with
  `ServiceModelDeprecating`. Check what is current in your region.
- **A model SKU is region-specific.** `Standard` is not available for every model
  everywhere; some need `GlobalStandard`.
- **Cognitive Services accounts soft-delete.** Recreating under the same name fails
  until the old one is purged with `az cognitiveservices account purge`.
- **Key Vault purge protection is irreversible.** A destroyed vault's name is reserved
  for the soft-delete retention period.
