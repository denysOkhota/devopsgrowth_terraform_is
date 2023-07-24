variable "name" {
  description = "Name of the Linux web app."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the web app will be created."
  type        = string
}

variable "location" {
  description = "Azure region where the web app will be created."
  type        = string
}

variable "service_plan_id" {
  description = "ID of the App Service Plan to which the web app will be deployed."
  type        = string
}

variable "virtual_network_subnet_id" {
  description = "ID of the subnet to which the web app will be integrated."
  type        = string
}

variable "app_insights_instrumentation_key" {
  description = "Application Insights Instrumentation Key."
  type        = string
}

variable "acr_login_server" {
  description = "Azure Container Registry (ACR) login server URL."
  type        = string
}

variable "acr_admin_username" {
  description = "ACR admin username."
  type        = string
}

variable "acr_admin_password" {
  description = "ACR admin password."
  type        = string
}

variable "storage_account_connection_string" {
  description = "Connection string of the Azure Storage Account."
  type        = string
}

variable "storage_account_file_share_name" {
  description = "Name of the file share in the Azure Storage Account."
  type        = string
}