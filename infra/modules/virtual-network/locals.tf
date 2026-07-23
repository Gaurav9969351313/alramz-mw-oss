locals {
  subnet_names = keys(var.subnets)

  nsg_names = {
    for subnet_name in local.subnet_names :
    subnet_name => "${var.vnet_name}-${subnet_name}-nsg"
  }

  subnet_prefixes = {
    for subnet_name, subnet in var.subnets :
    subnet_name => subnet.address_prefixes[0]
  }
  flattened_nsg_rules = length(var.nsg_rules) == 0 ? {} : merge([
    for subnet_name, rules in var.nsg_rules :
    {
      for rule in rules :
      "${subnet_name}-${rule.name}" => merge(rule, {
        subnet = subnet_name
      })
    }
  ]...)

  flattened_route_table_routes = length(var.route_tables) == 0 ? {} : merge([
    for route_table_key, route_table in var.route_tables :
    {
      for route_key, route in try(route_table.routes, {}) :
      "${route_table_key}-${route_key}" => merge(route, {
        route_table_key = route_table_key
        route_name      = route_key
      })
    }
  ]...)

  nat_gateway_subnet_associations = length(var.nat_gateway_config) == 0 ? {} : merge([
    for nat_key, nat_cfg in var.nat_gateway_config :
    {
      for subnet_name in try(nat_cfg.subnets, []) :
      "${nat_key}-${subnet_name}" => {
        nat_key     = nat_key
        subnet_name = subnet_name
      }
    }
  ]...)

}
  
