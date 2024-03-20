module "workload-identity" {
  source = "../../"

  name                      = "workload-identity"
  resource_group_name       = "workload-identity-aks-rg"
  location                  = "westeurope"
  service_cidr              = "10.241.0.0/24"
  kubernetes_version        = "1.27.3"
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  agent_pools = [
    {
      name                 = "linux"
      orchestrator_version = "1.27.3"
      vnet_subnet_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/virtualNetworks/myvnet1/subnets/mysub"
    },
  ]
}