# # ---------------------------------------------------------------------------------------------------------------------#
# Generate random secret strings / passwords
# # ---------------------------------------------------------------------------------------------------------------------#
resource "random_password" "password" {
  count            = 3
  length           = 16
  lower            = true
  upper            = true
  number           = true
  special          = true
  override_special = "!#$%&*?"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EFS file system
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_efs_file_system" "efs_file_system" {
  creation_token = "${var.magento["mage_owner"]}-efs-storage"
  tags = {
    Name = "${var.magento["mage_owner"]}-efs-storage"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EFS mount target for each subnet
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_efs_mount_target" "efs_mount_target" {
  count           = length(data.aws_subnet_ids.default.ids)
  file_system_id  = aws_efs_file_system.efs_file_system.id
  subnet_id       = tolist(data.aws_subnet_ids.default.ids)[count.index]
  security_groups = [aws_security_group.security_group["efs"].id]
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeCommit repository for Magento code
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codecommit_repository" "codecommit_repository" {
  repository_name = var.magento["mage_domain"]
  description     = "Magento 2.x code for ${var.magento["mage_domain"]}"
    tags = {
    Name = "${var.magento["mage_owner"]}-${var.magento["mage_domain"]}"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudFront distribution with S3 origin
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "CloudFront origin access identity"
}
resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.s3_bucket["media"].bucket_regional_domain_name
    origin_id   = "${var.magento["mage_domain"]}-media-assets"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
	  
    custom_header {
      name  = "X-Magenx-Header"
      value = uuid()
    }
  }

  aliases = [var.magento["mage_domain"]]

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.magento["mage_domain"]} media assets"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.s3_bucket["system"].bucket_domain_name
    prefix          = "${var.magento["mage_owner"]}-cloudfront-logs"
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.magento["mage_domain"]}-media-assets"

    compress = true
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.origin_request_policy.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.cache_policy.id

  viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100"

  tags = {
    Name = "production"
  }

  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.issued_us.arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameter configuration file for CloudWatch agent
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
                "log_group_name": "nginx_error_logs",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
              },
              {
                "file_path": "/home/${var.magento["mage_owner"]}/public_html/var/log/php-fpm-error.log",
                "log_group_name": "php_error_logs",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
              },
              {
                "file_path": "/home/${var.magento["mage_owner"]}/public_html/var/log/exception.log",
                "log_group_name": "magento_error_logs",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
              },
              {
                "file_path": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log",
                "log_group_name": "cloudwatch_agent_log",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
              },
              {
                "file_path": "/var/log/syslog",
                "log_group_name": "system_syslog",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
              }
            ]
          }
        },
        "log_stream_name": "${var.magento["mage_domain"]}",
        "force_flush_interval" : 5
      }
}
EOF

  tags = {
    Name = "amazon-cloudwatch-agent-${each.key}.json"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM YAML Document runShellScript to init/pull git
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "ssm_document_pull" {
  name          = "${var.magento["mage_owner"]}-deployment-git"
  document_type = "Command"
  document_format = "YAML"
  target_type   = "/AWS::EC2::Instance"
  content = <<EOT
---
schemaVersion: "2.2"
description: "Pull code changes from codecommit"
parameters:
mainSteps:
- action: "aws:runShellScript"
  name: "codecommitpullchanges"
  inputs:
    runCommand:
    - |-
      #!/bin/bash
      if [ -f /home/${var.magento["mage_owner"]}/public_html/app/etc/env.php ]; then
      cd /home/${var.magento["mage_owner"]}/public_html
      su ${var.magento["mage_owner"]} -s /bin/bash -c "git checkout main"
      su ${var.magento["mage_owner"]} -s /bin/bash -c "git pull origin main"
      systemctl reload php${var.magento["php_version"]}-fpm
      systemctl reload nginx
      else
      exit 1
      fi
EOT
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM YAML Document runShellScript to install magento, push to codecommit, init git
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "ssm_document_install" {
  name          = "${var.magento["mage_owner"]}-install-magento-git"
  document_type = "Command"
  document_format = "YAML"
  target_type   = "/AWS::EC2::Instance"
  content = <<EOT
---
schemaVersion: "2.2"
description: "Configure git, install magento, push to codecommit"
parameters:
mainSteps:
- action: "aws:runShellScript"
  name: "codecommitinstallmagento"
  inputs:
    runCommand:
    - |-
      #!/bin/bash
      cd /home/${var.magento["mage_owner"]}/public_html
      git config --system credential.UseHttpPath true
      git config --system user.email "${var.magento["mage_admin_email"]}"
      git config --system user.name "${var.magento["mage_owner"]}"
      su ${var.magento["mage_owner"]} -s /bin/bash -c "git clone ${var.magento["mage_source"]} ."
      su ${var.magento["mage_owner"]} -s /bin/bash -c "echo 007 > magento_umask"
      setfacl -Rdm u:${var.magento["mage_owner"]}:rwX,g:php-${var.magento["mage_owner"]}:rwX,o::- var generated pub/static pub/media
      rm -rf .git
      chmod +x bin/magento
      su ${var.magento["mage_owner"]} -s /bin/bash -c "bin/magento module:enable --all"
      su ${var.magento["mage_owner"]} -s /bin/bash -c "bin/magento setup:install \
      --base-url=https://${var.magento["mage_domain"]}/ \
      --base-url-secure=https://${var.magento["mage_domain"]}/ \
      --db-host=${aws_db_instance.db_instance.endpoint} \
      --db-name=${aws_db_instance.db_instance.name} \
      --db-user=${aws_db_instance.db_instance.username} \
      --db-password='${random_password.password[1].result}' \
      --admin-firstname=${var.magento["mage_owner"]} \
      --admin-lastname=${var.magento["mage_owner"]} \
      --admin-email=${var.magento["mage_admin_email"]} \
      --admin-user=admin \
      --admin-password='${random_password.password[2].result}' \
      --language=${var.magento["language"]} \
      --currency=${var.magento["currency"]} \
      --timezone=${var.magento["timezone"]} \
      --cleanup-database \
      --session-save=files \
      --use-rewrites=1 \
      --use-secure=1 \
      --use-secure-admin=1 \
      --consumers-wait-for-messages=0 \
      --amqp-host=${aws_mq_broker.mq_broker.instances.0.endpoints.0} \
      --amqp-port=5671 \
      --amqp-user=${var.magento["mage_owner"]} \
      --amqp-password='${random_password.password[0].result}' \
      --amqp-virtualhost='/' \
      --search-engine=elasticsearch7 \
      --elasticsearch-host=${aws_elasticsearch_domain.elasticsearch_domain.endpoint} \
      --elasticsearch-port=443 \
      --remote-storage-driver=aws-s3 \
      --remote-storage-bucket=${aws_s3_bucket.s3_bucket["media"].bucket} \
      --remote-storage-region=${data.aws_region.current.name}"
      ## installation check
      if [ ! -f /home/${var.magento["mage_owner"]}/public_html/app/etc/env.php ]; then
      echo "installation error"
      exit 1
      fi
      ## cache backend
      su ${var.magento["mage_owner"]} -s /bin/bash -c "bin/magento setup:config:set \
      --cache-backend=redis \
      --cache-backend-redis-server=${aws_elasticache_replication_group.elasticache_cluster["cache"].configuration_endpoint_address} \
      --cache-backend-redis-port=6379 \
      --cache-backend-redis-db=1 \
      --cache-backend-redis-compress-data=1 \
      --cache-backend-redis-compression-lib=l4z \
      -n"
      ## session
      su ${var.magento["mage_owner"]} -s /bin/bash -c "bin/magento setup:config:set \
      --session-save=redis \
      --session-save-redis-host=${aws_elasticache_replication_group.elasticache_cluster["session"].configuration_endpoint_address} \
      --session-save-redis-port=6379 \
      --session-save-redis-log-level=3 \
      --session-save-redis-db=1 \
      --session-save-redis-compression-lib=lz4 \
      -n"
      su ${var.magento["mage_owner"]} -s /bin/bash -c "bin/magento deploy:mode:set production"
      git init
      git add . -A
      git commit -m ${var.magento["mage_owner"]}-release-$(date +'%y%m%d-%H%M%S')
      git remote add origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.codecommit_repository.repository_name}
      git branch -m main
      git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.codecommit_repository.repository_name} main
EOT
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "ec2_instance_role" {
  name = "EC2InstanceRole"
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
resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  for_each   = var.ec2_instance_profile_policy
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = each.value
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create inline policy for EC2 service role to limit CodeCommit access
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy" "codecommit_access" {
  name = "PolicyForCodeCommitAccess"
  role = aws_iam_role.ec2_instance_role.id

  policy = jsonencode({
  Version = "2012-10-17",
  Statement = [
    {
      Effect = "Allow",
      Action = [
            "codecommit:Get*",
            "codecommit:List*",
            "codecommit:Describe*",
            "codecommit:Put*",
            "codecommit:Post*",
            "codecommit:Merge*",
            "codecommit:Test*",
            "codecommit:Update*",
            "codecommit:GitPull",
            "codecommit:GitPush"
      ],
      Resource = aws_codecommit_repository.codecommit_repository.arn
    }
  ]
})
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 Instance Profile
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2InstanceProfile"
  role = aws_iam_role.ec2_instance_role.name
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create RabbitMQ - queue message broker
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_mq_broker" "mq_broker" {
  broker_name = "${var.magento["mage_owner"]}-queue"
  engine_type        = "RabbitMQ"
  engine_version     = "3.8.6"
  host_instance_type = "mq.t3.micro"
  security_groups    = [aws_security_group.security_group["mq"].id]
  user {
    username = var.magento["mage_owner"]
    password = random_password.password[0].result
  }
  tags = {
    Name   = "${var.magento["mage_owner"]}-queue"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElastiCache - Redis Replication group - session + cache
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_elasticache_replication_group" "elasticache_cluster" {
  for_each                      = toset(var.redis["name"])
  engine                        = "redis"
  replication_group_id          = "${var.magento["mage_owner"]}-${each.key}-backend"
  replication_group_description = "Replication group for ${var.magento["mage_domain"]} ${each.key} backend"
  node_type                     = var.redis["node_type"]
  port                          = 6379
  parameter_group_name          = var.redis["parameter_group_name"]
  security_group_ids            = [aws_security_group.security_group[each.key].id]
  automatic_failover_enabled    = true
  multi_az_enabled              = true

  cluster_mode {
    replicas_per_node_group = var.redis["replicas_per_node_group"]
    num_node_groups         = var.redis["num_node_groups"]
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create S3 bucket
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket" "s3_bucket" {
  for_each      = var.s3
  bucket        = "${var.magento["mage_owner"]}-${each.key}-storage"
  force_destroy = true
  acl           = "private"
  tags = {
    Name        = "${var.magento["mage_owner"]}-${each.key}-storage"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for CloudFront and EC2 to limit S3 media bucket access
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket_policy" "s3_bucket_media_policy" {
  bucket = aws_s3_bucket.s3_bucket["media"].id
  policy = jsonencode(
            {
              Id        = "PolicyForMediaStorageAccess"
              Statement = [
                    {
                      Action    = "s3:GetObject"
                      Effect    = "Allow"
                      Principal = {
                          AWS = aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn
                        }
                      Resource  = "${aws_s3_bucket.s3_bucket["media"].arn}/*"
                    },
                    {
                      Action = [
                          "s3:PutObject",
                          "s3:GetObject",
                          "s3:DeleteObject",
                          "s3:PutObjectAcl"
                        ],
                      Effect    = "Allow"
                      Principal = {
                          AWS = aws_iam_role.ec2_instance_role.arn
                        }
                      Resource  = "${aws_s3_bucket.s3_bucket["media"].arn}/*"
                    },
                    {
                      Action = [
                          "s3:GetBucketLocation",
                          "s3:ListBucket"
                        ],
                      Effect    = "Allow"
                      Principal = {
                          AWS = aws_iam_role.ec2_instance_role.arn
                        }
                      Resource  = "${aws_s3_bucket.s3_bucket["media"].arn}"
                    },
                ]
              Version   = "2012-10-17"
            }
        )
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create S3 bucket policy for ALB to write access logs
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket_policy" "s3_bucket_system_policy" {
  bucket = aws_s3_bucket.s3_bucket["system"].id
  policy = jsonencode(
            {
  Id = "PolicyALBWriteLogs"
  Version = "2012-10-17"
  Statement = [
    {
      Action = [
        "s3:PutObject"
      ],
      Effect = "Allow"
      Resource = "arn:aws:s3:::${aws_s3_bucket.s3_bucket["system"].id}/${var.magento["mage_owner"]}-alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      Principal = {
        AWS = [
          data.aws_elb_service_account.current.arn
        ]
      }
    }
  ]
}
)
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElasticSearch service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_service_linked_role" "elasticsearch_domain" {
  aws_service_name = "es.amazonaws.com"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElasticSearch domain !!! ~45min creation time
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_elasticsearch_domain" "elasticsearch_domain" {
  depends_on = [aws_iam_service_linked_role.elasticsearch_domain]
  domain_name           = "${var.magento["mage_owner"]}-${var.elk["domain_name"]}"
  elasticsearch_version = var.elk["elasticsearch_version"]
  cluster_config {
    instance_type  = var.elk["instance_type"]
    instance_count = var.elk["instance_count"]
  }
  ebs_options {
    ebs_enabled = var.elk["ebs_enabled"]
    volume_type = var.elk["volume_type"]
    volume_size = var.elk["volume_size"]
  }
  vpc_options {
    subnet_ids = [sort(data.aws_subnet_ids.default.ids)[0]]
    security_group_ids = [aws_security_group.security_group["elk"].id]
  }
  tags = {
    Name = var.elk["domain_name"]
  }
  access_policies = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "*"
        ]
      },
      "Action": [
        "es:*"
      ],
      "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.elk["domain_name"]}/*"
    }
  ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS instance
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_db_instance" "db_instance" {
  identifier            = "${var.magento["mage_owner"]}-${var.rds["name"]}-database"
  allocated_storage     = var.rds["allocated_storage"]
  max_allocated_storage = var.rds["max_allocated_storage"]
  storage_type          = var.rds["storage_type"] 
  engine                = var.rds["engine"]
  engine_version        = var.rds["engine_version"]
  instance_class        = var.rds["instance_class"]
  name                  = "${var.magento["mage_owner"]}_${var.rds["name"]}"
  username              = var.magento["mage_owner"]
  password              = random_password.password[1].result
  parameter_group_name  = var.rds["parameter_group_name"]
  skip_final_snapshot   = var.rds["skip_final_snapshot"]
  vpc_security_group_ids = [aws_security_group.security_group["rds"].id]
  copy_tags_to_snapshot = true
  tags = {
    Name = "${var.magento["mage_owner"]}-database"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Security Groups
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "security_group" {
  for_each    = local.security_group
  name        = "${var.magento["mage_owner"]}-${each.key}"
  description = "${each.key} security group"
  vpc_id      = data.aws_vpc.default.id
  
    tags = {
    Name = "${var.magento["mage_owner"]}-${each.key}"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Security Rules for Security Groups
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group_rule" "security_rule" {
   for_each =  local.security_rule
      type             = lookup(each.value, "type", null)
      description      = lookup(each.value, "description", null)
      from_port        = lookup(each.value, "from_port", null)
      to_port          = lookup(each.value, "to_port", null)
      protocol         = lookup(each.value, "protocol", null)
      cidr_blocks      = lookup(each.value, "cidr_blocks", null)
      source_security_group_id = lookup(each.value, "source_security_group_id", null)
      security_group_id = each.value.security_group_id
    }
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Application Load Balancers
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb" "load_balancer" {
  for_each           = var.alb
  name               = "${var.magento["mage_owner"]}-${each.key}-alb"
  internal           = each.value
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security_group[each.key].id]
  subnets            = data.aws_subnet_ids.default.ids
  access_logs {
    bucket  = aws_s3_bucket.s3_bucket["system"].bucket
    prefix  = "${var.magento["mage_owner"]}-alb"
    enabled = true
  }
  tags = {
    Name = "${var.magento["mage_owner"]}-${each.key}-alb"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Target Groups for Load Balancers
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_target_group" "target_group" {
  for_each    = merge(var.ec2, var.ec2_extra)
  name        = "${var.magento["mage_owner"]}-${each.key}-target"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 instances for build and developer systems
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_instance" "instances" {
  for_each      = var.ec2_extra
  ami           = data.aws_ami.ubuntu_2004.id
  instance_type = each.value
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  vpc_security_group_ids = [aws_security_group.security_group["ec2"].id]
  root_block_device {
      volume_size = "50"
      volume_type = "gp3"
    }
  tags = {
    Name = "${var.magento["mage_owner"]}-${each.key}-ec2"
  }
  volume_tags = {
    Name = "${var.magento["mage_owner"]}-${each.key}-ec2"
  }
  user_data = base64encode(data.template_file.user_data[each.key].rendered)
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Launch Template for Autoscaling Groups - user_data converted
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_launch_template" "launch_template" {
  for_each = var.ec2
  name = "${var.magento["mage_owner"]}-${each.key}-lt"
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs { 
        volume_size = "50"
        volume_type = "gp3"
            }
  }
  iam_instance_profile { name = aws_iam_instance_profile.ec2_instance_profile.name }
  image_id = data.aws_ami.ubuntu_2004.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = each.value
  monitoring { enabled = false }
  network_interfaces { 
    associate_public_ip_address = true
    security_groups = [aws_security_group.security_group["ec2"].id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.magento["mage_owner"]}-${each.key}-ec2" }
  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.magento["mage_owner"]}-${each.key}-ec2" }
  }
  user_data = base64encode(data.template_file.user_data[each.key].rendered)
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling Groups
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_group" "autoscaling_group" {
  for_each = var.ec2
  name = "${var.magento["mage_owner"]}-${each.key}-asg"
  vpc_zone_identifier = data.aws_subnet_ids.default.ids
  desired_capacity    = var.asg["desired_capacity"]
  max_size            = var.asg["max_size"]
  min_size            = var.asg["min_size"]
  health_check_grace_period = var.asg["health_check_grace_period"]
  health_check_type         = var.asg["health_check_type"]
  target_group_arns  = [aws_lb_target_group.target_group[each.key].arn]
  launch_template {
    name    = aws_launch_template.launch_template[each.key].name
    version = "$Latest"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SNS topic and email subscription (confirm email right after resource creation)
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_sns_topic" "sns_topic_autoscaling" {
  name = "autoscaling-email-alerts"
}
resource "aws_sns_topic_subscription" "sns_topic_autoscaling_subscription" {
  topic_arn = aws_sns_topic.sns_topic_autoscaling.arn
  protocol  = "email"
  endpoint  = var.magento["mage_admin_email"]
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling groups actions for SNS topic email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_notification" "autoscaling_notification" {
for_each = aws_autoscaling_group.autoscaling_group 
group_names = [
    aws_autoscaling_group.autoscaling_group[each.key].name
  ]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = aws_sns_topic.sns_topic_autoscaling.arn
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create https:// listener for OUTER Load Balancer - forward to varnish
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener" "outerhttps" {
  load_balancer_arn = aws_lb.load_balancer["outer"].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  certificate_arn   = data.aws_acm_certificate.issued.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group["varnish"].arn
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create http:// listener for OUTER Load Balancer - redirect to https://
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener" "outerhttp" {
  load_balancer_arn = aws_lb.load_balancer["outer"].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create default listener for INNER Load Balancer - forward to frontend
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener" "inner" {
  load_balancer_arn = aws_lb.load_balancer["inner"].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group["frontend"].arn
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create conditional listener rule for INNER Load Balancer - forward to admin
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener_rule" "inneradmin" {
  listener_arn = aws_lb_listener.inner.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group["admin"].arn
  }
  condition {
    path_pattern {
      values = ["/${var.magento["admin_path"]}/*"]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create conditional listener rule for INNER Load Balancer - forward to staging
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener_rule" "innerstaging" {
  listener_arn = aws_lb_listener.inner.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group["staging"].arn
  }
  condition {
    host_header {
	values = [var.magento["mage_staging_domain"]]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create conditional listener rule for INNER Load Balancer - forward to developer
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener_rule" "innerdeveloper" {
  listener_arn = aws_lb_listener.inner.arn
  priority     = 30
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group["developer"].arn
  }
  condition {
    host_header {
	values = [var.magento["mage_developer_domain"]]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling policy for scale OUT
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_policy" "autoscaling_policy_out" {
  for_each               = var.ec2
  name                   = "${var.magento["mage_owner"]}-${each.key}-asp-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group[each.key].name
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch alarm metric to execute Autoscaling policy for scale OUT
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "cloudwatch_metric_alarm_out" {
  for_each            = var.ec2
  alarm_name          = "${var.magento["mage_owner"]}-${each.key} scale-out alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.asp["evaluation_periods"]
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.asp["period"]
  statistic           = "Average"
  threshold           = var.asp["out_threshold"]
  dimensions = {
    AutoScalingGroupName  = aws_autoscaling_group.autoscaling_group[each.key].name
  }
  alarm_description = "${each.key} scale-out alarm - CPU exceeds 60 percent"
  alarm_actions     = [aws_autoscaling_policy.autoscaling_policy_out[each.key].arn]
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling policy for scale IN
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_policy" "autoscaling_policy_in" {
  for_each               = var.ec2
  name                   = "${var.magento["mage_owner"]}-${each.key}-asp-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group[each.key].name
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch alarm metric to execute Autoscaling policy for scale IN
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "cloudwatch_metric_alarm_in" {
  for_each            = var.ec2
  alarm_name          = "${var.magento["mage_owner"]}-${each.key} scale-in alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.asp["evaluation_periods"]
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.asp["period"]
  statistic           = "Average"
  threshold           = var.asp["in_threshold"]
  dimensions = {
    AutoScalingGroupName  = aws_autoscaling_group.autoscaling_group[each.key].name
  }
  alarm_description = "${each.key} scale-in alarm - CPU less than 25 percent"
  alarm_actions     = [aws_autoscaling_policy.autoscaling_policy_in[each.key].arn]
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch events service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "eventsbridge_service_role" {
  name = "EventsBridgeServiceRole"
  description = "Provides EventsBridge manage events on your behalf."
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
# Attach policies to CloudWatch events role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "eventsbridge_role_policy_attachment" {
  for_each   = var.eventsbridge_policy
  role       = aws_iam_role.eventsbridge_service_role.name
  policy_arn = each.value
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch events rule to monitor CodeCommit magento repository state
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "eventsbridge_rule" {
  name        = "EventsBridgeRuleCodeCommitRepositoryStateChange"
  description = "CloudWatch monitor magento repository state change"
  event_pattern = <<EOF
{
	"source": ["aws.codecommit"],
	"detail-type": ["CodeCommit Repository State Change"],
	"resources": ["${aws_codecommit_repository.codecommit_repository.arn}"],
	"detail": {
		"referenceType": ["branch"],
		"referenceName": ["main"]
	}
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventsBridge target to execute AWS-RunShellScript
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "eventsbridge_target" {
  rule      = aws_cloudwatch_event_rule.eventsbridge_rule.name
  target_id = "EventsBridgeTargetGitDeploymentScript"
  arn       = aws_ssm_document.ssm_document_pull.arn
  role_arn  = aws_iam_role.eventsbridge_service_role.arn
 
run_command_targets {
    key    = "tag:Name"
    values = [aws_launch_template.launch_template["admin"].tag_specifications[0].tags.Name,aws_launch_template.launch_template["frontend"].tag_specifications[0].tags.Name]
  }
}
