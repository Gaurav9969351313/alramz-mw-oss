location            = "uaenorth"
resource_group_name = "alramz-hub-rg"

environment_name = "hub"

hub_vnet_name = "alramz-hub-vnet"

hub_address_space = [
  "10.0.0.0/24"
]

hub_subnets = {
  AzureFirewallSubnet = {
    address_prefixes = ["10.0.0.0/26"]
  }
  GatewaySubnet = {
    address_prefixes = ["10.0.0.64/27"]
  }
  # AzureBastionSubnet = {
  #   address_prefixes = ["10.0.0.96/26"]
  # }
  reserved = {
    address_prefixes = ["10.0.0.160/27"]
  }
  future = {
    address_prefixes = ["10.0.0.192/26"]
  }
}

firewall_sku_name = "AZFW_Hub"

vpn_gateway_sku_name = "Basic"

virtual_network_ids_for_dns = [
  "/subscriptions/9b9d81dc-3f06-48b2-b936-0a6b805fe94e/resourceGroups/alramz-dev-rg/providers/Microsoft.Network/virtualNetworks/alramz-dev-vnet-spoke",
]

private_dns_zones = [
  "privatelink.blob.core.windows.net",
  "privatelink.vaultcore.azure.net",
  "privatelink.database.windows.net",
  "privatelink.postgres.database.azure.com",
  "privatelink.redis.cache.windows.net",
  "privatelink.servicebus.windows.net",
  "privatelink.azurewebsites.net",
  "privatelink.azurecontainerapps.io",
]
