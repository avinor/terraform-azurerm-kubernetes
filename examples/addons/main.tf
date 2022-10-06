module "addon" {
  source = "../../"

  name                = "addons"
  resource_group_name = "addons-aks-rg"
  location            = "westeurope"
  service_cidr        = "10.241.0.0/24"
  kubernetes_version  = "1.23.8"

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

  azure_policy_enabled = false

  key_vault_secrets_provider = {
    enabled                  = true
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

}