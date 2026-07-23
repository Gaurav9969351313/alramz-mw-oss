variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "publisher_name" {
  type = string
}

variable "publisher_email" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "Developer_1"
}

variable "virtual_network_type" {
  type    = string
  default = "None"
}

variable "virtual_network_subnet_id" {
  type    = string
  default = null
}

variable "public_network_access_enabled" {
  type    = bool
  default = true
}

variable "services" {
  type = map(object({
    path = string
    url  = string
  }))

  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}