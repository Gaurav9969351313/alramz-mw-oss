variable "name" {
  description = "PostgreSQL Flexible Server name"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group"
  type        = string
}

variable "administrator_login" {
  description = "Administrator username"
  type        = string
}

variable "administrator_password" {
  description = "Administrator password"
  type        = string
  sensitive   = true
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "sku_name" {
  description = "Server SKU"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage size"
  type        = number
  default     = 32768
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "backup_retention_days" {
  description = "Backup retention"
  type        = number
  default     = 7
}

variable "zone" {
  description = "Availability Zone"
  type        = string
  default     = "1"
}

variable "public_network_access_enabled" {
  description = "Enable or disable public network access for PostgreSQL Flexible Server."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

