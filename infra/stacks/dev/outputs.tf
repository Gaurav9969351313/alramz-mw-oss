output "resource_group_name" {
  value = module.resource_group.name
}


output "vnet_id" {
  value = module.vnet.vnet_id
}

output "vnet_name" {
  value = module.vnet.vnet_name
}

output "vnet_address_space" {
  value = module.vnet.vnet_address_space
}

output "subnet_ids" {
  value = module.vnet.subnet_ids
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

output "container_app_fqdns" {
  value = module.container_apps.service_fqdns
}

output "container_apps" {
  value = module.container_apps.container_apps
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

output "redis_hostname" {
  value = module.redis.hostname
}

output "redis_port" {
  value = module.redis.port
}

output "redis_primary_access_key" {
  value     = module.redis.primary_access_key
  sensitive = true
}

output "redis_connection_string" {
  value     = module.redis.connection_string
  sensitive = true
}

output "postgres_server_name" {
  value = module.postgresql.name
}

output "postgres_fqdn" {
  value = module.postgresql.fqdn
}

output "postgres_database" {
  value = module.postgresql.database_name
}

output "kv_private_endpoint_id" {
  value = module.kv_private_endpoint.id
}

output "redis_private_endpoint_id" {
  value = module.redis_private_endpoint.id
}

output "postgresql_private_endpoint_id" {
  value = module.postgresql_private_endpoint.id
}

output "container_apps_private_dns_zone_id" {
  value = module.container_apps_dns_link.dns_zone_ids["ashybush-7d7123f8.uaenorth.azurecontainerapps.io"]
}

output "container_apps_private_dns_zone_name" {
  value = "ashybush-7d7123f8.uaenorth.azurecontainerapps.io"
}

output "container_apps_internal_wildcard_fqdn" {
  value = "*.internal.ashybush-7d7123f8.uaenorth.azurecontainerapps.io"
}
