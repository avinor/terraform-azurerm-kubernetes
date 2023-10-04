module "upgrade" {
  source = "../../"

  name                    = "upgrade"
  resource_group_name     = "upgrade-aks-rg"
  location                = "westeurope"
  service_cidr            = "10.241.0.0/24"
  kubernetes_version      = "1.18.14"
  node_os_channel_upgrade = "NodeImage"

  agent_pools = [
    {
      name                 = "linux"
      orchestrator_version = "1.18.14"
      vnet_subnet_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/virtualNetworks/myvnet1/subnets/mysub"
    },
  ]
}