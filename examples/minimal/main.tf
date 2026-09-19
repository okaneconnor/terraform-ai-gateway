module "ai_gateway_platform" {
  source = "../.."

  name_prefix = "aigw"
  environment = "dev"
  location    = "uksouth"

  address_space = "10.60.0.0/22"
}
