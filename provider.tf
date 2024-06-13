
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
  }
}


provider "aws" {
default_tags {
   tags = {
   Managed      = "terraform"
   Config       = "magenx"
   Environment  = "development"
  }
 }
}

provider "null" {}
provider "random" {}

