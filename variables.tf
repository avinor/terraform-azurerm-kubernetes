variable "name" {
  description = "Name of the Kubernetes cluster."
}

variable "resource_group_name" {
  description = "Name of resource group to deploy resources in."
}

variable "location" {
  description = "The Azure Region in which to create resource."
}

variable "subnet_id" {
  description = "Id of subnet where kubernetes cluster should be deployed."
}

variable "agent_pools" {
  description = "A list of agent pools to create."
  type = list(any)
  default = []
}

variable "service_cidr" {
  description = "Cidr of service subnet, should be in range 10.241.0.0/16 or network routing will fail."
}

variable "group_admins" {
  description = "List of Azure AD group object ids that should have admin access."
  type = list(string)
  default = []
}

variable "user_admins" {
  description = "List of Azure AD user object ids that should have admin access."
  type = list(string)
  default = []
}

variable "log_analytics_workspace_id" {
  description = "Specifies the ID of a Log Analytics Workspace where Diagnostics Data should be sent."
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources created."
  type        = map(string)
  default     = {}
}
