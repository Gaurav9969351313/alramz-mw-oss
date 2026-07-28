variable "name" {
  type        = string
  description = "Azure Bastion name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "bastion_subnet_id" {
  type        = string
  description = "ID of the AzureBastionSubnet"
}

variable "sku" {
  type        = string
  default     = "Standard"
  description = "Bastion SKU. Possible values are Basic and Standard."
}

variable "tags" {
  type    = map(string)
  default = {}
}
