data "azurerm_client_config" "current" {}

module "resource_group" {
  source = "../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
}

# RBAC Needs to be implemented 
module "key_vault" {
  source = "../../modules/key-vault"

  name                = var.key_vault_name
  location            = var.location
  resource_group_name = module.resource_group.name

  tenant_id = data.azurerm_client_config.current.tenant_id

  public_network_access_enabled = false

  depends_on = [ module.resource_group ]
}

module "apim" {
  source = "../../modules/apim"

  name                = var.apim_name
  location            = var.location
  resource_group_name = module.resource_group.name

  publisher_name  = var.apim_publisher_name
  publisher_email = var.apim_publisher_email
  sku_name        = var.apim_sku_name

  virtual_network_type          = var.apim_virtual_network_type
  virtual_network_subnet_id     = var.apim_subnet_name == null ? null : null
  public_network_access_enabled = var.apim_public_network_access_enabled

  depends_on = [module.resource_group]
}
