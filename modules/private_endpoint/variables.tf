variable "name" {
  description = "Name of the private endpoint."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the private endpoint will be created."
  type        = string
}

variable "location" {
  description = "Location of the private endpoint."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where the private endpoint will be placed."
  type        = string
}

variable "private_connection_resource_id" {
  description = "ID of the resource to which the private endpoint will connect."
  type        = string
}

variable "private_service_connection" {
  type = list(object({
    name                    = string
    is_manual_connection    = bool
    subresource_names       = list(string)
  }))
}