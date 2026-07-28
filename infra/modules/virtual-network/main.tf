resource "azurerm_virtual_network" "this" {

  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name

  address_space = var.address_space

  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos_protection || var.ddos_protection_plan_id != null ? [1] : []

    content {
      id     = var.ddos_protection_plan_id
      enable = var.enable_ddos_protection
    }
  }

  tags = var.tags
}

resource "azurerm_private_dns_zone" "this" {

  for_each = var.private_dns_zones

  name                = each.value.zone_name
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {

  for_each = var.private_dns_zones

  name                  = "${var.vnet_name}-${each.key}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = each.value.registration_enabled

  tags = var.tags
}

resource "azurerm_subnet" "this" {

  for_each = var.subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name

  address_prefixes                  = each.value.address_prefixes
  service_endpoints                 = each.value.service_endpoints
  private_endpoint_network_policies = each.value.private_endpoint_network_policies

  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []

    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.service_actions
      }
    }
  }

}

resource "azurerm_route_table" "this" {

  for_each = var.route_tables

  name                = coalesce(try(each.value.name, null), "${var.vnet_name}-${each.key}-rt")
  location            = var.location
  resource_group_name = var.resource_group_name
  # disable_bgp_route_propagation = try(each.value.disable_bgp_route_propagation, false)

  tags = var.tags
}

resource "azurerm_route" "this" {

  for_each = local.flattened_route_table_routes

  name                   = each.value.route_name
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.this[each.value.route_table_key].name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = try(each.value.next_hop_in_ip_address, null)
}

resource "azurerm_subnet_route_table_association" "this" {

  for_each = {
    for subnet_name, subnet in azurerm_subnet.this :
    subnet_name => subnet
    if try(var.subnets[subnet_name].route_table_key, null) != null
  }

  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.this[var.subnets[each.key].route_table_key].id
}

resource "azurerm_public_ip" "nat" {

  for_each = var.nat_gateway_config

  name                = "${var.vnet_name}-${each.key}-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"

  tags = var.tags
}

resource "azurerm_nat_gateway" "this" {

  for_each = var.nat_gateway_config

  name                    = coalesce(each.value.name, "${var.vnet_name}-${each.key}-natgw")
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = each.value.idle_timeout_in_minutes

  tags = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {

  for_each = var.nat_gateway_config

  nat_gateway_id       = azurerm_nat_gateway.this[each.key].id
  public_ip_address_id = azurerm_public_ip.nat[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "this" {

  for_each = local.nat_gateway_subnet_associations

  subnet_id      = azurerm_subnet.this[each.value.subnet_name].id
  nat_gateway_id = azurerm_nat_gateway.this[each.value.nat_key].id
}

resource "azurerm_network_security_group" "this" {

  for_each = local.nsg_names

  name                = each.value
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {

  for_each = local.nsg_associatable_subnets

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_network_security_rule" "this" {

  for_each = local.flattened_nsg_rules

  name                   = each.value.name
  priority               = each.value.priority
  direction              = each.value.direction
  access                 = each.value.access
  protocol               = each.value.protocol
  source_port_range      = each.value.source_port_range
  destination_port_range = each.value.destination_port_range

  source_address_prefix = each.value.source_address_prefix != null ? each.value.source_address_prefix : local.subnet_prefixes[each.value.source_subnet]

  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[each.value.subnet].name
}

resource "azurerm_network_security_rule" "default_deny_inbound" {

  for_each = var.nsg_default_deny_rules ? local.nsg_names : {}

  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[each.key].name

}

resource "azurerm_monitor_diagnostic_setting" "nsg_flow_logs" {

  for_each = var.enable_nsg_flow_logs && var.log_analytics_workspace_id != null ? local.nsg_names : {}

  name                       = "${each.value}-flow-logs"
  target_resource_id         = azurerm_network_security_group.this[each.key].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "NetworkSecurityGroupFlowEvent"

    # retention_policy {
    #   enabled = false
    # }
  }
}

resource "azurerm_management_lock" "vnet_lock" {

  for_each = var.management_lock_level != null ? {
    lock = true
  } : {}

  name       = "${var.vnet_name}-lock"
  scope      = azurerm_virtual_network.this.id
  lock_level = var.management_lock_level
}

resource "azurerm_management_lock" "nsg_locks" {

  for_each = var.management_lock_level != null ? local.nsg_names : {}

  name       = "${each.value}-lock"
  scope      = azurerm_network_security_group.this[each.key].id
  lock_level = var.management_lock_level
}

