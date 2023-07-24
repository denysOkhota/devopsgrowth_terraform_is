variable "name" {
  description = "Name of the MSSQL server."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the MSSQL server will be created."
  type        = string
}

variable "location" {
  description = "Location of the MSSQL server."
  type        = string
}

variable "version" {
  description = "Version of the MSSQL server."
  type        = string
}

variable "administrator_login" {
  description = "Administrator login for the MSSQL server."
  type        = string
}

variable "administrator_login_password" {
  description = "Administrator login password for the MSSQL server."
  type        = string
}