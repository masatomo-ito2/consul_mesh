# Vault
provider "vault" {}

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
  provider = aws.aws
  source   = "./iam"

  vpc_id   = data.terraform_remote_state.aws_state.outputs.vpc_id_japan
  region   = var.region
  env      = var.env
  location = data.terraform_remote_state.azure_state.outputs.rg_location
  rg_name  = data.terraform_remote_state.azure_state.outputs.rg_name

}

# Master tokens
resource "random_uuid" "master_token" {}
resource "random_uuid" "replication_token" {}
resource "random_string" "gossip_key" {
  length = 32
}

# Put secrets into vault
resource "vault_generic_secret" "consul" {
  path = "kv/consul"

  data_json = <<EOT
{
  "master_token": ${random_uuid.master_token.result},
	"replication_token": ${random_uuid.replication_token},
	"gossip_key": ${base64encode(random_string.gossip_key.result)}
}
EOT
}

# AWS
module "aws-consul-primary" {
  provider = aws.aws
  source   = "./aws-consul-primary"

  vpc_id                               = data.terraform_remote_state.aws_state.outputs.vpc_id_japan
  ssh_key_name                         = var.ssh_key_name
  public_subnets_id                    = data.terraform_remote_state.aws_state.outputs.public_subnets_japan
  region                               = var.region
  aws_consul_iam_instance_profile_name = module.iam.aws_consul_iam_instance_profile_name
  env                                  = var.env

  # consul stuff
  #master_token      = random_uuid.master_token.result
  #replication_token = random_uuid.replication_token
  #gossip_key        = base64encode(random_string.gossip_key.result)

  depends_on = [vault_generic_secret.consul]
}

# Azure

