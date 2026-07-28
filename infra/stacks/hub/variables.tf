variable "location" {
  type = string
}

variable "environment_name" {
  type    = string
  default = "hub"
}

variable "resource_group_name" {
  type = string
}

variable "hub_vnet_name" {
  type = string
}

variable "hub_address_space" {
  type = list(string)
}

variable "hub_subnets" {
  type = map(object({
    address_prefixes                  = list(string)
    private_endpoint_network_policies = optional(string)
    delegation = optional(object({
      name            = string
      service_name    = string
      service_actions = list(string)
    }))
  }))
}

variable "firewall_sku_name" {
  type    = string
  default = "Standard"
}

variable "vpn_gateway_sku_name" {
  type    = string
  default = "VpnGw1-5AZ"
}

variable "virtual_network_ids_for_dns" {
  type        = list(string)
  description = "VNet IDs to link to private DNS zones (hub + spokes)"
  default     = []
}

variable "private_dns_zones" {
  type        = list(string)
  description = "Private DNS zones to create"
  default = [
    "privatelink.blob.core.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.database.windows.net",
    "privatelink.postgres.database.azure.com",
    "privatelink.redis.cache.windows.net",
    "privatelink.servicebus.windows.net",
    "privatelink.azurewebsites.net",
    "privatelink.azurecontainerapps.io",
  ]
}
