variable "tfc_org" {
  default = "masa_org"
}

variable "tfc_aws_ws" {
  default = "aws_masa_vpc"
}

variable "tfc_azure_ws" {
  default = "azure_resourcegroup"
}

variable "region" {
  default = "ap-northeast-1"
}

variable "env" {
  default = "demo"
}

variable "ssh_key_name" {
  default = "masa"
}

variable "vault_addr" {
  default = "https://vault-cluster.vault.11eaf0ae-df46-699b-81b5-0242ac110015.aws.hashicorp.cloud:8200"
}
