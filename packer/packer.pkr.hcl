# packer amazon
# pre-build custom ami
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
# Packer variables from terraform
# # ---------------------------------------------------------------------------------------------------------------------#
variable "IAM_INSTANCE_PROFILE" {}
variable "INSTANCE_NAME" {}
variable "PARAMETERSTORE_NAME" {}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get environment variables from SSM ParameterStore
# # ---------------------------------------------------------------------------------------------------------------------#
data "amazon-parameterstore" "env" {
  name = "${var.PARAMETERSTORE_NAME}"
}
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  var = "${jsondecode(data.amazon-parameterstore.env.value)}"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create AMI Builder (EBS backed)
# # ---------------------------------------------------------------------------------------------------------------------#
source "amazon-ebs" "latest-ami" {
  ami_name        = "${local.var["PROJECT"]}-${var.INSTANCE_NAME}-${local.timestamp}"
  ami_description = "AMI for ${local.var["PROJECT"]} ${var.INSTANCE_NAME} - Packer Build ${local.timestamp}"
  region          = "${local.var["AWS_DEFAULT_REGION"]}"
  source_ami      = "${local.var["SOURCE_AMI"]}"
  iam_instance_profile = "${var.IAM_INSTANCE_PROFILE}"
  security_group_id = "${local.var["SECURITY_GROUP"]}"
  subnet_id       = "${local.var["SUBNET_ID"]}"
  ssh_username    = "admin"
  instance_type   = "c6g.large"
  launch_block_device_mappings {
    device_name = "/dev/xvda"
    volume_size = "${local.var["VOLUME_SIZE"]}"
    volume_type = "gp3"
    delete_on_termination = true
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }
  snapshot_tags = {
    Name = "${local.var["PROJECT"]}-${var.INSTANCE_NAME}-${local.timestamp}"
  }
}

build {
  name    = "latest-ami"
  sources = [
    "source.amazon-ebs.latest-ami"
  ]

  provisioner "shell" {
    script = "./build.sh"
    pause_before = "10s"
    timeout      = "60s"
    environment_vars = [
"INSTANCE_NAME=${var.INSTANCE_NAME}",
"CIDR=${local.var["CIDR"]}",
"RESOLVER=${local.var["RESOLVER"]}",
"AWS_DEFAULT_REGION=${local.var["AWS_DEFAULT_REGION"]}",
"ALB_DNS_NAME=${local.var["ALB_DNS_NAME"]}",
"EFS_DNS_TARGET=${local.var["EFS_DNS_TARGET"]}",
"DATABASE_ENDPOINT=${local.var["DATABASE_ENDPOINT"]}",
"SNS_TOPIC_ARN=${local.var["SNS_TOPIC_ARN"]}",
"CODECOMMIT_APP_REPO=${local.var["CODECOMMIT_APP_REPO"]}",
"CODECOMMIT_SERVICES_REPO=${local.var["CODECOMMIT_SERVICES_REPO"]}",
"LINUX_PACKAGES=${local.var["LINUX_PACKAGES"]}",
"PHP_PACKAGES=${local.var["PHP_PACKAGES"]}",
"EXCLUDE_LINUX_PACKAGES=${local.var["EXCLUDE_LINUX_PACKAGES"]}",
"PHP_VERSION=${local.var["PHP_VERSION"]}",
"PHP_INI=${local.var["PHP_INI"]}",
"PHP_FPM_POOL=${local.var["PHP_FPM_POOL"]}",
"PHP_OPCACHE_INI=${local.var["PHP_OPCACHE_INI"]}",
"VERSION=${local.var["VERSION"]}",
"DOMAIN=${local.var["DOMAIN"]}",
"BRAND=${local.var["BRAND"]}",
"PHP_USER=${local.var["PHP_USER"]}",
"ADMIN_EMAIL=${local.var["ADMIN_EMAIL"]}",
"WEB_ROOT_PATH=${local.var["WEB_ROOT_PATH"]}",
"TIMEZONE=${local.var["TIMEZONE"]}",
"MAGENX_HEADER=${local.var["MAGENX_HEADER"]}",
"HEALTH_CHECK_LOCATION=${local.var["HEALTH_CHECK_LOCATION"]}",
"MYSQL_PATH=${local.var["MYSQL_PATH"]}",
"PROFILER=${local.var["PROFILER"]}",
"BLOWFISH=${local.var["BLOWFISH"]}"
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
