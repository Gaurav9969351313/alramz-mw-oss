output "id" {
  value = azurerm_bastion_host.this.id
}

output "name" {
  value = azurerm_bastion_host.this.name
}

output "public_ip_address" {
  value = azurerm_public_ip.bastion.ip_address
}
