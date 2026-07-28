resource "azurerm_container_app_environment" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  log_analytics_workspace_id = var.log_analytics_workspace_id
  infrastructure_subnet_id   = var.infrastructure_subnet_id

  # Use an internal load balancer so the Container Apps Environment is accessible only from within the VNet.
  # Creates an internal (private) load balancer for the Container Apps Environment.
  # Applications are accessible only from resources with network connectivity to the VNet
  # (for example, VMs, AKS, VPN/ExpressRoute, or peered VNets) and are not exposed to the public internet.
  #  `public_network_access` cannot be `Enabled` when `internal_load_balancer_enabled` is set to `true`
  internal_load_balancer_enabled = true
  # Public network access must be disabled when using an internal load balancer.
  public_network_access = "Disabled"

  tags = var.tags
}