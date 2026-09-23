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

For people calling as themselves rather than through a workload, as the reference
allows, the same registration also needs:

4. The app role to allow users as well as applications (`allowedMemberTypes` of
   `Application` and `User`), assigned to a group the people are in. The role then
   appears in their own tokens. It does not work the other way round: a role assigned
   to a group never reaches a workload's app-only token, which gets `missing_role`.
5. A delegated scope, with Azure CLI (`04b07795-8ddb-461a-bbee-02f9e1bf7b46`)
   pre-authorised for it, so `az account get-access-token --scope
   api://<client id>/.default` works without a consent prompt.

Unlike the rest of this guide, this path has not yet been run end to end.

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

`service-principal` ids are workloads: managed identities and service principals, by
object id. They are bound into the product policy. `aad-group` ids are for people: the
group gets the same read grant, but the binding holds service principals only, so a
person's call passes it only in an application that lists none. Give people and
workloads separate applications.

**Separately, grant their workload identity the gateway's app role.** This is not in
the YAML because it happens in your directory:

```bash
az rest --method post \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/<their sp>/appRoleAssignments" \
  --body '{"principalId":"<their sp>","resourceId":"<gateway sp>","appRoleId":"<role id>"}'
```

Without it every call is refused with `missing_role`, whatever the YAML says.

### What the plan refuses

Every entry is checked at plan time, whichever input it came through, and every problem
is reported at once rather than one per run:

- a name that is not 2 to 40 lowercase letters, digits and single hyphens
- an application with no services, or no principal
- an object id that is not a GUID, or is the all-zero placeholder
- one identity granted by two owners, or listed as both a service principal and a group
- a capability that is not enabled, a service with no models, or a model the gateway
  does not serve
- a limit below 1, a daily cap its per-minute limit can never reach, or services whose
  own limits add up to more than their application's
- alerting enabled with no email, or on a service with no daily token quota of its own
- content safety configured while `enable_content_safety` is false, an unknown
  category, or a threshold outside 0 to 7

A typo in a model name, for instance, fails the plan rather than every call:

```
Application 'orders' cannot be onboarded:
  - service 'chat' allows model 'gpt4o', which this gateway does not serve (serves: gpt-4o, gpt-4o-reporting)
```

## What a team does

From inside the network, because both the vault and an Internal gateway are private
([ways onto it](key-vault-access.md#reading-a-secret-yourself)), and with the gateway's
hostname resolving to its private address (see
[reaching an Internal gateway](gateway.md#reaching-an-internal-gateway)):

```bash
az login --service-principal -u <their app id> -p <secret> --tenant <tenant> \
  --allow-no-subscriptions        # or --identity, for a managed identity

KEY=$(az keyvault secret show --vault-name <vault> \
  --name apim-subscription-orders-chat --query value -o tsv)
TOKEN=$(az account get-access-token --scope "api://<gateway app id>/.default" \
  --query accessToken -o tsv)

curl "https://<gateway>/ai/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Ocp-Apim-Subscription-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Say hello"}]}'
```

Each identity can read only its own application's keys; asking for another team's is
`Forbidden`. The subscription's `listSecrets` call in Azure Resource Manager also
returns a key, but it needs rights on the API Management instance itself, so it is an
operator's route rather than a team's.

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
| No key | 401 `missing_subscription_key` |
| A wrong or revoked key, including an offboarded team's | 401 `invalid_subscription_key` |
| A path matching no API | 404 `route_not_found` |
| `stream: true` | 400 `streaming_not_supported` |
| No `messages` | 400 `invalid_request` |
| A prompt attack, such as a jailbreak | 400 `content_filtered` |
| Content at or above a category's threshold | 400 `content_filtered` |
| Over a service's or application's request rate | 429 `rate_limit_exceeded` |
| Over a token rate or quota | 429 `token_quota_exceeded` |

The fourth is the subtlest: a leaked key alone gets nothing, because the product
policy matches the token's object id against the identities that application declared.

A service's own limits apply alongside its application's, so a tight service is
refused while its siblings carry on.

A content-safety threshold is compared with Content Safety's own score, which can be
lower than you would guess: a direct threat of violence passed at a threshold of 2.
To see that enforcement works at all, set a threshold of 0, which refuses even
"Say OK".

## Offboarding

Remove the entry and apply. The subscriptions are deleted, so their keys stop working
at once, and the team's secrets and read grants go with them.

Onboarding the same name again later works. With purge protection on, the deleted
secret is recovered rather than recreated, which takes about two minutes, and it
holds the new key, not the old one.

## Things that cost time if you hit them cold

- **A model version can be deprecating.** Deploying one fails with
  `ServiceModelDeprecating`. Check what is current in your region.
- **A model SKU is region-specific.** `Standard` is not available for every model
  everywhere; some need `GlobalStandard`.
- **Cognitive Services accounts soft-delete.** Recreating under the same name fails
  until the old one is purged with `az cognitiveservices account purge`.
- **Key Vault purge protection is irreversible.** A destroyed vault's name is reserved
  for the soft-delete retention period.
