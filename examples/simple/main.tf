module "simple" {
    source = "../../"

    name = "simple"
    resource_group_name = "simple-aks-rg"
    location = "westeurope"
    service_cidr = "10.241.0.0/24"
    kubernetes_version = "1.13.5"
    
    service_principal = {
        client_id = "00000000-0000-0000-0000-000000000000"
        client_secret = "00000000-0000-0000-0000-000000000000"
    }

    azure_active_directory = {
        client_app_id = "00000000-0000-0000-0000-000000000000"
        server_app_id = "00000000-0000-0000-0000-000000000000"
        server_app_secret = "00000000-0000-0000-0000-000000000000"
    }

    agent_pools = [
        {
            name = "linux"
            vnet_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/virtualNetworks/myvnet1"
        },
    ]
}