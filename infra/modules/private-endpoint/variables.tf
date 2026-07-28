variable "name" {
  type        = string
  description = "Private endpoint name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet to deploy the private endpoint into"
}

variable "target_resource_id" {
  type        = string
  description = "Resource ID of the target service"
}

variable "subresource_names" {
  type        = list(string)
  description = "Subresource names for the private endpoint connection"
}

variable "private_dns_zone_ids" {
  type        = list(string)
  description = "List of private DNS zone IDs to link"
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
