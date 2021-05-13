data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_elb_service_account" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_availability_zone" "all" {
  for_each = toset(data.aws_availability_zones.available.names)
  name = each.key
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
   vpc_id = data.aws_vpc.default.id

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "group-name"
    values = ["default"]
  }
}

data "aws_cloudfront_origin_request_policy" "origin_request_policy" {
  name = "Managed-CORS-S3Origin"
}

data "aws_cloudfront_cache_policy" "cache_policy" {
  name = "Managed-CachingOptimized"
}

data "aws_ami" "ubuntu_2004" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"]
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Variables for user_data templates
# # ---------------------------------------------------------------------------------------------------------------------#
data "template_file" "user_data" {
for_each = var.ec2
template = file("./user_data/${each.key}")

vars = {
  
INSTANCE_NAME = "${each.key}"
AWS_DEFAULT_REGION = "${data.aws_region.current.name}"
GITHUB_REPO_RAW_URL = "https://raw.githubusercontent.com/magenx/Magento-2-aws-cluster-terraform/master"
GITHUB_REPO_API_URL = "https://api.github.com/repos/magenx/Magento-2-aws-cluster-terraform/contents"

ALB_DNS_NAME = "${aws_lb.load_balancer["inner"].dns_name}"
EFS_DNS_TARGET = "${aws_efs_mount_target.efs_mount_target[0].dns_name}"
CODECOMMIT_MAGENTO_REPO_NAME = "${aws_codecommit_repository.codecommit_repository.repository_name}"

EXTRA_PACKAGES_DEB = "curl jq nfs-common gnupg2 apt-transport-https apt-show-versions ca-certificates lsb-release unzip vim wget git patch python3-pip acl attr imagemagick snmp"
PHP_PACKAGES_DEB = "cli fpm json common mysql zip gd mbstring curl xml bcmath intl soap oauth lz4"

PHP_VERSION = "${var.magento["php_version"]}"
PHP_INI = "/etc/php/${var.magento["php_version"]}/fpm/php.ini"
PHP_FPM_POOL = "/etc/php/${var.magento["php_version"]}/fpm/pool.d/www.conf"
PHP_OPCACHE_INI = "/etc/php/${var.magento["php_version"]}/fpm/conf.d/10-opcache.ini"

MAGE_VERSION = "2"
MAGE_DOMAIN = "${var.magento["mage_domain"]}"
MAGE_STAGING_DOMAIN = "${var.magento["mage_staging_domain"]}"
MAGE_OWNER = "${var.magento["mage_owner"]}"
MAGE_PHP_USER = "php-${var.magento["mage_owner"]}"
MAGE_ADMIN_EMAIL = "${var.magento["mage_admin_email"]}"
MAGE_WEB_ROOT_PATH = "/home/${var.magento["mage_owner"]}/public_html"
MAGE_TIMEZONE = "${var.magento["timezone"]}"

 }
}
