terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.88.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
    archive = {
      source = "hashicorp/archive"
      version = "2.7.0"
  }
 }
}

provider "aws" {
  default_tags {
   tags = local.default_tags
 }
}
provider "aws" {
  alias  = "useast1"
  region = "us-east-1"
  default_tags {
   tags = local.default_tags
 }
}
provider "null" {}
provider "random" {}
provider "archive" {}
