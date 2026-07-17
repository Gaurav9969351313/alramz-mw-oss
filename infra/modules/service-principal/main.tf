resource "azuread_application" "this" {
  display_name = var.name
}

resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id
}

resource "azurerm_role_assignment" "this" {
  for_each = {
    for idx, assignment in var.role_assignments :
    idx => assignment
  }

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azuread_service_principal.this.object_id
}

resource "azuread_application_password" "this" {
  count = var.create_client_secret ? 1 : 0

  application_id = azuread_application.this.id
  display_name   = var.client_secret_display_name
}