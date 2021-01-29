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

# Azure auth

/*
 vault write auth/azure/role/consul \
  policies=consul,admin ttl=30m \
  bound_service_principal_ids="${AZURE_CONSUL_SERVICE_PRINCIPAL_ID}"
*/

resource "vault_azure_auth_backend_role" "azure_role" {
  backend                     = vault_auth_backend.azure.path
  role                        = "consul"
  bound_service_principal_ids = [ var.azure_consul_user_assigned_identity_principal_id ]
  token_ttl                   = 3600
  token_max_ttl               = 36000
  token_policies              = ["default", "admin", "consul"]
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
