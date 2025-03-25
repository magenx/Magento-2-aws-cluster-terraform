variable "ecr" {
  description = "ECR repository configuration"
  type = object({
    force_delete = bool
  })
}

variable "ecs" {
  description = "ECS service configuration"
  type = object({
    desired_count                      = number
    deployment_minimum_healthy_percent = number
    deployment_maximum_percent         = number
    service_name                       = string
    container_port                     = number
    host_port                          = number
    cpu_units                          = number
    memory                             = number
  })
}

variable "github_repo" {
  description = "Magento GitHub repository"
  type        = string
}

variable "brand" {
  description = "Business brand name"
  type        = string
}

variable "codename" {
  description = "Project codename"
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
   project = lower("${var.brand}-${var.codename}-${substr(lower(terraform.workspace), 0, 1)}")
   # Get env from workspace
   environment = lower(terraform.workspace)
}

locals {
  default_tags = {
    Managed      = "terraform"
    Brand        = var.brand
    Environment  = local.environment
    Project      = local.project
  }
}

variable "password" {
   description = "Generate password"
   default     = [
      "rds",
      "rabbitmq",
      "redis",
      "opensearch"
   ]
}

variable "string" {
   description = "Generate random string"
   default     = [
      "admin_path",
      "health_check",
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
    availability_zones_qty = "2"
  }
}

variable "ec2" {
  default = {
    frontend = {
      instance_type    = "c7g.xlarge"
      volume_size      = "25"
      desired_capacity = "2"
      min_size         = "2"
      max_size         = "8"
    }
    varnish = {
      instance_type    = "c7g.large"
      volume_size      = "25"
      desired_capacity = "2"
      min_size         = "2"
      max_size         = "8"
    }
}

variable "opensearch" {
  description      = "Map OpenSearch configuration values"
  default  = {
    engine_version         = "OpenSearch_2.17"
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
  db_name        = "${local.db_name_prefix}"
}

variable "rds" {
  description      = "Map RDS configuration values"
  default  = {
    allocated_storage      = "50"
    max_allocated_storage  = "100"
    storage_type           = "gp3"
    storage_encrypted      = true
    engine                 = "mariadb"
    engine_version         = "10.11.21"
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
    engine_version         = "3.13"
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

variable "s3" {
  description = "S3 bucket names"
  type        = set(string)
  default     = ["media", "media-optimized", "system", "backup"]
}

variable "alb" {
  description = "Application Load Balancer configuration values"
  default     = {
    rps_threshold      = "5000"
    error_threshold    = "25"
    }
}

# Variable for EFS paths, UIDs, GIDs, and permissions
variable "efs" {
  type = map(object({
    uid         = number
    gid         = number
    permissions = string
  }))
  default = {
    var    = { uid = 1001, gid = 1002, permissions = "2770" }
    media  = { uid = 1001, gid = 1002, permissions = "2770" }
  }
}

variable "ec2_instance_profile_policy" {
  description = "Policy attach to EC2 Instance Profile"
  type        = set(string)
  default     = [
  "arn:aws:iam::aws:policy/AWSCloudMapRegisterInstanceAccess",
  "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess",
  "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
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

variable "restricted_countries" {
  description = "List of country codes to restrict access to"
  type        = list(string)
  default     = ["CN", "RU", "IR", "KP", "SD", "SY", "CU"]
}

locals {
  # Read the CSV files to get IPs
  whitelist_ips = csvdecode(file("${abspath(path.root)}/waf_whitelist.csv"))
  blacklist_ips = csvdecode(file("${abspath(path.root)}/waf_blacklist.csv"))
  # Define whitelist and blacklist IP sets
  waf_ipset = {
    whitelist = {
      name        = "${local.project}-whitelist-ip-set"
      description = "IP set for whitelisted IP addresses"
      addresses   = local.whitelist_ips[*].ip_address
    }
    blacklist = {
      name        = "${local.project}-blacklist-ip-set"
      description = "IP set for blacklisted IP addresses"
      addresses   = local.blacklist_ips[*].ip_address
    }
  }
  # Define rules for whitelist and blacklist
  waf_ipset_rules = {
    allow-whitelisted-ips = {
      priority     = 0
      action       = "allow"
      ip_set_key   = "whitelist"
      metric_name  = "${local.project}-allow-whitelisted-ips"
    }
    block-blacklisted-ips = {
      priority     = 1
      action       = "block"
      ip_set_key   = "blacklist"
      metric_name  = "${local.project}-block-blacklisted-ips"
    }
  }
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
