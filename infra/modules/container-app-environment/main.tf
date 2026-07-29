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
      "Microsoft.App/containerApps/*",
      "Microsoft.App/managedEnvironments/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/deployments/*",
      "Microsoft.OperationalInsights/workspaces/read",
      "Microsoft.ManagedIdentity/userAssignedIdentities/read",
      "Microsoft.Insights/components/read",
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