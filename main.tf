terraform {
  backend "azurerm" {}
  required_version = ">= 0.12.0"
  required_providers {
    azurerm = ">= 1.29.0"
  }
}

locals {
  default_agent_profile = {
    count   = 1
    vm_size = "Standard_D4_v3"
    os_type = "Linux"
    type    = "VirtualMachineScaleSets"
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

  agent_pools_with_defaults = [for ap in var.agent_pools :
    merge(local.default_agent_profile, ap)
  ]
  agent_pools = [for ap in local.agent_pools_with_defaults :
    ap.os_type == "Linux" ? merge(local.default_linux_node_profile, ap) : merge(local.default_windows_node_profile, ap)
  ]
}

resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                            = "${var.name}-aks"
  location                        = azurerm_resource_group.aks.location
  resource_group_name             = azurerm_resource_group.aks.name
  dns_prefix                      = var.name
  kubernetes_version              = var.kubernetes_version
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges

  dynamic "agent_pool_profile" {
    for_each = local.agent_pools
    iterator = ap
    content {
      name            = ap.value.name
      count           = ap.value.count
      vm_size         = ap.value.vm_size
      max_pods        = ap.value.max_pods
      os_disk_size_gb = ap.value.os_disk_size_gb
      os_type         = ap.value.os_type
      type            = ap.value.type
      vnet_subnet_id  = ap.value.vnet_subnet_id
    }
  }

  service_principal {
    client_id     = var.service_principal.client_id
    client_secret = var.service_principal.client_secret
  }

  addon_profile {
    # TODO Enable aci connector when its GA

    dynamic "oms_agent" {
      for_each = var.log_analytics_workspace_id ? [true] : []
      content {
        enabled                    = true
        log_analytics_workspace_id = var.log_analytics_workspace_id
      }
    }
  }

  dynamic "linux_profile" {
    for_each = var.linux_profile != null ? [true] : []
    iterator = lp
    content {
      admin_username = var.linux_profile.username

      ssh_key {
        key_data = var.linux_profile.ssh_key
      }
    }
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    dns_service_ip     = cidrhost(var.service_cidr, 10)
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr       = var.service_cidr
  }

  role_based_access_control {
    enabled = true

    azure_active_directory {
      client_app_id     = var.azure_active_directory.client_app_id
      server_app_id     = var.azure_active_directory.server_app_id
      server_app_secret = var.azure_active_directory.server_app_secret
    }
  }

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "public" {
  count                      = var.log_analytics_workspace_id != null ? 1 : 0
  name                       = "aks-log-analytics"
  target_resource_id         = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  log {
    category = "kube-apiserver"

    retention_policy {
      enabled = false
    }
  }

  log {
    category = "kube-controller-manager"

    retention_policy {
      enabled = false
    }
  }

  log {
    category = "cluster-autoscaler"

    retention_policy {
      enabled = false
    }
  }

  log {
    category = "kube-scheduler"

    retention_policy {
      enabled = false
    }
  }

  log {
    category = "kube-audit"

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate)
}

# AD user/group for AKS admins

resource "kubernetes_cluster_role_binding" "group" {
  count = length(var.group_admins)

  metadata {
    name = "azuread-admin-${var.group_admins[count.index]}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = var.group_admins[count.index]
  }
}

resource "kubernetes_cluster_role_binding" "user" {
  count = length(var.user_admins)

  metadata {
    name = "azuread-admin-${var.user_admins[count.index]}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = var.user_admins[count.index]
  }
}

# Dashboard doesn't use rbac, so give it only reader access
# Does not have access to read secrets

resource "kubernetes_cluster_role" "dashboardviewonly" {
  count = var.read_only_dashboard ? 1 : 0

  metadata {
    name = "dashboard-viewonly"
  }

  rule {
    api_groups = [""]
    resources = [
      "configmaps",
      "endpoints",
      "persistentvolumeclaims",
      "pods",
      "replicationcontrollers",
      "replicationcontrollers/scale",
      "serviceaccounts",
      "services",
      "nodes",
      "persistentvolumeclaims",
      "persistentvolumes",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = [""]
    resources = [
      "bindings",
      "events",
      "limitranges",
      "namespaces/status",
      "pods/log",
      "pods/status",
      "replicationcontrollers/status",
      "resourcequotas",
      "resourcequotas/status",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = [""]
    resources = [
      "namespaces",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = ["apps"]
    resources = [
      "daemonsets",
      "deployments",
      "deployments/scale",
      "replicasets",
      "replicasets/scale",
      "statefulsets",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = ["autoscaling"]
    resources = [
      "horizontalpodautoscalers",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = ["batch"]
    resources = [
      "cronjobs",
      "jobs",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = ["extensions"]
    resources = [
      "daemonsets",
      "deployments",
      "deployments/scale",
      "ingresses",
      "networkpolicies",
      "replicasets",
      "replicasets/scale",
      "replicationcontrollers/scale",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = ["policy"]
    resources = [
      "poddisruptionbudgets",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources = [
      "networkpolicies",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources = [
      "storageclasses",
      "volumeattachments",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources = [
      "clusterrolebindings",
      "clusterroles",
      "roles",
      "rolebindings",
    ]
    verbs = [
      "get",
      "list",
      "watch",
    ]
  }
}

resource "kubernetes_cluster_role_binding" "dashboardviewonly" {
  count = var.read_only_dashboard ? 1 : 0

  metadata {
    name = "kubernetes-dashboard"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.dashboardviewonly[0].metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "kubernetes-dashboard"
    namespace = "kube-system"
  }
}

# Give access for Azure to read container logs

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
