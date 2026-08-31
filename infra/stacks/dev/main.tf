data "azurerm_client_config" "current" {}

data "terraform_remote_state" "shared_platform" {
  backend = "azurerm"

  config = {
    resource_group_name  = "alramz-tf-assets-rg"
    storage_account_name = "alramztfstatefiles1994"
    container_name       = "sharedplatformtfstate"
    key                  = "sharedplatform.tfstate"
  }
}

module "resource_group" {
  source = "../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }
  
}

# module "vnet" {
#   source = "../../modules/vnet"

#   name                = var.vnet_name
#   location            = var.location
#   resource_group_name = module.resource_group.name
#   address_space       = var.address_space
#   subnets             = var.subnets

#   tags = {
#     Environment = var.environment_name
#     ManagedBy   = "Terraform"
#   }

#   depends_on = [module.resource_group]
# }

module "key_vault" {
  source = "../../modules/key-vault"

  name                = var.key_vault_name
  location            = var.location
  resource_group_name = module.resource_group.name

  tenant_id = data.azurerm_client_config.current.tenant_id

  rbac_principal_ids = [data.terraform_remote_state.shared_platform.outputs.github_actions_object_id]
  rbac_role_name     = "Key Vault Administrator"

  public_network_access_enabled = true

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group] #  module.vnet
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                       = var.log_analytics_workspace_name
  application_insights_name  = var.application_insights_name

  location            = var.location
  resource_group_name = module.resource_group.name

  retention_in_days = 30

  depends_on = [module.resource_group]

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }
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

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group] # , module.vnet
}

# COMMENTED OUT: Migrating from Azure Container Apps to AKS
# module "container_app_environment" {
#   source = "../../modules/container-app-environment"
# 
#   name                = var.container_app_environment_name
#   location            = var.location
#   resource_group_name = module.resource_group.name
# 
#   log_analytics_workspace_id = module.monitoring.id
# 
#   github_actions_object_id = data.terraform_remote_state.shared_platform.outputs.github_actions_object_id
#   subscription_id          = data.terraform_remote_state.shared_platform.outputs.subscription_id
# 
#   tags = {
#     Environment = var.environment_name
#     ManagedBy   = "Terraform"
#   }
# 
#   depends_on = [module.monitoring, module.resource_group]
# }

# COMMENTED OUT: Migrating from Azure Container Apps to AKS
# module "container_apps" {
#   source = "../../modules/container-apps"
# 
#   resource_group_name = module.resource_group.name
# 
#   location         = var.location
#   environment_name = var.environment_name
#   container_app_environment_id = module.container_app_environment.id
# 
#   container_apps = var.container_apps
# 
#   acr_id           = data.terraform_remote_state.shared_platform.outputs.acr_id
#   acr_login_server = data.terraform_remote_state.shared_platform.outputs.acr_login_server
# 
#   depends_on = [module.container_app_environment, module.monitoring]
#   tags = {
#     Environment = var.environment_name
#     ManagedBy   = "Terraform"
#   }
# }

module "platform_identity" {
  source = "../../modules/platform-identity"

  name                = var.platform_identity_name
  location            = var.location
  resource_group_name = module.resource_group.name

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group]
}

module "platform_identity_roles" {
  source = "../../modules/platform-identity-roles"

  identity_principal_id = module.platform_identity.principal_id
  subscription_id       = data.azurerm_client_config.current.subscription_id

  role_assignments = {
    acr_push = {
      scope = data.terraform_remote_state.shared_platform.outputs.acr_id
      role  = "AcrPush"
    }
    acr_pull = {
      scope = data.terraform_remote_state.shared_platform.outputs.acr_id
      role  = "AcrPull"
    }
    sql_server_contributor = {
      scope = module.postgresql.id
      role  = "SQL Server Contributor"
    }
    redis_contributor = {
      scope = module.redis.id
      role  = "Redis Contributor"
    }
    key_vault_secrets_user = {
      scope = module.key_vault.id
      role  = "Key Vault Secrets User"
    }
    apim_contributor = {
      scope = module.apim.id
      role  = "API Management Service Contributor"
    }
  }

  depends_on = [
    module.platform_identity,
    module.postgresql,
    module.redis,
    module.key_vault,
    module.apim
  ]
}

module "aks" {
  source = "../../modules/aks"

  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = module.resource_group.name

  dns_prefix         = var.aks_dns_prefix
  kubernetes_version = var.aks_kubernetes_version
  node_count         = var.aks_node_count
  vm_size            = var.aks_vm_size
  os_disk_size_gb    = var.aks_os_disk_size_gb

  log_analytics_workspace_id = module.monitoring.id
  acr_id                     = data.terraform_remote_state.shared_platform.outputs.acr_id
  identity_id                = module.platform_identity.id
  identity_name              = module.platform_identity.name

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group, module.monitoring, module.platform_identity]
}

module "redis" {

  source = "../../modules/redis"

  name                = var.redis_instance_name
  location            = var.location
  resource_group_name = module.resource_group.name

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group] # , module.vnet
}

module "postgresql" {

  source = "../../modules/postgresql"

  name                = var.postgres_instance_name
  location            = var.location
  resource_group_name = module.resource_group.name

  administrator_login    = "pgadmin"
  administrator_password = var.postgres_password

  postgres_version = "16"

  sku_name = "B_Standard_B1ms"

  storage_mb = 32768

  database_name = var.postgres_database_name

  public_network_access_enabled = var.apim_public_network_access_enabled

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group] # , module.vnet
}
