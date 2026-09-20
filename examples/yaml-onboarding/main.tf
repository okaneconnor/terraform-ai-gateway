module "ai_gateway" {
  source = "../.."

  name_prefix = var.name_prefix
  location    = var.location

  address_space = var.address_space

  model_deployments = {
    "gpt-4o" = {
      model_name    = "gpt-4o"
      model_version = "2024-11-20"
    }
  }

  apim = {
    publisher_name  = var.publisher_name
    publisher_email = var.publisher_email
  }

  jwt = {
    audiences = [var.gateway_app_id]
  }

  # Teams are declared in onboarding.yaml; onboarding.tf translates it.
  applications = local.applications

  # Off when Terraform runs outside the network, since the vault is private.
  deliver_keys_to_key_vault = var.deliver_keys_to_key_vault
}
