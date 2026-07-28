data "azurerm_client_config" "current" {}

module "resource_group" {
  source = "../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }
}

module "vnet" {
  source = "../../modules/virtual-network"

  vnet_name           = var.hub_vnet_name
  location            = var.location
  resource_group_name = module.resource_group.name
  address_space       = var.hub_address_space
  subnets             = var.hub_subnets

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group]
}

module "azure_firewall" {
  source = "../../modules/azure-firewall"

  name                = "${var.hub_vnet_name}-fw"
  location            = var.location
  resource_group_name = module.resource_group.name
  sku_name            = var.firewall_sku_name
  firewall_subnet_id  = module.vnet.subnet_ids["AzureFirewallSubnet"]

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group, module.vnet]
}

module "vpn_gateway" {
  source = "../../modules/vpn-gateway"

  name                = "${var.hub_vnet_name}-vpn"
  location            = var.location
  resource_group_name = module.resource_group.name
  gateway_subnet_id   = module.vnet.subnet_ids["GatewaySubnet"]
  sku_name            = var.vpn_gateway_sku_name

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group, module.vnet]
}

# module "azure_bastion" {
#   source = "../../modules/azure-bastion"

#   name                = "${var.hub_vnet_name}-bastion"
#   location            = var.location
#   resource_group_name = module.resource_group.name
#   bastion_subnet_id   = module.vnet.subnet_ids["AzureBastionSubnet"]

#   tags = {
#     Environment = var.environment_name
#     ManagedBy   = "Terraform"
#   }

#   depends_on = [module.resource_group, module.vnet]
# }

locals {
  all_virtual_network_ids = concat(
    [module.vnet.vnet_id],
    var.virtual_network_ids_for_dns
  )
}

module "private_dns" {
  source = "../../modules/private-dns"

  name                = var.hub_vnet_name
  location            = var.location
  resource_group_name = module.resource_group.name
  private_dns_zones   = var.private_dns_zones
  virtual_network_ids = local.all_virtual_network_ids

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.vnet]
}
