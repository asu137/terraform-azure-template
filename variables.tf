variable "region" {
  default = "japaneast"
}

variable "ip_whitelist" {
  description = "A list of CIDRs that will be allowed to access the instances"
  type        = list(string)
  default     = []
}

variable "resource_group_name" {
  type        = string
  default     = "FIXME"
}

variable "resource_name_prefix" {
  description = "In the case of 「〇〇」, it becomes 「〇〇-<resource name>」or 「〇〇<resource name>」"
  type        = string
  default     = ""
}

variable "vnet_address_range_prefix" {
  type        = string
  default     = "10.10."
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
}

variable "linux_user" {
  type        = string
  default     = "azureuser"
}
