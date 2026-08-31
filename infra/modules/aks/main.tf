resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
    os_disk_size_gb = var.os_disk_size_gb
    vnet_subnet_id = var.subnet_id
    type           = "VirtualMachineScaleSets"
    zones          = [1, 2, 3]
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  count                = var.acr_id != null ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_user_assigned_identity.platform.principal_id
}

resource "azurerm_role_assignment" "network_contributor" {
  count                = var.subnet_id != null ? 1 : 0
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_user_assigned_identity.platform.principal_id
}

data "azurerm_user_assigned_identity" "platform" {
  name                = var.identity_name
  resource_group_name = var.resource_group_name
}
