provider "vault" {}
provider "aws" {
  alias  = "aws"
  region = var.region
}
provider "azurerm" {
  alias = "azurerm"
  features {}
}

