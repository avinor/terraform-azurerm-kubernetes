terraform {
  required_version = ">= 1.3"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.96.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  default_agent_profile = {
    count                = 1
    vm_size              = "Standard_D2_v3"
    os_type              = "Linux"
    availability_zones   = null
    enable_auto_scaling  = false
    min_count            = null
    max_count            = null
    type                 = "VirtualMachineScaleSets"
    node_taints          = null
    orchestrator_version = null
  }

  # Defaults for Linux profile
  # Generally smaller images so can run more pods and require smaller HD
  default_linux_node_profile = {
    max_pods        = 30
    os_disk_size_gb = 60
  }

  # Defaults for Windows profile
  # Do not want to run same number of pods and some images can be quite large
  default_windows_node_profile = {
    max_pods        = 20
    os_disk_size_gb = 200
  }

  agent_pools_with_defaults = [
    for ap in var.agent_pools :
    merge(local.default_agent_profile, ap)
  ]
  agent_pools = {
    for ap in local.agent_pools_with_defaults :
    ap.name => ap.os_type == "Linux" ? merge(local.default_linux_node_profile, ap) : merge(local.default_windows_node_profile, ap)
  }
  default_pool = var.agent_pools[0].name

  # Determine which load balancer to use
  agent_pool_availability_zones_lb = [for ap in local.agent_pools : ap.availability_zones != null ? "standard" : ""]
  load_balancer_sku                = coalesce(flatten([local.agent_pool_availability_zones_lb, ["standard"]])...)

  # Distinct subnets
  agent_pool_subnets = distinct([for ap in local.agent_pools : ap.vnet_subnet_id])

  diag_resource_list = var.diagnostics != null ? split("/", var.diagnostics.destination) : []
  parsed_diag = var.diagnostics != null ? {
    log_analytics_id   = contains(local.diag_resource_list, "Microsoft.OperationalInsights") ? var.diagnostics.destination : null
    storage_account_id = contains(local.diag_resource_list, "Microsoft.Storage") ? var.diagnostics.destination : null
    event_hub_auth_id  = contains(local.diag_resource_list, "Microsoft.EventHub") ? var.diagnostics.destination : null
    metric             = var.diagnostics.metrics
    log                = var.diagnostics.logs
    } : {
    log_analytics_id   = null
    storage_account_id = null
    event_hub_auth_id  = null
    metric             = []
    log                = []
  }

  workload_identities_flat = flatten([
    for k, v in var.workload_identities : [
      for assignment, role in v.role_assignments : {
        identity   = k
        scope      = role.scope
        name       = role.name
        assignment = assignment
      }
    ]
  ])
}

resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_user_assigned_identity" "msi" {
  location            = var.location
  name                = format("%s-msi", var.name)
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                              = "${var.name}-aks"
  location                          = azurerm_resource_group.aks.location
  resource_group_name               = azurerm_resource_group.aks.name
  dns_prefix                        = var.name
  kubernetes_version                = var.kubernetes_version
  node_resource_group               = var.node_resource_group
  azure_policy_enabled              = var.azure_policy_enabled
  node_os_channel_upgrade           = var.node_os_channel_upgrade
  automatic_channel_upgrade         = var.automatic_channel_upgrade
  role_based_access_control_enabled = true
  workload_identity_enabled         = var.workload_identity_enabled
  tags                              = var.tags

  dynamic "maintenance_window_node_os" {
    for_each = var.maintenance_window_node_os != null ? [1] : []
    content {
      frequency   = var.maintenance_window_node_os.frequency
      interval    = var.maintenance_window_node_os.interval
      duration    = var.maintenance_window_node_os.duration
      day_of_week = var.maintenance_window_node_os.day_of_week
      start_time  = var.maintenance_window_node_os.start_time
    }
  }

  dynamic "default_node_pool" {
    for_each = { for k, v in local.agent_pools : k => v if k == local.default_pool }
    iterator = ap
    content {
      name                 = ap.value.name
      node_count           = ap.value.count
      vm_size              = ap.value.vm_size
      zones                = ap.value.availability_zones
      enable_auto_scaling  = ap.value.enable_auto_scaling
      min_count            = ap.value.min_count
      max_count            = ap.value.max_count
      max_pods             = ap.value.max_pods
      os_disk_size_gb      = ap.value.os_disk_size_gb
      type                 = ap.value.type
      vnet_subnet_id       = ap.value.vnet_subnet_id
      node_taints          = ap.value.node_taints
      orchestrator_version = ap.value.orchestrator_version
    }
  }

  dynamic "key_vault_secrets_provider" {
    for_each = var.key_vault_secrets_provider.enabled ? [true] : []
    content {
      secret_rotation_enabled  = var.key_vault_secrets_provider.secret_rotation_enabled
      secret_rotation_interval = var.key_vault_secrets_provider.secret_rotation_interval
    }
  }

  dynamic "oms_agent" {
    for_each = var.oms_agent_log_analytics_workspace_id != null ? [true] : []
    content {
      log_analytics_workspace_id = var.oms_agent_log_analytics_workspace_id
    }
  }

  dynamic "linux_profile" {
    for_each = var.linux_profile != null ? [true] : []
    content {
      admin_username = var.linux_profile.username

      ssh_key {
        key_data = var.linux_profile.ssh_key
      }
    }
  }

  dynamic "windows_profile" {
    for_each = var.windows_profile != null ? [true] : []
    content {
      admin_username = var.windows_profile.username
      admin_password = var.windows_profile.password
    }
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    dns_service_ip = cidrhost(var.service_cidr, 10)
    service_cidr   = var.service_cidr

    # Use Standard if availability zones are set, Basic otherwise
    load_balancer_sku = local.load_balancer_sku
  }

  azure_active_directory_role_based_access_control {
    managed                = true
    admin_group_object_ids = var.cluster_admins
    azure_rbac_enabled     = var.azure_rbac_enabled
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.msi.id]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "aks" {
  for_each = { for k, v in local.agent_pools : k => v if k != local.default_pool }

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = each.value.vm_size
  zones                 = each.value.availability_zones
  enable_auto_scaling   = each.value.enable_auto_scaling
  node_count            = each.value.count
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  max_pods              = each.value.max_pods
  os_disk_size_gb       = each.value.os_disk_size_gb
  os_type               = each.value.os_type
  vnet_subnet_id        = each.value.vnet_subnet_id
  node_taints           = each.value.node_taints
  orchestrator_version  = each.value.orchestrator_version

  tags = var.tags
}

data "azurerm_monitor_diagnostic_categories" "default" {
  resource_id = azurerm_kubernetes_cluster.aks.id
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  count = var.diagnostics != null ? 1 : 0

  name                           = "${var.name}-aks-diag"
  target_resource_id             = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id     = local.parsed_diag.log_analytics_id
  eventhub_authorization_rule_id = local.parsed_diag.event_hub_auth_id
  eventhub_name                  = local.parsed_diag.event_hub_auth_id != null ? var.diagnostics.eventhub_name : null
  storage_account_id             = local.parsed_diag.storage_account_id

  dynamic "enabled_log" {
    for_each = {
      for k, v in data.azurerm_monitor_diagnostic_categories.default.log_category_types : k => v
      if contains(local.parsed_diag.log, "all") || contains(local.parsed_diag.log, v)
    }
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.default.metrics
    content {
      category = metric.value
      enabled  = contains(local.parsed_diag.metric, "all") || contains(local.parsed_diag.metric, metric.value)
    }
  }
}

# Assign roles

# https://learn.microsoft.com/en-us/azure/aks/manage-azure-rbac
resource "azurerm_role_assignment" "users" {
  for_each = { for u in var.cluster_users : format("%s-%s", u.principal_id, u.namespace) => u }

  principal_id         = each.value.principal_id
  scope                = format("%s/namespaces/%s", azurerm_kubernetes_cluster.aks.id, each.value.namespace)
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
}

resource "azurerm_role_assignment" "acr" {
  count = length(var.container_registries)

  scope                = var.container_registries[count.index]
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.msi.principal_id
}

resource "azurerm_role_assignment" "subnet" {
  count = length(local.agent_pool_subnets)

  scope                = local.agent_pool_subnets[count.index]
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.msi.principal_id
}

resource "azurerm_role_assignment" "storage" {
  count = length(var.storage_contributor)

  scope                = var.storage_contributor[count.index]
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_user_assigned_identity.msi.principal_id
}

resource "azurerm_role_assignment" "msi" {
  count = length(var.managed_identities)

  scope                = var.managed_identities[count.index]
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.msi.principal_id
}

resource "azurerm_user_assigned_identity" "identity" {
  for_each = var.workload_identities

  name                = format("msi-%s", each.key)
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "identity" {
  for_each = var.workload_identities

  name                = format("fic-%s", each.key)
  resource_group_name = azurerm_resource_group.aks.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.identity[each.key].id
  subject             = format("system:serviceaccount:%s:%s", each.value.service_account_namespace, each.value.service_account_name)
}

resource "azurerm_role_assignment" "identity" {
  for_each = {
    for k in local.workload_identities_flat : "${k.identity}.${k.assignment}" => k
  }

  principal_id         = azurerm_user_assigned_identity.identity[each.value.identity].principal_id
  scope                = each.value.scope
  role_definition_name = each.value.name
}

# Configure cluster

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate)
}

#
# Impersonation of admins
#

resource "kubernetes_cluster_role" "impersonator" {
  metadata {
    name = "impersonator"
  }

  rule {
    api_groups = [""]
    resources  = ["users", "groups", "serviceaccounts"]
    verbs      = ["impersonate"]
  }
}

resource "kubernetes_cluster_role_binding" "impersonator" {
  count = length(var.admins)

  metadata {
    name = "${var.admins[count.index].name}-administrator"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.impersonator.metadata.0.name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = var.admins[count.index].kind
    name      = var.admins[count.index].name
  }
}

#
# Container logs for Azure
#

resource "kubernetes_cluster_role" "containerlogs" {
  metadata {
    name = "containerhealth-log-reader"
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "containerlogs" {
  metadata {
    name = "containerhealth-read-logs-global"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.containerlogs.metadata.0.name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = "clusterUser"
  }
}

#
# Service accounts
#

resource "kubernetes_service_account" "sa" {
  count = length(var.service_accounts)

  metadata {
    name      = var.service_accounts[count.index].name
    namespace = var.service_accounts[count.index].namespace
  }

  automount_service_account_token = true
}

resource "kubernetes_cluster_role_binding" "sa" {
  count = length(var.service_accounts)

  metadata {
    name = var.service_accounts[count.index].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = var.service_accounts[count.index].role
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.service_accounts[count.index].name
    namespace = var.service_accounts[count.index].namespace
  }
}
