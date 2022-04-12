

locals {
   # Create global project name to be assigned to all resources
   project = lower("${var.app["brand"]}-${random_string.this["project"].result}")
}

variable "default_tags" {
 description    = "Default tags to simplify global tag management"
 default        = {
   Managed      = "terraform"
   Config       = "magenx"
   Environment  = "development"
 }
}

variable "password" {
   description = "Generate password"
   default     = [
      "rds", 
      "rabbitmq", 
      "app", 
      "blowfish"
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
      "project"
   ]
}

variable "ec2" {
  description  = "EC2 instances names and types included in AutoScaling groups"
  default      = {
    frontend   = "c6g.xlarge"
    admin      = "c6g.xlarge"
   }
}

variable "fastly" {
  description  = "Enable Fastly CDN. If disabled = Varnish cache will be installed locally on EC2 frontend"
  default      = "enabled"
}

variable "app" {
  description      = "Map application params | Magento 2"
  default          = {
    source_repo      = "magenx/Magento-2"
    app_version      = "2"
    cidr_block       = "172.30.0.0/16"
    brand            = "magenx"
    domain           = "magenx.org"
    admin_email      = "admin@magenx.org"
    admin_login      = "admin"
    admin_firstname  = "Hereis"
    admin_lastname   = "Myname"
    language         = "en_US"
    currency         = "EUR"
    timezone         = "UTC"
    php_version      = "7.4"
    php_packages     = "cli fpm json common mysql zip gd mbstring curl xml bcmath intl soap oauth lz4 apcu"
    linux_packages   = "nfs-common git patch python3-pip acl attr imagemagick snmp rsync"
    exclude_linux_packages = "apache2* *apcu-bc"
    composer_user    = "8c681734f22763b50ea0c29dff9e7af2"
    composer_pass    = "02dfee497e669b5db1fe1c8d481d6974"
  }
}

variable "elk" {
  description      = "Map ElasticSearch configuration values"
  default  = {
    elasticsearch_version  = "7.9"
    instance_type          = "m6g.large.elasticsearch"
    instance_count         = "1"
    ebs_enabled            = true
    volume_type            = "gp2"
    volume_size            = "20"
    log_type               = "ES_APPLICATION_LOGS"
  }
}

variable "rds" {
  description      = "Map RDS configuration values"
  default  = {
    db_name                = "m2_magenx_live"
    allocated_storage      = "50"
    max_allocated_storage  = "100"
    storage_type           = "gp2"
    storage_encrypted      = true
    engine                 = "mariadb"
    engine_version         = "10.5.12"
    family                 = "mariadb10.5"
    instance_class         = "db.m6g.large"
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
  description = "Map 6g. class RDS max connection count"
  default = {
     "db.m6g.large"    = "683"
     "db.m6g.xlarge"   = "1365"
     "db.r6g.large"    = "1365"
     "db.m6g.2xlarge"  = "2731"
     "db.r6g.xlarge"   = "2731"
     "db.m6g.4xlarge"  = "5461"
     "db.r6g.2xlarge"  = "5461"
     "db.m6g.8xlarge"  = "10923"
     "db.r6g.4xlarge"  = "10923"
     "db.m6g.12xlarge" = "16384"
     "db.m6g.16xlarge" = "21845"
     "db.r6g.8xlarge"  = "21845"
     "db.r6g.12xlarge" = "32768"
     "db.r6g.16xlarge" = "43691"
  }
}

variable "rds_memory" {
  description = "Map 6g. class RDS memory gb"
  default = {
     "db.m6g.large"    = "8"
     "db.r6g.large"    = "16"
     "db.m6g.xlarge"   = "16"
     "db.r6g.xlarge"   = "32"
     "db.m6g.2xlarge"  = "32"
     "db.r6g.2xlarge"  = "64"
     "db.m6g.4xlarge"  = "64"
     "db.m6g.8xlarge"  = "128"
     "db.r6g.4xlarge"  = "128"
     "db.m6g.12xlarge" = "192"
     "db.m6g.16xlarge" = "256"
     "db.r6g.8xlarge"  = "256"
     "db.r6g.12xlarge" = "384"
     "db.r6g.16xlarge" = "512"
  }
}
      
variable "rabbitmq" {
  description      = "Map RabbitMQ configuration values"
  default  = {
    engine_version         = "3.8.11"
    deployment_mode        = "CLUSTER_MULTI_AZ"
    host_instance_type     = "mq.m5.large"
  }
}

variable "redis" {
  description      = "Map ElastiCache Redis configuration values"
  default  = {
    num_cache_clusters         = "1"
    node_type                  = "cache.m6g.large"
    name                       = ["session", "cache"]
    engine_version                = "6.x"
    family                        = "redis6.x"
    port                          = "6379"
    at_rest_encryption_enabled    = true
  }
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

variable "alb" {
  description      = "Map Application Load Balancer configuration values"
  default  = {
    enable_deletion_protection = false
    rps_threshold       = "5000"
    error_threshold     = "25"
  }
}

variable "s3" {
  description = "S3 bucket names"
  type        = set(string)
  default     = ["media", "system", "backup", "state"]
}

variable "ec2_instance_profile_policy" {
  description = "Policy attach to EC2 Instance Profile"
  type        = set(string)
  default     = [
  "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
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
