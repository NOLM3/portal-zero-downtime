provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "portal-zero-downtime"
      ManagedBy = "terraform"
    }
  }
}

provider "azurerm" {
  features {}
}
