output "container_apps" {
  description = "========= Container Apps and their details ========="

  value = {
    for name, app in azurerm_container_app.this :
    name => {
      id   = app.id
      fqdn = app.latest_revision_fqdn
    }
  }
}

output "service_fqdns" {
  value = {
    for k, app in azurerm_container_app.this :
    k => "https://${app.ingress[0].fqdn}"
  }
}