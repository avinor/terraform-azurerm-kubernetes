variables {

  name                = "addons"
  resource_group_name = "addons-aks-rg"
  location            = "westeurope"
  service_cidr        = "10.241.0.0/24"
  kubernetes_version  = "1.27.3"

  agent_pools = [
    {
      name                 = "linux"
      orchestrator_version = "1.27.3"
      vnet_subnet_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/virtualNetworks/myvnet1/subnets/mysub"
    },
  ]

  azure_policy_enabled = false

  key_vault_secrets_provider = {
    enabled                  = true
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }
}

run "simple" {
  command = plan
}