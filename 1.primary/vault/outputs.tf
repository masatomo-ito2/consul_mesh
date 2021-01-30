output "aws_consul_role_id" {
  value = vault_approle_auth_backend_role.consul.role_id
}

output "aws_consul_secret_id" {
  value = vault_approle_auth_backend_role_secret_id.consul.secret_id
}

output "aws_mgw_secret_id" {
  value = vault_approle_auth_backend_role_secret_id.mgw.secret_id
}
