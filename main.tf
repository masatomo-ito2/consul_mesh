# Remote state for AWS VPC
data "terraform_remote_state" "aws_state" {
  backend = "remote"

  config = {
    organization = var.tfc_org
    workspaces = {
      name = var.tfc_aws_ws
    }
  }
}

# Remote state for Azure RG
data "terraform_remote_state" "azure_state" {
  backend = "remote"

  config = {
    organization = var.tfc_org
    workspaces = {
      name = var.tfc_azure_ws
    }
  }
}

# IAM
module "iam" {
  source = "./iam"

  vpc_id               = data.terraform_remote_state.aws_state.outputs.vpc_id_japan
  region               = var.region
  env                  = var.env
  location             = data.terraform_remote_state.azure_state.outputs.rg_location
  rg_name              = data.terraform_remote_state.azure_state.outputs.rg_name
  aws_vault_account_id = var.aws_vault_account_id
}

# Master tokens
resource "random_uuid" "master_token" {}
resource "random_uuid" "replication_token" {}
resource "random_string" "gossip_key" {
  length = 32
}

# Set up Vault
module "vault" {
  source = "./vault"

  admin_passwd            = var.admin_passwd
  aws_consul_iam_role_arn = module.iam.aws_consul_iam_role_arn
}

# Put secrets into vault
resource "vault_generic_secret" "consul" {
  depends_on = [module.vault]
  path       = "kv/consul"

  data_json = <<EOT
{
  "master_token": "${random_uuid.master_token.result}",
	"replication_token": "${random_uuid.replication_token.result}",
	"gossip_key": "${base64encode(random_string.gossip_key.result)}"
}
EOT
}


# AWS
module "aws-consul-primary" {
  source = "./aws-consul-primary"

  vpc_id                               = data.terraform_remote_state.aws_state.outputs.vpc_id_japan
  ssh_key_name                         = var.ssh_key_name
  public_subnets_id                    = data.terraform_remote_state.aws_state.outputs.public_subnets_japan
  region                               = var.region
  aws_consul_iam_instance_profile_name = module.iam.aws_consul_iam_instance_profile_name
  env                                  = var.env
  vault_addr                           = var.vault_addr
  vault_namespace                      = var.vault_namespace
  admin_passwd                         = var.admin_passwd
  role_id                              = module.vault.aws_consul_role_id
  secret_id                            = module.vault.aws_consul_secret_id
  mgw_secret_id                        = module.vault.aws_mgw_secret_id

  # consul stuff
  #master_token      = random_uuid.master_token.result
  #replication_token = random_uuid.replication_token
  #gossip_key        = base64encode(random_string.gossip_key.result)

  depends_on = [vault_generic_secret.consul]
}

# Azure

/*
module "azure-consul-secondary" {
  source = "./azure-consul-secondary"

  depends_on = [module.aws-consul-primary]
}
*/

