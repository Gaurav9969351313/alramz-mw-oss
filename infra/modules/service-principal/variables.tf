variable "name" {
  description = "Display name for Azure AD Application"
  type        = string
}

variable "create_client_secret" {
  type    = bool
  default = true
}

variable "client_secret_display_name" {
  type    = string
  default = "terraform-generated-secret"
}

variable "role_assignments" {
  description = "Role assignments to create"
  type = list(object({
    scope = string
    role  = string
  }))
  default = []
}