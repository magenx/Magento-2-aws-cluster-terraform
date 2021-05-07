variable "ec2" {
  description  = "EC2 instances names and types included in AutoScaling groups"
  default      = {
    varnish    = "m6g.large"
    frontend   = "c6g.xlarge"
    admin      = "c6g.xlarge"
    staging    = "c6g.xlarge"
   }
}

variable "ec2_extra" {
  description  = "EC2 instance name and type for build and developer systems"
  default      = {
        build      = "t4g.micro"
        developer  = "c6g.xlarge"
   }
}

variable "magento" {
  description      = "Map Magento 2 config values"
  default          = {
    mage_owner            = "magenx"
    mage_domain           = "demo.magenx.com"
    mage_admin_email      = "admin@magenx.com"
    mage_staging_domain   = "staging.magenx.com"
    mage_developer_domain = "dev.magenx.com"
    mage_source           = "https://github.com/magenx/Magento-2.git"
    admin_path            = "ADMIN_PLACEHOLDER"
    language              = "en_US"
    currency              = "EUR"
    timezone              = "UTC"
    php_version           = "7.4"
  }
}

variable "elk" {
  description      = "Map ElasticSearch configuration values"
  default  = {
    domain_name            = "elk"
    elasticsearch_version  = "7.9"
    instance_type          = "m6g.xlarge.elasticsearch"
    instance_count         = "1"
    ebs_enabled            = true
    volume_type            = "gp2"
    volume_size            = "10"
  }
}

variable "rds" {
  description      = "Map RDS configuration values"
  default  = {
    name                   = "magento"
    allocated_storage      = "20"
    max_allocated_storage  = "100"
    storage_type           = "gp2"
    engine_version         = "8.0.21"
    instance_class         = "db.m6g.large"
    engine                 = "mysql"
    parameter_group_name   = "default.mysql8.0"
    skip_final_snapshot    = "true"
  }
}
      
variable "mq" {
  description      = "Map RabbitMQ configuration values"
  default  = {
    broker_name            = "queue"
    engine_version         = "3.8.11"
    host_instance_type     = "mq.t3.micro"
  }
}

variable "redis" {
  description      = "Map ElastiCache Redis configuration values"
  default  = {    
    node_type                  = "cache.m6g.large"
    parameter_group_name       = "default.redis6.x.cluster.on"
    replicas_per_node_group    = "2"
    num_node_groups            = "1"
    name                       = ["session", "cache"]
  }
}
          
variable "asg" {
  description      = "Map Autoscaling Group configuration values"
  default  = {
    desired_capacity      = "1"
    min_size              = "1"
    max_size              = "5"
    health_check_type     = "EC2"
    health_check_grace_period = "300"
  }
}
          
variable "asp" {
  description      = "Map Autoscaling Policy configuration values"
  default  = {    
    evaluation_periods  = "2"
    period        = "300"
    out_threshold = "60"
    in_threshold  = "25"
  }
}

variable "s3" {
  description = "S3 bucket names"
  type        = set(string)
  default     = ["media", "system"]
}

variable "efs" {
  description = "EFS names"
  type        = set(string)
  default     = ["developer", "staging"]
}

variable "alb" {
  description = "Application Load Balancer names and type"
  default     = {
    outer     = false
    inner     = true
    }
}

variable "ec2_instance_profile_policy" {
  description = "Policy attach to EC2 Instance Profile"
  type        = set(string)
  default     = [
  "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

variable "eventsbridge_policy" {
  description = "Policy attach to EventsBridge role"
  type        = set(string)
  default     = [
  "arn:aws:iam::aws:policy/service-role/CloudWatchEventsBuiltInTargetExecutionAccess", 
  "arn:aws:iam::aws:policy/service-role/CloudWatchEventsInvocationAccess",
  "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
  ]
}

variable "az_number" {
  description = "Assign a number to each AZ letter used in secondary cidr/subnets configuration"
  default = {
    a = 0
    b = 1
    c = 2
    d = 3
    e = 4
    f = 5
  }
}

locals {
  security_group = setunion(keys(var.alb),var.redis["name"],["ec2","rds","elk","mq","efs"])
}

locals {
 security_rule = {
  outer_alb_https_in = {
    type        = "ingress"
    description = "Allow all inbound traffic on the load balancer https listener port"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.security_group["outer"].id
    },
  outer_alb_http_in = {
    type        = "ingress"
    description = "Allow all inbound traffic on the load balancer http listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.security_group["outer"].id
    },
  outer_alb_http_out = {
    type        = "egress"
    description = "Allow outbound traffic to instances on the load balancer listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["ec2"].id
    security_group_id = aws_security_group.security_group["outer"].id
    },
  inner_alb_http_in = {
    type        = "ingress"
    description = "Allow inbound traffic from the VPC CIDR on the load balancer listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["ec2"].id
    security_group_id = aws_security_group.security_group["inner"].id
    },
  inner_alb_http_out = {
    type        = "egress"
    description = "Allow outbound traffic to instances on the load balancer listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["ec2"].id
    security_group_id = aws_security_group.security_group["inner"].id
    },
  ec2_https_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance https port"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.security_group["ec2"].id
    },
  ec2_http_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.security_group["ec2"].id
    },
  ec2_mysql_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance MySql port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["rds"].id
    security_group_id = aws_security_group.security_group["ec2"].id
    },
  ec2_rabbitmq_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance RabbitMQ port"
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["mq"].id
    security_group_id = aws_security_group.security_group["ec2"].id
    },
  ec2_redis_session_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance Redis port"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["session"].id
    security_group_id = aws_security_group.security_group["ec2"].id
    },
  ec2_redis_cache_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance Redis port"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["cache"].id
    security_group_id = aws_security_group.security_group["ec2"].id
    },
  ec2_efs_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance NFS port"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["efs"].id
    security_group_id = aws_security_group.security_group["ec2"].id
    },
  ec2_elk_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance ELK port"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["elk"].id
    security_group_id = aws_security_group.security_group["ec2"].id
    },
  ec2_http_in = {
    type        = "ingress"
    description = "Allow all inbound traffic from the load balancer on http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["inner"].id
    security_group_id = aws_security_group.security_group["ec2"].id
    },
  ec2_http_in = {
    type        = "ingress"
    description = "Allow all inbound traffic from the load balancer on http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["outer"].id
    security_group_id = aws_security_group.security_group["ec2"].id
    },
  rds_mysql_in = {
    type        = "ingress"
    description = "Allow access instances to MySQL Port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["ec2"].id
    security_group_id = aws_security_group.security_group["rds"].id
    },
  redis_session_in = {
    type        = "ingress"
    description = "Allow access instances to Redis Session"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["ec2"].id
    security_group_id = aws_security_group.security_group["session"].id
    },
  redis_cache_in = {
    type        = "ingress"
    description = "Allow access instances to Redis Cache"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["ec2"].id
    security_group_id = aws_security_group.security_group["cache"].id
    },
  rabbitmq_in = {
    type        = "ingress"
    description = "Allow access instances to RabbitMQ"
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    source_security_group_id = aws_security_group.security_group["ec2"].id
    security_group_id = aws_security_group.security_group["mq"].id
    },
  efs_in = {
    type        = "ingress"
    description = "Allow access instances to EFS target"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.security_group["ec2"].id
    security_group_id = aws_security_group.security_group["efs"].id
    },
  efs_out = {
    type        = "egress"
    description = "Allow access instances to EFS target"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.security_group["ec2"].id
    security_group_id = aws_security_group.security_group["efs"].id
    },
  elk_in = {
    type        = "ingress"
    description = "Allow inbound traffic to the instance ELK port"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.security_group["ec2"].id
    security_group_id = aws_security_group.security_group["elk"].id
    },
  elk_out = {
    type        = "egress"
    description = "Allow outbound traffic to the instance ELK port"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.security_group["ec2"].id
    security_group_id = aws_security_group.security_group["elk"].id
    },
  }
}
