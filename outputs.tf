output "id" {
  description = "The Kubernetes Managed Cluster ID."
  value       = azurerm_kubernetes_cluster.aks.id
}

output "host" {
  description = "The Kubernetes cluster server host."
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
  sensitive   = true
}

output "identity" {
  description = "The AKs managed identity Object(principal) ID."
  value       = azurerm_user_assigned_identity.msi.principal_id
}