# AppRole for Consul
resource "vault_approle_auth_backend_role" "consul" {
  backend        = var.approle_path
  role_name      = "consul"
  token_policies = ["default", "consul", "admin"]
}

# Secret ID for consul server
resource "vault_approle_auth_backend_role_secret_id" "consul" {
  backend   = var.approle_path
  role_name = vault_approle_auth_backend_role.consul.role_name
}

# Secret ID for mgw
resource "vault_approle_auth_backend_role_secret_id" "mgw" {
  backend   = var.approle_path
  role_name = vault_approle_auth_backend_role.consul.role_name
}
