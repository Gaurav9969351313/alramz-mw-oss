output "resource_group_name" {
  value = module.resource_group.name
}

output "hub_vnet_id" {
  value = module.vnet.vnet_id
}

output "hub_vnet_name" {
  value = module.vnet.vnet_name
}

output "hub_subnet_ids" {
  value = module.vnet.subnet_ids
}

output "firewall_id" {
  value = module.azure_firewall.id
}

output "firewall_private_ip_address" {
  value = module.azure_firewall.private_ip_address
}

output "firewall_public_ip_address" {
  value = module.azure_firewall.public_ip_address
}

output "vpn_gateway_id" {
  value = module.vpn_gateway.id
}

output "vpn_gateway_public_ip_address" {
  value = module.vpn_gateway.public_ip_address
}

# output "bastion_id" {
#   value = module.azure_bastion.id
# }

# output "bastion_public_ip_address" {
#   value = module.azure_bastion.public_ip_address
# }

output "private_dns_zone_ids" {
  value = module.private_dns.dns_zone_ids
}
