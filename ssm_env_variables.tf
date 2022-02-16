


/////////////////////////////////////////////////////////[ SYSTEMS MANAGER ]//////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameter store for aws params
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_parameter" "env" {
  name        = "${local.project}-env"
  description = "Environment variables for ${local.project} in ${data.aws_region.current.name}"
  type        = "String"
  value       = <<EOF
{
"PROJECT" : "${local.project}",
"FASTLY" : "${var.fastly}",
"AWS_DEFAULT_REGION" : "${data.aws_region.current.name}",
"VPC_ID" : "${aws_vpc.this.id}",
"CIDR" : "${aws_vpc.this.cidr_block}",
"SUBNET_ID" : "${values(aws_subnet.this).0.id}",
"SECURITY_GROUP" : "${aws_security_group.ec2.id}",
"SOURCE_AMI" : "${data.aws_ami.distro.id}",
"VOLUME_SIZE" : "${var.asg["volume_size"]}",
"ALB_DNS_NAME" : "${aws_lb.this.dns_name}",
"EFS_DNS_TARGET" : "${values(aws_efs_mount_target.this).0.dns_name}",
"SNS_TOPIC_ARN" : "${aws_sns_topic.default.arn}",
"CODECOMMIT_APP_REPO" : "codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name}",
"CODECOMMIT_SERVICES_REPO" : "codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name}",
"RABBITMQ_ENDPOINT" : "${regex("amqps://(.*):5671",aws_mq_broker.this.instances.0.endpoints.0)[0]}",
"RABBITMQ_USER" : "${var.app["brand"]}",
"RABBITMQ_PASSWORD" : "${random_password.this["rabbitmq"].result}",
"ELASTICSEARCH_ENDPOINT" : "https://${aws_elasticsearch_domain.this.endpoint}:443",
"REDIS_CACHE_BACKEND" : "${aws_elasticache_replication_group.this["cache"].primary_endpoint_address}",
"REDIS_SESSION_BACKEND" : "${aws_elasticache_replication_group.this["session"].primary_endpoint_address}",
"REDIS_CACHE_BACKEND_RO" : "${aws_elasticache_replication_group.this["cache"].reader_endpoint_address}",
"REDIS_SESSION_BACKEND_RO" : "${aws_elasticache_replication_group.this["session"].reader_endpoint_address}",
"S3_MEDIA_BUCKET" : "${aws_s3_bucket.this["media"].bucket}",
"S3_MEDIA_BUCKET_URL" : "${aws_s3_bucket.this["media"].bucket_regional_domain_name}",
"S3_MEDIA_BUCKET_KEY" : "${aws_iam_access_key.s3.id}",
"S3_MEDIA_BUCKET_SECRET" : "${aws_iam_access_key.s3.secret}",
"SES_KEY" : "${aws_iam_access_key.ses_smtp_user_access_key.id}",
"SES_SECRET" : "${aws_iam_access_key.ses_smtp_user_access_key.secret}",
"SES_PASSWORD" : "${aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4}",
"DATABASE_ENDPOINT" : "${aws_db_instance.this.endpoint}",
"DATABASE_NAME" : "${aws_db_instance.this.name}",
"DATABASE_USER_NAME" : "${aws_db_instance.this.username}",
"DATABASE_PASSWORD" : "${random_password.this["rds"].result}",
"ADMIN_PATH" : "admin_${random_string.this["admin_path"].result}",
"ADMIN_PASSWORD" : "${random_password.this["app"].result}",
"VERSION" : "${var.app["app_version"]}",
"DOMAIN" : "${var.app["domain"]}",
"BRAND" : "${var.app["brand"]}",
"PHP_USER" : "php-${var.app["brand"]}",
"ADMIN_EMAIL" : "${var.app["admin_email"]}",
"ADMIN_LOGIN" : "${var.app["admin_login"]}",
"ADMIN_FIRSTNAME" : "${var.app["admin_firstname"]}",
"ADMIN_LASTNAME" : "${var.app["admin_lastname"]}",
"LANGUAGE" : "${var.app["language"]}",
"CURRENCY" : "${var.app["currency"]}",
"TIMEZONE" : "${var.app["timezone"]}",
"CACHE_PREFIX" : "${random_string.this["cache_prefix"].result}",
"SESSION_PERSISTENT" : "${random_string.this["session_persistent"].result}",
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
"EXCLUDE_LINUX_PACKAGES" : "${var.app["exclude_linux_packages"]}",
"COMPOSER_USER" : "${var.app["composer_user"]}",
"COMPOSER_PASS" : "${var.app["composer_pass"]}"
}
EOF

  tags = {
    Name = "${local.project}-env"
  }
}
