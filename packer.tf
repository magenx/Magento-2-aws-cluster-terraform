


//////////////////////////////////////////////////////[ PACKER BUILDER ]//////////////////////////////////////////////////


# # ---------------------------------------------------------------------------------------------------------------------#
# Create custom AMI with Packer Builder
# # ---------------------------------------------------------------------------------------------------------------------#
resource "null_resource" "packer" {
  for_each = var.ec2
  provisioner "local-exec" {
    working_dir = "${abspath(path.root)}/packer"
    command = <<END
/usr/bin/packer init -force ${abspath(path.root)}/packer/packer.pkr.hcl
PACKER_LOG=1 PACKER_LOG_PATH="packer-${each.key}.log" /usr/bin/packer build \
-var INSTANCE_NAME=${each.key} \
-var SERVICE_ID=${aws_service_discovery_service.this[each.key].id} \
-var VOLUME_SIZE=${each.value.volume_size} \
-var MARIADB_DATA_VOLUME=${aws_ebs_volume.mariadb_data.id} \
-var IAM_INSTANCE_PROFILE=${aws_iam_instance_profile.ec2[each.key].name} \
-var AWS_ENVIRONMENT=${aws_ssm_parameter.aws_env.name} \
packer.pkr.hcl
END
  }
 triggers = {
    ami_creation_date = data.aws_ami.distro.creation_date
    build_script      = filesha256("${abspath(path.root)}/packer/build.sh")
  }
}
