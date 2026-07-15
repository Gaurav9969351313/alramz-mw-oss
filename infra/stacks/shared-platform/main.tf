module "resource_group" {
  source = "../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
}

module "acr" {
  source = "../../modules/acr"

  name                = var.acr_name
  location            = var.location
  resource_group_name = module.resource_group.name
}

