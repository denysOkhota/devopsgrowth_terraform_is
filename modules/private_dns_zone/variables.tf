variable "name" {
  description = "Name of the private DNS zone."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the private DNS zone will be created."
  type        = string
}