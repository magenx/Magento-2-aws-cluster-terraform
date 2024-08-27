

locals {
   # Create global project name to be assigned to all resources
   project = lower("${var.magento["brand"]}-${random_string.this["project"].result}")
   environment = lower(terraform.workspace)
}

variable "password" {
   description = "Generate password"
   default     = [
      "mariadb",
      "mariadb_root",
      "rabbitmq",
      "redis",
      "opensearch",
      "indexer",
      "blowfish"
   ]
}

variable "string" {
   description = "Generate random string"
   default     = [
      "admin_path", 
      "phpmyadmin", 
      "profiler", 
      "health_check", 
      "project",
      "opensearch"
   ]
}

variable "ec2" {
  default = {
    frontend = {
      instance_type    = "c7g.xlarge"
      service          = null
      volume_size      = "25"
      warm_pool        = "enabled"
      desired_capacity = "1"
      min_size         = "1"
      max_size         = "5"
    }
    admin = {
      instance_type    = "c7g.xlarge"
      service          = null
      volume_size      = "25"
      warm_pool        = "enabled"
      desired_capacity = "1"
      min_size         = "1"
      max_size         = "5"
    }
    opensearch = {
      instance_type    = "c7g.large"
      service          = true
      volume_size      = "100"
      warm_pool        = "disabled"
      desired_capacity = "1"
      min_size         = "1"
      max_size         = "1"
    }
    redis = {
      instance_type    = "c7g.large"
      service          = true
      volume_size      = "25"
      warm_pool        = "disabled"
      desired_capacity = "1"
      min_size         = "1"
      max_size         = "1"
    }
    rabbitmq = {
      instance_type    = "c7g.medium"
      service          = true
      volume_size      = "25"
      warm_pool        = "disabled"
      desired_capacity = "1"
      min_size         = "1"
      max_size         = "1"
    }
    mariadb = {
      instance_type    = "m7g.2xlarge"
      service          = true
      volume_size      = "25"
      warm_pool        = "disabled"
      desired_capacity = "1"
      min_size         = "1"
      max_size         = "1"
    }
  }
}

variable "magento" {
  description      = "Map application params | Magento 2"
  default          = {
    app_version      = "2"
    cidr_block       = "172.35.0.0/16"
    brand            = "magenx"
    domain           = "magenx.org"
    admin_email      = "admin@magenx.org"
    admin_login      = "admin"
    language         = "en_US"
    currency         = "EUR"
    timezone         = "UTC"
    php_version      = "8.3"
    php_packages     = "cli fpm common mysql zip gd mbstring curl xml bcmath intl soap oauth apcu"
    linux_packages   = "nfs-common unzip git patch python3-pip acl attr imagemagick snmp binutils pkg-config libssl-dev"
    exclude_linux_packages = "apache2* *apcu-bc"
    composer_user    = "8c681734f22763b50ea0c29dff9e7af2"
    composer_pass    = "02dfee497e669b5db1fe1c8d481d6974"
  }
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
  MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS        = "AWS::IAM::User"
  EC2_STOPPED_INSTANCE                      = "AWS::EC2::Instance"
  INCOMING_SSH_DISABLED                     = "AWS::EC2::SecurityGroup"
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
