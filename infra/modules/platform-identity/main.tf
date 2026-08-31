resource "azurerm_user_assigned_identity" "platform" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_role_assignment" "managed_identity_operator" {
  scope                = azurerm_user_assigned_identity.platform.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}

data "azurerm_client_config" "current" {}
