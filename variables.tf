variable "ec2" {
  description  = "EC2 instances names and types included in AutoScaling groups"
  default      = {
    varnish    = "m6g.large"
    frontend   = "c6g.xlarge"
    admin      = "c6g.xlarge"
    staging    = "c6g.xlarge"
    build      = "t4g.micro"
   }
}

variable "app" {
  description      = "Map application params | Magento 2"
  default          = {
    brand            = "magenx"
    domain           = "magenx.com"
    admin_email      = "admin@magenx.com"
    staging_domain   = "stg.magenx.com"
    source           = "https://github.com/magenx/Magento-2.git"
    language         = "en_US"
    currency         = "EUR"
    timezone         = "UTC"
    php_version      = "7.4"
  }
}

variable "elk" {
  description      = "Map ElasticSearch configuration values"
  default  = {
    domain_name            = "elk"
    elasticsearch_version  = "7.9"
    instance_type          = "m6g.large.elasticsearch"
    instance_count         = "3"
    ebs_enabled            = true
    volume_type            = "gp2"
    volume_size            = "10"
  }
}

variable "rds" {
  description      = "Map RDS configuration values"
  default  = {
    name                   = ["production","staging"]
    allocated_storage      = "20"
    max_allocated_storage  = "100"
    storage_type           = "gp2"
    engine_version         = "10.5.8"
    instance_class         = "db.m6g.large"
    engine                 = "mariadb"
    parameter_group_name   = "default.mariadb10.5"
    skip_final_snapshot    = true
    multi_az               = true
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
    replicas_per_node_group    = "1"
    num_node_groups            = "2"
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
    out_threshold = "80"
    in_threshold  = "25"
  }
}

variable "s3" {
  description = "S3 bucket names"
  type        = set(string)
  default     = ["media", "system"]
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

variable "eventbridge_policy" {
  description = "Policy attach to EventBridge role"
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
    security_group_id = aws_security_group.this["outer"].id
    },
  outer_alb_http_in = {
    type        = "ingress"
    description = "Allow all inbound traffic on the load balancer http listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.this["outer"].id
    },
  outer_alb_http_out = {
    type        = "egress"
    description = "Allow outbound traffic to instances on the load balancer listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["outer"].id
    },
  inner_alb_http_in = {
    type        = "ingress"
    description = "Allow inbound traffic from the VPC CIDR on the load balancer listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["inner"].id
    },
  inner_alb_http_out = {
    type        = "egress"
    description = "Allow outbound traffic to instances on the load balancer listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["inner"].id
    },
  ec2_https_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance https port"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_http_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_mysql_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance MySql port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["rds"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_rabbitmq_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance RabbitMQ port"
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["mq"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_redis_session_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance Redis port"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["session"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_redis_cache_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance Redis port"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["cache"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_efs_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance NFS port"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["efs"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_elk_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance ELK port"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["elk"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_http_in_inner = {
    type        = "ingress"
    description = "Allow all inbound traffic from the load balancer on http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["inner"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_http_in_outer = {
    type        = "ingress"
    description = "Allow all inbound traffic from the load balancer on http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["outer"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  rds_mysql_in = {
    type        = "ingress"
    description = "Allow access instances to MySQL Port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["rds"].id
    },
  redis_session_in = {
    type        = "ingress"
    description = "Allow access instances to Redis Session"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["session"].id
    },
  redis_cache_in = {
    type        = "ingress"
    description = "Allow access instances to Redis Cache"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["cache"].id
    },
  rabbitmq_in = {
    type        = "ingress"
    description = "Allow access instances to RabbitMQ"
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["mq"].id
    },
  efs_in = {
    type        = "ingress"
    description = "Allow access instances to EFS target"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["efs"].id
    },
  efs_out = {
    type        = "egress"
    description = "Allow access instances to EFS target"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["efs"].id
    },
  elk_in = {
    type        = "ingress"
    description = "Allow inbound traffic to the instance ELK port"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["elk"].id
    },
  elk_out = {
    type        = "egress"
    description = "Allow outbound traffic to the instance ELK port"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["elk"].id
    },
  }
}
