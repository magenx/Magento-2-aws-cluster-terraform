


//////////////////////////////////////////////////////[ PACKER BUILDER ]//////////////////////////////////////////////////


# # ---------------------------------------------------------------------------------------------------------------------#
# Create custom AMI with Packer Builder
# # ---------------------------------------------------------------------------------------------------------------------#
resource "null_resource" "packer" {
  for_each = var.ec2
  provisioner "local-exec" {
    working_dir = "${abspath(path.root)}/packer"
    command = <<EOF
/usr/bin/packer init -force ${abspath(path.root)}/packer/packer.pkr.hcl
PACKER_LOG=1 PACKER_LOG_PATH="packerlog" /usr/bin/packer build \
-var INSTANCE_NAME=${each.key} \
-var IAM_INSTANCE_PROFILE=${aws_iam_instance_profile.ec2[each.key].name} \
-var PARAMETERSTORE_NAME=${aws_ssm_parameter.env.name} \
packer.pkr.hcl
EOF
  }
 triggers = {
    ami_creation_date = data.aws_ami.distro.creation_date
    build_script      = filesha256("${abspath(path.root)}/packer/build.sh")
  }
}
