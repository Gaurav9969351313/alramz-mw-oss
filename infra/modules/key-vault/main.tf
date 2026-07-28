resource "azurerm_key_vault" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tenant_id = var.tenant_id

  sku_name = "standard"

  rbac_authorization_enabled    = true
  public_network_access_enabled = var.public_network_access_enabled
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7

  tags = var.tags
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  for_each = toset(var.rbac_principal_ids)

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}