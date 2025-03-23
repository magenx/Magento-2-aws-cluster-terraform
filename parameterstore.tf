


///////////////////////////////////////////////[ SYSTEMS MANAGER - PARAMETERSTORE ]///////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameterstore for aws env
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_parameter" "aws_env" {
  for_each    = local.parameters
  name        = "/${local.project}/${local.environment}/${each.key}"
  description = "Environment variable value for ${each.key}"
  type        = "String"
  value       = each.value
  tags = {
    Name = "${local.project}-${local.environment}-${each.key}"
  }
}
locals {
  parameters = {
    PROJECT                     = local.project
    ENVIRONMENT                 = local.environment
    AWS_DEFAULT_REGION          = data.aws_region.current.name
    VPC_ID                      = aws_vpc.this.id
    CIDR                        = aws_vpc.this.cidr_block
    SUBNET_ID                   = join(",", random_shuffle.subnets.result)
    EC2_SECURITY_GROUP          = aws_security_group.ec2.id
    SOURCE_AMI                  = data.aws_ami.distro.id
    EFS_SYSTEM_ID               = aws_efs_file_system.this.id
    EFS_ACCESS_POINT_VAR        = aws_efs_access_point.this["var"].id
    EFS_ACCESS_POINT_MEDIA      = aws_efs_access_point.this["media"].id
    SNS_TOPIC_ARN               = aws_sns_topic.default.arn
    FRONTEND_CLOUDMAP_SERVICE_ID = aws_service_discovery_service.this["frontend"].id
    VARNISH_CLOUDMAP_SERVICE_ID = aws_service_discovery_service.this["varnish"].id
    RABBITMQ_ENDPOINT           = trimsuffix(trimprefix("${aws_mq_broker.this.instances.0.endpoints.0}", "amqps://"), ":5671")
    RABBITMQ_USER               = var.brand
    RABBITMQ_PASSWORD           = random_password.this["rabbitmq"].result
    OPENSEARCH_ENDPOINT         = "https://${aws_opensearch_domain.this.endpoint}:443"
    OPENSEARCH_ADMIN            = random_string.this["opensearch"].result
    OPENSEARCH_PASSWORD         = random_password.this["opensearch"].result
    REDIS_CACHE_BACKEND         = aws_elasticache_replication_group.this["cache"].primary_endpoint_address
    REDIS_SESSION_BACKEND       = aws_elasticache_replication_group.this["session"].primary_endpoint_address
    REDIS_CACHE_BACKEND_RO      = aws_elasticache_replication_group.this["cache"].reader_endpoint_address
    REDIS_SESSION_BACKEND_RO    = aws_elasticache_replication_group.this["session"].reader_endpoint_address
    REDIS_PASSWORD              = random_password.this["redis"].result
    S3_MEDIA_BUCKET             = aws_s3_bucket.this["media"].bucket
    S3_SYSTEM_BUCKET            = aws_s3_bucket.this["system"].bucket
    S3_MEDIA_BUCKET_URL         = aws_s3_bucket.this["media"].bucket_regional_domain_name
    ALB_DNS_NAME                = aws_lb.this.dns_name
    CLOUDFRONT_DOMAIN           = aws_cloudfront_distribution.this.domain_name
    SES_KEY                     = aws_iam_access_key.ses_smtp_user_access_key.id
    SES_SECRET                  = aws_iam_access_key.ses_smtp_user_access_key.secret
    SES_PASSWORD                = aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4
    SES_ENDPOINT                = "email-smtp.${data.aws_region.current.name}.amazonaws.com"
    MARIADB_ENDPOINT            = aws_db_instance.this.endpoint
    MARIADB_NAME                = aws_db_instance.this.identifier
    MARIADB_USER                = aws_db_instance.this.username
    MARIADB_PASSWORD            = random_password.this["mariadb"].result
    MARIADB_ROOT_PASSWORD       = random_password.this["mariadb_root"].result
    ADMIN_PATH                  = "admin_${random_string.this["admin_path"].result}"
    DOMAIN                      = var.domain
    BRAND                       = var.brand
    PHP_USER                    = "php-${var.brand}"
    ADMIN_EMAIL                 = var.admin_email
    WEB_ROOT_PATH               = "/home/${var.brand}/public_html"
    SECURITY_HEADER             = random_uuid.this.result
    HEALTH_CHECK_LOCATION       = random_string.this["health_check"].result
    RESOLVER                    = cidrhost(aws_vpc.this.cidr_block, 2)
    HTTP_X_HEADER               = random_uuid.this.result
  }
}
