terraform {
  required_version = ">= 1.1.9"
  required_providers {
    azurerm = {
      version = "=3.51.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "terraform-tfstate"
    storage_account_name = "" // FIXME
    container_name       = "tfstate"
    key                  = "tfstate"
  }
}
