variable "name" {
  description = "Name of the Kubernetes cluster."
}

variable "resource_group_name" {
  description = "Name of resource group to deploy resources in."
}

variable "location" {
  description = "The Azure Region in which to create resource."
}

variable "service_cidr" {
  description = "Cidr of service subnet. If subnet has UDR make sure this is routed correctly."
}

variable "kubernetes_version" {
  description = "Version of Kubernetes to deploy."
}

variable "node_resource_group" {
  description = "The name of the Resource Group where the Kubernetes Nodes should exist."
  default     = null
}

variable "agent_pools" {
  description = "A list of agent pools to create, each item supports same properties as `agent_pool_profile`."
  type        = list(any)
}

variable "service_principal" {
  description = "Service principal to connect to cluster."
  type        = object({ client_id = string, client_secret = string })
}

variable "azure_active_directory" {
  description = "Azure AD configuration for enabling rbac."
  type        = object({ client_app_id = string, server_app_id = string, server_app_secret = string })
}

variable "api_server_authorized_ip_ranges" {
  description = "The IP ranges to whitelist for incoming traffic to the masters."
  type        = list(string)
  default     = null
}

variable "linux_profile" {
  description = "Username and ssh key for accessing Linux machines with ssh."
  type        = object({ username = string, ssh_key = string })
  default     = null
}

variable "read_only_dashboard" {
  description = "Kubernetes dashboard does not support rbac. This will create a dashboard that is read-only."
  type        = bool
  default     = false
}

variable "admins" {
  description = "List of Azure AD object ids that should have access to get admin credentials."
  type        = list(string)
  default     = []
}

variable "container_registries" {
  description = "List of Azure Container Registry ids where AKS needs pull access."
  type        = list(string)
  default     = []
}

variable "storage_contributor" {
  description = "List of storage account ids where the AKS service principal should have access."
  type        = list(string)
  default     = []
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
