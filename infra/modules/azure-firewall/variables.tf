variable "name" {
  type        = string
  description = "Azure Firewall name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "sku_name" {
  type        = string
  default     = "Standard"
  description = "Firewall SKU. Possible values are Basic, Standard, and Premium."
}

variable "firewall_subnet_id" {
  type        = string
  description = "ID of the AzureFirewallSubnet"
}

variable "zones" {
  type        = list(string)
  default     = ["1", "2", "3"]
  description = "Availability zones for the firewall public IP"
}

variable "tags" {
  type    = map(string)
  default = {}
}