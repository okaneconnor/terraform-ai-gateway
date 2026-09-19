resource "azurerm_api_management_policy_fragment" "baseline" {
  for_each = local.policy_fragments

  api_management_id = azurerm_api_management.gateway.id
  name              = each.key
  format            = "rawxml"
  value             = each.value
}

# The global policy includes fragments by name, so APIM rejects it until they exist.
resource "azurerm_api_management_policy" "global" {
  api_management_id = azurerm_api_management.gateway.id
  xml_content       = file("${path.module}/policies/global.xml")

  depends_on = [azurerm_api_management_policy_fragment.baseline]
}
