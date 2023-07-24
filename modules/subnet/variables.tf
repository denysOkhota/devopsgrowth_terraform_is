variable "name" {
  description = "Name of the subnet."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the virtual network is located."
  type        = string
}

variable "virtual_network_name" {
  description = "Name of the virtual network where the subnet will be created."
  type        = string
}

variable "subnet_index" {
  description = "Index of the subnet. Used to calculate the address prefix."
  type        = number
}