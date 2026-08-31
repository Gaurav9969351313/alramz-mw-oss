variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "dns_prefix" {
  type    = string
  default = "aks-dev"
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "os_disk_size_gb" {
  type    = number
  default = 30
}

variable "availability_zones" {
  type    = list(number)
  default = []
}

variable "subnet_id" {
  type    = string
  default = null
}

variable "log_analytics_workspace_id" {
  type    = string
  default = null
}

variable "acr_id" {
  type    = string
  default = null
}

variable "identity_id" {
  description = "Existing user-assigned managed identity ID to use for AKS"
  type        = string
  default = null
}

variable "identity_name" {
  description = "Name of the existing user-assigned managed identity"
  type        = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
