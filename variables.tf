

locals {
   # Create global project name to be assigned to all resources
   project = lower("${var.app["brand"]}-${random_string.this["project"].result}")
   environment = lower(terraform.workspace)
}

variable "password" {
   description = "Generate password"
   default     = [
      "rds",
      "rabbitmq",
      "app",
      "blowfish",
      "redis",
      "opensearch"
   ]
}

variable "string" {
   description = "Generate random string"
   default     = [
      "admin_path", 
      "mysql_path", 
      "profiler", 
      "session_persistent", 
      "cache_prefix", 
      "health_check", 
      "project",
      "opensearch"
   ]
}

variable "ec2" {
  description  = "EC2 instances names and types included in AutoScaling groups"
  default      = {
    varnish    = "m7g.large"
    frontend   = "c7g.xlarge"
    admin      = "c7g.xlarge"
   }
}

variable "app" {
  description      = "Map application params | Magento 2"
  default          = {
    install          = "enabled"
    source_repo      = "magenx/Magento-2"
    app_version      = "2"
    cidr_block       = "172.30.0.0/16"
    brand            = "magenx"
    domain           = "magenx.org"
    admin_email      = "admin@magenx.org"
    admin_login      = "admin"
    admin_firstname  = "Hereis"
    admin_lastname   = "Myname"
    source           = "https://github.com/magenx/Magento-2.git"
    language         = "en_US"
    currency         = "EUR"
    timezone         = "UTC"
    php_version      = "8.3"
    php_packages     = "cli fpm common mysql zip gd mbstring curl xml bcmath intl soap oauth apcu"
    linux_packages   = "nfs-common unzip git patch python3-pip acl attr imagemagick snmp binutils pkg-config libssl-dev"
    exclude_linux_packages = "apache2* *apcu-bc"
    volume_size      = "50"
    composer_user    = "8c681734f22763b50ea0c29dff9e7af2"
    composer_pass    = "02dfee497e669b5db1fe1c8d481d6974"
  }
}

variable "opensearch" {
  description      = "Map OpenSearch configuration values"
  default  = {
    engine_version         = "OpenSearch_2.13"
    instance_type          = "m6g.large.search"
    instance_count         = "1"
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
    storage_type           = "gp3"
    storage_encrypted      = true
    engine                 = "mariadb"
    engine_version         = "10.11.6"
    family                 = "mariadb10.11"
    instance_class         = "db.m7g.large"
    skip_final_snapshot    = true
    multi_az               = false
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
    volume_size           = "50"
    monitoring            = false
    warm_pool             = "disabled"
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
    evaluation_periods_in  = "2"
    evaluation_periods_out = "1"
    period                 = "300"
    out_threshold          = "80"
    in_threshold           = "25"
  }
}

variable "s3" {
  description = "S3 bucket names"
  type        = set(string)
  default     = ["media", "media-optimized", "system", "backup", "state"]
}

variable "alb" {
  description = "Application Load Balancer configuration values"
  default     = {
    type               = ["internal","external"]
    rps_threshold      = "5000"
    error_threshold    = "25"
    }
}

variable "efs" {
  description = "Create shared folders in EFS"
  default     = {
    path      = ["var","media"]
    }
}

variable "ec2_instance_profile_policy" {
  description = "Policy attach to EC2 Instance Profile"
  type        = set(string)
  default     = [
  "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess",
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

variable "aws_config_rule" {
  description = "Use AWS Config to evaluate critical configuration settings for your AWS resources."
  default     = {
  ROOT_ACCOUNT_MFA_ENABLED                  = ""
  MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS        = ""
  EC2_STOPPED_INSTANCE                      = ""
  INCOMING_SSH_DISABLED                     = "AWS::EC2::SecurityGroup"
  DB_INSTANCE_BACKUP_ENABLED                = "AWS::RDS::DBInstance"
  RDS_SNAPSHOTS_PUBLIC_PROHIBITED           = "AWS::RDS::DBSnapshot"
  RDS_INSTANCE_DELETION_PROTECTION_ENABLED  = "AWS::RDS::DBInstance"
  EC2_IMDSV2_CHECK                          = "AWS::EC2::Instance"
  EC2_VOLUME_INUSE_CHECK                    = "AWS::EC2::Volume"
  ELB_DELETION_PROTECTION_ENABLED           = "AWS::ElasticLoadBalancingV2::LoadBalancer"
  }
}

# Define the variable for resource types
variable "resource_types" {
  type = list(string)
  default = [
    "AWS::EC2::Instance",
    "AWS::S3::Bucket",
    "AWS::IAM::Role",
    "AWS::IAM::User",
    "AWS::RDS::DBInstance",
    "AWS::EC2::VPC",
    "AWS::EC2::Subnet",
    "AWS::EC2::SecurityGroup"
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

variable "restricted_countries" {
  description = "List of country codes to restrict access to"
  type        = list(string)
  default     = ["CN", "RU", "IR", "KP", "SD", "SY", "CU"]
}



## Regions with Regional Edge Caches
locals {
  rec_regions = {
    US_EAST_2       = "us-east-2"
    US_EAST_1       = "us-east-1"
    US_WEST_2       = "us-west-2"
    AP_SOUTH_1      = "ap-south-1"
    AP_NORTHEAST_2  = "ap-northeast-2"
    AP_SOUTHEAST_1  = "ap-southeast-1"
    AP_SOUTHEAST_2  = "ap-southeast-2"
    AP_NORTHEAST_1  = "ap-northeast-1"
    EU_CENTRAL_1    = "eu-central-1"
    EU_WEST_1       = "eu-west-1"
    EU_WEST_2       = "eu-west-2"
    SA_EAST_1       = "sa-east-1"
  }
## Other supported regions
  other_regions = {
    US_WEST_1       = "us-west-1"
    AF_SOUTH_1      = "af-south-1"
    AP_EAST_1       = "ap-east-1"
    CA_CENTRAL_1    = "ca-central-1"
    EU_SOUTH_1      = "eu-south-1"
    EU_WEST_3       = "eu-west-3"
    EU_NORTH_1      = "eu-north-1"
    ME_SOUTH_1      = "me-south-1"
  }
## Region to Origin Shield mappings based on latency.
## To be updated when new Regions are available or new RECs are added to CloudFront.
  region_to_origin_shield_mappings = merge(
    {
      (local.rec_regions.US_EAST_2)       = local.rec_regions.US_EAST_2
      (local.rec_regions.US_EAST_1)       = local.rec_regions.US_EAST_1
      (local.rec_regions.US_WEST_2)       = local.rec_regions.US_WEST_2
      (local.rec_regions.AP_SOUTH_1)      = local.rec_regions.AP_SOUTH_1
      (local.rec_regions.AP_NORTHEAST_2)  = local.rec_regions.AP_NORTHEAST_2
      (local.rec_regions.AP_SOUTHEAST_1)  = local.rec_regions.AP_SOUTHEAST_1
      (local.rec_regions.AP_SOUTHEAST_2)  = local.rec_regions.AP_SOUTHEAST_2
      (local.rec_regions.AP_NORTHEAST_1)  = local.rec_regions.AP_NORTHEAST_1
      (local.rec_regions.EU_CENTRAL_1)    = local.rec_regions.EU_CENTRAL_1
      (local.rec_regions.EU_WEST_1)       = local.rec_regions.EU_WEST_1
      (local.rec_regions.EU_WEST_2)       = local.rec_regions.EU_WEST_2
      (local.rec_regions.SA_EAST_1)       = local.rec_regions.SA_EAST_1
    },
    {
      (local.other_regions.US_WEST_1)     = local.rec_regions.US_WEST_2
      (local.other_regions.AF_SOUTH_1)    = local.rec_regions.EU_WEST_1
      (local.other_regions.AP_EAST_1)     = local.rec_regions.AP_SOUTHEAST_1
      (local.other_regions.CA_CENTRAL_1)  = local.rec_regions.US_EAST_1
      (local.other_regions.EU_SOUTH_1)    = local.rec_regions.EU_CENTRAL_1
      (local.other_regions.EU_WEST_3)     = local.rec_regions.EU_WEST_2
      (local.other_regions.EU_NORTH_1)    = local.rec_regions.EU_WEST_2
      (local.other_regions.ME_SOUTH_1)    = local.rec_regions.AP_SOUTH_1
    }
  )

  origin_shield_region = lookup(local.region_to_origin_shield_mappings, data.aws_region.current.name, null)
}
