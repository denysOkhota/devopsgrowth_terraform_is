variable "mssql_admin_login" {}
variable "mssql_admin_pass" { sensitive = true }
variable "tfstate_rg" {}
variable "tfstate_sa_name" {}
variable "tfstate_container_name" {}
variable "tfstate_key" {}
variable "sas_token" {}