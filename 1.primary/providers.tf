provider "vault" {
	namespace = "admin/consul_mesh"
}

provider "aws" {
  region = var.region
}

provider "azurerm" {
  features {}
}

