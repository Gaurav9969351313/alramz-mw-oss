output "id" {
  value = azurerm_api_management.this.id
}

output "name" {
  value = azurerm_api_management.this.name
}

output "gateway_url" {
  value = azurerm_api_management.this.gateway_url
}

output "backend_ids" {
  value = {
    for name, backend in azurerm_api_management_backend.this : name => backend.id
  }
}

output "api_ids" {
  value = {
    for name, api in azurerm_api_management_api.this : name => api.id
  }
}

output "product_ids" {
  value = {
    for name, product in azurerm_api_management_product.this : name => product.id
  }
}