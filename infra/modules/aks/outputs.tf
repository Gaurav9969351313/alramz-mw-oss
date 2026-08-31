output "id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "fqdn" {
  value = azurerm_kubernetes_cluster.this.fqdn
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive = true
}
