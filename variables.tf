variable "resource_group_name" {
  type    = string
  default = "rg-monitoring"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "user_assigned_identity_name" {
  type    = string
  default = "mi-monitoring-001"
}

variable "log_analytics_workspace_name" {
  type    = string
  default = "law-monitoring-001"
}

variable "log_analytics_workspace_retention_in_days" {
  type    = number
  default = 90
}

variable "virtual_network_name" {
  type    = string
  default = "vnet-monitoring"
}

variable "subnet_name" {
  type    = string
  default = "subnet-monitoring-001"
}

variable "username" {
  type    = string
  default = "adminuser"
}

variable "password" {
  type    = string
  default = "P@ssw0rd1234!"
}

variable "list_zones" {
  type    = list(string)
  default = ["privatelink.monitor.azure.com", "privatelink.oms.opinsights.azure.com", "privatelink.ods.opinsights.azure.com", "privatelink.agentsvc.azure-automation.net", "privatelink.blob.core.windows.net"]
}

variable "dns_resource_group_name" {
  type    = string
  default = "private-dns-zones-rg"
}