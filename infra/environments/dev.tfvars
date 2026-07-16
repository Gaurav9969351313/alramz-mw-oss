location                       = "uaenorth"
resource_group_name            = "alramz-dev-rg"

key_vault_name                 = "alramz-dev-key-vault"

apim_name                          = "alramz-dev-api-gateway"
apim_publisher_name                = "Al Ramz"
apim_publisher_email               = "apiadmin@alramz.ae"
apim_sku_name                      = "Developer_1"
apim_virtual_network_type          = "None" # For prod it should be internal

log_analytics_workspace_name   = "alramz-dev-log-analytics-workspace"
application_insights_name      = "alramz-dev-application-insights"

container_app_environment_name                    = "alramz-dev-container-apps-env"
container_app_environment_zone_redundancy_enabled = false
environment_name                                  = "dev"


