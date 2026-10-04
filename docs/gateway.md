# The gateway

## What a request meets

A call arrives at API Management and passes through policies in scope order.

1. **Global policy.** Sets a correlation ID, validates the Entra token and checks the
   caller carries one of `jwt.required_roles`, then sets observability variables.
2. **API policy.** Strips the caller's credentials so they never reach a backend,
   selects the backend, rewrites the path for the upstream service.
3. **Backend.** Reached as the gateway's managed identity. No keys exist anywhere:
   the AI account has local authentication disabled.
4. **On error.** A single envelope, so callers get the same error shape whatever
   failed.

The health endpoint is the one exception. Its policy omits `<base />`, so it skips
the token check entirely and answers unauthenticated.

## Capabilities

`enabled_capabilities` publishes APIs from the module's catalogue. Each is its own API
with its own path, OpenAPI document and policy, and a service is onboarded to one.

| Capability | Path | Takes | `allowedModels` means |
| --- | --- | --- | --- |
| `chat-completions-v1` | `/ai/v1` | JSON chat request | model deployments |
| `document-intelligence-v1` | `/ai/v1/document-intelligence` | a document, analysed asynchronously | Document Intelligence model IDs |

**Document Intelligence.** `POST /documentModels/{modelId}:analyze` starts an analysis
and returns `202` with an `Operation-Location` header. The gateway rewrites that header
to point at itself, so the backend host never reaches a caller; poll it with
`GET /documentModels/{modelId}/analyzeResults/{resultId}`. The model is in the path, so
the model allowlist is applied to the path, not to the body, and a document is never
parsed. A service may only name models on `document_models` (the prebuilt models by
default), so a custom model is added there first. Content safety and token limits are
chat-only and do not apply; the request rate and daily limits do. A completed analysis
emits a `Pages Analyzed` metric per subscription.

The backend is the same AI Services account as chat, reached as the gateway's managed
identity. That identity is granted `Cognitive Services User` on the account when a
capability other than chat is enabled, because the OpenAI role does not cover it.

## Names that are public API

Capability policies reference these by name, so renaming one breaks any consumer
that wrote a policy against it.

Fragments: `ai-auth-entra-jwt`, `ai-backend-managed-identity`, `ai-header-scrub`,
`ai-error-handling`, `ai-observability`, `ai-model-allowlist`, `ai-token-metrics`,
`ai-document-metrics`.

Backends: `ai-services`, and `content-safety` when enabled.

## Reaching an Internal gateway

`Internal` is the default: the gateway has no public address and lives on the API
Management subnet. Its private address is the `apim_private_ip` output.

Nothing resolves its hostname to that address on its own. A caller needs either a
DNS record pointing at it, or a custom hostname supplied through
`apim_gateway_hostnames` with a certificate. Until then it is reachable only by IP
with a `Host` header, from inside the network.

Microsoft's guidance for Internal mode is to register exact host names only: an `A`
record for each name the instance serves (`<name>.azure-api.net`, and the `portal`,
`developer`, `management` and `scm` variants if you use them) pointing at the private
address. Do not create a private DNS zone, or a forward lookup zone, for the
`azure-api.net` apex. Doing so makes your zone authoritative for a domain Azure and
other services share, and breaks their public records. See
[DNS configuration for internal virtual network scenarios](https://learn.microsoft.com/azure/api-management/api-management-using-with-internal-vnet#dns-configuration-for-internal-virtual-network-scenarios).

`create_private_dns_zones` covers the Key Vault and AI Services endpoints only. It
does not create anything for the gateway's own host names.

## The Developer SKU has no SLA

Azure takes a Developer instance's management endpoint offline during platform
upgrades. While it is down, Terraform cannot manage anything inside the gateway:

```
Failed to connect to Management endpoint Port 3443 ... for the Developer SKU
service which will have inherent downtime during underneath platform upgrades.
```

In practice that means an apply can hang for an hour on a create that Azure has
already finished, and a destroy can fail partway, leaving the instance in a state
where later runs also fail. It recovers on its own, but not predictably.

Use Developer to try the module. Use a tier with an SLA for anything a team depends
on.

## Before an authenticated call will work

The gateway validates tokens against an Entra app registration this module does not
create, because that needs directory permission and has its own lifecycle. You need
an app registration with an app role whose value matches `jwt.required_roles`, and
its client ID passed as `jwt.audiences`. Fragments deploy without it; calls will not
succeed until it exists.
