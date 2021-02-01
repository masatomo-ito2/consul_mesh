# Azure auth
resource "vault_azure_auth_backend_config" "azure_config" {
  backend   = var.azure_path
  tenant_id = var.azure_tenant_id
  resource  = "https://management.azure.com/"
}

resource "vault_azure_auth_backend_role" "azure_role" {
  backend                     = var.azure_path
  role                        = "consul"
  bound_service_principal_ids = [var.azure_consul_user_assigned_identity_principal_id]
  token_ttl                   = 3600
  token_max_ttl               = 36000
  token_policies              = ["default", "admin", "consul"]
}

