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
  alias  = "useast1"
  region = "us-east-1"
  default_tags {
   tags = {
   Managed      = "terraform"
   Config       = var.app["brand"]
   Environment  = local.environment
  }
 }
}
provider "null" {}
provider "random" {}
provider "template" {}
provider "external" {}

