resource "azurerm_api_management_backend" "ai_services" {
  name                = "ai-services"
  resource_group_name = local.resource_group_name
  api_management_name = azurerm_api_management.gateway.name
  protocol            = "http"
  url                 = local.ai_services.endpoint

  circuit_breaker_rule {
    name                       = "ai-services-breaker"
    trip_duration              = var.apim_circuit_breaker.trip_duration
    accept_retry_after_enabled = true

    failure_condition {
      count             = var.apim_circuit_breaker.failure_count
      interval_duration = var.apim_circuit_breaker.interval
      status_code_range {
        min = 500
        max = 599
      }
    }
  }
}

# azurerm cannot express managed-identity credentials on a backend, which this one
# needs: no policy fragment runs before a content-safety call to attach a token.
resource "azapi_resource" "content_safety_backend" {
  for_each = var.enable_content_safety ? { content_safety = {} } : {}

  type                      = "Microsoft.ApiManagement/service/backends@2024-05-01"
  name                      = "content-safety"
  parent_id                 = azurerm_api_management.gateway.id
  schema_validation_enabled = false

  body = {
    properties = {
      protocol = "http"
      url      = local.content_safety_endpoint
      credentials = {
        managedIdentity = {
          clientId = local.identity.client_id
          resource = "https://cognitiveservices.azure.com"
        }
      }
      circuitBreaker = {
        rules = [{
          name = "content-safety-breaker"
          failureCondition = {
            count    = var.apim_circuit_breaker.failure_count
            interval = var.apim_circuit_breaker.interval
            # 429 as well as 5xx: a throttled screening service cannot return a verdict.
            statusCodeRanges = [
              { min = 429, max = 429 },
              { min = 500, max = 599 },
            ]
          }
          tripDuration     = var.apim_circuit_breaker.trip_duration
          acceptRetryAfter = true
        }]
      }
    }
  }
}
