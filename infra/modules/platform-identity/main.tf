resource "azurerm_user_assigned_identity" "platform" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

locals {
  role_assignments = {
    acr_push = {
      scope = var.acr_id
      role  = "AcrPush"
    }
    acr_pull = {
      scope = var.acr_id
      role  = "AcrPull"
    }
    storage_blob_data_contributor = {
      scope = var.storage_account_id
      role  = "Storage Blob Data Contributor"
    }
    sql_server_contributor = {
      scope = var.sql_server_id
      role  = "SQL Server Contributor"
    }
    redis_contributor = {
      scope = var.redis_id
      role  = "Redis Contributor"
    }
    key_vault_secrets_user = {
      scope = var.key_vault_id
      role  = "Key Vault Secrets User"
    }
    apim_contributor = {
      scope = var.apim_id
      role  = "API Management Service Contributor"
    }
    web_plan_contributor = {
      scope = var.web_plan_id
      role  = "Web Plan Contributor"
    }
    website_contributor = {
      scope = var.function_app_id
      role  = "Website Contributor"
    }
    storage_queue_data_contributor = {
      scope = var.storage_account_id
      role  = "Storage Queue Data Contributor"
    }
    service_bus_data_owner = {
      scope = var.service_bus_id
      role  = "Azure Service Bus Data Owner"
    }
  }

  filtered_role_assignments = {
    for k, v in local.role_assignments : k => v
    if v.scope != null
  }
}

resource "azurerm_role_assignment" "dynamic" {
  for_each             = local.filtered_role_assignments
  scope                = each.value.scope
  role_definition_name = each.value.role
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
