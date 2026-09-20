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
