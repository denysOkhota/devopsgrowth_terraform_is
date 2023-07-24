locals {
  virtual_network_cidr = try(split("/", module.virtual_network.virtual_network_address_space[0]), module.virtual_network.virtual_network_address_space)
  subnet_address_space = cidrsubnet(local.virtual_network_cidr, 4, var.subnet_index)
}

resource "azurerm_subnet" "subnet" {
  name                 = var.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [local.subnet_address_space]
  service_endpoints = [ "Microsoft.KeyVault" ]
  private_endpoint_network_policies_enabled = true
}