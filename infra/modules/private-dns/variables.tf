variable "name" {
  type        = string
  description = "Prefix for DNS link resources"
  default     = "private-dns"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "private_dns_zones" {
  type        = list(string)
  description = "List of private DNS zone names to create"
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

variable "virtual_network_ids" {
  type        = list(string)
  description = "List of VNet IDs to link to all DNS zones"
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  zone_vnet_pairs = flatten([
    for zone_name in var.private_dns_zones : [
      for idx, vnet_id in var.virtual_network_ids : {
        key       = "${zone_name}-${idx}"
        zone_name = zone_name
        vnet_id   = vnet_id
      }
    ]
  ])
}
