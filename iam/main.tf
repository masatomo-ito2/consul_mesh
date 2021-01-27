provider "aws" {
  region = var.region
}

provider "azurerm" {
  features {}
}

data "azurerm_subscription" "primary" {}
