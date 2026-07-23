variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "Balanced_B0"
}

variable "tags" {
  type    = map(string)
  default = {}
}