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
    runner-aksmgmt-prod = {
      service_account_name      = "ipt-workload-identity-sa"
      service_account_namespace = "runners-ipt"
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
    condition     = azurerm_user_assigned_identity.identity["runner-aksmgmt-prod"].name == "msi-runner-aksmgmt-prod"
    error_message = "Identity name did not match expected"
  }

  assert {
    condition     = azurerm_user_assigned_identity.identity["runner-aksmgmt-prod"].location == "westeurope"
    error_message = "Identity location did not match expected"
  }

  assert {
    condition     = azurerm_user_assigned_identity.identity["runner-aksmgmt-prod"].resource_group_name == "workload-identity-aks-rg"
    error_message = "Identity resource group name did not match expected"
  }

  assert {
    condition     = azurerm_user_assigned_identity.identity["runner-aksmgmt-prod"].tags == null
    error_message = "Identity tags did not match expected"
  }

  assert {
    condition     = azurerm_federated_identity_credential.identity["runner-aksmgmt-prod"].name == "fic-runner-aksmgmt-prod"
    error_message = "Identity credentials name did not match expected"
  }

  assert {
    condition     = azurerm_federated_identity_credential.identity["runner-aksmgmt-prod"].audience[0] == "api://AzureADTokenExchange"
    error_message = "Identity credentials name did not match expected"
  }

  assert {
    condition     = azurerm_federated_identity_credential.identity["runner-aksmgmt-prod"].subject == "system:serviceaccount:runners-ipt:ipt-workload-identity-sa"
    error_message = "Identity credentials name did not match expected"
  }

  assert {
    condition     = azurerm_role_assignment.identity["runner-aksmgmt-prod.k8s_contributor"].role_definition_name == "Contributor"
    error_message = "Identity credentials name did not match expected"
  }

  assert {
    condition     = azurerm_role_assignment.identity["runner-aksmgmt-prod.k8s_contributor"].scope == "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-k8s-cluster"
    error_message = "Identity credentials name did not match expected"
  }

  assert {
    condition     = azurerm_role_assignment.identity["runner-aksmgmt-prod.k8s_contributor"].scope == "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-k8s-cluster"
    error_message = "Identity credentials name did not match expected"
  }

}