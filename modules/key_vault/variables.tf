variable "name" {
  description = "Name of the Azure Key Vault."
  type        = string
}

variable "location" {
  description = "Azure region where the Key Vault will be created."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the Key Vault will be created."
  type        = string
}

variable "sku_name" {
  description = "SKU name for the Key Vault (e.g., 'standard', 'premium')."
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID."
  type        = string
}

variable "object_id" {
  description = "Azure AD object ID of the principal to assign access policy to."
  type        = string
}

variable "virtual_network_subnet_ids" {
  description = "List of subnet IDs to which the Key Vault will be integrated."
  type        = list(string)
}