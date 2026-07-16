variable "name" {
  description = "Log Analytics Workspace name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group name"
  type        = string
}

variable "sku" {
  description = "Workspace SKU"
  type        = string
  default     = "PerGB2018"
}

variable "retention_in_days" {
  description = "Retention period"
  type        = number
  default     = 30
}

variable "application_insights_name" {
  description = "Application Insights name"
  type        = string
}