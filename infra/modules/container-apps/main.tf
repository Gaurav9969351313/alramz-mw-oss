# ==============================================================================
# STEP 1: Independent Identity Creation
# ==============================================================================
# We create a standalone, User-Assigned Managed Identity first. 
# Because it exists independently of the Container Apps, we can obtain its 
# principal_id immediately without waiting for any container hosting infrastructure.
resource "azurerm_user_assigned_identity" "aca_identity" {
  name                = "${var.resource_group_name}-aca-identity"
  location            = var.location
  resource_group_name = var.resource_group_name

}

# ==============================================================================
# STEP 2: Pre-Authorization (Granting Access Before Use)
# ==============================================================================
# We explicitly bind the AcrPull role to our new identity.
# Doing this here ensures that Azure's IAM active directory subsystem has time to 
# propagate the permissions *before* any container tries to boot up and pull an image.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aca_identity.principal_id
}

# ==============================================================================
# STEP 3: Container App Deployment with strict dependency enforcement
# ==============================================================================
resource "azurerm_container_app" "this" {
  for_each = var.container_apps

  name                         = each.key
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id

  revision_mode = "Single"

  

  # Attach the pre-authorized User-Assigned identity to the application metadata
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca_identity.id]
  }

  # Instruct the container host to use the User-Assigned identity for the registry handshake
  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.aca_identity.id
  }

  template {
    min_replicas                     = 1
    max_replicas                     = 2
    container {
      name   = each.key
      image  = each.value.image
      cpu    = each.value.cpu
      memory = each.value.memory
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].container,
      template[0].min_replicas,
      template[0].max_replicas
    ]
  }

  ingress {
    external_enabled = try(each.value.external_enabled, false)
    target_port      = each.value.target_port

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  # CRITICAL GUARDRAIL: This hard block forces Terraform to stall the creation 
  # of the container apps until Step 2 (Role Assignment) is 100% complete.
  depends_on = [
    azurerm_role_assignment.acr_pull
  ]

  tags = var.tags
  
}

