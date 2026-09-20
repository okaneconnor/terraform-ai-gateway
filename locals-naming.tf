locals {
  # CAF region abbreviations. An unmapped region falls back to the raw location
  # string, which keeps names deterministic without needing every Azure region here.
  region_short_map = {
    uksouth            = "uks"
    ukwest             = "ukw"
    northeurope        = "neu"
    westeurope         = "weu"
    swedencentral      = "sdc"
    francecentral      = "frc"
    germanywestcentral = "gwc"
    switzerlandnorth   = "szn"
    eastus             = "eus"
    eastus2            = "eus2"
    centralus          = "cus"
    westus2            = "wus2"
    westus3            = "wus3"
    canadacentral      = "cac"
    brazilsouth        = "brs"
    australiaeast      = "aue"
    japaneast          = "jpe"
    koreacentral       = "krc"
    southeastasia      = "sea"
    centralindia       = "inc"
    southafricanorth   = "san"
    uaenorth           = "uan"
  }

  region_short = lookup(local.region_short_map, var.location, var.location)

  # Azure CAF: <type>-<name_prefix>[-<environment>][-<region>][-<instance>].
  # compact() drops the optional tokens when they are null.
  name_base = join("-", compact([
    var.name_prefix,
    var.environment,
    local.region_short,
    var.instance,
  ]))

  # Every generated name lives here and nowhere else. Downstream code reads
  # local.names.<key>; it never rebuilds a name from the input variables.
  #
  # Subnets, and any other resource unique within a parent, are named short: the
  # parent already carries the workload identity, so repeating the base is noise.
  names = {
    resource_group             = coalesce(var.custom_names.resource_group, "rg-${local.name_base}")
    virtual_network            = coalesce(var.custom_names.virtual_network, "vnet-${local.name_base}")
    apim_subnet                = coalesce(var.custom_names.apim_subnet, "snet-apim")
    private_endpoint_subnet    = coalesce(var.custom_names.private_endpoint_subnet, "snet-private-endpoints")
    apim_nsg                   = coalesce(var.custom_names.apim_nsg, "nsg-apim-${local.name_base}")
    private_endpoint_nsg       = coalesce(var.custom_names.private_endpoint_nsg, "nsg-private-endpoints-${local.name_base}")
    route_table                = coalesce(var.custom_names.route_table, "rt-${local.name_base}")
    key_vault                  = coalesce(var.custom_names.key_vault, "kv-${local.name_base}")
    key_vault_private_endpoint = coalesce(var.custom_names.key_vault_private_endpoint, "pep-kv-${local.name_base}")
    identity                   = coalesce(var.custom_names.identity, "id-${local.name_base}")
    log_analytics              = coalesce(var.custom_names.log_analytics, "log-${local.name_base}")
    application_insights       = coalesce(var.custom_names.application_insights, "appi-${local.name_base}")

    ai_services                     = coalesce(var.custom_names.ai_services, "aif-${local.name_base}")
    ai_services_private_endpoint    = coalesce(var.custom_names.ai_services_private_endpoint, "pep-aif-${local.name_base}")
    content_safety                  = coalesce(var.custom_names.content_safety, "cs-${local.name_base}")
    content_safety_private_endpoint = coalesce(var.custom_names.content_safety_private_endpoint, "pep-cs-${local.name_base}")
    apim                            = coalesce(var.custom_names.apim, "apim-${local.name_base}")
    apim_public_ip                  = coalesce(var.custom_names.apim_public_ip, "pip-apim-${local.name_base}")
  }

  # Azure length limits that a long name_prefix, environment or instance can breach.
  # Checked by a precondition on each resource so the caller gets a clear message
  # naming the custom_names key to set, rather than an opaque API rejection.
  name_length_caps = {
    resource_group       = { name = local.names.resource_group, max = 90, key = "custom_names.resource_group" }
    virtual_network      = { name = local.names.virtual_network, max = 64, key = "custom_names.virtual_network" }
    key_vault            = { name = local.names.key_vault, max = 24, key = "custom_names.key_vault" }
    identity             = { name = local.names.identity, max = 128, key = "custom_names.identity" }
    log_analytics        = { name = local.names.log_analytics, max = 63, key = "custom_names.log_analytics" }
    application_insights = { name = local.names.application_insights, max = 260, key = "custom_names.application_insights" }
  }
}
