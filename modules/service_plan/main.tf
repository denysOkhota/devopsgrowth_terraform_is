resource "azurerm_app_service_plan" "service_plan" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = var.os_type
  sku {
    tier = var.sku_name
    size = "B1"
  }
}