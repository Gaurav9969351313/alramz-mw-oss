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

data "external" "existing_role_assignment" {
  for_each = var.role_assignments

  program = [
    "bash",
    "-c",
    "eval \"$(jq -r '@sh \"PRINCIPAL_ID=$(.var_identity_principal_id) SCOPE=$(.var_scope) ROLE=$(.var_role)\"')\"; EXISTS=$(az role assignment list --assignee \"$PRINCIPAL_ID\" --scope \"$SCOPE\" --role \"$ROLE\" --query \"[?principalId=='$PRINCIPAL_ID'].id|[0]\" -o tsv 2>/dev/null); if [ -n \"$EXISTS\" ]; then echo '{\"exists\":\"true\"}'; else echo '{\"exists\":\"false\"}'; fi",
  ]

  query = {
    var_identity_principal_id = var.identity_principal_id
    var_scope                 = each.value.scope
    var_role                  = each.value.role
  }
}

locals {
  role_assignment_keys = {
    for k, v in var.role_assignments : k => v
    if jsondecode(data.external.existing_role_assignment[k].result.exists) == "false"
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