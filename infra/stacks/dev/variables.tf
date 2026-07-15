variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}


variable "key_vault_name" {
  type = string
}


variable "apim_name" {
  type = string
}

variable "apim_publisher_name" {
  type = string
}

variable "apim_publisher_email" {
  type = string
}

variable "apim_sku_name" {
  type    = string
  default = "Developer_1"
}

variable "apim_virtual_network_type" {
  type    = string
  default = "None"
}

variable "apim_subnet_name" {
  type    = string
  default = null
}

variable "apim_public_network_access_enabled" {
  type    = bool
  default = true
}
