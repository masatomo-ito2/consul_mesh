resource "vault_auth_backend" "userpass" {
  type = "userpass"
}

resource "vault_auth_backend" "aws" {
  type = "aws"
}

resource "vault_auth_backend" "azure" {
  type = "azure"
}
