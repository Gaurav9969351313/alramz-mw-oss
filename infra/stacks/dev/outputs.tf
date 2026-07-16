output "resource_group_name" {
  value = module.resource_group.name
}


output "key_vault_name" {
  value = module.key_vault.name
}

output "key_vault_uri" {
  value = module.key_vault.vault_uri
}

output "apim_gateway_url" {
  value = module.apim.gateway_url
}

output "container_app_environment_name" {
  value = module.container_app_environment.name
}

output "container_app_environment_domain" {
  value = module.container_app_environment.default_domain
}


output "log_analytics_workspace_name" {
  value = module.monitoring.name
}

output "log_analytics_workspace_id" {
  value = module.monitoring.workspace_id
}

output "application_insights_name" {
  value = module.monitoring.application_insights_name
}

output "application_insights_connection_string" {
  value     = module.monitoring.application_insights_connection_string
  sensitive = true
}

output "application_insights_instrumentation_key" {
  value     = module.monitoring.application_insights_instrumentation_key
  sensitive = true
}

