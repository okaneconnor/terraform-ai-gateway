resource "azurerm_api_management_product" "application" {
  for_each = local.applications

  product_id            = each.key
  display_name          = each.key
  resource_group_name   = local.resource_group_name
  api_management_name   = azurerm_api_management.gateway.name
  published             = true
  subscription_required = true
  approval_required     = false

  # A variable validation only sees its own variable, so these carry the typed
  # variable's rules onto whatever arrived through applications_yaml.
  lifecycle {
    precondition {
      condition     = alltrue([for svc in values(local.services) : contains(var.enabled_capabilities, svc.capability) if svc.application == each.key])
      error_message = "Application '${each.key}' names a capability that is not in enabled_capabilities."
    }
    precondition {
      condition     = length(local.applications[each.key].service_principal_ids) + length(local.applications[each.key].group_ids) > 0
      error_message = "Application '${each.key}' grants access to no principal, so nobody could use it."
    }
  }
}

# Carries the application's identity binding, limits and content-safety settings.
resource "azurerm_api_management_product_policy" "application" {
  for_each = local.applications

  product_id          = azurerm_api_management_product.application[each.key].product_id
  api_management_name = azurerm_api_management.gateway.name
  resource_group_name = local.resource_group_name

  xml_content = templatefile("${path.module}/policies/product.xml", local.application_policy_inputs[each.key])

  depends_on = [azurerm_api_management_policy_fragment.baseline]
}

# A product with no API linked grants its subscribers nothing.
resource "azurerm_api_management_product_api" "allowed" {
  for_each = local.product_apis

  product_id          = azurerm_api_management_product.application[each.value.application].product_id
  api_name            = azurerm_api_management_api.capability[each.value.capability].name
  api_management_name = azurerm_api_management.gateway.name
  resource_group_name = local.resource_group_name
}

# One per service: the unit of attribution, revocation and rate limiting.
resource "azurerm_api_management_subscription" "service" {
  for_each = local.services

  product_id          = azurerm_api_management_product.application[each.value.application].id
  api_management_name = azurerm_api_management.gateway.name
  resource_group_name = local.resource_group_name
  display_name        = each.value.subscription_name
  state               = "active"
  allow_tracing       = each.value.allow_tracing
}

# The vault is private, so this needs Terraform to run where its private endpoint is
# reachable. The reference runs its onboarding stage, and only that stage, on a
# self-hosted agent inside the network for exactly this reason.
resource "azurerm_key_vault_secret" "subscription_key" {
  for_each = local.services

  name         = "apim-subscription-${each.key}"
  value        = azurerm_api_management_subscription.service[each.key].primary_key
  key_vault_id = azurerm_key_vault.platform.id
  content_type = "apim-subscription-primary-key"

  depends_on = [azurerm_role_assignment.key_vault_secrets_officers]
}

# Scoped to the one secret rather than the vault: a gateway onboards many teams, and
# vault-wide read would let any of them read another's key.
resource "azurerm_role_assignment" "service_secret_reader" {
  for_each = local.service_secret_readers

  scope                = azurerm_key_vault_secret.subscription_key[each.value.service_key].resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type
}
