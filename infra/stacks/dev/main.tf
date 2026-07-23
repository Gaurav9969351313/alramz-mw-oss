data "azurerm_client_config" "current" {}

data "terraform_remote_state" "shared_platform" {
  backend = "azurerm"

  config = {
    resource_group_name  = "alramz-tf-assets-rg"
    storage_account_name = "alramztfstatefiles98"
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

module "vnet" {
  source = "../../modules/virtual-network"
  vnet_name           = var.vnet_name
  location            = var.location
  resource_group_name = module.resource_group.name
  address_space       = var.address_space
  subnets             = var.subnets

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group]
}

module "key_vault" {
  source = "../../modules/key-vault"

  name                = var.key_vault_name
  location            = var.location
  resource_group_name = module.resource_group.name

  tenant_id = data.azurerm_client_config.current.tenant_id

  public_network_access_enabled = false

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group, module.vnet]
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                       = var.log_analytics_workspace_name
  application_insights_name  = var.application_insights_name

  location            = var.location
  resource_group_name = module.resource_group.name

  retention_in_days = 30

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group]
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

  depends_on = [module.resource_group, module.vnet]
}

module "container_app_environment" {
  source = "../../modules/container-app-environment"

  name                = var.container_app_environment_name
  location            = var.location
  resource_group_name = module.resource_group.name

  log_analytics_workspace_id = module.monitoring.id

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.monitoring, module.resource_group, module.vnet]
}

module "container_apps" {
  source = "../../modules/container-apps"

  resource_group_name = module.resource_group.name

  location         = var.location
  environment_name = var.environment_name
  container_app_environment_id = module.container_app_environment.id

  container_apps = var.container_apps

  acr_id           = data.terraform_remote_state.shared_platform.outputs.acr_id
  acr_login_server = data.terraform_remote_state.shared_platform.outputs.acr_login_server

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.container_app_environment, module.monitoring, module.vnet]
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

  depends_on = [module.resource_group, module.vnet]
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

  public_network_access_enabled = false

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group, module.vnet]
}
