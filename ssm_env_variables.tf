


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
"AWS_DEFAULT_REGION" : "${data.aws_region.current.name}",
"VPC_ID" : "${aws_vpc.this.id}",
"CIDR" : "${aws_vpc.this.cidr_block}",
"SUBNET_ID" : "${values(aws_subnet.this).0.id}",
"SECURITY_GROUP" : "${aws_security_group.ec2.id}",
"SOURCE_AMI" : "${data.aws_ami.distro.id}",
"VOLUME_SIZE" : "${var.app["volume_size"]}",
"EFS_SYSTEM_ID" : "${aws_efs_file_system.this.id}",
"EFS_ACCESS_POINT_VAR" : "${aws_efs_access_point.this["var"].id}",
"EFS_ACCESS_POINT_MEDIA" : "${aws_efs_access_point.this["media"].id}",
"SNS_TOPIC_ARN" : "${aws_sns_topic.default.arn}",
"CODECOMMIT_APP_REPO" : "codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name}",
"CODECOMMIT_SERVICES_REPO" : "codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name}",
"RABBITMQ_ENDPOINT" : "${trimsuffix(trimprefix("${aws_mq_broker.this.instances.0.endpoints.0}", "amqps://"), ":5671")}",
"RABBITMQ_USER" : "${var.app["brand"]}",
"RABBITMQ_PASSWORD" : "${random_password.this["rabbitmq"].result}",
"OPENSEARCH_ENDPOINT" : "https://${aws_opensearch_domain.this.endpoint}:443",
"OPENSEARCH_ADMIN" : "${random_string.this["opensearch"].result}",
"OPENSEARCH_PASSWORD" : "${random_password.this["opensearch"].result}",
"REDIS_CACHE_BACKEND" : "${aws_elasticache_replication_group.this["cache"].primary_endpoint_address}",
"REDIS_SESSION_BACKEND" : "${aws_elasticache_replication_group.this["session"].primary_endpoint_address}",
"REDIS_CACHE_BACKEND_RO" : "${aws_elasticache_replication_group.this["cache"].reader_endpoint_address}",
"REDIS_SESSION_BACKEND_RO" : "${aws_elasticache_replication_group.this["session"].reader_endpoint_address}",
"REDIS_PASSWORD" : "${random_password.this["redis"].result}",
"S3_MEDIA_BUCKET" : "${aws_s3_bucket.this["media"].bucket}",
"S3_MEDIA_BUCKET_URL" : "${aws_s3_bucket.this["media"].bucket_regional_domain_name}",
"EXTERNAL_ALB_DNS_NAME" : "${aws_lb.this["external"].dns_name}",
"INTERNAL_ALB_DNS_NAME" : "${aws_lb.this["internal"].dns_name}",
"CLOUDFRONT_DOMAIN" : "${aws_cloudfront_distribution.this.domain_name}",
"SES_KEY" : "${aws_iam_access_key.ses_smtp_user_access_key.id}",
"SES_SECRET" : "${aws_iam_access_key.ses_smtp_user_access_key.secret}",
"SES_PASSWORD" : "${aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4}",
"SES_ENDPOINT" : "email-smtp.${data.aws_region.current.name}.amazonaws.com",
"DATABASE_ENDPOINT" : "${aws_db_instance.this.endpoint}",
"DATABASE_NAME" : "${aws_db_instance.this.identifier}",
"DATABASE_USER_NAME" : "${aws_db_instance.this.username}",
"DATABASE_PASSWORD" : "${random_password.this["rds"].result}",
"ADMIN_PATH" : "admin_${random_string.this["admin_path"].result}",
"ADMIN_PASSWORD" : "${random_password.this["app"].result}",
"VERSION" : "${var.app["app_version"]}",
"DOMAIN" : "${var.app["domain"]}",
"BRAND" : "${var.app["brand"]}",
"PHP_USER" : "php-${var.app["brand"]}",
"ADMIN_EMAIL" : "${var.app["admin_email"]}",
"WEB_ROOT_PATH" : "/home/${var.app["brand"]}/public_html",
"TIMEZONE" : "${var.app["timezone"]}",
"MAGENX_HEADER" : "${random_uuid.this.result}",
"HEALTH_CHECK_LOCATION" : "${random_string.this["health_check"].result}",
"MYSQL_PATH" : "mysql_${random_string.this["mysql_path"].result}",
"PROFILER" : "${random_string.this["profiler"].result}",
"BLOWFISH" : "${random_password.this["blowfish"].result}",
"RESOLVER" : "${cidrhost(aws_vpc.this.cidr_block, 2)}",
"PHP_VERSION" : "${var.app["php_version"]}",
"PHP_INI" : "/etc/php/${var.app["php_version"]}/fpm/php.ini",
"PHP_FPM_POOL" : "/etc/php/${var.app["php_version"]}/fpm/pool.d/www.conf",
"PHP_OPCACHE_INI" : "/etc/php/${var.app["php_version"]}/fpm/conf.d/10-opcache.ini",
"HTTP_X_HEADER" : "${random_uuid.this.result}",
"LINUX_PACKAGES" : "${var.app["linux_packages"]}",
"PHP_PACKAGES" : "${var.app["php_packages"]}",
"EXCLUDE_LINUX_PACKAGES" : "${var.app["exclude_linux_packages"]}"
}
EOF

  tags = {
    Name = "${local.project}-${local.environment}-env"
  }
}
