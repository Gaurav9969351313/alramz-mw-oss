data "azurerm_client_config" "current" {}

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

module "github_actions_sp" {
  source = "../../modules/service-principal"

  name                 = "alramz-github-actions-sp"
  create_client_secret = true

  role_assignments = [
    {
      scope = module.acr.id
      role  = "AcrPush"
    },
    {
      scope = module.acr.id
      role  = "Contributor"
    },
    {
      scope = module.acr.id
      role  = "AcrPull"
    }
  ]
}

# aca_pull_sp: Azure Container Apps Will be using this as they need to pull images from acr 
module "aca_pull_sp" {
  source = "../../modules/service-principal"

  name = "alramz-aca-pull-sp"

  role_assignments = [
    {
      scope = module.acr.id
      role  = "AcrPull"
    }
  ]
}


