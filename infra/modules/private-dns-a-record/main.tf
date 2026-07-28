variable "name" {
  type        = string
  description = "DNS A record name"
}

variable "zone_name" {
  type        = string
  description = "Private DNS zone name"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "ttl" {
  type        = number
  description = "TTL in seconds"
  default     = 300
}

variable "records" {
  type        = list(string)
  description = "List of IPv4 addresses"
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "azurerm_private_dns_a_record" "this" {
  name                = var.name
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.ttl
  records             = var.records

  tags = var.tags
}
