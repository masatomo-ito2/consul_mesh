# Userpass
resource "vault_generic_endpoint" "admin" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/admin"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["admin"],
  "password": "${var.admin_passwd}"
}
EOT
}

# AppRole for Consul
resource "vault_approle_auth_backend_role" "consul" {
  backend        = vault_auth_backend.approle.path
  role_name      = "consul"
  token_policies = ["default", "consul", "admin"]
}

# Secret ID for consul server
resource "vault_approle_auth_backend_role_secret_id" "consul" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.consul.role_name
}

# Secret ID for mgw
resource "vault_approle_auth_backend_role_secret_id" "mgw" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.consul.role_name
}
