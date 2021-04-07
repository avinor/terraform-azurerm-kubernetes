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
  description = "A list of agent pools to create, each item supports same properties as `agent_pool_profile`. See README for default values."
  type        = list(any)
}

variable "service_principal" {
  description = "Service principal to connect to cluster."
  type = object({
    object_id     = string
    client_id     = string
    client_secret = string
  })
}

variable "azure_active_directory" {
  description = "Azure AD configuration for enabling rbac."
  type = object({
    client_app_id     = string
    server_app_id     = string
    server_app_secret = string
  })
}

variable "api_server_authorized_ip_ranges" {
  description = "The IP ranges to whitelist for incoming traffic to the masters."
  type        = list(string)
  default     = null
}

variable "linux_profile" {
  description = "Username and ssh key for accessing Linux machines with ssh."
  type = object({
    username = string
    ssh_key  = string
  })
  default = null
}

variable "windows_profile" {
  description = "Admin username and password for Windows hosts."
  type = object({
    username = string
    password = string
  })
  default = null
}

variable "admins" {
  description = "List of Azure AD object ids that should be able to impersonate admin user."
  type = list(object({
    kind = string
    name = string
  }))
  default = []
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

variable "managed_identities" {
  description = "List of managed identities where the AKS service principal should have access."
  type        = list(string)
  default     = []
}

variable "service_accounts" {
  description = "List of service accounts to create and their roles."
  type = list(object({
    name      = string
    namespace = string
    role      = string
  }))
  default = []
}

variable "enable_pod_security_policy" {
  description = "Whether Pod Security Policies are enabled. Note that this also requires role based access control to be enabled."
  type        = bool
  default     = true
}

variable "diagnostics" {
  description = "Diagnostic settings for those resources that support it. See README.md for details on configuration."
  type = object({
    destination   = string
    eventhub_name = string
    logs          = list(string)
    metrics       = list(string)
  })
  default = null
}

variable "addons" {
  description = "Addons to enable / disable."
  type = object({
    dashboard              = bool
    oms_agent              = bool
    oms_agent_workspace_id = string
    policy                 = bool
  })
  default = {
    dashboard              = false
    oms_agent              = false
    oms_agent_workspace_id = null
    policy                 = true
  }
}

variable "tags" {
  description = "Tags to apply to all resources created."
  type        = map(string)
  default     = {}
}
