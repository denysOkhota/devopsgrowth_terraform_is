output "webapp_id" {
  description = "The ID of the created Linux web app."
  value       = azurerm_linux_web_app.webapp.id
}