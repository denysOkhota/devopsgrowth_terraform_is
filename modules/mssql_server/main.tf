resource "azurerm_mssql_server" "mssql_server" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  version             = var.version
  administrator_login = var.administrator_login
  administrator_login_password = var.administrator_login_password
}