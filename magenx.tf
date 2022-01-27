


/////////////////////////////////////////////////[ AWS BUDGET NOTIFICATION ]//////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create alert when your budget thresholds are forecasted to exceed
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_budgets_budget" "all" {
  name              = "${local.project}-budget-monthly-forecasted"
  budget_type       = "COST"
  limit_amount      = "2000"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.app["admin_email"]]
  }
}



///////////////////////////////////////////////////[ RANDOM STRING GENERATOR ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Generate random uuid string that is intended to be used as unique identifier
# # ---------------------------------------------------------------------------------------------------------------------#
resource "random_uuid" "this" {}
# # ---------------------------------------------------------------------------------------------------------------------#
# Generate random passwords
# # ---------------------------------------------------------------------------------------------------------------------#
resource "random_password" "this" {
  for_each         = toset(var.password)
  length           = (each.key == "blowfish" ? 32 : 16)
  lower            = true
  upper            = true
  number           = true
  special          = true
  override_special = "%*?"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Generate random string
# # ---------------------------------------------------------------------------------------------------------------------#
resource "random_string" "this" {
  for_each       = toset(var.string)
  length         = (each.key == "id_prefix" ? 3 : 7)
  lower          = true
  number         = true
  special        = false
  upper          = false
}



////////////////////////////////////////////////////[ SNS SUBSCRIPTION TOPIC ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SNS topic and email subscription (confirm email right after resource creation)
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_sns_topic" "default" {
  name = "${local.project}-email-alerts"
}
resource "aws_sns_topic_subscription" "default" {
  topic_arn = aws_sns_topic.default.arn
  protocol  = "email"
  endpoint  = var.app["admin_email"]
}



///////////////////////////////////////////////////[ AWS CERTIFICATE MANAGER ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create and validate ssl certificate for domain and subdomains
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_acm_certificate" "default" {
  domain_name               = "${var.app["domain"]}"
  subject_alternative_names = ["*.${var.app["domain"]}"]
  validation_method         = "EMAIL"

lifecycle {
    create_before_destroy   = true
  }
}

resource "aws_acm_certificate_validation" "default" {
  certificate_arn = aws_acm_certificate.default.arn
}



///////////////////////////////////////////////////[ ELASTIC FILE SYSTEM ]////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EFS file system
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_efs_file_system" "this" {
  creation_token = "${local.project}-efs-storage"
  tags = {
    Name = "${local.project}-efs-storage"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EFS mount target for each subnet
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_efs_mount_target" "this" {
  for_each        = aws_subnet.this
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = aws_subnet.this[each.key].id
  security_groups = [aws_security_group.efs.id]
}



////////////////////////////////////////////////////////[ CODECOMMIT ]////////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeCommit repository for application code
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codecommit_repository" "app" {
  repository_name = var.app["domain"]
  description     = "Magento 2.x code for ${var.app["domain"]}"
    tags = {
      Name = "${local.project}-${var.app["domain"]}"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeCommit repository for services configuration
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codecommit_repository" "services" {
  repository_name = "${var.app["brand"]}-services-config"
  description     = "EC2 linux and services configurations"
    tags = {
      Name = "${local.project}-services-config"
  }
  provisioner "local-exec" {
  interpreter = ["/bin/bash", "-c"]
  command = <<EOF
          cd ${abspath(path.root)}/services/nginx
          git init
          git commit --allow-empty -m "main branch"
          git branch -m main
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} main

          git branch -m nginx_admin
          git add .
          git commit -m "nginx_ec2_config"
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} nginx_admin

          git branch -m nginx_frontend
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} nginx_frontend
          rm -rf .git
EOF
  }
}



/////////////////////////////////////////////////////[ EC2 INSTANCE PROFILE ]/////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "ec2" {
  for_each = var.ec2
  name = "${local.project}-EC2InstanceRole-${each.key}"
  description = "Allows EC2 instances to call AWS services on your behalf"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policies to EC2 service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "ec2" {
  for_each = { for policy in [ for role,policy in setproduct(keys(var.ec2),var.ec2_instance_profile_policy): { role = policy[0] , policy = policy[1]} ] : "${policy.role}-${policy.policy}" => policy }
  role       = aws_iam_role.ec2[each.value.role].name
  policy_arn = each.value.policy
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create inline policy for EC2 service role to publish sns message
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy" "sns_publish" {
  for_each = var.ec2
  name = "${local.project}EC2ProfileSNS${title(each.key)}"
  role = aws_iam_role.ec2[each.key].id

  policy = jsonencode({
  Version = "2012-10-17",
  Statement = [
    {
      Sid    = "EC2ProfileSNSPublishPolicy${each.key}",
      Effect = "Allow",
      Action = [
            "sns:Publish"
      ],
      Resource = aws_sns_topic.default.arn
 }]
})
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create inline policy for EC2 service role to limit CodeCommit access
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy" "codecommit_access" {
  for_each = var.ec2
  name = "${local.project}PolicyForCodeCommitAccess${title(each.key)}"
  role = aws_iam_role.ec2[each.key].id

  policy = jsonencode({
  Version = "2012-10-17",
  Statement = [
    {
      Sid    = "codecommitaccessapp${each.key}",
      Effect = "Allow",
      Action = [
            "codecommit:Get*",
            "codecommit:List*",
            "codecommit:Merge*",
            "codecommit:GitPull",
            "codecommit:GitPush"
      ],
      Resource = aws_codecommit_repository.app.arn
      Condition = {
                StringEqualsIfExists = {
                    "codecommit:References" = ["refs/heads/main"]
    }
   }
},
     {
      Sid    = "codecommitaccessservices${each.key}", 
      Effect = "Allow",
      Action = [
            "codecommit:Get*",
            "codecommit:List*",
            "codecommit:Describe*",
            "codecommit:GitPull"
      ],
      Resource = aws_codecommit_repository.services.arn
    }]
})
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 Instance Profile
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_instance_profile" "ec2" {
  for_each = var.ec2
  name     = "${local.project}-EC2InstanceProfile-${each.key}"
  role     = aws_iam_role.ec2[each.key].name
}


/////////////////////////////////////////////////[ AMAZON RABBITMQ BROKER ]///////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create RabbitMQ - queue message broker
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_mq_broker" "this" {
  broker_name = "${local.project}-${var.rabbitmq["broker_name"]}"
  engine_type        = "RabbitMQ"
  engine_version     = var.rabbitmq["engine_version"]
  host_instance_type = var.rabbitmq["host_instance_type"]
  security_groups    = [aws_security_group.rabbitmq.id]
  subnet_ids         = [values(aws_subnet.this).0.id]
  user {
    username = var.app["brand"]
    password = random_password.this["rabbitmq"].result
  }
  tags = {
    Name   = "${local.project}-${var.rabbitmq["broker_name"]}"
  }
}



////////////////////////////////////////////////////////[ EVENTBRIDGE RULES ]/////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "eventbridge_service_role" {
  name = "${local.project}-EventBridgeServiceRole"
  description = "Provides EventBridge manage events on your behalf."
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "events.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for EventBridge role to start CodePipeline
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_policy" "eventbridge_service_role" {
  name = "${local.project}-start-codepipeline"
  path = "/service-role/"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codepipeline:StartPipelineExecution"
            ],
            "Resource": [
                "${aws_codepipeline.this.arn}"
            ]
        }
    ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policies to EventBridge role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "eventbridge" {
  policy_arn = aws_iam_policy.eventbridge_service_role.arn
  role       = aws_iam_role.eventbridge_service_role.name
}
resource "aws_iam_role_policy_attachment" "eventbridge_service_role" {
  for_each   = var.eventbridge_policy
  role       = aws_iam_role.eventbridge_service_role.name
  policy_arn = each.value
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge rule to run Magento cronjob
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "cronjob" {
  name        = "${local.project}-EventBridge-Rule-Run-Magento-Cronjob"
  description = "EventBridge rule to run Magento cronjob every minute"
  schedule_expression = "rate(1 minute)"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge target to execute SSM command
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "cronjob" {
  rule      = aws_cloudwatch_event_rule.cronjob.name
  target_id = "${local.project}-EventBridge-Target-Admin-Instance-Cron"
  arn       = "arn:aws:ssm:${data.aws_region.current.name}::document/AWS-RunShellScript"
  role_arn  = aws_iam_role.eventbridge_service_role.arn
  input     = "{\"commands\":[\"su ${var.app["brand"]} -s /bin/bash -c '/home/${var.app["brand"]}/public_html/bin/magento cron:run 2>&1'\"],\"executionTimeout\":[\"180\"]}"
 
run_command_targets {
    key    = "tag:Name"
    values = [aws_launch_template.this["admin"].tag_specifications[0].tags.Name]
  }
}



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
"RABBITMQ_ENDPOINT" : "${trimsuffix(trimprefix("${aws_mq_broker.this.instances.0.endpoints.0}", "amqps://"), ":5671")}",
"RABBITMQ_USER" : "${var.app["brand"]}",
"RABBITMQ_PASSWORD" : "${random_password.this["rabbitmq"].result}",
"ELASTICSEARCH_ENDPOINT" : "https://${aws_elasticsearch_domain.this.endpoint}:443",
"REDIS_CACHE_BACKEND" : "${aws_elasticache_replication_group.this["cache"].primary_endpoint_address}",
"REDIS_SESSION_BACKEND" : "${aws_elasticache_replication_group.this["session"].primary_endpoint_address}",
"SES_KEY" : "${aws_iam_access_key.ses_smtp_user_access_key.id}",
"SES_SECRET" : "${aws_iam_access_key.ses_smtp_user_access_key.secret}",
"SES_PASSWORD" : "${aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4}",
"DATABASE_ENDPOINT" : "${aws_db_instance.this.endpoint}",
"DATABASE_INSTANCE_NAME" : "${aws_db_instance.this.name}",
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
    Name = "${local.project}-env"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameter configuration file for CloudWatch Agent
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  for_each    = var.ec2
  name        = "amazon-cloudwatch-agent-${each.key}.json"
  description = "Configuration file for CloudWatch agent at ${each.key}"
  type        = "String"
  value       = <<EOF
{
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
            {
                "file_path": "/var/log/nginx/error.log",
                "log_group_name": "${var.app["brand"]}_nginx_error_logs",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
            },
            %{ if each.key == "admin" ~}
            {
                "file_path": "/home/${var.app["brand"]}/public_html/var/log/php-fpm-error.log",
                "log_group_name": "${var.app["brand"]}_php_app_error_logs",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
            },
            {
                "file_path": "/home/${var.app["brand"]}/public_html/var/log/exception.log",
                "log_group_name": "${var.app["brand"]}_app_error_logs",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
            },
            %{ endif ~}
            {
                "file_path": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log",
                "log_group_name": "${var.app["brand"]}_cloudwatch_agent_log",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
            },
            {
                "file_path": "/var/log/apt/history.log",
                "log_group_name": "${var.app["brand"]}_system_apt_history",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
            },
            {
                "file_path": "/var/log/syslog",
                "log_group_name": "${var.app["brand"]}_system_syslog",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
            }
            ]
          }
        },
        "log_stream_name": "${var.app["domain"]}",
        "force_flush_interval" : 60
      }
}
EOF

  tags = {
    Name = "amazon-cloudwatch-agent-${each.key}.json"
  }
}

