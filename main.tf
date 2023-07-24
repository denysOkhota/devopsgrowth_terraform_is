terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "tfstate"
    storage_account_name = "dentfstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"

    sas_token = var.sas_token
  }
}

provider "azurerm" {
  features {}
}

#------------------------------------------------------------------------------
# Creating resource group
#------------------------------------------------------------------------------

resource "azurerm_resource_group" "taskrg" {
  name     = "${terraform.workspace}task-rg"
  location = "eastus"
}

#------------------------------------------------------------------------------
# 1 VNET with 3 subnets 
#------------------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet1"
  location            = azurerm_resource_group.taskrg.location
  resource_group_name = azurerm_resource_group.taskrg.name
  address_space       = ["10.0.0.0/16"]
}

#------------------------------------------------------------------------------
#subnet1 delegated to web app
#------------------------------------------------------------------------------

resource "azurerm_subnet" "subnet1" {
  address_prefixes                          = ["10.0.0.0/24"]
  name                                      = "subnet1"
  resource_group_name                       = azurerm_resource_group.taskrg.name
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  private_endpoint_network_policies_enabled = true

  service_endpoints = ["Microsoft.KeyVault"]

  delegation {
    name = "delegation"

    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
      "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    }
  }


}

#------------------------------------------------------------------------------
#subnet2 
#------------------------------------------------------------------------------
resource "azurerm_subnet" "subnet2" {
  address_prefixes                          = ["10.0.1.0/24"]
  name                                      = "subnet2"
  resource_group_name                       = azurerm_resource_group.taskrg.name
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  private_endpoint_network_policies_enabled = true
  service_endpoints                         = ["Microsoft.KeyVault"]
}

#------------------------------------------------------------------------------
#subnet3
#------------------------------------------------------------------------------

resource "azurerm_subnet" "subnet3" {
  address_prefixes                          = ["10.0.2.0/24"]
  name                                      = "subnet3"
  resource_group_name                       = azurerm_resource_group.taskrg.name
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  private_endpoint_network_policies_enabled = true
  service_endpoints                         = ["Microsoft.KeyVault"]
}

#------------------------------------------------------------------------------
#Creating Service Plan (App Service Plan)
#------------------------------------------------------------------------------
resource "azurerm_service_plan" "serviceplan" {
  location            = azurerm_resource_group.taskrg.location
  name                = "${terraform.workspace}dendevopsgrowth_sp"
  os_type             = "Linux"
  sku_name            = "B1"
  resource_group_name = azurerm_resource_group.taskrg.name

}

#------------------------------------------------------------------------------
#Creating pp Service - Integrate with Vnet, Enable System Managed Identity 
#------------------------------------------------------------------------------

resource "azurerm_linux_web_app" "webapp" {
  name                = "${terraform.workspace}dendevopsgrowth"
  resource_group_name = azurerm_resource_group.taskrg.name
  location            = azurerm_resource_group.taskrg.location
  service_plan_id     = azurerm_service_plan.serviceplan.id
  # Integrate with Vnet
  virtual_network_subnet_id = azurerm_subnet.subnet1.id

  # Enable System Managed Identity
  identity {
    type = "SystemAssigned"
  }
  site_config {
    always_on = true
  }
  app_settings = {
    # Linking App Insights Instrumentation
    APPINSIGHTS_INSTRUMENTATIONKEY = "${azurerm_application_insights.appins.instrumentation_key}"
    # Integrating ACR
    DOCKER_REGISTRY_SERVER_URL      = azurerm_container_registry.acr.login_server
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.acr.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.acr.admin_password
    # Linking file share 
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.storage_account_1.primary_blob_connection_string
    WEBSITE_CONTENTSHARE                     = azurerm_storage_share.storageshare.name
  }
}

#------------------------------------------------------------------------------
# Creating App Insights Linked to App Service
#------------------------------------------------------------------------------

resource "azurerm_application_insights" "appins" {
  name                = "web_app_insights"
  application_type    = "web"
  location            = azurerm_resource_group.taskrg.location
  resource_group_name = azurerm_resource_group.taskrg.name
}

#------------------------------------------------------------------------------
# Creating Storage account - Configured Private Endpoint with VNET and link Fileshare to App Service
#------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "dns-zone" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.taskrg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network_link" {
  name                  = "devopsgrowth_vnl"
  resource_group_name   = azurerm_resource_group.taskrg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns-zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_storage_account" "storage_account_1" {
  name                     = "${terraform.workspace}dendevopsgrowthsa"
  resource_group_name      = azurerm_resource_group.taskrg.name
  location                 = azurerm_resource_group.taskrg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

resource "azurerm_storage_share" "storageshare" {
  name                 = "${terraform.workspace}dendevopsgrowthshare"
  storage_account_name = azurerm_storage_account.storage_account_1.name
  quota                = 500
}

resource "azurerm_private_endpoint" "privateendpoint" {
  name                = "dendevopsgrowthpe"
  resource_group_name = azurerm_resource_group.taskrg.name
  location            = azurerm_resource_group.taskrg.location
  subnet_id           = azurerm_subnet.subnet2.id

  private_service_connection {
    name                           = "dendevopsgrowth_psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.storage_account_1.id
    subresource_names              = ["file"]
  }
}

data "azurerm_private_endpoint_connection" "private-ip1" {
  name                = azurerm_private_endpoint.privateendpoint.name
  resource_group_name = azurerm_resource_group.taskrg.name
  depends_on          = [azurerm_storage_share.storageshare]
}


resource "azurerm_private_dns_a_record" "dns_a" {
  name                = "dendevopsgrowth"
  zone_name           = azurerm_private_dns_zone.dns-zone.name
  resource_group_name = azurerm_resource_group.taskrg.name
  ttl                 = 300
  records             = [data.azurerm_private_endpoint_connection.private-ip1.private_service_connection.0.private_ip_address]
}


#------------------------------------------------------------------------------
# MS SQL DB - Private Endpoint needs to be configured
#------------------------------------------------------------------------------

resource "azurerm_mssql_server" "mssqlsrv" {
  name                         = "${terraform.workspace}dendevopsgrowthmssqlsrv"
  location                     = azurerm_resource_group.taskrg.location
  resource_group_name          = azurerm_resource_group.taskrg.name
  version                      = "12.0"
  administrator_login          = var.mssql_admin_login
  administrator_login_password = var.mssql_admin_pass
}

# Creating DB
resource "azurerm_mssql_database" "mssqldb" {
  name      = "${terraform.workspace}dendevopsgrowthmssqldb"
  server_id = azurerm_mssql_server.mssqlsrv.id
}

# Configuring PE
resource "azurerm_private_endpoint" "dbpep" {
  name                = "${terraform.workspace}dendevopsgrowthdbpep"
  location            = azurerm_resource_group.taskrg.location
  resource_group_name = azurerm_resource_group.taskrg.name
  subnet_id           = azurerm_subnet.subnet3.id

  private_service_connection {
    name                           = "dendevopsgrowthdbpep_psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_mssql_server.mssqlsrv.id
    subresource_names              = ["sqlServer"]
  }
}

data "azurerm_private_endpoint_connection" "private-ip2" {
  name                = azurerm_private_endpoint.dbpep.name
  resource_group_name = azurerm_resource_group.taskrg.name
  depends_on          = [azurerm_mssql_server.mssqlsrv]
}

resource "azurerm_private_dns_zone" "dns-zone2" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.taskrg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet-link2" {
  name                  = "vnet-private-zone-link"
  resource_group_name   = azurerm_resource_group.taskrg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns-zone2.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = true
}

resource "azurerm_private_dns_a_record" "arecord1" {
  name                = azurerm_mssql_server.mssqlsrv.name
  zone_name           = azurerm_private_dns_zone.dns-zone2.name
  resource_group_name = azurerm_resource_group.taskrg.name
  ttl                 = 300
  records             = [data.azurerm_private_endpoint_connection.private-ip2.private_service_connection.0.private_ip_address]
}

#------------------------------------------------------------------------------
# Creating Key Vault Integrate with VNET and addded permissions to App Service Identity
#------------------------------------------------------------------------------

data "azurerm_client_config" "current" {}


resource "azurerm_key_vault" "keyvault" {
  name                = "dendevopskeyvault"
  location            = azurerm_resource_group.taskrg.location
  resource_group_name = azurerm_resource_group.taskrg.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
  }

  # Integration with VNET
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.subnet1.id, azurerm_subnet.subnet2.id, azurerm_subnet.subnet3.id]
  }
}


resource "azurerm_key_vault_access_policy" "kvap" {
  key_vault_id = azurerm_key_vault.keyvault.id
  object_id    = azurerm_linux_web_app.webapp.identity.0.principal_id
  tenant_id    = azurerm_linux_web_app.webapp.identity.0.tenant_id

  key_permissions = [
    "Get",
  ]

  secret_permissions = [
    "Get",
  ]
}

#------------------------------------------------------------------------------
# ACR - Azure Container Registry, grant access to App Service
#------------------------------------------------------------------------------

resource "azurerm_container_registry" "acr" {
  name                = "dendevopsgrowthacr"
  resource_group_name = azurerm_resource_group.taskrg.name
  location            = azurerm_resource_group.taskrg.location
  sku                 = "Standard"
  admin_enabled       = true

}
