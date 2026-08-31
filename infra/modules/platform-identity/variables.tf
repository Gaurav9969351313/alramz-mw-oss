variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "acr_id" {
  description = "ACR resource ID for push/pull role assignments"
  type        = string
  default     = null
}

variable "storage_account_id" {
  description = "Storage account resource ID for blob data access"
  type        = string
  default     = null
}

variable "sql_server_id" {
  description = "SQL server resource ID for authentication"
  type        = string
  default     = null
}

variable "redis_id" {
  description = "Redis resource ID for access"
  type        = string
  default     = null
}

variable "key_vault_id" {
  description = "Key Vault resource ID for secrets access"
  type        = string
  default     = null
}

variable "apim_id" {
  description = "API Management resource ID for contributor role"
  type        = string
  default     = null
}

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
