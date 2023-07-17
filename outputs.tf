output "instrumentation_key" {
  value     = azurerm_application_insights.appins.instrumentation_key
  sensitive = true
}

output "app_id" {
  value = azurerm_application_insights.appins.app_id
}


output "resource_group_id" {
  value = azurerm_resource_group.taskrg.id
}

output "virtual_network_id" {
  value = azurerm_virtual_network.vnet.id
}

output "subnet1_id" {
  value = azurerm_subnet.subnet1.id
}

output "subnet2_id" {
  value = azurerm_subnet.subnet2.id
}

output "subnet3_id" {
  value = azurerm_subnet.subnet3.id
}

output "service_plan_id" {
  value = azurerm_service_plan.serviceplan.id
}

output "web_app_id" {
  value = azurerm_linux_web_app.webapp.id
}

output "app_insights_instrumentation_key" {
  value     = azurerm_application_insights.appins.instrumentation_key
  sensitive = true
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  value = azurerm_container_registry.acr.admin_username
}

output "acr_admin_password" {
  value     = azurerm_container_registry.acr.admin_password
  sensitive = true
}

output "storage_account_connection_string" {
  value     = azurerm_storage_account.storage_account_1.primary_blob_connection_string
  sensitive = true
}

output "storage_share_name" {
  value = azurerm_storage_share.storageshare.name
}

output "private_endpoint_id" {
  value = azurerm_private_endpoint.privateendpoint.id
}

output "mssql_server_id" {
  value = azurerm_mssql_server.mssqlsrv.id
}

output "mssql_database_id" {
  value = azurerm_mssql_database.mssqldb.id
}

output "key_vault_id" {
  value = azurerm_key_vault.keyvault.id
}

output "acr_id" {
  value = azurerm_container_registry.acr.id
}
