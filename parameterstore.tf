


///////////////////////////////////////////////[ SYSTEMS MANAGER - PARAMETERSTORE ]///////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameter store for aws env
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_parameter" "aws_env" {
  name        = "/${local.project}/${local.environment}/aws/env"
  description = "AWS environment for ${local.project} in ${data.aws_region.current.name}"
  type        = "String"
  value       = <<EOF
{
"PROJECT" : "${local.project}",
"ENVIRONMENT" : "${local.environment}",
"AWS_DEFAULT_REGION" : "${data.aws_region.current.name}",
"VPC_ID" : "${aws_vpc.this.id}",
"CIDR" : "${aws_vpc.this.cidr_block}",
"SUBNET_ID" : "${values(aws_subnet.this).0.id}",
"SOURCE_AMI" : "${data.aws_ami.distro.id}",
"EFS_SYSTEM_ID" : "${aws_efs_file_system.this.id}",
"EFS_ACCESS_POINT_VAR" : "${aws_efs_access_point.this["var"].id}",
"EFS_ACCESS_POINT_MEDIA" : "${aws_efs_access_point.this["media"].id}",
"EFS_ACCESS_POINT_BACKUP" : "${aws_efs_access_point.this["backup"].id}",
"SNS_TOPIC_ARN" : "${aws_sns_topic.default.arn}",
"RABBITMQ_USER" : "${var.brand}",
"RABBITMQ_PASSWORD" : "${random_password.this["rabbitmq"].result}",
"OPENSEARCH_ADMIN" : "${random_string.this["opensearch"].result}",
"OPENSEARCH_PASSWORD" : "${random_password.this["opensearch"].result}",
"INDEXER_PASSWORD" : "${random_password.this["indexer"].result}",
"REDIS_PASSWORD" : "${random_password.this["redis"].result}",
"S3_MEDIA_BUCKET" : "${aws_s3_bucket.this["media"].bucket}",
"S3_MEDIA_BUCKET_URL" : "${aws_s3_bucket.this["media"].bucket_regional_domain_name}",
"ALB_DNS_NAME" : "${aws_lb.this.dns_name}",
"CLOUDFRONT_DOMAIN" : "${aws_cloudfront_distribution.this.domain_name}",
"SES_KEY" : "${aws_iam_access_key.ses_smtp_user_access_key.id}",
"SES_SECRET" : "${aws_iam_access_key.ses_smtp_user_access_key.secret}",
"SES_PASSWORD" : "${aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4}",
"SES_ENDPOINT" : "email-smtp.${data.aws_region.current.name}.amazonaws.com",
"DATABASE_NAME" : "${var.brand}",
"DATABASE_USER" : "${var.brand}",
"DATABASE_PASSWORD" : "${random_password.this["mariadb"].result}",
"DATABASE_ROOT_PASSWORD" : "${random_password.this["mariadb_root"].result}",
"ADMIN_PATH" : "admin_${random_string.this["admin_path"].result}",
"DOMAIN" : "${var.domain}",
"BRAND" : "${var.brand}",
"PHP_USER" : "php-${var.brand}",
"ADMIN_EMAIL" : "${var.admin_email}",
"WEB_ROOT_PATH" : "/home/${var.brand}/public_html",
"TIMEZONE" : "${var.timezone}",
"SECURITY_HEADER" : "${random_uuid.this.result}",
"HEALTH_CHECK_LOCATION" : "${random_string.this["health_check"].result}",
"PHPMYADMIN" : "${random_string.this["phpmyadmin"].result}",
"BLOWFISH" : "${random_password.this["blowfish"].result}",
"PROFILER" : "${random_string.this["profiler"].result}",
"RESOLVER" : "${cidrhost(aws_vpc.this.cidr_block, 2)}",
"CRYPT_KEY" : "${var.crypt_key}",
"GRAPHQL_ID_SALT" : "${var.graphql_id_salt}",
"PHP_VERSION" : "${var.php_version}",
"PHP_INI" : "/etc/php/${var.php_version}/fpm/php.ini",
"PHP_FPM_POOL" : "/etc/php/${var.php_version}/fpm/pool.d/www.conf",
"HTTP_X_HEADER" : "${random_uuid.this.result}"
}
EOF
  tags = {
    Name = "${local.project}-${local.environment}-env"
  }
}
