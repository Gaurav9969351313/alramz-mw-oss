output "id" {
  value = azurerm_virtual_network_gateway.this.id
}

output "name" {
  value = azurerm_virtual_network_gateway.this.name
}

output "public_ip_address" {
  value = azurerm_public_ip.vpn_gateway.ip_address
}

output "vpn_client_configuration" {
  value     = azurerm_virtual_network_gateway.this.vpn_client_configuration
  sensitive = true
}