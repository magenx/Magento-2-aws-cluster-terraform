
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
}


provider "aws" {
default_tags {
   tags = {
   Managed      = "Terraform"
   Config       = var.magento["brand"]
   Environment  = local.environment
  }
}
}
provider "null" {}
provider "random" {}
provider "template" {}
provider "external" {}
