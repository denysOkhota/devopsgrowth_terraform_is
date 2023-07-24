variable "name" {
  description = "Name of the service plan (App Service Plan)."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the service plan will be created."
  type        = string
}

variable "location" {
  description = "Location for the service plan."
  type        = string
}

variable "os_type" {
  description = "Operating system type for the service plan (Windows or Linux)."
  type        = string
  default     = "Linux"
}

variable "sku_name" {
  description = "App Service Plan SKU name."
  type        = string
  default     = "B1"
}