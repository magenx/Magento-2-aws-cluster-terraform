


//////////////////////////////////////////////////////[ PACKER BUILDER ]//////////////////////////////////////////////////


# # ---------------------------------------------------------------------------------------------------------------------#
# Create IP address for Packer Builder instance
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_eip" "packer" {
  vpc  = true
  tags = {
    Name = "${var.app["brand"]}-packer-builder-address"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create custom AMI with Packer Builder
# # ---------------------------------------------------------------------------------------------------------------------#
resource "null_resource" "packer" {
  for_each = var.ec2
  provisioner "local-exec" {
    working_dir = "${abspath(path.root)}/packer"
    command = <<EOF
/usr/bin/packer build \
-var VPC_ID=${aws_vpc.this.id} \
-var EIP_ALLOCATION_ID=${aws_eip.packer.allocation_id} \
-var SOURCE_AMI=${data.aws_ami.distro.id} \
-var VOLUME_SIZE=${var.app["volume_size"]} \
-var INSTANCE_NAME=${each.key} \
-var IAM_INSTANCE_PROFILE=${aws_iam_instance_profile.ec2[each.key].name} \
-var SUBNET_ID=${values(aws_subnet.this).0.id} \
-var SECURITY_GROUP=${aws_security_group.ec2.id} \
-var CIDR=${aws_vpc.this.cidr_block} \
-var RESOLVER=${cidrhost(aws_vpc.this.cidr_block, 2)} \
-var AWS_DEFAULT_REGION=${data.aws_region.current.name} \
-var ALB_DNS_NAME=${aws_lb.this.dns_name} \
-var EFS_DNS_TARGET=${values(aws_efs_mount_target.this).0.dns_name} \
-var DATABASE_ENDPOINT=${aws_db_instance.this.endpoint} \
-var SNS_TOPIC_ARN=${aws_sns_topic.default.arn} \
-var CODECOMMIT_APP_REPO=codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name} \
-var CODECOMMIT_SERVICES_REPO=codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} \
-var VERSION=2 \
-var DOMAIN=${var.app["domain"]} \
-var STAGING_DOMAIN=${var.app["staging_domain"]} \
-var BRAND=${var.app["brand"]} \
-var PHP_USER=php-${var.app["brand"]} \
-var ADMIN_EMAIL=${var.app["admin_email"]} \
-var WEB_ROOT_PATH="/home/${var.app["brand"]}/public_html" \
-var TIMEZONE=${var.app["timezone"]} \
-var MAGENX_HEADER=${random_uuid.this.result} \
-var HEALTH_CHECK_LOCATION=${random_string.this["health_check"].result} \
-var MYSQL_PATH=mysql_${random_string.this["mysql_path"].result} \
-var PROFILER=${random_string.this["profiler"].result} \
-var BLOWFISH=${random_password.this["blowfish"].result} \
-var EXTRA_PACKAGES_DEB="nfs-common unzip git patch python3-pip acl attr imagemagick snmp" \
-var PHP_PACKAGES_DEB="cli fpm json common mysql zip gd mbstring curl xml bcmath intl soap oauth lz4 apcu" \
-var EXCLUDE_PACKAGES_DEB="apache2* *apcu-bc" \
-var PHP_VERSION=${var.app["php_version"]} \
-var PHP_INI="/etc/php/${var.app["php_version"]}/fpm/php.ini" \
-var PHP_FPM_POOL="/etc/php/${var.app["php_version"]}/fpm/pool.d/www.conf" \
-var PHP_OPCACHE_INI="/etc/php/${var.app["php_version"]}/fpm/conf.d/10-opcache.ini" \
packer.pkr.hcl
EOF
  }
 triggers = {
    ami_creation_date = data.aws_ami.distro.creation_date
    build_script      = filesha256("${abspath(path.root)}/packer/build.sh")
  }
}
