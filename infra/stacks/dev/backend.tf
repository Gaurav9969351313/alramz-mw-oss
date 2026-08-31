terraform {
  backend "azurerm" {
    resource_group_name  = "alramz-tf-assets-rg"
    storage_account_name = "alramztfstatefiles1994"
    container_name       = "devtfstate"
    key                  = "dev.tfstate"
  }
}