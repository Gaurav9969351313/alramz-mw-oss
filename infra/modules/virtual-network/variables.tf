variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "address_space" {
  type = list(string)
  validation {
    condition     = length(var.address_space) > 0
    error_message = "address_space must contain at least one CIDR block."
  }
}

variable "subnets" {

  description = "Subnet definitions"
  type = map(object({
    address_prefixes                  = list(string)
    service_endpoints                 = optional(list(string), [])
    private_endpoint_network_policies = optional(string, "Enabled")
    route_table_key                   = optional(string, null)

    delegation = optional(object({
      name            = string
      service_name    = string
      service_actions = list(string)
    }), null) # Defaults to null if not provided
  }))

}

variable "tags" {
  type = map(string)
}

variable "nsg_rules" {

  description = "NSG Rules"

  type = map(list(object({

    name      = string
    priority  = number
    direction = string
    access    = string
    protocol  = string

    source_port_range      = string
    destination_port_range = string

    source_subnet              = optional(string)
    source_address_prefix      = optional(string)
    destination_address_prefix = string

  })))

  default = {}

}

variable "private_dns_zones" {

  description = "Private DNS zones to create and link to this VNet (keyed map)."

  type = map(object({
    zone_name            = string
    registration_enabled = optional(bool, false)
  }))

  default = {}

}

variable "route_tables" {

  description = "Route table definitions keyed by route_table_key for optional subnet association."

  type = map(object({
    name                          = optional(string)
    disable_bgp_route_propagation = optional(bool, false)
    routes = optional(map(object({
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = optional(string)
    })), {})
  }))

  default = {}

}

variable "enable_nsg_flow_logs" {
  description = "Enable NSG flow logs sent to Log Analytics workspace."
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for NSG flow logs and diagnostics."
  type        = string
  default     = null
}

variable "lag_workspace_resource_group_name" {
  description = "Resource group name where Log Analytics workspace exists (for flow log creation)."
  type        = string
  default     = null
}

variable "nsg_default_deny_rules" {
  description = "Enable default NSG deny inbound rule (deny all inbound by default, then allow via explicit rules)."
  type        = bool
  default     = false
}

variable "nat_gateway_config" {
  description = "NAT Gateway configuration for controlled egress (optional per subnet)."
  type = map(object({
    name                    = optional(string)
    public_ip_prefixes      = optional(list(string), [])
    subnets                 = optional(list(string), [])
    idle_timeout_in_minutes = optional(number, 4)
  }))
  default = {}
}

variable "ddos_protection_plan_id" {
  description = "ID of existing DDoS Protection Plan to bind to this VNet (optional)."
  type        = string
  default     = null
}

variable "enable_ddos_protection" {
  description = "Enable DDoS Standard protection (requires premium plan subscription)."
  type        = bool
  default     = false
}

variable "management_lock_level" {
  description = "Resource lock level for the VNet and NSGs (CanNotDelete, ReadOnly, or null for no lock)."
  type        = string
  default     = null

  validation {
    condition     = var.management_lock_level == null || contains(["CanNotDelete", "ReadOnly"], var.management_lock_level)
    error_message = "management_lock_level must be null, CanNotDelete, or ReadOnly."
  }
}

