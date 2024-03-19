variables {

  name                = "workload-identity"
  resource_group_name = "workload-identity-aks-rg"
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

  workload_identities = {
    identity_name = {
      service_account_name      = "identity-sa"
      service_account_namespace = "identity-namespace"
      role_assignments = {
        acr_pull = {
          scope = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/my-rg/providers/Microsoft.ContainerRegistry/registries/myregistry"
          name  = "AcrPull"
        },
        k8s_contributor = {
          scope = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-k8s-cluster"
          name  = "Contributor"
        }
      }
    }
  }
}

run "workload-identities" {

  command = plan

  assert {
    condition     = length(azurerm_user_assigned_identity.identity) == 1
    error_message = "Identities did not match expected length"
  }

  assert {
    condition     = azurerm_user_assigned_identity.identity["identity_name"].name == "msi-identity_name"
    error_message = "Identity name did not match expected"
  }

  assert {
    condition     = azurerm_user_assigned_identity.identity["identity_name"].location == "westeurope"
    error_message = "Identity location did not match expected"
  }

  assert {
    condition     = azurerm_user_assigned_identity.identity["identity_name"].resource_group_name == "workload-identity-aks-rg"
    error_message = "Identity resource group name did not match expected"
  }

  assert {
    condition     = azurerm_user_assigned_identity.identity["identity_name"].tags == null
    error_message = "Identity tags did not match expected"
  }

  assert {
    condition     = azurerm_federated_identity_credential.identity["identity_name"].name == "fic-identity_name"
    error_message = "Identity credentials name did not match expected"
  }

  assert {
    condition     = azurerm_federated_identity_credential.identity["identity_name"].audience[0] == "api://AzureADTokenExchange"
    error_message = "Identity credentials name did not match expected"
  }

  assert {
    condition     = azurerm_federated_identity_credential.identity["identity_name"].subject == "system:serviceaccount:identity-namespace:identity-sa"
    error_message = "Identity credentials name did not match expected"
  }

  assert {
    condition     = azurerm_role_assignment.identity["identity_name.k8s_contributor"].role_definition_name == "Contributor"
    error_message = "Identity credentials name did not match expected"
  }

  assert {
    condition     = azurerm_role_assignment.identity["identity_name.k8s_contributor"].scope == "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-k8s-cluster"
    error_message = "Identity credentials name did not match expected"
  }

  assert {
    condition     = azurerm_role_assignment.identity["identity_name.k8s_contributor"].scope == "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-k8s-cluster"
    error_message = "Identity credentials name did not match expected"
  }

}