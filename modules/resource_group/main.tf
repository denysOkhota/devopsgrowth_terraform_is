resource "azurerm_resource_group" "taskrg" {
  name     = var.name
  location = var.location
}