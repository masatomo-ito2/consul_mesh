# Remote state for Vault WS
data "terraform_remote_state" "vault_state" {
  backend = "remote"

  config = {
    organization = var.tfc_org
    workspaces = {
      name = var.tfc_vault_ws
    }
  }
}

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

  vpc_id   = data.terraform_remote_state.aws_state.outputs.vpc_id_japan
  region   = var.region
  env      = var.env
  location = data.terraform_remote_state.azure_state.outputs.rg_location
  rg_name  = data.terraform_remote_state.azure_state.outputs.rg_name
}


# Set up Vault
module "vault" {
  source = "./vault"

  aws_consul_iam_role_arn                          = module.iam.aws_consul_iam_role_arn
  azure_consul_user_assigned_identity_principal_id = module.iam.azure_consul_user_assigned_identity_principal_id
  azure_tenant_id                                  = var.azure_tenant_id
  approle_path                                     = data.terraform_remote_state.vault_state.outputs.approle_path
  azure_path                                       = data.terraform_remote_state.vault_state.outputs.azure_path

  depends_on = [module.iam]
}

# AWS
module "aws-consul-primary" {
  source = "./aws-consul-primary"

  vpc_id                               = data.terraform_remote_state.aws_state.outputs.vpc_id_japan
  ssh_key_name                         = var.ssh_key_name
  public_subnets_id                    = data.terraform_remote_state.aws_state.outputs.public_subnets_japan
  region                               = var.region
  azure_region                         = data.terraform_remote_state.azure_state.outputs.rg_location
  aws_consul_iam_instance_profile_name = module.iam.aws_consul_iam_instance_profile_name
  env                                  = var.env
  vault_addr                           = var.vault_addr
  vault_namespace                      = var.vault_namespace
  admin_passwd                         = data.terraform_remote_state.vault_state.outputs.admin_passwd

  role_id       = module.vault.aws_consul_role_id
  secret_id     = module.vault.aws_consul_secret_id
  mgw_secret_id = module.vault.aws_mgw_secret_id


  depends_on = [module.vault]
}

