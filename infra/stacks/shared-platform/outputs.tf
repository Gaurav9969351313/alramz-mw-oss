output "resource_group_name" {
  value = module.resource_group.name
}

output "acr_id" {
  value = module.acr.id
}

output "acr_name" {
  value = module.acr.name
}

output "acr_login_server" {
  value = module.acr.login_server
}


output "github_actions_client_id" {
  value = module.github_actions_sp.client_id
}

output "github_actions_client_secret" {
  value     = module.github_actions_sp.client_secret
  sensitive = true
}

output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "github_actions_object_id" {
  value = module.github_actions_sp.object_id
}
