variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "github_actions_object_id" {
  description = "Object ID of the GitHub Actions service principal for RBAC assignment"
  type        = string
  default     = ""
}

variable "subscription_id" {
  description = "Azure subscription ID for the custom role definition assignable scope"
  type        = string
  default     = ""
}