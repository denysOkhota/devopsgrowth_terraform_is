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
  address_prefixes                          = ["10.0.3.0/24"]
  name                                      = "subnet3"
  resource_group_name                       = module.resource_group.name
  virtual_network_name                      = module.virtual_network.name
  private_endpoint_network_policies_enabled = true
  service_endpoints                         = ["Microsoft.KeyVault"]
}

#------------------------------------------------------------------------------
#Creating Service Plan (App Service Plan)
#------------------------------------------------------------------------------

module "service_plan" {
  source = "./modules/service_plan"
  location            = module.resource_group.location
  name                = "${terraform.workspace}dendevopsgrowth_sp"
  os_type             = "Linux"
  sku_name            = "B1"
  resource_group_name = module.resource_group.name
}

#------------------------------------------------------------------------------
#Creating pp Service - Integrate with Vnet, Enable System Managed Identity 
#------------------------------------------------------------------------------
module "linux_web_app" {
  source = "./modules/linux_web_app"
  name                = "${terraform.workspace}dendevopsgrowth"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  service_plan_id     = module.service_plan.id
  virtual_network_subnet_id = azurerm_subnet.subnet1.id

  app_insights_instrumentation_key = "${module.app_insight.instrumentation_key}"

  acr_login_server = module.container_registry.login_server
  acr_admin_username = module.container_registry.admin_username
  acr_admin_password = module.container_registry.admin_password

  storage_account_connection_string = module.storage_account_1.primary_blob_connection_string
  storage_account_file_share_name = azurerm_storage_share.storageshare.name
}

#------------------------------------------------------------------------------
# Creating App Insights Linked to App Service
#------------------------------------------------------------------------------


module "app_insight" {
  source = "./modules/app_insight"
  name                = "${terraform.workspace}web_app_insights"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
}

#------------------------------------------------------------------------------
# Creating Storage account - Configured Private Endpoint with VNET and link Fileshare to App Service
#------------------------------------------------------------------------------


module "private_dns_zone" {
  source = "./modules/private_dns_zone"
  name                = "privatelink.file.core.windows.net"
  resource_group_name = module.resource_group.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network_link" {
  name                  = "devopsgrowth_vnl"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = module.private_dns_zone.name
  virtual_network_id    = module.virtual_network.id
}


module "storage_account_1" {
  source = "./modules/storage_account"
  name                     = "${terraform.workspace}dendevopsgrowthsa"
  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}


resource "azurerm_storage_share" "storageshare" {
  name                 = "${terraform.workspace}dendevopsgrowthshare"
  storage_account_name = module.storage_account_1.name
  quota                = 500
}

module "privateendpoint" {
  source = "./modules/private_endpoint"
  name                = "dendevopsgrowthpe"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = azurerm_subnet.subnet2.id
  private_connection_resource_id = module.storage_account_1.id
  private_service_connection = [{
    name                           = "dendevopsgrowth_psc"
    is_manual_connection           = false
    subresource_names              = ["file"]
  }]
}


data "azurerm_private_endpoint_connection" "private-ip1" {
  name                = module.privateendpoint.name
  resource_group_name = module.resource_group.name
  depends_on          = [azurerm_storage_share.storageshare]
}


resource "azurerm_private_dns_a_record" "dns_a" {
  name                = "dendevopsgrowth"
  zone_name           = module.private_dns_zone.name
  resource_group_name = module.resource_group.name
  ttl                 = 300
  records             = [data.azurerm_private_endpoint_connection.private-ip1.private_service_connection.0.private_ip_address]
}


#------------------------------------------------------------------------------
# MS SQL DB - Private Endpoint needs to be configured
#------------------------------------------------------------------------------

module "mssqlsrv" {
  source = "./modules/mssql_server"
  name                         = "${terraform.workspace}dendevopsgrowthmssqlsrv"
  location                     = module.resource_group.location
  resource_group_name          = module.resource_group.name
  administrator_login          = var.mssql_admin_login
  administrator_login_password = var.mssql_admin_pass
}

# Creating DB
module "mssqldb" {
  source = "./modules/mssql_db"
  name      = "${terraform.workspace}dendevopsgrowthmssqldb"
  server_id = module.mssqlsrv.id
}

# Configuring PE
module "dbpep" {
  source = "./modules/private_endpoint"
  name                = "${terraform.workspace}dendevopsgrowthdbpep"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  subnet_id           = azurerm_subnet.subnet3.id
  private_connection_resource_id = module.mssqlsrv.id

  private_service_connection= [{
    name                           = "dendevopsgrowthdbpep_psc"
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }]
}

data "azurerm_private_endpoint_connection" "private-ip2" {
  name                = module.dbpep.name
  resource_group_name = module.resource_group.name
  depends_on          = [module.mssqlsrv]
}


module "private_dns_zone2"{
  source = "./modules/private_dns_zone"
  name                = "privatelink.database.windows.net"
  resource_group_name = module.resource_group.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet-link2" {
  name                  = "vnet-private-zone-link"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = module.private_dns_zone2.name
  virtual_network_id    = module.virtual_network.id
  registration_enabled  = true
}

resource "azurerm_private_dns_a_record" "arecord1" {
  name                = module.mssqlsrv.name
  zone_name           = module.private_dns_zone2.name
  resource_group_name = module.resource_group.name
  ttl                 = 300
  records             = [data.azurerm_private_endpoint_connection.private-ip2.private_service_connection.0.private_ip_address]
}

#------------------------------------------------------------------------------
# Creating Key Vault Integrate with VNET and addded permissions to App Service Identity
#------------------------------------------------------------------------------

data "azurerm_client_config" "current" {}


module "keyvault" {
  source = "./modules/key_vault"
  name                = "${terraform.workspace}dendevopskeyvault"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id
  virtual_network_subnet_ids = [azurerm_subnet.subnet1.id, azurerm_subnet.subnet2.id, azurerm_subnet.subnet3.id]

}


resource "azurerm_key_vault_access_policy" "kvap" {
  key_vault_id = module.keyvault.id
  object_id    = module.linux_web_app.principal_id
  tenant_id    = module.linux_web_app.tenant_id

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

module "container_registry" {
  source = "./modules/container_registry"
  name                = "${terraform.workspace}dendevopsgrowthacr"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  sku                 = "Standard"
  admin_enabled       = true
  
}
