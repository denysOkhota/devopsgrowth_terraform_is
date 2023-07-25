output "webapp_id" {
  description = "The ID of the created Linux web app."
  value       = azurerm_linux_web_app.webapp.id
}

output "tenant_id" {
  value = azurerm_linux_web_app.webapp.identity.0.tenant_id
}

output "principal_id" {
  value = azurerm_linux_web_app.webapp.identity.0.principal_id
}