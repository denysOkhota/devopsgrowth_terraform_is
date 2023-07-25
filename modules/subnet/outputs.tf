variable "address_prefixes" {
  type    = list(string)
  default = ["10.0.0.0/24"]
}

variable "name" {
  type    = string
  default = "subnet1"
}

variable "resource_group_name" {
}

variable "virtual_network_name" {
}

variable "private_endpoint_network_policies_enabled" {
}

variable "service_endpoints" {
}

variable "delegation_name" {
}

variable "service_delegation_name" {
}

variable "service_delegation_actions" {

}