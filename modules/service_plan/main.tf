resource "azurerm_service_plan" "serviceplan" {
  location            = var.location
  name                = var.name
  os_type             = var.os_type
  sku_name            = var.sku_name
  resource_group_name = var.resource_group_name
}