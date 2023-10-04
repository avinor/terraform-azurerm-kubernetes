module "diagnostics" {
  source = "../../"

  name                    = "diagnostics"
  resource_group_name     = "diagnostics-aks-rg"
  location                = "westeurope"
  service_cidr            = "10.241.0.0/24"
  kubernetes_version      = "1.27.3"

  agent_pools = [
    {
      name                 = "linux"
      orchestrator_version = "1.27.3"
      vnet_subnet_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/virtualNetworks/myvnet1/subnets/mysub"
    },
  ]

  diagnostics = {
    destination = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-rg/providers/Microsoft.OperationalInsights/workspaces/my-log-analytics"
    logs        = ["kube-audit-admin", "guard"]
    metrics     = ["all"]
  }

}