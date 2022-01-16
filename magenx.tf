


/////////////////////////////////////////////////[ AWS BUDGET NOTIFICATION ]//////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create alert when your budget thresholds are forecasted to exceed
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_budgets_budget" "all" {
  name              = "${var.app["brand"]}-budget-monthly-forecasted"
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
resource "random_uuid" "this" {
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Generate random passwords
# # ---------------------------------------------------------------------------------------------------------------------#
resource "random_password" "this" {
  for_each         = toset(["rds", "mq", "app", "blowfish"])
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
  for_each       = toset(["admin_path", "mysql_path", "profiler", "persistent", "id_prefix", "health_check"])
  length         = (each.key == "id_prefix" ? 3 : 7)
  lower          = true
  number         = true
  special        = false
  upper          = false
}



////////////////////////////////////////////////////////[ VPC NETWORKING ]////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_vpc" "this" {
  cidr_block           = var.app["cidr_block"]
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.app["brand"]}-vpc"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create subnets for each AZ in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_subnet" "this" {
  for_each                = data.aws_availability_zone.all
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 4, var.az_number[each.value.name_suffix])
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.app["brand"]}-subnet"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS subnet group in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_db_subnet_group" "this" {
  name       = "${var.app["brand"]}-db-subnet"
  description = "${var.app["brand"]} RDS Subnet"
  subnet_ids = values(aws_subnet.this).*.id
  tags = {
    Name = "${var.app["brand"]}-db-subnet"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElastiCache subnet group in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_elasticache_subnet_group" "this" {
  description = "${var.app["brand"]} ElastiCache Subnet"
  name       = "${var.app["brand"]}-elasticache-subnet"
  subnet_ids = values(aws_subnet.this).*.id 
  tags = {
    Name = "${var.app["brand"]}-elasticache-subnet"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create internet gateway in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.app["brand"]}-igw"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create route table in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_route" "this" {
  route_table_id         = aws_vpc.this.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Assign AZ subnets to route table in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_route_table_association" "this" {
  for_each       = aws_subnet.this
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_vpc.this.main_route_table_id
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create DHCP options in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_vpc_dhcp_options" "this" {
  domain_name          = "${data.aws_region.current.name}.compute.internal"
  domain_name_servers  = ["AmazonProvidedDNS"]
  tags = {
    Name = "${var.app["brand"]}-dhcp"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Assign DHCP options to our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_vpc_dhcp_options_association" "this" {
  vpc_id          = aws_vpc.this.id
  dhcp_options_id = aws_vpc_dhcp_options.this.id
}



////////////////////////////////////////////////////[ SNS SUBSCRIPTION TOPIC ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SNS topic and email subscription (confirm email right after resource creation)
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_sns_topic" "default" {
  name = "${var.app["brand"]}-email-alerts"
}
resource "aws_sns_topic_subscription" "default" {
  topic_arn = aws_sns_topic.default.arn
  protocol  = "email"
  endpoint  = var.app["admin_email"]
}



///////////////////////////////////////////////////////[ SECURITY GROUPS ]////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Security Groups
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "this" {
  for_each    = local.security_group
  name        = "${var.app["brand"]}-${each.key}"
  description = "${each.key} security group"
  vpc_id      = aws_vpc.this.id
  
    tags = {
    Name = "${var.app["brand"]}-${each.key}"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Security Rules for Security Groups
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group_rule" "this" {
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
  creation_token = "${var.app["brand"]}-efs-storage"
  tags = {
    Name = "${var.app["brand"]}-efs-storage"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EFS mount target for each subnet
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_efs_mount_target" "this" {
  for_each        = aws_subnet.this
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = aws_subnet.this[each.key].id
  security_groups = [aws_security_group.this["efs"].id]
}



////////////////////////////////////////////////////////[ CODECOMMIT ]////////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeCommit repository for application code
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codecommit_repository" "app" {
  repository_name = var.app["domain"]
  description     = "Magento 2.x code for ${var.app["domain"]}"
    tags = {
    Name = "${var.app["brand"]}-${var.app["domain"]}"
  }
  provisioner "local-exec" {
  interpreter = ["/bin/bash", "-c"]
  command = <<EOF
          git clone ${var.app["source"]} /tmp/magento
          cd /tmp/magento
          git remote add origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name}
          git branch -m main
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name} main
          rm -rf /tmp/magento
EOF
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeCommit repository for services configuration
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codecommit_repository" "services" {
  repository_name = "${var.app["brand"]}-services-config"
  description     = "EC2 linux and services configurations"
    tags = {
    Name = "${var.app["brand"]}-services-config"
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

          cd ${abspath(path.root)}/services/varnish
          git init
          git add .
          git commit -m "varnish_ec2_config"
          git branch -m varnish
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} varnish
          rm -rf .git

          cd ${abspath(path.root)}/services/systemd_proxy
          git init
          git add .
          git commit -m "systemd_proxy_ec2_config"
          git branch -m systemd_proxy
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} systemd_proxy
          rm -rf .git

          cd ${abspath(path.root)}/services/nginx_proxy
          git init
          git add .
          git commit -m "nginx_proxy_ec2_config"
          git branch -m nginx_proxy
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} nginx_proxy
          rm -rf .git
EOF
  }
}



////////////////////////////////////////////////////////[ CLOUDFRONT ]////////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudFront distribution with S3 origin
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "CloudFront origin access identity"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  web_acl_id          = aws_wafv2_web_acl.this.arn
  price_class         = "PriceClass_100"
  comment             = "${var.app["domain"]} assets"
  
  origin {
    domain_name = aws_s3_bucket.this["media"].bucket_regional_domain_name
    origin_id   = "${var.app["domain"]}-media-assets"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
    }
	  
    custom_header {
      name  = "X-Magenx-Header"
      value = random_uuid.this.result
    }
  }
  
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.app["domain"]}-media-assets"

    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.s3.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.s3.id

    viewer_protocol_policy = "https-only"

  }
  
  origin {
	domain_name = var.app["domain"]
	origin_id   = "${var.app["domain"]}-static-assets"

	custom_origin_config {
		http_port              = 80
		https_port             = 443
		origin_protocol_policy = "https-only"
		origin_ssl_protocols   = ["TLSv1.2"]
	}
  }

  ordered_cache_behavior {
	path_pattern     = "/static/*"
	allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
	cached_methods   = ["GET", "HEAD"]
	target_origin_id = "${var.app["domain"]}-static-assets"
	
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.custom.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.custom.id

    viewer_protocol_policy = "https-only"
    compress               = true
}
  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.this["system"].bucket_domain_name
    prefix          = "${var.app["brand"]}-cloudfront-logs"
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version = "TLSv1.2_2021"
  }
  
  tags = {
    Name = "${var.app["brand"]}-cloudfront"
  }
}



/////////////////////////////////////////////////////[ EC2 INSTANCE PROFILE ]/////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "ec2" {
  for_each = var.ec2
  name = "${var.app["brand"]}-EC2InstanceRole-${each.key}-${data.aws_region.current.name}"
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
  name = "EC2ProfileSNSPublishPolicy${title(each.key)}"
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
  name = "PolicyForCodeCommitAccess${title(each.key)}"
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
  name     = "${var.app["brand"]}-EC2InstanceProfile-${each.key}"
  role     = aws_iam_role.ec2[each.key].name
}


/////////////////////////////////////////////////////[ AMAZON MQ BROKER ]/////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create RabbitMQ - queue message broker
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_mq_broker" "this" {
  broker_name = "${var.app["brand"]}-${var.mq["broker_name"]}"
  engine_type        = "RabbitMQ"
  engine_version     = var.mq["engine_version"]
  host_instance_type = var.mq["host_instance_type"]
  security_groups    = [aws_security_group.this["mq"].id]
  subnet_ids         = [values(aws_subnet.this).0.id]
  user {
    username = var.app["brand"]
    password = random_password.this["mq"].result
  }
  tags = {
    Name   = "${var.app["brand"]}-${var.mq["broker_name"]}"
  }
}



//////////////////////////////////////////////////////////[ ELASTICACHE ]/////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElastiCache parameter groups
# # ---------------------------------------------------------------------------------------------------------------------#		  
resource "aws_elasticache_parameter_group" "this" {
  for_each      = toset(var.redis["name"])
  name          = "${var.app["brand"]}-${each.key}-parameter"
  family        = "redis6.x"
  description   = "Parameter group for ${var.app["domain"]} ${each.key} backend"
  parameter {
    name  = "cluster-enabled"
    value = "no"
  }
  tags = {
    Name = "${var.app["brand"]}-${each.key}-parameter"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElastiCache - Redis Replication group - session + cache
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_elasticache_replication_group" "this" {
  for_each                      = toset(var.redis["name"])
  number_cache_clusters         = length(values(aws_subnet.this).*.id)
  engine                        = "redis"
  engine_version                = var.redis["engine_version"]
  replication_group_id          = "${var.app["brand"]}-${each.key}-backend"
  replication_group_description = "Replication group for ${var.app["domain"]} ${each.key} backend"
  node_type                     = var.redis["node_type"]
  port                          = var.redis["port"]
  parameter_group_name          = aws_elasticache_parameter_group.this[each.key].id
  security_group_ids            = [aws_security_group.this[each.key].id]
  subnet_group_name             = aws_elasticache_subnet_group.this.name
  automatic_failover_enabled    = var.redis["automatic_failover_enabled"]
  multi_az_enabled              = var.redis["multi_az_enabled"]
  notification_topic_arn        = aws_sns_topic.default.arn
  tags = {
    Name = "${var.app["brand"]}-${each.key}-backend"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch CPU Utilization metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "elasticache_cpu" {
  for_each            = aws_elasticache_replication_group.this
  alarm_name          = "${var.app["brand"]}-elasticache-${each.key}-cpu-utilization"
  alarm_description   = "Redis cluster CPU utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.this[each.key].id
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch Freeable Memory metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "elasticache_memory" {
  for_each            = aws_elasticache_replication_group.this
  alarm_name          = "${var.app["brand"]}-elasticache-${each.key}-freeable-memory"
  alarm_description   = "Redis cluster freeable memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = "60"
  statistic           = "Average"
  threshold           = 10000000
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.this[each.key].id
  }
}



//////////////////////////////////////////////////////////[ S3 BUCKET ]///////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create S3 bucket
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket" "this" {
  for_each      = var.s3
  bucket        = "${var.app["brand"]}-${each.key}-storage"
  force_destroy = true
  acl           = "private"
  tags = {
    Name        = "${var.app["brand"]}-${each.key}-storage"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create IAM user for S3 bucket
# # ---------------------------------------------------------------------------------------------------------------------#	  
resource "aws_iam_user" "s3" {
  name = "${var.app["brand"]}-s3-media"
  tags = {
    Name = "${var.app["brand"]}-s3-media"
  }
}
	  
resource "aws_iam_access_key" "s3" {
  user = aws_iam_user.s3.name
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for CloudFront and S3 user to limit S3 media bucket access
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket_policy" "media" {
   bucket = aws_s3_bucket.this["media"].id
   policy = jsonencode({
   Id = "PolicyForMediaStorageAccess"
   Statement = [
	  {
         Action = "s3:GetObject"
         Effect = "Allow"
         Principal = {
            AWS = aws_cloudfront_origin_access_identity.this.iam_arn
         }
         Resource = [
            "${aws_s3_bucket.this["media"].arn}/*.jpg",
            "${aws_s3_bucket.this["media"].arn}/*.jpeg",
            "${aws_s3_bucket.this["media"].arn}/*.png",
            "${aws_s3_bucket.this["media"].arn}/*.gif",
            "${aws_s3_bucket.this["media"].arn}/*.webp"
         ]
      }, 
      {
         Action = ["s3:PutObject"],
         Effect = "Allow"
         Principal = {
            AWS = [ aws_iam_user.s3.arn ]
         }
         Resource = [
            "${aws_s3_bucket.this["media"].arn}",
            "${aws_s3_bucket.this["media"].arn}/*"
         ]
         Condition = {
            StringEquals = {
                "aws:SourceVpc" = [ aws_vpc.this.id ]
         }
	}
      }, 
      {
         Action = ["s3:GetObject", "s3:GetObjectAcl"],
         Effect = "Allow"
         Principal = {
            AWS = [ aws_iam_user.s3.arn ]
         }
         Resource = [
            "${aws_s3_bucket.this["media"].arn}",
            "${aws_s3_bucket.this["media"].arn}/*"
         ]
      }, 
      {
         Action = ["s3:GetBucketLocation", "s3:ListBucket"],
         Effect = "Allow"
         Principal = {
            AWS = [ aws_iam_user.s3.arn ]
         }
         Resource = "${aws_s3_bucket.this["media"].arn}"
      }, 
	  ] 
	  Version = "2012-10-17"
   })
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create S3 bucket policy for ALB to write access logs
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket_policy" "system" {
  bucket = aws_s3_bucket.this["system"].id
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
      Resource = "arn:aws:s3:::${aws_s3_bucket.this["system"].id}/${var.app["brand"]}-alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
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



//////////////////////////////////////////////////////////[ ELASTICSEARCH ]///////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElasticSearch service linked role if not exists
# # ---------------------------------------------------------------------------------------------------------------------#
resource "null_resource" "es" {
  provisioner "local-exec" {
  interpreter = ["/bin/bash", "-c"]
  command = <<EOF
          exit_code=$(aws iam get-role --role-name AWSServiceRoleForAmazonElasticsearchService > /dev/null 2>&1 ; echo $?)
          if [[ $exit_code -ne 0 ]]; then
          aws iam create-service-linked-role --aws-service-name es.amazonaws.com
          fi
EOF
 }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElasticSearch domain
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_elasticsearch_domain" "this" {
  depends_on = [null_resource.es]
  domain_name           = "${var.app["brand"]}-${var.elk["domain_name"]}"
  elasticsearch_version = var.elk["elasticsearch_version"]
  cluster_config {
    instance_type  = var.elk["instance_type"]
    instance_count = var.elk["instance_count"]
    
    zone_awareness_enabled = true
    zone_awareness_config {
        availability_zone_count = var.elk["instance_count"]
      }
  }
  ebs_options {
    ebs_enabled = var.elk["ebs_enabled"]
    volume_type = var.elk["volume_type"]
    volume_size = var.elk["volume_size"]
  }
  vpc_options {
    subnet_ids = slice(values(aws_subnet.this).*.id, 0, var.elk["instance_count"])
    security_group_ids = [aws_security_group.this["elk"].id]
  }
  tags = {
    Name = "${var.app["brand"]}-${var.elk["domain_name"]}"
  }
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elk.arn
    log_type                 = var.elk["log_type"]
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
      "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.app["brand"]}-${var.elk["domain_name"]}/*"
    }
  ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch log group for ElasticSearch log stream
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_log_group" "elk" {
  name = "${var.app["brand"]}-${var.elk["domain_name"]}"
}

resource "aws_cloudwatch_log_resource_policy" "elk" {
  policy_name = "${var.app["brand"]}-${var.elk["domain_name"]}"

  policy_document = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:*"
    }
  ]
}
EOF
}



//////////////////////////////////////////////////////////////[ RDS ]/////////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS parameter groups
# # ---------------------------------------------------------------------------------------------------------------------#		
resource "aws_db_parameter_group" "this" {
  for_each          = var.rds["name"]
  name              = "${var.app["brand"]}-parameters"
  family            = "mariadb10.5"
  description       = "Parameter group for ${var.app["brand"]} database"
  tags = {
    Name = "${var.app["brand"]}-parameters"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS instance
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_db_instance" "this" {
  for_each               = var.rds["name"]
  identifier             = "${var.app["brand"]}"
  allocated_storage      = var.rds["allocated_storage"]
  max_allocated_storage  = var.rds["max_allocated_storage"]
  storage_type           = var.rds["storage_type"] 
  engine                 = var.rds["engine"]
  engine_version         = var.rds["engine_version"]
  instance_class         = var.rds["instance_class"]
  multi_az               = var.rds["multi_az"]
  name                   = "${var.app["brand"]}"
  username               = var.app["brand"]
  password               = random_password.this["rds"].result
  parameter_group_name   = aws_db_parameter_group.this.id
  skip_final_snapshot    = var.rds["skip_final_snapshot"]
  vpc_security_group_ids = [aws_security_group.this["rds"].id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  enabled_cloudwatch_logs_exports = [var.rds["enabled_cloudwatch_logs_exports"]]
  performance_insights_enabled    = var.rds["performance_insights_enabled"]
  copy_tags_to_snapshot           = var.rds["copy_tags_to_snapshot"]
  backup_retention_period         = var.rds["backup_retention_period"]
  delete_automated_backups        = var.rds["delete_automated_backups"]
  deletion_protection             = var.rds["deletion_protection"]
  tags = {
    Name = "${var.app["brand"]}-${each.key}"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS instance event subscription
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_db_event_subscription" "db_event_subscription" {
  name      = "${var.app["brand"]}-rds-event-subscription"
  sns_topic = aws_sns_topic.default.arn
  source_type = "db-instance"
  source_ids = [aws_db_instance.this.id]
  event_categories = [
    "availability",
    "deletion",
    "failover",
    "failure",
    "low storage",
    "maintenance",
    "notification",
    "read replica",
    "recovery",
    "restoration",
    "configuration change"
  ]
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch CPU Utilization metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.app["brand"]} rds cpu utilization too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Average database CPU utilization over last 10 minutes too high"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch Freeable Memory metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "rds_memory" {
  alarm_name          = "${var.app["brand"]} rds freeable memory too low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Average"
  threshold           = "1.0e+09"
  alarm_description   = "Average database freeable memory over last 10 minutes too low, performance may suffer"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch Connections Anomaly metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "rds_connections_anomaly" {
  alarm_name          = "${var.app["brand"]} rds connections anomaly"
  comparison_operator = "GreaterThanUpperThreshold"
  evaluation_periods  = "5"
  threshold_metric_id = "e1"
  alarm_description   = "Database connection count anomaly detected"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]
  
  insufficient_data_actions = []

  metric_query {
    id          = "e1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)"
    label       = "DatabaseConnections (Expected)"
    return_data = "true"
  }

  metric_query {
    id          = "m1"
    return_data = "true"
    metric {
      metric_name = "DatabaseConnections"
      namespace   = "AWS/RDS"
      period      = "600"
      stat        = "Average"
      unit        = "Count"

      dimensions = {
        DBInstanceIdentifier = aws_db_instance.this.id
      }
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch Max Connections metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "rds_max_connections" {
  alarm_name          = "${var.app["brand"]} rds connections over last 10 minutes is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Average"
  threshold           = ceil((80 / 100) * var.max_connection_count[var.rds["instance_class"]])
  alarm_description   = "Average connections over last 10 minutes is too high"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
}


/////////////////////////////////////////////////[ APPLICATION LOAD BALANCER ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Application Load Balancers
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb" "this" {
  for_each           = var.alb
  name               = "${var.app["brand"]}-${each.key}-alb"
  internal           = each.value
  load_balancer_type = "application"
  drop_invalid_header_fields = true
  security_groups    = [aws_security_group.this[each.key].id]
  subnets            = values(aws_subnet.this).*.id
  access_logs {
    bucket  = aws_s3_bucket.this["system"].bucket
    prefix  = "${var.app["brand"]}-alb"
    enabled = true
  }
  tags = {
    Name = "${var.app["brand"]}-${each.key}-alb"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Target Groups for Load Balancers
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_target_group" "this" {
  for_each    = var.ec2
  name        = "${var.app["brand"]}-${each.key}-target"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  health_check {
    path = "/${random_string.this["health_check"].result}"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create https:// listener for OUTER Load Balancer - forward to varnish
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener" "outerhttps" {
  depends_on = [aws_acm_certificate_validation.default]
  load_balancer_arn = aws_lb.this["outer"].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  certificate_arn   = aws_acm_certificate.default.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["varnish"].arn
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create http:// listener for OUTER Load Balancer - redirect to https://
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener" "outerhttp" {
  load_balancer_arn = aws_lb.this["outer"].arn
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
# Create default listener for INNER Load Balancer - default response
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener" "inner" {
  load_balancer_arn = aws_lb.this["inner"].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "fixed-response"
    fixed_response {
        content_type = "text/plain"
        message_body = "No targets are responding to this request"
        status_code  = "502"
        }
    }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create conditional listener rule for INNER Load Balancer - forward to frontend
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener_rule" "innerfrontend" {
  listener_arn = aws_lb_listener.inner.arn
  priority     = 30
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["frontend"].arn
  }
  condition {
    host_header {
      values = [var.app["domain"]]
    }
  }
  condition {
    http_header {
      http_header_name = "X-Magenx-Header"
      values           = [random_uuid.this.result]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create conditional listener rule for INNER Load Balancer - forward to admin
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener_rule" "inneradmin" {
  listener_arn = aws_lb_listener.inner.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["admin"].arn
  }
  condition {
    http_header {
      http_header_name = "X-Magenx-Header"
      values           = [random_uuid.this.result]
    }
  }
  condition {
    path_pattern {
      values = ["/admin_${random_string.this["admin_path"].result}/*"]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create conditional listener rule for INNER Load Balancer - forward to phpmyadmin
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener_rule" "innermysql" {
  listener_arn = aws_lb_listener.inner.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["admin"].arn
  }
  condition {
    http_header {
      http_header_name = "X-Magenx-Header"
      values           = [random_uuid.this.result]
    }
  }
  condition {
    path_pattern {
      values = ["/mysql_${random_string.this["mysql_path"].result}/*"]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch HTTP 5XX metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "httpcode_target_5xx_count" {
  alarm_name          = "${var.app["brand"]}-http-5xx-errors-from-target"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = "25"
  alarm_description   = "HTTPCode 5XX count for frontend instances over 25"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]
  
  dimensions = {
    TargetGroup  = aws_lb_target_group.this["frontend"].arn
    LoadBalancer = aws_lb.this["inner"].arn
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch HTTP 5XX metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "httpcode_elb_5xx_count" {
  alarm_name          = "${var.app["brand"]}-http-5xx-errors-from-loadbalancer"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = "25"
  alarm_description   = "HTTPCode 5XX count for loadbalancer over 25"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]
  
  dimensions = {
    LoadBalancer = aws_lb.this["outer"].arn
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch RequestCount metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "alb_rps" {
  alarm_name          = "${var.app["brand"]}-loadbalancer-rps"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = "120"
  statistic           = "Sum"
  threshold           = "5000"
  alarm_description   = "The number of requests processed over 2 minutes greater than 5000"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]

  dimensions = {
    LoadBalancer = aws_lb.this["outer"].arn
  }
}



////////////////////////////////////////////////////////[ EVENTBRIDGE RULES ]/////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "eventbridge_service_role" {
  name = "${var.app["brand"]}-EventBridgeServiceRole"
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
# Attach policies to EventBridge role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "eventbridge_service_role" {
  for_each   = var.eventbridge_policy
  role       = aws_iam_role.eventbridge_service_role.name
  policy_arn = each.value
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge rule to run Magento cronjob
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "cronjob" {
  name        = "${var.app["brand"]}-EventBridge-Rule-Run-Magento-Cronjob"
  description = "EventBridge rule to run Magento cronjob every minute"
  schedule_expression = "rate(1 minute)"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge target to execute SSM command
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "cronjob" {
  rule      = aws_cloudwatch_event_rule.cronjob.name
  target_id = "${var.app["brand"]}-EventBridge-Target-Admin-Instance-Cron"
  arn       = "arn:aws:ssm:${data.aws_region.current.name}::document/AWS-RunShellScript"
  role_arn  = aws_iam_role.eventbridge_service_role.arn
  input     = "{\"commands\":[\"su ${var.app["brand"]} -s /bin/bash -c '/home/${var.app["brand"]}/public_html/bin/magento cron:run 2>&1'\"],\"executionTimeout\":[\"180\"]}"
 
run_command_targets {
    key    = "tag:Name"
    values = [aws_launch_template.this["admin"].tag_specifications[0].tags.Name]
  }
}



////////////////////////////////////////////////////[ AMAZON SIMPLE EMAIL SERVICE ]///////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SES user credentials, Configuration Set to stream SES metrics to CloudWatch
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_user" "ses_smtp_user" {
  name = "${var.app["brand"]}-ses-smtp-user"
}
	
resource "aws_ses_email_identity" "ses_email_identity" {
  email = "${var.app["admin_email"]}"
}

resource "aws_iam_user_policy" "ses_smtp_user_policy" {
  name = "${var.app["brand"]}-ses-smtp-user-policy"
  user = aws_iam_user.ses_smtp_user.name
  
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "ses_smtp_user_access_key" {
  user = aws_iam_user.ses_smtp_user.name
}

resource "aws_ses_configuration_set" "this" {
  name = "${var.app["brand"]}-ses-events"
  reputation_metrics_enabled = true
  delivery_options {
    tls_policy = "Require"
  }
}

resource "aws_ses_event_destination" "cloudwatch" {
  name                   = "${var.app["brand"]}-ses-event-destination-cloudwatch"
  configuration_set_name = aws_ses_configuration_set.this.name
  enabled                = true
  matching_types         = ["bounce", "send", "complaint", "delivery"]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "dimension"
    value_source   = "emailHeader"
  }
}



/////////////////////////////////////////////////////////[ SYSTEMS MANAGER ]//////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameter store for aws params
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_parameter" "infrastructure_params" {
  name        = "${var.app["brand"]}-aws-infrastructure-params"
  description = "Parameters for AWS infrastructure"
  type        = "String"
  value       = <<EOF

DATABASE_ENDPOINT="${aws_db_instance.this.endpoint}"
DATABASE_INSTANCE_NAME="${aws_db_instance.this.name}"
DATABASE_USER_NAME="${aws_db_instance.this.username}"
DATABASE_PASSWORD='${random_password.this["rds"].result}'

ADMIN_PATH='admin_${random_string.this["admin_path"].result}'
ADMIN_PASSWORD='${random_password.this["app"].result}'
	
MYSQL_PATH="mysql_${random_string.this["mysql_path"].result}"
PROFILER="${random_string.this["profiler"].result}"

RABBITMQ_ENDPOINT="${trimsuffix(trimprefix("${aws_mq_broker.this.instances.0.endpoints.0}", "amqps://"), ":5671")}"
RABBITMQ_USER="${var.app["brand"]}"
RABBITMQ_PASSWORD='${random_password.this["mq"].result}'

ELASTICSEARCH_ENDPOINT="https://${aws_elasticsearch_domain.this.endpoint}:443"

REDIS_CACHE_BACKEND="${aws_elasticache_replication_group.this["cache"].primary_endpoint_address}"
REDIS_SESSION_BACKEND="${aws_elasticache_replication_group.this["session"].primary_endpoint_address}"
REDIS_CACHE_BACKEND_RO="${aws_elasticache_replication_group.this["cache"].reader_endpoint_address}"
REDIS_SESSION_BACKEND_RO="${aws_elasticache_replication_group.this["session"].reader_endpoint_address}"
	
OUTER_ALB_DNS_NAME="${aws_lb.this["outer"].dns_name}"
INNER_ALB_DNS_NAME="${aws_lb.this["inner"].dns_name}"

CLOUDFRONT_ADDRESS=${aws_cloudfront_distribution.this.domain_name}

EFS_DNS_TARGET="${values(aws_efs_mount_target.this).0.dns_name}"

CODECOMMIT_APP_REPO="codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name}"
CODECOMMIT_SERVICES_REPO="codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name}"
	  
SES_KEY=${aws_iam_access_key.ses_smtp_user_access_key.id}
SES_SECRET=${aws_iam_access_key.ses_smtp_user_access_key.secret}
SES_PASSWORD=${aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4}

HTTP_X_HEADER="${random_uuid.this.result}"

EOF

  tags = {
    Name = "${var.app["brand"]}-aws-infrastructure-params"
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

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document runShellScript to install magento, push to codecommit, init git
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "install_magento" {
  name          = "${var.app["brand"]}-install-magento-push-codecommit"
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
  name: "${var.app["brand"]}InstallMagentoPushCodecommit"
  inputs:
    runCommand:
    - |-
      #!/bin/bash
      cd /home/${var.app["brand"]}/public_html
      su ${var.app["brand"]} -s /bin/bash -c "echo 007 > magento_umask"
      su ${var.app["brand"]} -s /bin/bash -c "echo -e '/pub/media/*\n/var/*'" > .gitignore
      su ${var.app["brand"]} -s /bin/bash -c "composer -n -q config -g http-basic.repo.magento.com 8c681734f22763b50ea0c29dff9e7af2 02dfee497e669b5db1fe1c8d481d6974"
      su ${var.app["brand"]} -s /bin/bash -c "composer install -n"
      chmod +x bin/magento
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento module:enable --all"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:install \
      --base-url=https://${var.app["domain"]}/ \
      --base-url-secure=https://${var.app["domain"]}/ \
      --db-host=${aws_db_instance.this.endpoint} \
      --db-name=${aws_db_instance.this.name} \
      --db-user=${aws_db_instance.this.username} \
      --db-password='${random_password.this["rds"].result}' \
      --admin-firstname=${var.app["brand"]} \
      --admin-lastname=${var.app["brand"]} \
      --admin-email=${var.app["admin_email"]} \
      --admin-user=admin \
      --admin-password='${random_password.this["app"].result}' \
      --backend-frontname='admin_${random_string.this["admin_path"].result}' \
      --language=${var.app["language"]} \
      --currency=${var.app["currency"]} \
      --timezone=${var.app["timezone"]} \
      --cleanup-database \
      --session-save=files \
      --use-rewrites=1 \
      --use-secure=1 \
      --use-secure-admin=1 \
      --consumers-wait-for-messages=0 \
      --amqp-host=${trimsuffix(trimprefix("${aws_mq_broker.this.instances.0.endpoints.0}", "amqps://"), ":5671")} \
      --amqp-port=5671 \
      --amqp-user=${var.app["brand"]} \
      --amqp-password='${random_password.this["mq"].result}' \
      --amqp-virtualhost='/' \
      --amqp-ssl=true \
      --search-engine=elasticsearch7 \
      --elasticsearch-host="https://${aws_elasticsearch_domain.this.endpoint}" \
      --elasticsearch-port=443 \
      --elasticsearch-index-prefix=${var.app["brand"]} \
      --elasticsearch-enable-auth=0"
      ## installation check
      if [[ $? -ne 0 ]]; then
      echo
      echo "Installation error - check command output log"
      exit 1
      fi
      if [ ! -f /home/${var.app["brand"]}/public_html/app/etc/env.php ]; then
      echo "Installation error - env.php not available"
      exit 1
      fi
      ## cache backend
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:config:set \
      --cache-id-prefix="${random_string.this["id_prefix"].result}_" \
      --cache-backend=redis \
      --cache-backend-redis-server=${aws_elasticache_replication_group.this["cache"].primary_endpoint_address} \
      --cache-backend-redis-port=6379 \
      --cache-backend-redis-db=0 \
      --cache-backend-redis-compress-data=1 \
      --cache-backend-redis-compression-lib=l4z \
      -n"
      ## session
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:config:set \
      --session-save=redis \
      --session-save-redis-host=${aws_elasticache_replication_group.this["session"].primary_endpoint_address} \
      --session-save-redis-port=6379 \
      --session-save-redis-log-level=3 \
      --session-save-redis-db=0 \
      --session-save-redis-compression-lib=lz4 \
      --session-save-redis-persistent-id=${random_string.this["persistent"].result} \
      -n"
      ## add cache optimization
      sed -i "/${aws_elasticache_replication_group.this["cache"].primary_endpoint_address}/a\            'load_from_slave' => '${aws_elasticache_replication_group.this["cache"].reader_endpoint_address}:6379', \\
            'master_write_only' => '0', \\
            'retry_reads_on_master' => '1', \\
            'persistent' => '${random_string.this["persistent"].result}', \\
            'preload_keys' => [ \\
                    '${random_string.this["id_prefix"].result}_EAV_ENTITY_TYPES', \\
                    '${random_string.this["id_prefix"].result}_GLOBAL_PLUGIN_LIST', \\
                    '${random_string.this["id_prefix"].result}_DB_IS_UP_TO_DATE', \\
                    '${random_string.this["id_prefix"].result}_SYSTEM_DEFAULT', \\
                ],"  app/etc/env.php
      ## clean cache
      rm -rf var/cache var/page_cache
      ## enable s3 remote storage
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:config:set --remote-storage-driver=aws-s3 \
      --remote-storage-bucket=${aws_s3_bucket.this["media"].bucket} \
      --remote-storage-region=${data.aws_region.current.name} \
      --remote-storage-key=${aws_iam_access_key.s3.id} \
      --remote-storage-secret="${aws_iam_access_key.s3.secret}" \
      -n"
      ## sync to s3 remote storage
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento remote-storage:sync"
      ## install modules to properly test magento 2 production-ready functionality
      su ${var.app["brand"]} -s /bin/bash -c "composer -n require fooman/sameorderinvoicenumber-m2 fooman/emailattachments-m2 fooman/printorderpdf-m2 mageplaza/module-smtp magefan/module-blog stripe/stripe-payments"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:upgrade -n --no-ansi"
      ## correct general contact name and email address
      su ${var.app["brand"]} -s /bin/bash -c 'bin/magento config:set trans_email/ident_general/name ${var.app["brand"]}'
      su ${var.app["brand"]} -s /bin/bash -c 'bin/magento config:set trans_email/ident_general/email ${var.app["admin_email"]}'
      ## configure smtp ses 
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/general/enabled 1"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/general/log_email 0"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/host email-smtp.${data.aws_region.current.name}.amazonaws.com"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/port 587"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/protocol tls"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/authentication login"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/username ${aws_iam_access_key.ses_smtp_user_access_key.id}"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/password ${aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4}"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/test_email/from general"
      su ${var.app["brand"]} -s /bin/bash -c 'bin/magento config:set smtp/configuration_option/test_email/to ${var.app["admin_email"]}'
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/developer/developer_mode 0"
      ## explicitly set the new catalog media url format
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/url/catalog_media_url_format image_optimization_parameters"
      ## configure cloudfront media / static base url
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/unsecure/base_media_url https://${aws_cloudfront_distribution.this.domain_name}/media/"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/secure/base_media_url https://${aws_cloudfront_distribution.this.domain_name}/media/"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/unsecure/base_static_url https://${aws_cloudfront_distribution.this.domain_name}/static/"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/secure/base_static_url https://${aws_cloudfront_distribution.this.domain_name}/static/"
      ## minify js and css
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set dev/css/minify_files 1"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set dev/js/minify_files 1"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set dev/js/move_script_to_bottom 1"
      ## enable hsts upgrade headers
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/secure/enable_hsts 1"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/secure/enable_upgrade_insecure 1"
      ## enable eav cache
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set dev/caching/cache_user_defined_attributes 1"
      ## deploy production mode
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento deploy:mode:set production"
      if [[ $? -ne 0 ]]; then
      echo
      echo "Code compilation error"
      exit 1
      fi
      git add . -A
      git commit -m ${var.app["brand"]}-init-$(date +'%y%m%d-%H%M%S')
      git remote add origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name}
      git branch -m main
      git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name} main
EOT
}



///////////////////////////////////////////////////////[ AWS WAFv2 RULES ]////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create AWS WAFv2 rules
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_wafv2_web_acl" "this" {
  name        = "${var.app["brand"]}-WAF-Protections"
  provider    = aws.useast1
  scope       = "CLOUDFRONT"
  description = "${var.app["brand"]}-WAF-Protections"

  default_action {
    allow {
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name = "${var.app["brand"]}-WAF-Protections"
    sampled_requests_enabled = true
  }

  rule {
    name     = "${var.app["brand"]}-Cloudfront-WAF-media-Protection-rate-based"
    priority = 0

    action {
      count {}
    }

    statement {
      rate_based_statement {
       limit              = 100
       aggregate_key_type = "IP"
       
       scope_down_statement {
         byte_match_statement {
          field_to_match {
              uri_path   {}
              }
          search_string  = "/media/"
          positional_constraint = "STARTS_WITH"

          text_transformation {
            priority   = 0
            type       = "NONE"
           }
         }
       }
     }
  }
      visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app["brand"]}-Cloudfront-WAF-Protection-rate-based-rule"
      sampled_requests_enabled   = true
    }
   }
   
   rule {
    name     = "${var.app["brand"]}-Cloudfront-WAF-static-Protection-rate-based"
    priority = 1

    action {
      count {}
    }

    statement {
      rate_based_statement {
       limit              = 200
       aggregate_key_type = "IP"
       
       scope_down_statement {
         byte_match_statement {
          field_to_match {
              uri_path   {}
              }
          search_string  = "/static/"
          positional_constraint = "STARTS_WITH"

          text_transformation {
            priority   = 0
            type       = "NONE"
           }
         }
       }
     }
    }
      visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app["brand"]}-Cloudfront-WAF-static-Protection-rate-based-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name = "AWSManagedRulesCommonRule"
    priority = 2
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "${var.app["brand"]}-AWSManagedRulesCommonRule"
      sampled_requests_enabled = true
    }
  }
  rule {
    name = "AWSManagedRulesAmazonIpReputation"
    priority = 3
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "${var.app["brand"]}-AWSManagedRulesAmazonIpReputation"
      sampled_requests_enabled = true
    }
  }
  rule {
    name = "AWSManagedRulesBotControlRule"
    priority = 4
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "${var.app["brand"]}-AWSManagedRulesBotControlRule"
      sampled_requests_enabled = true
    }
  }
}
