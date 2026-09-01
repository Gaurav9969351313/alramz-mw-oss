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

data "http" "existing_role_assignment" {
  for_each = var.role_assignments

  url = "https://management.azure.com${each.value.scope}/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01&%24filter=atScope()&%24filter=principalId%20eq%20'${var.identity_principal_id}'"

  request_headers = {
    Authorization = "Bearer ${data.azurerm_client_config.current.access_token}"
  }
}

data "azurerm_client_config" "current" {}

locals {
  role_assignment_keys = {
    for k, v in var.role_assignments : k => k
    if length(jsondecode(data.http.existing_role_assignment[k].response_body).value) == 0
  }
}

resource "azurerm_role_assignment" "dynamic" {
  for_each = local.role_assignment_keys

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = var.identity_principal_id

  depends_on = [data.http.existing_role_assignment]
}

resource "azurerm_role_assignment" "monitoring_metrics_publisher" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = var.identity_principal_id
}
