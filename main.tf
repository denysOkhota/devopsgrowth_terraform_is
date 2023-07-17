terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "tfstate"
    storage_account_name = "tfstatedixj2"
    container_name       = "statefile"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "taskrg" {
  name     = "task-rg"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet1"
  location            = azurerm_resource_group.taskrg.location
  resource_group_name = azurerm_resource_group.taskrg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet1" {
  address_prefixes                          = ["10.0.0.0/24"]
  name                                      = "subnet1"
  resource_group_name                       = azurerm_resource_group.taskrg.name
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  private_endpoint_network_policies_enabled = true

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

resource "azurerm_subnet" "subnet2" {
  address_prefixes                          = ["10.0.1.0/24"]
  name                                      = "subnet2"
  resource_group_name                       = azurerm_resource_group.taskrg.name
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet" "subnet3" {
  address_prefixes                          = ["10.0.2.0/24"]
  name                                      = "subnet3"
  resource_group_name                       = azurerm_resource_group.taskrg.name
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  private_endpoint_network_policies_enabled = true
}

data "azurerm_subscription" "current" {}

resource "azurerm_service_plan" "serviceplan" {
  location            = azurerm_resource_group.taskrg.location
  name                = "dendevopsgrowth_sp"
  os_type             = "Linux"
  sku_name            = "B1"
  resource_group_name = azurerm_resource_group.taskrg.name
  
}

resource "azurerm_linux_web_app" "webapp" {
  name                      = "dendevopsgrowth"
  resource_group_name       = azurerm_resource_group.taskrg.name
  location                  = azurerm_resource_group.taskrg.location
  service_plan_id           = azurerm_service_plan.serviceplan.id
  virtual_network_subnet_id = azurerm_subnet.subnet1.id
  
  identity {
    type = "SystemAssigned"
  }
  site_config {}
  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY = "${azurerm_application_insights.appins.instrumentation_key}"
  }
}

resource "azurerm_application_insights" "appins" {
  name                = "web_app_insights"
  application_type    = "web"
  location            = azurerm_resource_group.taskrg.location
  resource_group_name = azurerm_resource_group.taskrg.name
}

output "instrumentation_key" {
  value = azurerm_application_insights.appins.instrumentation_key
  sensitive = true
}

output "app_id" {
  value = azurerm_application_insights.appins.app_id
}

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
  name                     = "dendevopsgrowthsa"
  resource_group_name      = azurerm_resource_group.taskrg.name
  location                 = azurerm_resource_group.taskrg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

resource "azurerm_storage_share" "storageshare" {
  name                 = "dendevopsgrowthshare"
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


resource "azurerm_mssql_server" "mssqlsrv" {
  name = "dendevopsgrowthmssqlsrv"
  location = azurerm_resource_group.taskrg.location
  resource_group_name = azurerm_resource_group.taskrg.name
  version = "12.0"
  administrator_login = var.mssql_admin_login
  administrator_login_password = var.mssql_admin_pass
}

resource "azurerm_mssql_database" "mssqldb" {
  name = "dendevopsgrowthmssqldb"
  server_id = azurerm_mssql_server.mssqlsrv.id
}

resource "azurerm_private_endpoint" "dbpep" {
  name = "dendevopsgrowthdbpep"
  location = azurerm_resource_group.taskrg.location
  resource_group_name = azurerm_resource_group.taskrg.name
  subnet_id = azurerm_subnet.subnet3.id

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