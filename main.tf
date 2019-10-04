terraform {
  required_version = ">= 0.12.0"
  required_providers {
    azurerm = ">= 1.32.0"
  }
}

locals {
  default_agent_profile = {
    count               = 1
    vm_size             = "Standard_D2_v3"
    os_type             = "Linux"
    availability_zones  = null
    enable_auto_scaling = false
    min_count           = null
    max_count           = null
    type                = "VirtualMachineScaleSets"
    node_taints         = null
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

  # Determine which load balancer to use
  agent_pool_availability_zones_lb = [for ap in local.agent_pools : ap.availability_zones != null ? "Standard" : ""]
  load_balancer_sku                = coalesce(flatten([local.agent_pool_availability_zones_lb, ["Standard"]])...)

  # Distinct subnets
  agent_pool_subnets = distinct(local.agent_pools.*.vnet_subnet_id)
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
  node_resource_group             = var.node_resource_group

  dynamic "agent_pool_profile" {
    for_each = local.agent_pools
    iterator = ap
    content {
      name                = ap.value.name
      count               = ap.value.count
      vm_size             = ap.value.vm_size
      availability_zones  = ap.value.availability_zones
      enable_auto_scaling = ap.value.enable_auto_scaling
      min_count           = ap.value.min_count
      max_count           = ap.value.max_count
      max_pods            = ap.value.max_pods
      os_disk_size_gb     = ap.value.os_disk_size_gb
      os_type             = ap.value.os_type
      type                = ap.value.type
      vnet_subnet_id      = ap.value.vnet_subnet_id
      node_taints         = ap.value.node_taints
    }
  }

  service_principal {
    client_id     = var.service_principal.client_id
    client_secret = var.service_principal.client_secret
  }

  # TODO Fails if no addon_profile's are defined, creates empty block then
  addon_profile {
    # TODO Enable aci connector when its GA

    dynamic "oms_agent" {
      for_each = var.log_analytics_workspace_id != null ? [true] : []
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

    # Use Standard if availability zones are set, Basic otherwise
    load_balancer_sku = local.load_balancer_sku
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

resource "azurerm_monitor_diagnostic_setting" "aks" {
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

# Assign roles

resource "azurerm_role_assignment" "acr" {
  count                = length(var.container_registries)
  scope                = var.container_registries[count.index]
  role_definition_name = "AcrPull"
  principal_id         = var.service_principal.object_id
}

resource "azurerm_role_assignment" "subnet" {
  count                = length(local.agent_pool_subnets)
  scope                = local.agent_pool_subnets[count.index]
  role_definition_name = "Network Contributor"
  principal_id         = var.service_principal.object_id
}

resource "azurerm_role_assignment" "storage" {
  count                = length(var.storage_contributor)
  scope                = var.storage_contributor[count.index]
  role_definition_name = "Storage Account Contributor"
  principal_id         = var.service_principal.object_id
}

resource "azurerm_role_assignment" "msi" {
  count                = length(var.managed_identities)
  scope                = var.managed_identities[count.index]
  role_definition_name = "Managed Identity Operator"
  principal_id         = var.service_principal.object_id
}

resource "azurerm_role_assignment" "admin" {
  count                = length(var.admins)
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = var.admins[count.index]
}

# Configure cluster

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate)
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

#
# Tiller service account
#

resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }

  automount_service_account_token = true
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "tiller"
    namespace = "kube-system"
  }
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate)
  }

  install_tiller  = "true"
  service_account = "tiller"
  tiller_image    = "gcr.io/kubernetes-helm/tiller:${var.tiller_version}"
}

# Using raw chart to deploy containerlogs, resources to allow Azure to read
# container logs. Could use terraform kubernetes resources but want to initialize
# helm and need to deploy a chart. Can change once Helm v3 is out.

data "helm_repository" "incubator" {
    name = "incubator"
    url  = "https://kubernetes-charts-incubator.storage.googleapis.com"
}

resource "helm_release" "containerlogs" {
    name       = "containerlogs"
    repository = data.helm_repository.incubator.metadata.0.name
    chart      = "raw"
    version    = "0.2.3"

    values = [
      <<VALUES
resources:
- apiVersion: rbac.authorization.k8s.io/v1 
  kind: ClusterRole 
  metadata: 
    name: containerHealth-log-reader 
  rules: 
    - apiGroups: [""] 
      resources: ["pods/log", "events"] 
      verbs: ["get", "list"]  

- apiVersion: rbac.authorization.k8s.io/v1 
  kind: ClusterRoleBinding 
  metadata: 
    name: containerHealth-read-logs-global 
  roleRef: 
      kind: ClusterRole 
      name: containerHealth-log-reader 
      apiGroup: rbac.authorization.k8s.io 
  subjects: 
    - kind: User 
      name: clusterUser 
      apiGroup: rbac.authorization.k8s.io
      VALUES
    ]
}


# resource "kubernetes_cluster_role" "containerlogs" {
#   metadata {
#     name = "containerhealth-log-reader"
#   }

#   rule {
#     api_groups = [""]
#     resources  = ["pods/log"]
#     verbs      = ["get"]
#   }
# }

# resource "kubernetes_cluster_role_binding" "containerlogs" {
#   metadata {
#     name = "containerhealth-read-logs-global"
#   }

#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = kubernetes_cluster_role.containerlogs.metadata.0.name
#   }

#   subject {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "User"
#     name      = "clusterUser"
#   }
# }