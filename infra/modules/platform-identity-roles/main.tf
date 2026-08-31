variable "identity_principal_id" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "role_assignments" {
  type = map(object({
    scope = string
    role  = string
  }))
  default = {}
}

resource "azurerm_role_assignment" "dynamic" {
  for_each             = var.role_assignments
  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = var.identity_principal_id
}

resource "azurerm_role_assignment" "monitoring_metrics_publisher" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = var.identity_principal_id
}
