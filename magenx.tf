


///////////////////////////////////////////////////[ RANDOM STRING GENERATOR ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Generate random uuid string that is intended to be used as unique identifier
# # ---------------------------------------------------------------------------------------------------------------------#
resource "random_uuid" "uuid" {
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Generate random passwords
# # ---------------------------------------------------------------------------------------------------------------------#
resource "random_password" "password" {
  count            = 4
  length           = 16
  lower            = true
  upper            = true
  number           = true
  special          = true
  override_special = "!#$%&*?"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Generate random string
# # ---------------------------------------------------------------------------------------------------------------------#
resource "random_string" "string" {
  length           = 7
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
  name = "${var.app["brand"]}-email-alerts"
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
  count                     = data.aws_region.current.name != "us-east-1" ? 1 : 0
  domain_name               = "${var.app["domain"]}"
  subject_alternative_names = ["*.${var.app["domain"]}"]
  validation_method         = "EMAIL"

lifecycle {
    create_before_destroy   = true
  }
}

resource "aws_acm_certificate" "cloudfront" {
  provider                  = aws.us
  domain_name               = "${var.app["domain"]}"
  subject_alternative_names = ["*.${var.app["domain"]}"]
  validation_method         = "EMAIL"

lifecycle {
    create_before_destroy   = true
  }
}

resource "aws_acm_certificate_validation" "default" {
  count           = data.aws_region.current.name != "us-east-1" ? 1 : 0
  certificate_arn = aws_acm_certificate.default[0].arn
}

resource "aws_acm_certificate_validation" "cloudfront" {
  certificate_arn = aws_acm_certificate.cloudfront.arn
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
  count           = length(data.aws_subnet_ids.default.ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = tolist(data.aws_subnet_ids.default.ids)[count.index]
  security_groups = [aws_security_group.this["efs"].id]
}



////////////////////////////////////////////////////////[ CODECOMMIT ]////////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeCommit repository for application code
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codecommit_repository" "this" {
  repository_name = var.app["domain"]
  description     = "Magento 2.x code for ${var.app["domain"]}"
    tags = {
    Name = "${var.app["brand"]}-${var.app["domain"]}"
  }
  provisioner "local-exec" {
  interpreter = ["/bin/bash", "-c"]
  command = <<EOF
          git clone -b aws ${var.app["source"]} /tmp/magento
          cd /tmp/magento
          git remote add origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.this.repository_name}
          git branch -m main
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.this.repository_name} main
          rm -rf /tmp/magento
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
  depends_on = [aws_acm_certificate_validation.cloudfront]
  origin {
    domain_name = aws_s3_bucket.this["media"].bucket_regional_domain_name
    origin_id   = "${var.app["domain"]}-media-assets"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
    }
	  
    custom_header {
      name  = "X-Magenx-Header"
      value = random_uuid.uuid.result
    }
  }

  aliases = [var.app["domain"]]

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.app["domain"]} media assets"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.this["system"].bucket_domain_name
    prefix          = "${var.app["brand"]}-cloudfront-logs"
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.app["domain"]}-media-assets"

    compress = true
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.this.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.this.id

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
    acm_certificate_arn = aws_acm_certificate.cloudfront.arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }
}




/////////////////////////////////////////////////////[ EC2 INSTANCE PROFILE ]/////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "ec2" {
  name = "${var.app["brand"]}-EC2InstanceRole"
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
  for_each   = var.ec2_instance_profile_policy
  role       = aws_iam_role.ec2.name
  policy_arn = each.value
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create inline policy for EC2 service role to limit CodeCommit access
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy" "codecommit_access" {
  name = "PolicyForCodeCommitAccess"
  role = aws_iam_role.ec2.id

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
      Resource = aws_codecommit_repository.this.arn
    }
  ]
})
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 Instance Profile
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_instance_profile" "this" {
  name = "${var.app["brand"]}-EC2InstanceProfile"
  role = aws_iam_role.ec2.name
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
  user {
    username = var.app["brand"]
    password = random_password.password[0].result
  }
  tags = {
    Name   = "${var.app["brand"]}-${var.mq["broker_name"]}"
  }
}



//////////////////////////////////////////////////////////[ ELASTICACHE ]/////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElastiCache - Redis Replication group - session + cache
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_elasticache_replication_group" "this" {
  for_each                      = toset(var.redis["name"])
  engine                        = "redis"
  replication_group_id          = "${var.app["brand"]}-${each.key}-backend"
  replication_group_description = "Replication group for ${var.app["domain"]} ${each.key} backend"
  node_type                     = var.redis["node_type"]
  port                          = 6379
  parameter_group_name          = var.redis["parameter_group_name"]
  security_group_ids            = [aws_security_group.this[each.key].id]
  automatic_failover_enabled    = true
  multi_az_enabled              = true

  cluster_mode {
    replicas_per_node_group = var.redis["replicas_per_node_group"]
    num_node_groups         = var.redis["num_node_groups"]
  }
}



//////////////////////////////////////////////////////////[ S3 STORAGE ]//////////////////////////////////////////////////

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
# Create policy for CloudFront and EC2 to limit S3 media bucket access
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket_policy" "media" {
  bucket = aws_s3_bucket.this["media"].id
  policy = jsonencode(
            {
              Id        = "PolicyForMediaStorageAccess"
              Statement = [
                    {
                      Action    = "s3:GetObject"
                      Effect    = "Allow"
                      Principal = {
                          AWS = aws_cloudfront_origin_access_identity.this.iam_arn
                        }
                      Resource  = "${aws_s3_bucket.this["media"].arn}/*"
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
                          AWS = aws_iam_role.ec2.arn
                        }
                      Resource  = "${aws_s3_bucket.this["media"].arn}/*"
                    },
                    {
                      Action = [
                          "s3:GetBucketLocation",
                          "s3:ListBucket"
                        ],
                      Effect    = "Allow"
                      Principal = {
                          AWS = aws_iam_role.ec2.arn
                        }
                      Resource  = "${aws_s3_bucket.this["media"].arn}"
                    },
                ]
              Version   = "2012-10-17"
            }
        )
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
# Create ElasticSearch service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_service_linked_role" "elasticsearch_domain" {
  aws_service_name = "es.amazonaws.com"
  lifecycle {
    create_before_destroy   = true
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElasticSearch domain
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_elasticsearch_domain" "this" {
  depends_on = [aws_iam_service_linked_role.elasticsearch_domain]
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
  advanced_security_options {
    enabled = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name = "elastic"
      master_user_password = "${random_password.password[3].result}"
    }
  }
  node_to_node_encryption  {
    enabled = true
  }
  ebs_options {
    ebs_enabled = var.elk["ebs_enabled"]
    volume_type = var.elk["volume_type"]
    volume_size = var.elk["volume_size"]
  }
  vpc_options {
    subnet_ids = slice(tolist(data.aws_subnet_ids.default.ids), 0, var.elk["instance_count"])
    security_group_ids = [aws_security_group.this["elk"].id]
  }
  tags = {
    Name = "${var.app["brand"]}-${var.elk["domain_name"]}"
  }
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elk.arn
    log_type                 = "ES_APPLICATION_LOGS"
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
# Create RDS instance
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_db_instance" "this" {
  identifier            = "${var.app["brand"]}-${var.rds["name"]}-database"
  allocated_storage     = var.rds["allocated_storage"]
  max_allocated_storage = var.rds["max_allocated_storage"]
  storage_type          = var.rds["storage_type"] 
  engine                = var.rds["engine"]
  engine_version        = var.rds["engine_version"]
  instance_class        = var.rds["instance_class"]
  multi_az              = var.rds["multi_az"]
  name                  = "${var.app["brand"]}_${var.rds["name"]}"
  username              = var.app["brand"]
  password              = random_password.password[1].result
  parameter_group_name  = var.rds["parameter_group_name"]
  skip_final_snapshot   = var.rds["skip_final_snapshot"]
  vpc_security_group_ids = [aws_security_group.this["rds"].id]
  copy_tags_to_snapshot = true
  enabled_cloudwatch_logs_exports = ["general"]
  tags = {
    Name = "${var.app["brand"]}-database"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS instance event subscription
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_db_event_subscription" "db_event_subscription" {
  name      = "${var.app["brand"]}-rds-event-subscription"
  sns_topic = aws_sns_topic.default.arn
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
resource "aws_cloudwatch_metric_alarm" "cpu_utilization_too_high" {
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
    DBInstanceIdentifier = "${aws_db_instance.this.id}"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch Freeable Memory metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "freeable_memory_too_low" {
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
    DBInstanceIdentifier = "${aws_db_instance.this.id}"
  }
}



///////////////////////////////////////////////////////[ SECURITY GROUPS ]////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Security Groups
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "this" {
  for_each    = local.security_group
  name        = "${var.app["brand"]}-${each.key}"
  description = "${each.key} security group"
  vpc_id      = data.aws_vpc.default.id
  
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
	
	
	
/////////////////////////////////////////////////[ APPLICATION LOAD BALANCER ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Application Load Balancers
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb" "this" {
  for_each           = var.alb
  name               = "${var.app["brand"]}-${each.key}-alb"
  internal           = each.value
  load_balancer_type = "application"
  security_groups    = [aws_security_group.this[each.key].id]
  subnets            = data.aws_subnet_ids.default.ids
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
  vpc_id      = data.aws_vpc.default.id
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create https:// listener for OUTER Load Balancer - forward to varnish
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener" "outerhttps" {
  depends_on = [aws_acm_certificate_validation.cloudfront, aws_acm_certificate_validation.default]
  load_balancer_arn = aws_lb.this["outer"].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  certificate_arn   = data.aws_region.current.name != "us-east-1" ? aws_acm_certificate.default[0].arn : aws_acm_certificate.cloudfront.arn
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
# Create default listener for INNER Load Balancer - forward to frontend
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener" "inner" {
  load_balancer_arn = aws_lb.this["inner"].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["frontend"].arn
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
    target_group_arn = aws_lb_target_group.this["admin"].arn
  }
  condition {
    path_pattern {
      values = ["/admin_${random_string.string.result}/*"]
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
    target_group_arn = aws_lb_target_group.this["staging"].arn
  }
  condition {
    host_header {
	values = [var.app["staging_domain"]]
    }
  }
}


/////////////////////////////////////////////////////[ AUTOSCALING CONFIGURATION ]////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Launch Template for Autoscaling Groups - user_data converted
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_launch_template" "this" {
  for_each = var.ec2
  name = "${var.app["brand"]}-${each.key}-lt"
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs { 
        volume_size = "50"
        volume_type = "gp3"
            }
  }
  iam_instance_profile { name = aws_iam_instance_profile.this.name }
  image_id = data.aws_ami.ubuntu_2004.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = each.value
  monitoring { enabled = false }
  network_interfaces { 
    associate_public_ip_address = true
    security_groups = [aws_security_group.this["ec2"].id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.app["brand"]}-${each.key}-ec2" }
  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.app["brand"]}-${each.key}-ec2" }
  }
  user_data = base64encode(data.template_file.user_data[each.key].rendered)
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling Groups
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_group" "this" {
  for_each = var.ec2
  name = "${var.app["brand"]}-${each.key}-asg"
  vpc_zone_identifier = data.aws_subnet_ids.default.ids
  desired_capacity    = var.asg["desired_capacity"]
  min_size            = var.asg["min_size"]
  max_size            = (each.key == "build" ? 1 : var.asg["max_size"])
  health_check_grace_period = var.asg["health_check_grace_period"]
  health_check_type         = var.asg["health_check_type"]
  target_group_arns  = [aws_lb_target_group.this[each.key].arn]
  launch_template {
    name    = aws_launch_template.this[each.key].name
    version = "$Latest"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling groups actions for SNS topic email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_notification" "this" {
for_each = aws_autoscaling_group.this 
group_names = [
    aws_autoscaling_group.this[each.key].name
  ]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = aws_sns_topic.default.arn
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling policy for scale-out
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_policy" "scaleout" {
  for_each               = {for name,type in var.ec2: name => type if name != "build"}
  name                   = "${var.app["brand"]}-${each.key}-asp-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this[each.key].name
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch alarm metric to execute Autoscaling policy for scale-out
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "scaleout" {
  for_each            = {for name,type in var.ec2: name => type if name != "build"}
  alarm_name          = "${var.app["brand"]}-${each.key} scale-out alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.asp["evaluation_periods"]
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.asp["period"]
  statistic           = "Average"
  threshold           = var.asp["out_threshold"]
  dimensions = {
    AutoScalingGroupName  = aws_autoscaling_group.this[each.key].name
  }
  alarm_description = "${each.key} scale-out alarm - CPU exceeds ${var.asp["out_threshold"]} percent"
  alarm_actions     = [aws_autoscaling_policy.scaleout[each.key].arn]
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling policy for scale-in
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_policy" "scalein" {
  for_each               = {for name,type in var.ec2: name => type if name != "build"}
  name                   = "${var.app["brand"]}-${each.key}-asp-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this[each.key].name
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch alarm metric to execute Autoscaling policy for scale-in
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "scalein" {
  for_each            = {for name,type in var.ec2: name => type if name != "build"}
  alarm_name          = "${var.app["brand"]}-${each.key} scale-in alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.asp["evaluation_periods"]
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.asp["period"]
  statistic           = "Average"
  threshold           = var.asp["in_threshold"]
  dimensions = {
    AutoScalingGroupName  = aws_autoscaling_group.this[each.key].name
  }
  alarm_description = "${each.key} scale-in alarm - CPU less than ${var.asp["in_threshold"]} percent"
  alarm_actions     = [aws_autoscaling_policy.scalein[each.key].arn]
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
# Create EventBridge rule to monitor CodeCommit repository state
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "codecommit_main" {
  name        = "${var.app["brand"]}-EventBridge-Rule-CodeCommit-Repository-State-Change"
  description = "CloudWatch monitor magento repository state change main branch"
  event_pattern = <<EOF
{
	"source": ["aws.codecommit"],
	"detail-type": ["CodeCommit Repository State Change"],
	"resources": ["${aws_codecommit_repository.this.arn}"],
	"detail": {
		"referenceType": ["branch"],
		"referenceName": ["main"]
	}
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge target to execute SSM Document
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "codecommit_main" {
  rule      = aws_cloudwatch_event_rule.codecommit_main.name
  target_id = "${var.app["brand"]}-EventBridge-Target-Git-Deployment-Script"
  arn       = aws_ssm_document.ssm_document_pull_main.arn
  role_arn  = aws_iam_role.eventbridge_service_role.arn
 
run_command_targets {
    key    = "tag:Name"
    values = [aws_launch_template.this["admin"].tag_specifications[0].tags.Name,aws_launch_template.this["frontend"].tag_specifications[0].tags.Name]
  }
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
  name = uuid()
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
DATABASE_PASSWORD='${random_password.password[1].result}'

ADMIN_PATH='admin_${random_string.string.result}'
ADMIN_PASSWORD='${random_password.password[2].result}'

RABBITMQ_ENDPOINT="${trimsuffix(trimprefix("${aws_mq_broker.this.instances.0.endpoints.0}", "amqps://"), ":5671")}"
RABBITMQ_USER="${var.app["brand"]}"
RABBITMQ_PASSWORD='${random_password.password[0].result}'

ELASTICSEARCH_ENDPOINT="${aws_elasticsearch_domain.this.endpoint}:443"
ELASTICSEARCH_USER="elastic"
ELASTICSEARCH_PASSWORD="${random_password.password[3].result}"

REDIS_CACHE_BACKEND="${aws_elasticache_replication_group.this["cache"].configuration_endpoint_address}"
REDIS_SESSION_BACKEND="${aws_elasticache_replication_group.this["session"].configuration_endpoint_address}"

OUTER_ALB_DNS_NAME="${aws_lb.this["outer"].dns_name}"
INNER_ALB_DNS_NAME="${aws_lb.this["inner"].dns_name}"

CLOUDFRONT_ADDRESS=${aws_cloudfront_distribution.this.domain_name}

EFS_DNS_TARGET="${aws_efs_mount_target.this[0].dns_name}"

CODECOMMIT_REPO_NAME="${aws_codecommit_repository.this.repository_name}"
	  
SES_KEY=${aws_iam_access_key.ses_smtp_user_access_key.id}
SES_SECRET=${aws_iam_access_key.ses_smtp_user_access_key.secret}
SES_PASSWORD=${aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4}

HTTP_X_HEADER="${random_uuid.uuid.result}"

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
              {
                "file_path": "/home/${var.app["brand"]}/public_html/var/log/php-fpm-error.log",
                "log_group_name": "${var.app["brand"]}_php_error_logs",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
              },
              {
                "file_path": "/home/${var.app["brand"]}/public_html/var/log/exception.log",
                "log_group_name": "${var.app["brand"]}_magento_error_logs",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}"
              },
              {
                "file_path": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log",
                "log_group_name": "${var.app["brand"]}_cloudwatch_agent_log",
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
        "force_flush_interval" : 5
      }
}
EOF

  tags = {
    Name = "amazon-cloudwatch-agent-${each.key}.json"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document runShellScript to pull main branch from CodeCommit
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "ssm_document_pull_main" {
  name          = "${var.app["brand"]}-codecommit-pull-main-changes"
  document_type = "Command"
  document_format = "YAML"
  target_type   = "/AWS::EC2::Instance"
  content = <<EOT
---
schemaVersion: "2.2"
description: "Pull code changes from CodeCommit main branch"
parameters:
mainSteps:
- action: "aws:runShellScript"
  name: "${var.app["brand"]}CodecommitPullMainChanges"
  inputs:
    runCommand:
    - |-
      #!/bin/bash
      cd /home/${var.app["brand"]}/public_html
      su ${var.app["brand"]} -s /bin/bash -c "git fetch origin"
      su ${var.app["brand"]} -s /bin/bash -c "git reset --hard origin/main"
      systemctl reload php${var.app["php_version"]}-fpm
      systemctl reload nginx
EOT
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document runShellScript to pull staging branch from CodeCommit
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "ssm_document_pull_staging" {
  name          = "${var.app["brand"]}-codecommit-pull-staging-changes"
  document_type = "Command"
  document_format = "YAML"
  target_type   = "/AWS::EC2::Instance"
  content = <<EOT
---
schemaVersion: "2.2"
description: "Pull code changes from CodeCommit staging branch"
parameters:
mainSteps:
- action: "aws:runShellScript"
  name: "${var.app["brand"]}CodecommitPullStagingChanges"
  inputs:
    runCommand:
    - |-
      #!/bin/bash
      cd /home/${var.app["brand"]}/public_html
      su ${var.app["brand"]} -s /bin/bash -c "git fetch origin"
      su ${var.app["brand"]} -s /bin/bash -c "git reset --hard origin/staging"
      systemctl reload php${var.app["php_version"]}-fpm
      systemctl reload nginx
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento cache:flush"
EOT
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document runShellScript to install magento, push to codecommit, init git
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "ssm_document_install" {
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
      chmod +x bin/magento
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento module:enable --all"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:install \
      --base-url=https://${var.app["domain"]}/ \
      --base-url-secure=https://${var.app["domain"]}/ \
      --db-host=${aws_db_instance.this.endpoint} \
      --db-name=${aws_db_instance.this.name} \
      --db-user=${aws_db_instance.this.username} \
      --db-password='${random_password.password[1].result}' \
      --admin-firstname=${var.app["brand"]} \
      --admin-lastname=${var.app["brand"]} \
      --admin-email=${var.app["admin_email"]} \
      --admin-user=admin \
      --admin-password='${random_password.password[2].result}' \
      --backend-frontname='admin_${random_string.string.result}' \
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
      --amqp-password='${random_password.password[0].result}' \
      --amqp-virtualhost='/' \
      --amqp-ssl=true \
      --search-engine=elasticsuite \
      --es-hosts="${aws_elasticsearch_domain.this.endpoint}:443" \
      --es-user=elastic \
      --es-pass='${random_password.password[3].result}' \
      --es-enable-ssl=1 \
      --remote-storage-driver=aws-s3 \
      --remote-storage-bucket=${aws_s3_bucket.this["media"].bucket} \
      --remote-storage-region=${data.aws_region.current.name}"
      ## installation check
      if [ ! -f /home/${var.app["brand"]}/public_html/app/etc/env.php ]; then
      echo "installation error"
      exit 1
      fi
      ## cache backend
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:config:set \
      --cache-backend=redis \
      --cache-backend-redis-server=${aws_elasticache_replication_group.this["cache"].configuration_endpoint_address} \
      --cache-backend-redis-port=6379 \
      --cache-backend-redis-db=1 \
      --cache-backend-redis-compress-data=1 \
      --cache-backend-redis-compression-lib=l4z \
      -n"
      ## session
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:config:set \
      --session-save=redis \
      --session-save-redis-host=${aws_elasticache_replication_group.this["session"].configuration_endpoint_address} \
      --session-save-redis-port=6379 \
      --session-save-redis-log-level=3 \
      --session-save-redis-db=1 \
      --session-save-redis-compression-lib=lz4 \
      -n"
      ## configure smtp ses 
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/general/enabled 1"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/general/log_email 0"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/host email-smtp.eu-west-1.amazonaws.com"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/port 587"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/protocol tls"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/authentication login"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/username ${aws_iam_access_key.ses_smtp_user_access_key.secret}"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/password ${aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4}"
      su ${var.app["brand"]} -s /bin/bash -c 'bin/magento config:set smtp/configuration_option/return_path_email ${var.app["admin_email"]}'
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/test_email/from general"
      su ${var.app["brand"]} -s /bin/bash -c 'bin/magento config:set smtp/configuration_option/test_email/to ${var.app["admin_email"]}'
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/developer/developer_mode 0"
      ## configure cloudfront media base url
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/unsecure/base_media_url ${aws_cloudfront_distribution.this.domain_name}"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/secure/base_media_url ${aws_cloudfront_distribution.this.domain_name}"
      ## deploy production mode
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento deploy:mode:set production"
      git add . -A
      git commit -m ${var.app["brand"]}-release-$(date +'%y%m%d-%H%M%S')
      git remote add origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.this.repository_name}
      git branch -m main
      git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.this.repository_name} main
EOT
}
