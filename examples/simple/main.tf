module "simple" {
  source = "../../"

  name                    = "simple"
  resource_group_name     = "simple-aks-rg"
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
}