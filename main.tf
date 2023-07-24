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

    sas_token = "sp=racwdli&st=2023-07-24T08:06:18Z&se=2023-08-01T16:06:18Z&spr=https&sv=2022-11-02&sr=c&sig=csUJ5LLeAWLJnhpOSiA7GgUTPe2oZTtHknaFuOxtqrs%3D"
  }
}

provider "azurerm" {
  features {}
}

#------------------------------------------------------------------------------
# Creating resource group
#------------------------------------------------------------------------------

module "resource_group" {
  source   = "./modules/resource_group"
  name     = "${terraform.workspace}task-rg"
  location = "eastus"
}


#------------------------------------------------------------------------------
# 1 VNET with 3 subnets 
#------------------------------------------------------------------------------

module "virtual_network" {
  source              = "./modules/virtual_network"
  name                = "vnet"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
}

#------------------------------------------------------------------------------
#subnet1 delegated to web app
#------------------------------------------------------------------------------

resource "azurerm_subnet" "subnet1" {
  address_prefixes                          = ["10.0.0.0/24"]
  name                                      = "subnet1"
  resource_group_name                       = module.resource_group.name
  virtual_network_name                      = module.virtual_network.name
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
  resource_group_name                       = module.resource_group.name
  virtual_network_name                      = module.virtual_network.name
  private_endpoint_network_policies_enabled = true
  service_endpoints                         = ["Microsoft.KeyVault"]
}

#------------------------------------------------------------------------------
#subnet3
#------------------------------------------------------------------------------

resource "azurerm_subnet" "subnet3" {
  address_prefixes                          = ["10.0.2.0/24"]
  name                                      = "subnet3"
  resource_group_name                       = module.resource_group.name
  virtual_network_name                      = module.virtual_network.name
  private_endpoint_network_policies_enabled = true
  service_endpoints                         = ["Microsoft.KeyVault"]
}

#------------------------------------------------------------------------------
#Creating Service Plan (App Service Plan)
#------------------------------------------------------------------------------
resource "azurerm_service_plan" "serviceplan" {
  location            = module.resource_group.location
  name                = "${terraform.workspace}dendevopsgrowth_sp"
  os_type             = "Linux"
  sku_name            = "B1"
  resource_group_name = module.resource_group.name

}

#------------------------------------------------------------------------------
#Creating pp Service - Integrate with Vnet, Enable System Managed Identity 
#------------------------------------------------------------------------------

resource "azurerm_linux_web_app" "webapp" {
  name                = "${terraform.workspace}dendevopsgrowth"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
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
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
}

#------------------------------------------------------------------------------
# Creating Storage account - Configured Private Endpoint with VNET and link Fileshare to App Service
#------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "dns-zone" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = module.resource_group.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network_link" {
  name                  = "devopsgrowth_vnl"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.dns-zone.name
  virtual_network_id    = module.virtual_network.id
}

resource "azurerm_storage_account" "storage_account_1" {
  name                     = "${terraform.workspace}dendevopsgrowthsa"
  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
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
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
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
  resource_group_name = module.resource_group.name
  depends_on          = [azurerm_storage_share.storageshare]
}


resource "azurerm_private_dns_a_record" "dns_a" {
  name                = "dendevopsgrowth"
  zone_name           = azurerm_private_dns_zone.dns-zone.name
  resource_group_name = module.resource_group.name
  ttl                 = 300
  records             = [data.azurerm_private_endpoint_connection.private-ip1.private_service_connection.0.private_ip_address]
}


#------------------------------------------------------------------------------
# MS SQL DB - Private Endpoint needs to be configured
#------------------------------------------------------------------------------

resource "azurerm_mssql_server" "mssqlsrv" {
  name                         = "${terraform.workspace}dendevopsgrowthmssqlsrv"
  location                     = module.resource_group.location
  resource_group_name          = module.resource_group.name
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
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
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
  resource_group_name = module.resource_group.name
  depends_on          = [azurerm_mssql_server.mssqlsrv]
}

resource "azurerm_private_dns_zone" "dns-zone2" {
  name                = "privatelink.database.windows.net"
  resource_group_name = module.resource_group.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet-link2" {
  name                  = "vnet-private-zone-link"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.dns-zone2.name
  virtual_network_id    = module.virtual_network.id
  registration_enabled  = true
}

resource "azurerm_private_dns_a_record" "arecord1" {
  name                = azurerm_mssql_server.mssqlsrv.name
  zone_name           = azurerm_private_dns_zone.dns-zone2.name
  resource_group_name = module.resource_group.name
  ttl                 = 300
  records             = [data.azurerm_private_endpoint_connection.private-ip2.private_service_connection.0.private_ip_address]
}

#------------------------------------------------------------------------------
# Creating Key Vault Integrate with VNET and addded permissions to App Service Identity
#------------------------------------------------------------------------------

data "azurerm_client_config" "current" {}


resource "azurerm_key_vault" "keyvault" {
  name                = "dendevopskeyvault"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
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
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  sku                 = "Standard"
  admin_enabled       = true

}
