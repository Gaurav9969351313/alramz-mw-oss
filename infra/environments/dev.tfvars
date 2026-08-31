location                       = "uaenorth"
resource_group_name            = "alramz-dev-rg"

key_vault_name                 = "alramz-dev-kv"

apim_name                          = "alramz-dev-api-gw"
apim_publisher_name                = "Al Ramz"
apim_publisher_email               = "apiadmin@alramz.ae"
apim_sku_name                      = "Developer_1"
apim_virtual_network_type          = "None" # For prod it should be internal

log_analytics_workspace_name   = "alramz-dev-log-analytics-workspace"
application_insights_name      = "alramz-dev-application-insights"

container_app_environment_name                    = "alramz-dev-container-apps-env"
container_app_environment_zone_redundancy_enabled = false
environment_name                                  = "dev"

# COMMENTED OUT: Container Apps migrated to AKS
# container_apps = {
#   data-validation-service = {
#     image       = "alramzregistry.azurecr.io/data-validation-service:fe970"
#     target_port = 8080
#     cpu         = 0.5
#     memory      = "1Gi"
#     external_enabled = false
#   }
# }

# AKS Configuration
aks_cluster_name       = "alramz-dev-aks"
platform_identity_name = "alramz-dev-platform-identity"
aks_dns_prefix         = "alramz-dev-aks"
aks_kubernetes_version = "1.36"
aks_node_count         = 1
aks_vm_size            = "B2as_v2"
aks_os_disk_size_gb    = 30
aks_availability_zones = []

redis_instance_name  = "alramz-dev-cache"


postgres_instance_name = "alramz-dev-db"
postgres_database_name = "eTradesDb"
postgres_password = "SPadmin!1234"

