variable "name" {
  description = "Key Vault name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant id"
  type        = string
}

variable "rbac_principal_ids" {
  description = "List of principal IDs to grant Key Vault access"
  type        = list(string)
  default     = []
}

variable "rbac_role_name" {
  description = "RBAC role to assign to principals on the Key Vault"
  type        = string
  default     = "Key Vault Secrets User"
}

variable "public_network_access_enabled" {
  description = "Enable or disable public network access for Key Vault."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
