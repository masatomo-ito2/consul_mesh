resource "vault_auth_backend" "userpass" {
  type = "userpass"
}

resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_auth_backend" "aws" {
  type = "aws"
}

resource "vault_auth_backend" "azure" {
  type = "azure"
}

# AWS auth

/*
resource "vault_aws_auth_backend_role" "consul" {
  backend                  = vault_auth_backend.aws.path
  role                     = "consul"
  auth_type                = "iam"
  token_policies           = ["default", "admin", "consul"]
  bound_iam_principal_arns = [var.aws_consul_iam_role_arn]
}
*/
