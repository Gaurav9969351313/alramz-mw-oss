variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "container_app_environment_id" {
  type = string
}

variable "environment_name" {
  type = string
}

variable "container_apps" {
  type = map(object({
    image            = string
    target_port      = number
    cpu              = number
    memory           = string
    external_enabled = optional(bool, false)
  }))
}

variable "acr_id" {
  description = "Azure Container Registry ID"
  type        = string
}

variable "acr_login_server" {
  description = "Azure Container Registry Login Server"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}