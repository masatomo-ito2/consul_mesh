provider "vault" {}

provider "aws" {
  alias  = "aws"
  region = var.region
  features {}
}

provider "azurerm" {
  alias = "azurerm"
  features {}
}

