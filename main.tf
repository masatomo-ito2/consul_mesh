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


# Set up Vault
module "vault" {
  source = "./vault"

  admin_passwd                                     = var.admin_passwd
  aws_consul_iam_role_arn                          = module.iam.aws_consul_iam_role_arn
  azure_consul_user_assigned_identity_principal_id = module.iam.azure_consul_user_assigned_identity_principal_id
  azure_tenant_id                                  = var.azure_tenant_id
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

  depends_on = [ module.vault ]
}

# Azure

module "azure-consul-secondary" {
  source = "./azure-consul-secondary"

  rg_name                                = data.terraform_remote_state.azure_state.outputs.rg_name
  rg_location                            = data.terraform_remote_state.azure_state.outputs.rg_location
  azure_consul_user_assigned_identity_id = module.iam.azure_consul_user_assigned_identity_id
  # azure_consul_user_assigned_identity_principal_id = module.azure_consul_user_assigned_identity_principal_id
  env               = var.env
  vault_addr        = var.vault_addr
  vault_namespace   = var.vault_namespace
  aws_mgw_public_ip = module.aws-consul-primary.aws_mgw_public_ip
  ssh_public_key    = var.ssh_public_key
  aws_region        = var.region

  depends_on = [module.aws-consul-primary]
}

