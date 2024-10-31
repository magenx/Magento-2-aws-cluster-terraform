


//////////////////////////////////////////////////////////////[ RDS ]/////////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS subnet group in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_db_subnet_group" "this" {
  name       = "${local.project}-db-subnet"
  description = "RDS Subnet for ${replace(local.project,"-"," ")}"
  subnet_ids = values(aws_subnet.this).*.id
  tags = {
    Name = "${local.project}-db-subnet"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS parameter groups
# # ---------------------------------------------------------------------------------------------------------------------#		
resource "aws_db_parameter_group" "this" {
  name              = "${local.project}-parameters"
  family            = var.rds["family"]
  description       = "Parameter group for ${local.project} database"
   dynamic "parameter" {
    for_each = var.rds_parameters
    content {
      name  = parameter.value["name"]
      value = parameter.value["value"]
    }
  }
  tags = {
    Name = "${local.project}-parameters"
  }
}

data "aws_iam_policy_document" "monitoring_rds_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  description         = "IAM Role for RDS Enhanced monitoring"
  path                = "/"
  assume_role_policy  = data.aws_iam_policy_document.monitoring_rds_assume_role.json
  managed_policy_arns = ["arn:${data.aws_region.current.name}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]
  tags = {
    Name = "${local.project}-rds-enhanced-monitoring"
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS Aurora cluster and instance
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_rds_cluster" "this" {
  cluster_identifier          = "${local.project}-aurora-cluster"
  engine                      = var.rds["engine"]
  engine_version              = var.rds["engine_version"]
  availability_zones          = []
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = [aws_security_group.rds.id]
  port                        = "3306"
  database_name               = local.db_name
  master_username                  = var.magento["brand"]
  master_password                  = random_password.this["rds"].result
  db_cluster_parameter_group_name  = aws_rds_cluster_parameter_group.this.id
  db_instance_parameter_group_name = aws_db_parameter_group.this.id
  backup_retention_period          = var.rds["backup_retention_period"]
  storage_encrypted               = var.rds["storage_encrypted"]
  storage_type                    = var.rds["storage_type"]
  apply_immediately               = true
  skip_final_snapshot             = var.rds["skip_final_snapshot"]
  final_snapshot_identifier       = var.rds["skip_final_snapshot"] ? null : "${local.project}-${local.db_name}-${formatdate("YYYYMMDDHHMMSS", timestamp())}"
  enabled_cloudwatch_logs_exports = [var.rds["enabled_cloudwatch_logs_exports"]]
  tags = {
    Name = "${local.project}-rds"
  }

  lifecycle {
    ignore_changes = [
      replication_source_identifier,
      snapshot_identifier,
      engine_version
    ]
  }
}

resource "aws_rds_cluster_instance" "this" {
  identifier                   = "${local.project}-aurora-cluster-instance"
  cluster_identifier           = aws_rds_cluster.this.id
  engine                       = var.rds["engine"]
  engine_version               = var.rds["engine_version"]
  instance_class               = var.rds["instance_class"]
  db_subnet_group_name         = aws_db_subnet_group.this.name
  db_parameter_group_name      = aws_db_parameter_group.this.id
  performance_insights_enabled = var.rds["performance_insights_enabled"]
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = aws_iam_role.rds_enhanced_monitoring.arn
  apply_immediately            = true
  tags = {
    Name = "${local.project}-aurora-cluster-instance"
  }
}


# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS instance event subscription
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_db_event_subscription" "db_event_subscription" {
  name      = "${local.project}-rds-event-subscription"
  sns_topic = aws_sns_topic.default.arn
  source_type = "db-instance"
  source_ids = [aws_rds_cluster_instance.this.identifier]
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
  alarm_name          = "${local.project} rds cpu utilization too high"
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
    DBInstanceIdentifier = aws_rds_cluster_instance.this.id
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch Freeable Memory metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "rds_memory" {
  alarm_name          = "${local.project} rds freeable memory too low"
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
    DBInstanceIdentifier = aws_rds_cluster_instance.this.id
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch Connections Anomaly metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "rds_connections_anomaly" {
  alarm_name          = "${local.project} rds connections anomaly"
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
        DBInstanceIdentifier = aws_rds_cluster_instance.this.id
      }
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch Max Connections metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "rds_max_connections" {
  alarm_name          = "${local.project} rds connections over last 10 minutes is too high"
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
    DBInstanceIdentifier = aws_rds_cluster_instance.this.id
  }
}
