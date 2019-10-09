output "id" {
  description = "The Kubernetes Managed Cluster ID."
  value       = azurerm_kubernetes_cluster.aks.id
}

output "host" {
  description = "The Kubernetes cluster server host."
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
}
