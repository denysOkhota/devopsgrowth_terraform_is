resource "azurerm_private_endpoint" "private_endpoint" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = var.private_service_connection[0].name
    is_manual_connection           = var.private_service_connection[0].is_manual_connection
    private_connection_resource_id = var.private_connection_resource_id
    subresource_names              = var.private_service_connection[0].subresource_names
  }
}