variable "name" {
  description = "Name of the virtual network."
  type        = string
}

variable "location" {
  description = "Location for the virtual network."
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
}

variable "subnet_count" {
  description = "Number of subnets to create in the virtual network."
  type        = number
}