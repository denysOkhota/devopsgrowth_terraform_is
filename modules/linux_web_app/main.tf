resource "azurerm_linux_web_app" "webapp" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = var.service_plan_id

  # Integrate with Vnet
  virtual_network_subnet_id = var.virtual_network_subnet_id

  # Enable System Managed Identity
  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
  }

  app_settings = {
    # Linking App Insights Instrumentation
    APPINSIGHTS_INSTRUMENTATIONKEY = var.app_insights_instrumentation_key

    # Integrating ACR
    DOCKER_REGISTRY_SERVER_URL      = var.acr_login_server
    DOCKER_REGISTRY_SERVER_USERNAME = var.acr_admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = var.acr_admin_password

    # Linking file share
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = var.storage_account_connection_string
    WEBSITE_CONTENTSHARE                     = var.storage_account_file_share_name
  }
}