terraform {
  required_version = ">= 0.12.0"
  required_providers {
    azurerm = "~> 1.35.0"
    kubernetes = "~> 1.9.0"
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
  enable_pod_security_policy      = var.enable_pod_security_policy

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

data "kubernetes_secret" "sa" {
  count = length(var.service_accounts)

  metadata {
    name      = kubernetes_service_account.sa[count.index].default_secret_name
    namespace = var.service_accounts[count.index].namespace
  }
}

#
# Tiller service account
#

# resource "kubernetes_service_account" "tiller" {
#   metadata {
#     name      = "tiller"
#     namespace = "kube-system"
#   }

#   automount_service_account_token = true
# }

# resource "kubernetes_cluster_role_binding" "tiller" {
#   metadata {
#     name = "tiller"
#   }

#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = "cluster-admin"
#   }

#   subject {
#     kind      = "ServiceAccount"
#     name      = "tiller"
#     namespace = "kube-system"
#   }
# }

module "tiller" {
  source  = "iplabs/tiller/kubernetes"
  version = "3.2.0"
}

# provider "helm" {
#   kubernetes {
#     host                   = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
#     client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate)
#     client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key)
#     cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate)
#   }

#   install_tiller  = "true"
#   service_account = "tiller"
#   tiller_image    = "gcr.io/kubernetes-helm/tiller:${var.tiller_version}"
# }

# Using raw chart to deploy containerlogs, resources to allow Azure to read
# container logs. Could use terraform kubernetes resources but want to initialize
# helm and need to deploy a chart. Can change once Helm v3 is out.

# Using the resource and not data to make sure it runs in correct stage of CI pipeline
# resource "helm_repository" "incubator" {
#   name = "incubator"
#   url  = "https://kubernetes-charts-incubator.storage.googleapis.com"
# }

# resource "helm_release" "containerlogs" {
#   name       = "containerlogs"
#   repository = helm_repository.incubator.metadata.0.name
#   chart      = "raw"
#   version    = "0.2.3"

#   values = [
#     <<VALUES
# resources:
# - apiVersion: rbac.authorization.k8s.io/v1 
#   kind: ClusterRole 
#   metadata: 
#     name: containerHealth-log-reader 
#   rules: 
#     - apiGroups: [""] 
#       resources: ["pods/log", "events"] 
#       verbs: ["get", "list"]  

# - apiVersion: rbac.authorization.k8s.io/v1 
#   kind: ClusterRoleBinding 
#   metadata: 
#     name: containerHealth-read-logs-global 
#   roleRef: 
#       kind: ClusterRole 
#       name: containerHealth-log-reader 
#       apiGroup: rbac.authorization.k8s.io 
#   subjects: 
#     - kind: User 
#       name: clusterUser 
#       apiGroup: rbac.authorization.k8s.io
#       VALUES
#   ]
# }
