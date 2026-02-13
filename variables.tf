variable "subscription_id" {
  description = "Deine Azure Subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name der existierenden Resource Group"
  type        = string
}

variable "location" {
  description = "Azure Region (muss Claude Modelle unterstützen, z.B. eastus2, swedencentral)"
  type        = string
  default     = "eastus2" 
}

variable "vm_admin_username" {
  default = "azureuser"
}
