resource "azurerm_virtual_network" "vnet" {
  name                = var.name
  location            = var.location
  address_space       = var.address_space
}
