# Remote state for AWS primary datacenter
data "terraform_remote_state" "primary" {
  backend = "remote"

  config = {
    organization = var.tfc_org
    workspaces = {
      name = var.primary_ws
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

# Azure

module "azure-consul-secondary" {
  source = "./azure-consul-secondary"

  rg_name                                = data.terraform_remote_state.azure_state.outputs.rg_name
  rg_location                            = data.terraform_remote_state.azure_state.outputs.rg_location
  azure_consul_user_assigned_identity_id = data.terraform_remote_state.primary.outputs.azure_consul_user_assigned_identity_id
  env                                    = data.terraform_remote_state.primary.outputs.env
  vault_addr                             = data.terraform_remote_state.primary.outputs.vault_addr
  vault_namespace                        = data.terraform_remote_state.primary.outputs.vault_namespace
  aws_mgw_public_ip                      = data.terraform_remote_state.primary.outputs.aws_mgw_public_ip
  aws_region                             = data.terraform_remote_state.primary.outputs.region
  ssh_public_key                         = var.ssh_public_key
}

