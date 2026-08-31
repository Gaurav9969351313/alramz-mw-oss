resource "azurerm_user_assigned_identity" "platform" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Role assignments for various services
resource "azurerm_role_assignment" "acr_push" {
  count                = var.acr_id != null ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

resource "azurerm_role_assignment" "acr_pull" {
  count                = var.acr_id != null ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  count                = var.storage_account_id != null ? 1 : 0
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

resource "azurerm_role_assignment" "sql_server_contributor" {
  count                = var.sql_server_id != null ? 1 : 0
  scope                = var.sql_server_id
  role_definition_name = "SQL Server Contributor"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

resource "azurerm_role_assignment" "redis_contributor" {
  count                = var.redis_id != null ? 1 : 0
  scope                = var.redis_id
  role_definition_name = "Redis Contributor"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  count                = var.key_vault_id != null ? 1 : 0
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

resource "azurerm_role_assignment" "apim_contributor" {
  count                = var.apim_id != null ? 1 : 0
  scope                = var.apim_id
  role_definition_name = "API Management Service Contributor"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

resource "azurerm_role_assignment" "monitoring_metrics_publisher" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

resource "azurerm_role_assignment" "managed_identity_operator" {
  scope                = azurerm_user_assigned_identity.platform.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

# Function App roles
resource "azurerm_role_assignment" "web_plan_contributor" {
  count                = var.web_plan_id != null ? 1 : 0
  scope                = var.web_plan_id
  role_definition_name = "Web Plan Contributor"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

resource "azurerm_role_assignment" "website_contributor" {
  count                = var.function_app_id != null ? 1 : 0
  scope                = var.function_app_id
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

resource "azurerm_role_assignment" "storage_queue_data_contributor" {
  count                = var.storage_account_id != null ? 1 : 0
  scope                = var.storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

# Service Bus roles
resource "azurerm_role_assignment" "service_bus_data_owner" {
  count                = var.service_bus_id != null ? 1 : 0
  scope                = var.service_bus_id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

data "azurerm_client_config" "current" {}
