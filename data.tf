# # ---------------------------------------------------------------------------------------------------------------------#
# Get the name of the region where the Terraform deployment is running
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_region" "current" {}

# # ---------------------------------------------------------------------------------------------------------------------#
# Get the effective Account ID, User ID, and ARN in which Terraform is authorized.
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_caller_identity" "current" {}

# # ---------------------------------------------------------------------------------------------------------------------#
# Get the Account ID of the AWS ELB Service Account for the purpose of permitting in S3 bucket policy.
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_elb_service_account" "current" {}

# # ---------------------------------------------------------------------------------------------------------------------#
# Get AWS Inspector rules available in this region
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_inspector_rules_packages" "available" {}

# # ---------------------------------------------------------------------------------------------------------------------#
# Get default tags aws provider
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_default_tags" "this" {}

# # ---------------------------------------------------------------------------------------------------------------------#
# Get the list of AWS Availability Zones available in this region
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_availability_zones" "available" {
  state = "available"
  exclude_zone_ids = ["use1-az3"]
}

data "aws_availability_zone" "all" {
  for_each = toset(data.aws_availability_zones.available.names)
  name = each.key
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get the ID of default VPC
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_vpc" "default" {
  default = true
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get default subnets from AZ in this region/vpc
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_subnets" "default" {
   filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
   }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get all available VPC in this region
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_vpcs" "available" {}

data "aws_vpc" "all" {
  for_each = toset(data.aws_vpcs.available.ids)
  id = each.key
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get the ID of default Security Group
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "group-name"
    values = ["default"]
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get the ID of CloudFront origin request policy
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_cloudfront_origin_request_policy" "media" {
  name = "Managed-CORS-S3Origin"
}
data "aws_cloudfront_origin_request_policy" "static" {
  name = "Managed-CORS-CustomOrigin"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get the ID of CloudFront cache policy.
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_cloudfront_cache_policy" "media" {
  name = "Managed-CachingOptimized"
}
data "aws_cloudfront_cache_policy" "static" {
  name = "UseOriginCacheControlHeaders"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get get the latest ID of a registered AMI linux distro by owner and version
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_ami" "distro" {
  most_recent = true
  #owners      = ["099720109477"] # ubuntu
  owners      = ["136693071363"] # debian

  filter {
    name   = "name"
    values = ["debian-12-arm64*"] # debian
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get AMI image_id generated from manifest with external data script
# # ---------------------------------------------------------------------------------------------------------------------#
data "external" "packer" {
   depends_on = [null_resource.packer]
   for_each = var.ec2
   program = ["/bin/bash", "${abspath(path.root)}/packer/ami_id.sh"] 
   query = {
    INSTANCE_NAME = each.key
  }
 }
# # ---------------------------------------------------------------------------------------------------------------------#
#  Get IP address where Packer Builder is running to add to EC2 security group to allow ssh access
# # ---------------------------------------------------------------------------------------------------------------------#
data "http" "packer" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}
