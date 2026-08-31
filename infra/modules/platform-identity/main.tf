resource "azurerm_user_assigned_identity" "platform" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Role assignments with static keys - dynamic values in map values
locals {
  role_scopes = {
    acr_push                    = var.acr_id
    acr_pull                    = var.acr_id
    storage_blob_data_contributor = var.storage_account_id
    sql_server_contributor      = var.sql_server_id
    redis_contributor           = var.redis_id
    key_vault_secrets_user      = var.key_vault_id
    apim_contributor            = var.apim_id
    web_plan_contributor        = var.web_plan_id
    website_contributor         = var.function_app_id
    storage_queue_data_contributor = var.storage_account_id
    service_bus_data_owner      = var.service_bus_id
  }

  role_names = {
    acr_push                    = "AcrPush"
    acr_pull                    = "AcrPull"
    storage_blob_data_contributor = "Storage Blob Data Contributor"
    sql_server_contributor      = "SQL Server Contributor"
    redis_contributor           = "Redis Contributor"
    key_vault_secrets_user      = "Key Vault Secrets User"
    apim_contributor            = "API Management Service Contributor"
    web_plan_contributor        = "Web Plan Contributor"
    website_contributor         = "Website Contributor"
    storage_queue_data_contributor = "Storage Queue Data Contributor"
    service_bus_data_owner      = "Azure Service Bus Data Owner"
  }
}

resource "azurerm_role_assignment" "dynamic" {
  for_each             = { for k, v in local.role_scopes : k => v if v != null }
  scope                = each.value
  role_definition_name = local.role_names[each.key]
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

data "azurerm_client_config" "current" {}
