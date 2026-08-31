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
  default = {}
}

# AKS Variables
variable "aks_cluster_name" {
  type = string
}

variable "platform_identity_name" {
  type    = string
  default = null
}

variable "aks_dns_prefix" {
  type    = string
  default = "aks-dev"
}

variable "aks_kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "aks_node_count" {
  type    = number
  default = 1
}

variable "aks_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "aks_os_disk_size_gb" {
  type    = number
  default = 30
}

# Function App and Service Bus Variables
variable "web_plan_id" {
  description = "App Service Plan resource ID for Function Apps"
  type        = string
  default     = null
}

variable "function_app_id" {
  description = "Function App resource ID"
  type        = string
  default     = null
}

variable "service_bus_id" {
  description = "Service Bus namespace resource ID"
  type        = string
  default     = null
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

variable postgres_database_name {
  type = string
}

variable "postgres_password" {
  type = string
}

