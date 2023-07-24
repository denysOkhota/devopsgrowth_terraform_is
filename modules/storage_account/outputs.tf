output "storage_account_name" {
  value = azurerm_storage_account.storage_account.name
}

output "primary_blob_connection_string" {
  value = azurerm_storage_account.storage_account.primary_blob_connection_string
}