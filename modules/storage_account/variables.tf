variable "name" {
  description = "Name of the storage account."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the storage account will be created."
  type        = string
}

variable "location" {
  description = "Location for the storage account."
  type        = string
}

variable "account_tier" {
  description = "The storage account tier (Standard or Premium)."
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "The storage account replication type (LRS, GRS, RAGRS, ZRS)."
  type        = string
  default     = "GRS"
}