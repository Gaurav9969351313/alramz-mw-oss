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

variable "identity_resource_group_name" {
  type = string
}

variable "identity_name" {
  type = string
}

data "azurerm_user_assigned_identity" "this" {
  name                = var.identity_name
  resource_group_name = var.identity_resource_group_name
}

data "external" "existing_role_assignment" {
  for_each = var.role_assignments

  program = ["${path.module}/scripts/check_role_assignment.sh"]

  query = {
    var_identity_principal_id = data.azurerm_user_assigned_identity.this.client_id
    var_scope                 = each.value.scope
    var_role                  = each.value.role
  }
}

locals {
  missing_keys = [
    for k in keys(var.role_assignments) : k
    if try(data.external.existing_role_assignment[k].result.exists, "true") == "false"
  ]

  role_assignment_keys = {
    for k in local.missing_keys : k => var.role_assignments[k]
  }
}

resource "azurerm_role_assignment" "dynamic" {
  for_each = local.role_assignment_keys

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = var.identity_principal_id

  depends_on = [data.external.existing_role_assignment]
}

resource "azurerm_role_assignment" "monitoring_metrics_publisher" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = var.identity_principal_id
}