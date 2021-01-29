data "azurerm_subscription" "primary" {}

resource "azurerm_user_assigned_identity" "consul" {
  location            = var.location
  resource_group_name = var.rg_name

  name = "consul-${var.env}"
}

resource "azurerm_role_assignment" "consul" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.consul.principal_id
}

resource "azurerm_user_assigned_identity" "product-api" {
  location            = var.location
  resource_group_name = var.rg_name

  name = "product-api-${var.env}"
}

resource "azurerm_role_assignment" "product-api" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.product-api.principal_id
}
