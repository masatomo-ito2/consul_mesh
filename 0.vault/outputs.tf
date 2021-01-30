output "master_token" {
  value = random_uuid.master_token.result
}

output "admin_passwd" {
  value = var.admin_passwd
}

output "approle_path" {
  value = vault_auth_backend.approle.path
}

output "azure_path" {
  value = vault_auth_backend.azure.path
}
