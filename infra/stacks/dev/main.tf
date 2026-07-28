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
  source              = "../../modules/virtual-network"
  vnet_name           = var.vnet_name
  location            = var.location
  resource_group_name = module.resource_group.name
  address_space       = var.address_space
  subnets             = var.subnets
  nsg_rules           = var.nsg_rules

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

  public_network_access_enabled = true

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group, module.vnet]
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                      = var.log_analytics_workspace_name
  application_insights_name = var.application_insights_name

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
  virtual_network_subnet_id     = var.apim_subnet_name == null ? null : module.vnet.subnet_ids[var.apim_subnet_name]
  public_network_access_enabled = var.apim_public_network_access_enabled

  backends = {
    "data-validation-service" = {
      url = "https://data-validation-service.internal.ashybush-7d7123f8.uaenorth.azurecontainerapps.io"
    }
  }

  apis = {
    "data-validation-api" = {
      path = "api/v1"
      backend_id = "data-validation-service"
      service_config = {
        path = "/api/v1"
      }
    }
  }

  api_operations = {
    "data-validation-api" = {
      "info" = {
        method = "GET"
        url    = "/info"
      }
    }
  }

  products = {
    "data-validation-product" = {
      display_name = "Data Validation API"
      api_ids      = ["data-validation-api"]
    }
  }

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group, module.vnet]
}

module "container_app_environment" {
  source = "../../modules/container-app-environment"

  name                     = var.container_app_environment_name
  location                 = var.location
  resource_group_name      = module.resource_group.name
  infrastructure_subnet_id = module.vnet.subnet_ids["containerapps"]

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

  location                     = var.location
  environment_name             = var.environment_name
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

  public_network_access_enabled = true

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.resource_group, module.vnet]
}

locals {
  data_subnet_id = module.vnet.subnet_ids["data"]
}

module "kv_private_endpoint" {
  source = "../../modules/private-endpoint"

  name                = "${var.key_vault_name}-pe"
  location            = var.location
  resource_group_name = module.resource_group.name
  subnet_id           = local.data_subnet_id
  target_resource_id  = module.key_vault.id
  subresource_names   = ["vault"]

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.key_vault, module.vnet]
}

module "redis_private_endpoint" {
  source = "../../modules/private-endpoint"

  name                = "${var.redis_instance_name}-pe"
  location            = var.location
  resource_group_name = module.resource_group.name
  subnet_id           = local.data_subnet_id
  target_resource_id  = module.redis.id
  subresource_names   = ["redisEnterprise"]

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.redis, module.vnet]
}

module "postgresql_private_endpoint" {
  source = "../../modules/private-endpoint"

  name                = "${var.postgres_instance_name}-pe"
  location            = var.location
  resource_group_name = module.resource_group.name
  subnet_id           = local.data_subnet_id
  target_resource_id  = module.postgresql.id
  subresource_names   = ["postgresqlServer"]

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.postgresql, module.vnet]
}

locals {
  container_apps_dns_zone_name = "ashybush-7d7123f8.uaenorth.azurecontainerapps.io"
}

module "container_apps_dns_link" {
  source = "../../modules/private-dns"

  name                = "container-apps-internal"
  location            = var.location
  resource_group_name = module.resource_group.name
  private_dns_zones   = [local.container_apps_dns_zone_name]
  virtual_network_ids = [module.vnet.vnet_id]

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }
}

module "container_apps_internal_wildcard" {
  source = "../../modules/private-dns-a-record"

  name                = "*.internal"
  zone_name           = local.container_apps_dns_zone_name
  resource_group_name = module.resource_group.name
  records             = [module.container_app_environment.static_ip_address]
  ttl                 = 300

  tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.container_app_environment]
}
