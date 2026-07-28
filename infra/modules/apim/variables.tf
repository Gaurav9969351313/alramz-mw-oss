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

variable "backends" {
  type = map(object({
    url = string
  }))
  default = {}
}

variable "apis" {
  type = map(object({
    path   = string
    schemes = optional(list(string), ["https"])
    backend_id = optional(string, null)
    service_config = optional(object({
      path = optional(string, null)
      url  = optional(string, null)
    }), null)
  }))
  default = {}
}

variable "api_operations" {
  type = map(map(object({
    method = string
    url    = string
  })))
  default = {}
}

variable "products" {
  type = map(object({
    display_name = string
    description  = optional(string, "")
    api_ids      = optional(list(string), [])
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}