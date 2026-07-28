resource "azurerm_api_management" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  publisher_name  = var.publisher_name
  publisher_email = var.publisher_email

  sku_name                      = var.sku_name
  virtual_network_type          = var.virtual_network_type
  public_network_access_enabled = var.public_network_access_enabled

  dynamic "virtual_network_configuration" {
    for_each = var.virtual_network_type == "External" && var.virtual_network_subnet_id != null ? [1] : []
    content {
      subnet_id = var.virtual_network_subnet_id
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_api_management_backend" "this" {
  for_each = var.backends

  name                = each.key
  resource_group_name = var.resource_group_name
  api_management_name = var.name
  protocol            = "http"
  url                 = each.value.url
}

resource "azurerm_api_management_product" "this" {
  for_each = var.products

  product_id                = each.key
  resource_group_name       = var.resource_group_name
  api_management_name       = var.name
  display_name              = each.value.display_name
  description               = each.value.description
  subscription_required     = false
  approval_required         = false
  subscriptions_limit       = 0
  published                 = true
}

resource "azurerm_api_management_api" "this" {
  for_each = var.apis

  name                = each.key
  resource_group_name = var.resource_group_name
  api_management_name = var.name

  revision            = "1"
  display_name        = title(replace(each.key, "_", " "))
  path                = each.value.path
  protocols           = each.value.schemes
  service_url         = try(each.value.service_config.url, null)
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "this" {
  for_each = {
    for api_key, ops in var.api_operations : api_key => ops
  }

  operation_id        = each.key
  api_name           = each.key
  resource_group_name = var.resource_group_name
  api_management_name = var.name

  display_name = title(replace(each.key, "_", " "))
  method       = "GET"
  url_template = try(each.value.url, "/")

  request {
    query_parameter {
      name     = "dummy"
      type     = "string"
      required = false
    }
  }

  response {
    status_code = 200
  }
}

locals {
  product_api_associations = merge([
    for product_key, product in var.products : {
      for api_id in product.api_ids :
      "${product_key}-${api_id}" => {
        product_id = product_key
        api_name   = api_id
      }
    }
  ]...)
}

resource "azurerm_api_management_product_api" "this" {
  for_each = local.product_api_associations

  product_id          = each.value.product_id
  api_name            = each.value.api_name
  resource_group_name = var.resource_group_name
  api_management_name = var.name
}