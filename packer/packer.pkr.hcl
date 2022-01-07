# packer amazon
# pre-build custom ami from debian 11 arm
# # ---------------------------------------------------------------------------------------------------------------------#
# Packer variables
# # ---------------------------------------------------------------------------------------------------------------------#
variable "IAM_INSTANCE_PROFILE" {}
variable "SUBNET_ID" {}
variable "SECURITY_GROUP" {}
variable "VOLUME_SIZE" {}
variable "VPC_ID" {}
variable "SOURCE_AMI" {}
variable "INSTANCE_NAME" {}
variable "CIDR" {}
variable "RESOLVER" {}
variable "AWS_DEFAULT_REGION" {}
variable "ALB_DNS_NAME" {}
variable "EFS_DNS_TARGET" {}
variable "PRODUCTION_DATABASE_ENDPOINT" {}
variable "STAGING_DATABASE_ENDPOINT" {}
variable "SNS_TOPIC_ARN" {}
variable "CODECOMMIT_APP_REPO" {}
variable "CODECOMMIT_SERVICES_REPO" {}
variable "EXTRA_PACKAGES_DEB" {}
variable "PHP_PACKAGES_DEB" {}
variable "EXCLUDE_PACKAGES_DEB" {}
variable "PHP_VERSION" {}
variable "PHP_INI" {}
variable "PHP_FPM_POOL" {}
variable "PHP_OPCACHE_INI" {}
variable "VERSION" {}
variable "DOMAIN" {}
variable "STAGING_DOMAIN" {}
variable "BRAND" {}
variable "PHP_USER" {}
variable "ADMIN_EMAIL" {}
variable "WEB_ROOT_PATH" {}
variable "TIMEZONE" {}
variable "MAGENX_HEADER" {}
variable "HEALTH_CHECK_LOCATION" {}
variable "MYSQL_PATH" {}
variable "PROFILER" {}
variable "BLOWFISH" {}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create packer timestamp variable
# # ---------------------------------------------------------------------------------------------------------------------#
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Set packer amazon plugin version
# # ---------------------------------------------------------------------------------------------------------------------#
packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create AMI Builder (EBS backed)
# # ---------------------------------------------------------------------------------------------------------------------#
source "amazon-ebs" "latest-ami" {
  ami_name        = "${var.BRAND}-${var.INSTANCE_NAME}-${var.AWS_DEFAULT_REGION}-${local.timestamp}"
  ami_description = "AMI for ${var.BRAND} ${var.INSTANCE_NAME} - Packer Build ${local.timestamp}"
  region          = "${var.AWS_DEFAULT_REGION}"
  source_ami      = "${var.SOURCE_AMI}"
  iam_instance_profile = "${var.IAM_INSTANCE_PROFILE}"
  security_group_id = "${var.SECURITY_GROUP}"
  subnet_id       = "${var.SUBNET_ID}"
  ssh_username    = "admin"
  instance_type   = "c6g.large"
  launch_block_device_mappings {
    device_name = "/dev/xvda"
    volume_size = "${var.VOLUME_SIZE}"
    volume_type = "gp3"
    delete_on_termination = true
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }
  snapshot_tags = {
    Name = "${var.BRAND}-${var.INSTANCE_NAME}-${var.AWS_DEFAULT_REGION}-${local.timestamp}"
  }
}

build {
  name    = "latest-ami"
  sources = [
    "source.amazon-ebs.latest-ami"
  ]

  provisioner "shell" {
    script = "./build.sh"
    pause_before = "30s"
    timeout      = "60s"
    environment_vars = [
"INSTANCE_NAME=${var.INSTANCE_NAME}",
"CIDR=${var.CIDR}",
"RESOLVER=${var.RESOLVER}",
"AWS_DEFAULT_REGION=${var.AWS_DEFAULT_REGION}",
"ALB_DNS_NAME=${var.ALB_DNS_NAME}",
"EFS_DNS_TARGET=${var.EFS_DNS_TARGET}",
"PRODUCTION_DATABASE_ENDPOINT=${var.PRODUCTION_DATABASE_ENDPOINT}",
"STAGING_DATABASE_ENDPOINT=${var.STAGING_DATABASE_ENDPOINT}",
"SNS_TOPIC_ARN=${var.SNS_TOPIC_ARN}",
"CODECOMMIT_APP_REPO=${var.CODECOMMIT_APP_REPO}",
"CODECOMMIT_SERVICES_REPO=${var.CODECOMMIT_SERVICES_REPO}",
"EXTRA_PACKAGES_DEB=${var.EXTRA_PACKAGES_DEB}",
"PHP_PACKAGES_DEB=${var.PHP_PACKAGES_DEB}",
"EXCLUDE_PACKAGES_DEB=${var.EXCLUDE_PACKAGES_DEB}",
"PHP_VERSION=${var.PHP_VERSION}",
"PHP_INI=${var.PHP_INI}",
"PHP_FPM_POOL=${var.PHP_FPM_POOL}",
"PHP_OPCACHE_INI=${var.PHP_OPCACHE_INI}",
"VERSION=${var.VERSION}",
"DOMAIN=${var.DOMAIN}",
"STAGING_DOMAIN=${var.STAGING_DOMAIN}",
"BRAND=${var.BRAND}",
"PHP_USER=${var.PHP_USER}",
"ADMIN_EMAIL=${var.ADMIN_EMAIL}",
"WEB_ROOT_PATH=${var.WEB_ROOT_PATH}",
"TIMEZONE=${var.TIMEZONE}",
"MAGENX_HEADER=${var.MAGENX_HEADER}",
"HEALTH_CHECK_LOCATION=${var.HEALTH_CHECK_LOCATION}",
"MYSQL_PATH=${var.MYSQL_PATH}",
"PROFILER=${var.PROFILER}",
"BLOWFISH=${var.BLOWFISH}"
]
 }
  
  post-processor "manifest" {
        output = "./manifest_for_${var.INSTANCE_NAME}.json"
        strip_path = true
        custom_data = {
          timestamp = "${local.timestamp}"
        }
    }
  
}
