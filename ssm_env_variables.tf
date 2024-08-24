


/////////////////////////////////////////////////////////[ SYSTEMS MANAGER ]//////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameter store for aws params
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_parameter" "env" {
  name        = "${local.project}-${local.environment}-env"
  description = "Environment variables for ${local.project} in ${data.aws_region.current.name}"
  type        = "String"
  value       = <<EOF
{
"PROJECT" : "${local.project}",
"DNS" : "${aws_route53_zone.this.name}",
"AWS_DEFAULT_REGION" : "${data.aws_region.current.name}",
"VPC_ID" : "${aws_vpc.this.id}",
"CIDR" : "${aws_vpc.this.cidr_block}",
"SUBNET_ID" : "${values(aws_subnet.this).0.id}",
"EC2_SECURITY_GROUP" : "${aws_security_group.ec2.id}",
"SOURCE_AMI" : "${data.aws_ami.distro.id}",
"EFS_SYSTEM_ID" : "${aws_efs_file_system.this.id}",
"EFS_ACCESS_POINT_VAR" : "${aws_efs_access_point.this["var"].id}",
"EFS_ACCESS_POINT_MEDIA" : "${aws_efs_access_point.this["media"].id}",
"SNS_TOPIC_ARN" : "${aws_sns_topic.default.arn}",
"RABBITMQ_ENDPOINT" : "rabbitmq.${aws_route53_zone.this.name}",
"RABBITMQ_USER" : "${var.magento["brand"]}",
"RABBITMQ_PASSWORD" : "${random_password.this["rabbitmq"].result}",
"OPENSEARCH_ENDPOINT" : "opensearch.${aws_route53_zone.this.name}",
"OPENSEARCH_ADMIN" : "${random_string.this["opensearch"].result}",
"OPENSEARCH_PASSWORD" : "${random_password.this["opensearch"].result}",
"INDEXER_PASSWORD" : "${random_password.this["indexer"].result}",
"REDIS_CACHE_ENDPOINT" : "redis.${aws_route53_zone.this.name}",
"REDIS_SESSION_ENDPOINT" : "redis.${aws_route53_zone.this.name}",
"REDIS_PASSWORD" : "${random_password.this["redis"].result}",
"S3_MEDIA_BUCKET" : "${aws_s3_bucket.this["media"].bucket}",
"S3_MEDIA_BUCKET_URL" : "${aws_s3_bucket.this["media"].bucket_regional_domain_name}",
"ALB_DNS_NAME" : "${aws_lb.this.dns_name}",
"CLOUDFRONT_DOMAIN" : "${aws_cloudfront_distribution.this.domain_name}",
"SES_KEY" : "${aws_iam_access_key.ses_smtp_user_access_key.id}",
"SES_SECRET" : "${aws_iam_access_key.ses_smtp_user_access_key.secret}",
"SES_PASSWORD" : "${aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4}",
"SES_ENDPOINT" : "email-smtp.${data.aws_region.current.name}.amazonaws.com",
"DATABASE_ENDPOINT" : "mariadb.${aws_route53_zone.this.name}",
"DATABASE_NAME" : "${var.magento["brand"]}",
"DATABASE_USER" : "${var.magento["brand"]}",
"DATABASE_PASSWORD" : "${random_password.this["mariadb"].result}",
"DATABASE_ROOT_PASSWORD" : "${random_password.this["mariadb_root"].result}",
"ADMIN_PATH" : "admin_${random_string.this["admin_path"].result}",
"VERSION" : "${var.magento["app_version"]}",
"DOMAIN" : "${var.magento["domain"]}",
"BRAND" : "${var.magento["brand"]}",
"PHP_USER" : "php-${var.magento["brand"]}",
"ADMIN_EMAIL" : "${var.magento["admin_email"]}",
"WEB_ROOT_PATH" : "/home/${var.magento["brand"]}/public_html",
"TIMEZONE" : "${var.magento["timezone"]}",
"SECURITY_HEADER" : "${random_uuid.this.result}",
"HEALTH_CHECK_LOCATION" : "${random_string.this["health_check"].result}",
"MYSQL_PATH" : "mysql_${random_string.this["mysql_path"].result}",
"PROFILER" : "${random_string.this["profiler"].result}",
"RESOLVER" : "${cidrhost(aws_vpc.this.cidr_block, 2)}",
"PHP_VERSION" : "${var.magento["php_version"]}",
"PHP_INI" : "/etc/php/${var.magento["php_version"]}/fpm/php.ini",
"PHP_FPM_POOL" : "/etc/php/${var.magento["php_version"]}/fpm/pool.d/www.conf",
"PHP_OPCACHE_INI" : "/etc/php/${var.magento["php_version"]}/fpm/conf.d/10-opcache.ini",
"HTTP_X_HEADER" : "${random_uuid.this.result}",
"LINUX_PACKAGES" : "${var.magento["linux_packages"]}",
"PHP_PACKAGES" : "${var.magento["php_packages"]}",
"EXCLUDE_LINUX_PACKAGES" : "${var.magento["exclude_linux_packages"]}"
}
EOF

  tags = {
    Name = "${local.project}-${local.environment}-env"
  }
}
