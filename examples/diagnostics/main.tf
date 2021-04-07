module "diagnostics" {
  source = "../../"

  name                = "diagnostics"
  resource_group_name = "diagnostics-aks-rg"
  location            = "westeurope"
  service_cidr        = "10.241.0.0/24"
  kubernetes_version  = "1.18.14"

  service_principal = {
    object_id     = "00000000-0000-0000-0000-000000000000"
    client_id     = "00000000-0000-0000-0000-000000000000"
    client_secret = "00000000-0000-0000-0000-000000000000"
  }

  azure_active_directory = {
    client_app_id     = "00000000-0000-0000-0000-000000000000"
    server_app_id     = "00000000-0000-0000-0000-000000000000"
    server_app_secret = "00000000-0000-0000-0000-000000000000"
  }

  agent_pools = [
    {
      name                 = "linux"
      orchestrator_version = "1.18.14"
      vnet_subnet_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/virtualNetworks/myvnet1"
    },
  ]

  diagnostics = {
    destination   = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-rg/providers/Microsoft.OperationalInsights/workspaces/my-log-analytics"
    eventhub_name = null
    logs          = ["kube-audit-admin", "guard"]
    metrics       = ["all"]
  }

}