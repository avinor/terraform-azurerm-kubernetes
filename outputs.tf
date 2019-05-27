output "rg_name" {
  value = "${local.rg_name}"
}

output "host" {
  value = "${azurerm_kubernetes_cluster.aks.kube_admin_config.0.host}"
}
output "client_certificate" {
  value = "${base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate)}"
  sensitive = true
}

output "client_key" {
  value = "${base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key)}"
  sensitive = true
}

output "cluster_ca_certificate" {
  value = "${base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate)}"
  sensitive = true
}