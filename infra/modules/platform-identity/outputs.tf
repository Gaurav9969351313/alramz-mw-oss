output "id" {
  value = azurerm_user_assigned_identity.platform.id
}

output "name" {
  value = azurerm_user_assigned_identity.platform.name
}

output "principal_id" {
  value = azurerm_user_assigned_identity.platform.principal_id
}

output "client_id" {
  value = azurerm_user_assigned_identity.platform.client_id
}

output "tenant_id" {
  value = azurerm_user_assigned_identity.platform.tenant_id
}
