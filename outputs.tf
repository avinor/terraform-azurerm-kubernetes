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
}

# output "client_certificate" {
#   description = "Base64 encoded public certificate used by clients to authenticate to the Kubernetes cluster."
#   value       = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate)
#   sensitive   = true
# }

# output "client_key" {
#   description = "Base64 encoded private key used by clients to authenticate to the Kubernetes cluster."
#   value       = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key)
#   sensitive   = true
# }

# output "cluster_ca_certificate" {
#   description = "Base64 encoded public CA certificate used as the root of trust for the Kubernetes cluster."
#   value       = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate)
#   sensitive   = true
# }

# output "kube_config_admin" {
#   description = "Raw kubeconfig output for admin account."
#   value       = azurerm_kubernetes_cluster.aks.kube_admin_config_raw
#   sensitive   = true
# }