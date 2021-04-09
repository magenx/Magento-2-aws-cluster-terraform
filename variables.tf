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
  description      = "Map some magento values"
  default          = {
    mage_owner            = "magenx"
    mage_domain           = "demo.magenx.com"
    mage_admin_email      = "admin@magenx.com"
    mage_staging_domain   = "staging.magenx.com"
    mage_developer_domain = "developer.magenx.com"
    admin_path            = "ADMIN_PLACEHOLDER"
    language              = "en_US"
    currency              = "EUR"
    timezone              = "UTC"
    php_version           = "7.4"
  }
}

variable "elk" {
  description      = "Map some ElasticSearch configuration values"
  default  = {
    domain_name            = "magenx-elk"
    elasticsearch_version  = "7.9"
    instance_type          = "t2.small.elasticsearch"
    instance_count         = "1"
    ebs_enabled            = true
    volume_type            = "gp2"
    volume_size            = "10"
  }
}

variable "rds" {
  description      = "Map some RDS configuration values"
  default  = {
    name     = "magenx_aws_demo"
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
	  
variable "redis" {
  description      = "Map some ElastiCache configuration values"
  default  = {    
    node_type                  = "cache.m6g.large"
    parameter_group_name       = "default.redis6.x.cluster.on"
    replicas_per_node_group    = "2"
    num_node_groups            = "1"
    name                       = ["session", "cache"]
  }
}
	  
variable "asg" {
  description      = "Map some Autoscaling configuration values"
  default  = {
    desired_capacity      = "1"
    min_size              = "1"
    max_size              = "5"
    health_check_type     = "EC2"
    health_check_grace_period = "300"
  }
}
	  
variable "asp" {
  description      = "Map some Autoscaling Policy configuration values"
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
  description = "Load balanser names"
  type        = set(string)
  default     = ["outer", "inner"]
}

variable "ec2_instance_profile_policy" {
  description = "Policy attach to ec2 instance profile"
  type        = set(string)
  default     = [
  "arn:aws:iam::aws:policy/AWSCodeCommitFullAccess", 
  "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy", 
  "arn:aws:iam::aws:policy/AmazonS3FullAccess", 
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

locals {
  outer_alb_security_rules = {
  https_in = {
    type        = "ingress"
    description = "Allow all inbound traffic on the load balancer https listener port"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    },
  http_in = {
    type        = "ingress"
    description = "Allow all inbound traffic on the load balancer http listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    },
  http_out = {
    type        = "egress"
    description = "Allow outbound traffic to instances on the instance listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = data.aws_security_group.security_group.id
    }
  }
}

locals {
  inner_alb_security_rules = {
  http_in = {
    type        = "ingress"
    description = "Allow inbound traffic from the VPC CIDR on the load balancer listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    },
  http_out = {
    type        = "egress"
    description = "Allow outbound traffic to instances on the instance listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = data.aws_security_group.security_group.id
    }
  }
}
