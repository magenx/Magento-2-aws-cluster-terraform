# packer amazon
# pre-build custom ami
# # ---------------------------------------------------------------------------------------------------------------------#
# Set packer amazon plugin version
# # ---------------------------------------------------------------------------------------------------------------------#
packer {
  required_plugins {
    amazon = {
      version = "~> 1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Packer variables from terraform
# # ---------------------------------------------------------------------------------------------------------------------#
variable "IAM_INSTANCE_PROFILE" {}
variable "INSTANCE_NAME" {}
variable "VOLUME_SIZE" {}
variable "PARAMETERSTORE_NAME" {}
# # ---------------------------------------------------------------------------------------------------------------------#
# Get environment variables from SSM ParameterStore
# # ---------------------------------------------------------------------------------------------------------------------#
data "amazon-parameterstore" "env" {
  name = "${var.PARAMETERSTORE_NAME}"
}
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  parameter = "${jsondecode(data.amazon-parameterstore.env.value)}"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create AMI Builder (EBS backed)
# # ---------------------------------------------------------------------------------------------------------------------#
source "amazon-ebs" "latest-ami" {
  ami_name        = "${local.parameter["PROJECT"]}-${var.INSTANCE_NAME}-${local.timestamp}"
  ami_description = "AMI for ${local.parameter["PROJECT"]} ${var.INSTANCE_NAME} - Packer Build ${local.timestamp}"
  region          = "${local.parameter["AWS_DEFAULT_REGION"]}"
  source_ami      = "${local.parameter["SOURCE_AMI"]}"
  iam_instance_profile = "${var.IAM_INSTANCE_PROFILE}"
  subnet_id       = "${local.parameter["SUBNET_ID"]}"
  ssh_username    = "admin"
  temporary_key_pair_type = "ed25519"
  temporary_security_group_source_public_ip = true
  instance_type   = "c7g.large"
  launch_block_device_mappings {
    device_name = "/dev/xvda"
    volume_size = "${var.VOLUME_SIZE}"
    volume_type = "gp3"
    delete_on_termination = true
    encrypted   = true
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }
  snapshot_tags = {
    Name = "${local.parameter["PROJECT"]}-${var.INSTANCE_NAME}-${local.timestamp}"
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
      "PARAMETERSTORE=${var.PARAMETERSTORE_NAME}"
    ]
    execute_command  = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
 }
  
  post-processor "manifest" {
        output = "./manifest_for_${var.INSTANCE_NAME}.json"
        strip_path = true
        custom_data = {
          timestamp = "${local.timestamp}"
        }
    }
  
}
