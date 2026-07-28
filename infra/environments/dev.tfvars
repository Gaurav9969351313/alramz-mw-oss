location            = "uaenorth"
resource_group_name = "alramz-dev-rg"

key_vault_name = "alramz-dev-key-vault"

apim_name                 = "alramz-dev-api-gateway"
apim_publisher_name       = "Al Ramz"
apim_publisher_email      = "apiadmin@alramz.ae"
apim_sku_name             = "Developer_1"
apim_virtual_network_type = "External" # Public APIM inside the apim subnet
apim_subnet_name          = "apim"

log_analytics_workspace_name = "alramz-dev-log-analytics-workspace"
application_insights_name    = "alramz-dev-application-insights"

container_app_environment_name = "alramz-dev-container-apps-env"

environment_name                                  = "dev"

vnet_name = "alramz-dev-vnet-spoke"

address_space = [
  "10.1.0.0/22"
]

subnets = {
  containerapps = {
    address_prefixes = ["10.1.0.0/24"]

    delegation = {
      name            = "aca-delegation"
      service_name    = "Microsoft.App/environments"
      service_actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
  data = {
    address_prefixes = ["10.1.1.0/25"]
  }
  private-endpoints = {
    address_prefixes                  = ["10.1.1.128/26"]
    private_endpoint_network_policies = "Disabled"
  }
  public = {
    address_prefixes = ["10.1.1.192/27"]
  }
  apim = {
    address_prefixes = ["10.1.1.224/27"]
  }
  reserved = {
    address_prefixes = ["10.1.2.0/23"]
  }
}

nsg_rules = {
  apim = [
    {
      name                       = "Allow-Apim-Management-Endpoint"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3443"
      destination_address_prefix = "*"
      source_address_prefix      = "Internet"
    }
  ]
  containerapps = [
    {
      name                       = "Allow-Apim-To-ContainerApps"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.1.1.224/27"
      destination_address_prefix = "*"
    }
  ]
}


container_apps = {
  data-validation-service = {
    image            = "alramzregistry.azurecr.io/data-validation-service:fe970"
    target_port      = 8080
    cpu              = 0.5
    memory           = "1Gi"
    external_enabled = false

    
  }
}

redis_instance_name = "alramz-dev-redis"

postgres_instance_name = "alramz-dev-postgres-db"
postgres_database_name = "eTradesDb"
postgres_password      = "SPadmin!1234"
