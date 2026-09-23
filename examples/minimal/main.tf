module "ai_gateway_platform" {
  source = "../.."

  name_prefix = "aigw"
  environment = "dev"
  location    = "uksouth"

  address_space = "10.60.0.0/22"

  apim = {
    publisher_name  = "Platform Team"
    publisher_email = "platform@example.com"
  }

  # The app registration the gateway validates tokens against. The module does not
  # create it: see docs/deploying.md.
  jwt = { audiences = ["api://<gateway app client id>"] }
}
