
resource "azurerm_mssql_database" "mssql_database" {
  name       = var.name
  server_id  = var.server_id
}

