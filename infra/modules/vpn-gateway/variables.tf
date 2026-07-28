variable "name" {
  type        = string
  description = "VPN Gateway name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "gateway_subnet_id" {
  type        = string
  description = "ID of the GatewaySubnet"
}

variable "sku_name" {
  type        = string
  default     = "VpnGw1"
  description = "VPN Gateway SKU. Possible values include VpnGw1, VpnGw2, VpnGw3, etc."
}

variable "vpn_type" {
  type        = string
  default     = "RouteBased"
  description = "VPN type. Possible values are PolicyBased and RouteBased."
}

variable "enable_active_active" {
  type        = bool
  default     = false
  description = "Enable active-active mode for the VPN Gateway"
}

variable "tags" {
  type    = map(string)
  default = {}
}