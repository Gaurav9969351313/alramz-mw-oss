resource "azurerm_container_app_environment" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  log_analytics_workspace_id = var.log_analytics_workspace_id

  tags = var.tags
}

resource "azurerm_role_definition" "container_app_deployer" {

  name        = "Container App Deployer"
  scope       = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  description = "Least privilege role for GitHub Actions deploying Azure Container Apps"
  permissions {
    actions = [
      # -------------------------------
      # Azure Container Apps
      # -------------------------------
      "Microsoft.App/containerApps/*",
      "Microsoft.App/managedEnvironments/read",

      # -------------------------------
      # Managed Identity
      # -------------------------------
      "Microsoft.ManagedIdentity/userAssignedIdentities/read",
      "Microsoft.ManagedIdentity/userAssignedIdentities/assign/action",

      # -------------------------------
      # Resource Groups / ARM
      # -------------------------------
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/deployments/*",

      # -------------------------------
      # Log Analytics
      # -------------------------------
      "Microsoft.OperationalInsights/workspaces/read",

      # -------------------------------
      # Application Insights
      # -------------------------------
      "Microsoft.Insights/components/read",

      # -------------------------------
      # Azure Storage
      # -------------------------------
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/write",
      "Microsoft.Storage/storageAccounts/blobServices/*",

      # -------------------------------
      # Azure Key Vault
      # -------------------------------
      "Microsoft.KeyVault/vaults/read",
      "Microsoft.KeyVault/vaults/write",

      # -------------------------------
      # Azure PostgreSQL Flexible Server
      # -------------------------------
      "Microsoft.DBforPostgreSQL/flexibleServers/read",
      "Microsoft.DBforPostgreSQL/flexibleServers/write",

      # -------------------------------
      # Azure Service Bus
      # -------------------------------
      "Microsoft.ServiceBus/namespaces/read",
      "Microsoft.ServiceBus/namespaces/write",
      "Microsoft.ServiceBus/namespaces/queues/*",
      "Microsoft.ServiceBus/namespaces/topics/*",
      "Microsoft.ServiceBus/namespaces/authorizationRules/read",

      # -------------------------------
      # Azure Managed Redis
      # -------------------------------
      "Microsoft.Cache/redis/read",
      "Microsoft.Cache/redis/write",

      # -------------------------------
      # Azure Automation
      # -------------------------------
      "Microsoft.Automation/automationAccounts/read",
      "Microsoft.Automation/automationAccounts/write",
      "Microsoft.Automation/automationAccounts/jobs/*",
      "Microsoft.Automation/automationAccounts/runbooks/*",

      # -------------------------------
      # Read authorization metadata
      # -------------------------------
      "Microsoft.Authorization/*/read",

      # Read tags
      "Microsoft.Resources/tags/read",
      "Microsoft.Resources/tags/write"
    ]
    not_actions = []
  }
  assignable_scopes = [
    "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}",
  ]
}

resource "azurerm_role_assignment" "container_app_deployer" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_id   = azurerm_role_definition.container_app_deployer.role_definition_resource_id
  principal_id         = var.github_actions_object_id
}