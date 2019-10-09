output "id" {
  description = "The Kubernetes Managed Cluster ID."
  value       = azurerm_kubernetes_cluster.aks.id
}

output "host" {
  description = "The Kubernetes cluster server host."
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
}

output "service_account_keys" {
  description = "Map of all service accounts created and their keys."
  value       = zipmap(var.service_accounts.*.name, data.kubernetes_secret.sa.*.data)
  sensitive   = true
}
