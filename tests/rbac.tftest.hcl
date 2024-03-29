variables {

  name                = "rbac"
  resource_group_name = "rbac-aks-rg"
  location            = "norwayeast"
  service_cidr        = "10.241.0.0/24"
  kubernetes_version  = "1.27.3"
  azure_rbac_enabled  = true

  agent_pools = [
    {
      name                 = "linux"
      orchestrator_version = "1.27.3"
      vnet_subnet_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/virtualNetworks/myvnet1/subnets/mysub"
    },
  ]

  cluster_admins = [
    "12345678-1234-1234-1234-123456789012",
  ]

  cluster_users = [
    {
      principal_id = "12345678-1234-1234-1234-123456789013"
      namespace    = "my-namespace"
    },
    {
      principal_id = "12345678-1234-1234-1234-123456789014"
      namespace    = "your-namespace"
    },
  ]
}

run "simple" {
  command = plan
}