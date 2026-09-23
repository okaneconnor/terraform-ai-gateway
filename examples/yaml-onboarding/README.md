# Onboarding teams from YAML

You consume this module from your own repository. Application teams who want to use
your gateway raise pull requests against **your** repository, not against the module.

Copy these files into yours:

| File | Whose | Purpose |
| --- | --- | --- |
| `onboarding.yaml` | yours | what teams edit, the only file they touch |
| `main.tf` | yours | calls the module, handing it the decoded YAML |

That is the whole wiring:

```hcl
applications_yaml = yamldecode(file("${path.module}/onboarding.yaml"))
```

The module does the translation, so every consumer gets the same behaviour and a
correction arrives with the module version rather than needing to be copied.

The decoding happens on your side because a published module cannot read a file from
your repository: `path.module` inside the module points at the downloaded copy.

The YAML is optional. Pass `applications` in HCL instead if you prefer; set one or
the other, not both.

## What a team adds

```yaml
applications:
  - application: orders
    owner: payments-team
    accessType:
      service-principal:
        ids: [<workload identity object id>]
    limits:
      requestsPerMinute: 60
      dailyTokenQuota: 50000
    services:
      - service: chat
        capability:
          api: chat-completions-v1
          allowedModels: [gpt-4o]
```

That produces an API Management product carrying the team's policy, one subscription
per service, and a key per subscription.

## What a team also needs, which is not in this file

A workload identity holding the gateway's app role. Assigning it needs directory
permission, so it lives in your directory rather than in this repository. In the
reference implementation it is a pull request against a separate repository that owns
the app registration.

Without it a call is refused with `missing_role`, whatever the YAML says.

## Settings cascade

A service overrides its application, which overrides the module's defaults. Omit a key
and it inherits, so the common case stays short. In the example above `summariser`
takes a tighter rate limit and a looser Violence threshold while inheriting everything
else.

## Keys

Each subscription key is written to the platform vault, and the team's principals are
granted read on that secret alone, not the vault. A gateway onboards many teams, and
vault-wide read would let any of them read another's key.

The vault is private, so Terraform has to run somewhere its private endpoint is
reachable. The reference runs its onboarding stage, and only that stage, on a
self-hosted agent inside the network while everything else runs on hosted agents. Do
the same, or run the whole thing on-network.
