output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "vnet_address_space" {
  value = azurerm_virtual_network.this.address_space
}

output "subnet_names" {
  value = keys(azurerm_subnet.this)
}

output "subnet_ids" {
  description = "Map of subnet IDs"

  value = {
    for subnet_name, subnet in azurerm_subnet.this :
    subnet_name => subnet.id
  }
}

output "nsg_ids" {
  value = {
    for nsg in azurerm_network_security_group.this :
    nsg.name => nsg.id
  }
}

output "nsg_names" {
  value = keys(azurerm_network_security_group.this)
}

output "private_dns_zone_ids" {
  value = {
    for zone_key, zone in azurerm_private_dns_zone.this :
    zone_key => zone.id
  }
}

output "private_dns_zone_names" {
  value = {
    for zone_key, zone in azurerm_private_dns_zone.this :
    zone_key => zone.name
  }
}

output "route_table_ids" {
  value = {
    for route_table_key, route_table in azurerm_route_table.this :
    route_table_key => route_table.id
  }
}

output "nat_gateway_ids" {
  value = {
    for nat_key, nat_gw in azurerm_nat_gateway.this :
    nat_key => nat_gw.id
  }
  description = "NAT Gateway IDs for controlled egress."
}

output "nat_gateway_public_ips" {
  value = {
    for nat_key, public_ip in azurerm_public_ip.nat :
    nat_key => public_ip.ip_address
  }
  description = "Public IPs used for egress from NAT Gateway-tagged subnets."
  sensitive   = false
}

output "management_locks_enabled" {
  value = var.management_lock_level != null
  description = "Whether management locks (CanNotDelete/ReadOnly) are applied to VNet and NSGs."
}

