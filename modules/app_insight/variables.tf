variable "name" {
  description = "Name of the Azure Container Registry."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the Azure Container Registry will be created."
  type        = string
}

variable "location" {
  description = "Azure region where the Azure Container Registry will be created."
  type        = string
}

variable "sku" {
  description = "SKU tier for the Azure Container Registry (e.g., 'Basic', 'Standard', 'Premium')."
  type        = string
  default     = "Standard"
}

variable "admin_enabled" {
  description = "Indicates whether admin user is enabled for the Azure Container Registry."
  type        = bool
  default     = false
}