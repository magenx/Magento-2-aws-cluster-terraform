
variable "github_repo" {
  description = "Magento GitHub repository"
  type        = string
}

variable "brand" {
  description = "Business brand name"
  type        = string
}

variable "domain" {
  description = "Shop domain name"
  type        = string
}

variable "admin_email" {
  description = "Shop admin email"
  type        = string
}

locals {
   # Create global project name to be assigned to all resources
   project = lower("${var.brand}-${random_string.this["project"].result}")
   environment = lower(terraform.workspace)
}

locals {
  default_tags = {
    Managed      = "terraform"
    Brand        = var.brand
    Environment  = local.environment
    Dns          = "${var.brand}.internal"
  }
}

locals {
  ec2_setup = {
    Setup = "s3_system_setup"
  }
}

variable "password" {
   description = "Generate password"
   default     = [
      "rds", 
      "rabbitmq", 
      "magento", 
      "blowfish",
      "redis",
      "opensearch"
   ]
}

variable "vpc" {
  description      = "Configuration for VPC"
  default          = {
    enable_dns_support   = true
    enable_dns_hostnames = true
    instance_tenancy     = "default"
    cidr_block           = "172.35.0.0/16"
  }
}

variable "string" {
   description = "Generate random string"
   default     = [
      "admin_path",
      "mysql_path",
      "health_check",
      "project",
      "opensearch"
   ]
}

variable "ec2" {
  description  = "EC2 instances names and types included in AutoScaling groups"
  default      = {
    frontend   = "c7g.xlarge"
   }
}


variable "opensearch" {
  description      = "Map OpenSearch configuration values"
  default  = {
    engine_version         = "OpenSearch_2.13"
    instance_type          = "m6g.large.search"
    instance_count         = "3"
    ebs_enabled            = true
    volume_type            = "gp3"
    volume_size            = "50"
    log_type               = "ES_APPLICATION_LOGS"
  }
}

locals {
  db_name_prefix = replace(local.project, "-", "_")
  db_name        = "${local.db_name_prefix}_${local.environment}"
}

variable "rds" {
  description      = "Map RDS configuration values"
  default  = {
    allocated_storage      = "50"
    max_allocated_storage  = "100"
    storage_type           = ""
    storage_encrypted      = true
    engine                 = "aurora-mysql"
    engine_version         = "8.0.mysql_aurora.3.07.1"
    family                 = "mysql8.0"
    instance_class         = "db.m7g.large"
    skip_final_snapshot    = true
    enabled_cloudwatch_logs_exports = "error"
    performance_insights_enabled = true
    copy_tags_to_snapshot    = true
    backup_retention_period  = "0"
    delete_automated_backups = true
    deletion_protection      = false
  }
}

variable "max_connection_count" {
  description = "Map 7g. class RDS max connection count"
  default = {
     "db.m7g.large"    = "683"
     "db.m7g.xlarge"   = "1365"
     "db.r7g.large"    = "1365"
     "db.m7g.2xlarge"  = "2731"
     "db.r7g.xlarge"   = "2731"
     "db.m7g.4xlarge"  = "5461"
     "db.r7g.2xlarge"  = "5461"
     "db.m7g.8xlarge"  = "10923"
     "db.r7g.4xlarge"  = "10923"
     "db.m7g.12xlarge" = "16384"
     "db.m7g.16xlarge" = "21845"
     "db.r7g.8xlarge"  = "21845"
     "db.r7g.12xlarge" = "32768"
     "db.r7g.16xlarge" = "43691"
  }
}

variable "rds_memory" {
  description = "Map 7g. class RDS memory gb"
  default = {
     "db.m7g.large"    = "8"
     "db.r7g.large"    = "16"
     "db.m7g.xlarge"   = "16"
     "db.r7g.xlarge"   = "32"
     "db.m7g.2xlarge"  = "32"
     "db.r7g.2xlarge"  = "64"
     "db.m7g.4xlarge"  = "64"
     "db.m7g.8xlarge"  = "128"
     "db.r7g.4xlarge"  = "128"
     "db.m7g.12xlarge" = "192"
     "db.m7g.16xlarge" = "256"
     "db.r7g.8xlarge"  = "256"
     "db.r7g.12xlarge" = "384"
     "db.r7g.16xlarge" = "512"
  }
}

variable "rds_parameters" {
  description = "Map RDS MariaDB Parameters"
  default = [
    {
      name    = "max_allowed_packet"
      value   = "268435456"
    },
    {
      name    = "max_connect_errors"
      value   = "500"
    },
    {
      name    = "interactive_timeout"
      value   = "7200"
    },
    {
      name    = "wait_timeout"
      value   = "7200"
    },
    {
      name    = "innodb_lock_wait_timeout"
      value   = "60"
    },
    {
      name    = "innodb_flush_log_at_trx_commit"
      value   = "2"
    },
    {
      name    = "tmp_table_size"
      value   = "{DBInstanceClassMemory/512}"
    },
    {
      name    = "max_heap_table_size"
      value   = "{DBInstanceClassMemory/512}"
    }
  ]
}

variable "rabbitmq" {
  description      = "Map RabbitMQ configuration values"
  default  = {
    engine_version         = "3.12.13"
    deployment_mode        = "SINGLE_INSTANCE" ## "CLUSTER_MULTI_AZ"
    host_instance_type     = "mq.m5.large"
  }
}

variable "redis" {
  description      = "Map ElastiCache Redis configuration values"
  default  = {
    num_cache_clusters            = "1"
    node_type                     = "cache.m7g.large"
    name                          = ["session", "cache"]
    family                        = "redis7"
    engine_version                = "7.1"
    port                          = "6379"
    at_rest_encryption_enabled    = true
  }
}

variable "redis_parameters" {
  description = "Map ElastiCache Redis Parameters"
  default = [
  {
    name  = "cluster-enabled"
    value = "no"
  },
  {
    name  = "maxmemory-policy"
    value = "allkeys-lfu"
  }
 ]
}

variable "asg" {
  description      = "Map Autoscaling Group configuration values"
  default  = {
    health_check_type     = "EC2"
    health_check_grace_period = "300"
  }
}
          
variable "asp" {
  description      = "Map Autoscaling Policy configuration values"
  default  = {    
    evaluation_periods_in  = "2"
    evaluation_periods_out = "1"
    period                 = "300"
    out_threshold          = "80"
    in_threshold           = "25"
  }
}

variable "alb" {
  description      = "Map Application Load Balancer configuration values"
  default  = {
    enable_deletion_protection = false
    rps_threshold       = "5000"
    error_threshold     = "25"
  }
}

variable "efs" {
  description = "Create shared folders in EFS"
  default     = {
    path      = ["var","media"]
    }
}

variable "s3" {
  description = "S3 bucket names"
  type        = set(string)
  default     = ["media", "system"]
}

variable "ec2_instance_profile_policy" {
  description = "Policy attach to EC2 Instance Profile"
  type        = set(string)
  default     = [
  "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
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
    g = 6
  }
}
