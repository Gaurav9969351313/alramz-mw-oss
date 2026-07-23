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

variable "environment_name" {
  type = string
}

variable "container_app_environment_name" {
  type = string
}

variable "container_apps" {
  type = map(object({
    image       = string
    target_port = number
    cpu         = number
    memory      = string
    external_enabled = optional(bool, false)
  }))
}

variable "log_analytics_workspace_name" {
  type = string
}

variable "application_insights_name" {
  type = string
}


variable "redis_instance_name" {
  type = string
}

variable "postgres_instance_name" {
  type = string
}

variable "postgres_database_name" {
  type = string
}

variable "postgres_password" {
  type = string
}

variable "vnet_name" {
  type    = string
}

variable "address_space" {
  type    = list(string)
}

variable "subnets" {
  type = map(object({
    address_prefixes = list(string)
    private_endpoint_network_policies = optional(string)
    delegation = optional(object({
      name            = string
      service_name    = string
      service_actions = list(string)
    }))
  }))
  default = {}
}


