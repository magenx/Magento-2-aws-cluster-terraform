


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
  tags = {
    Name = "${local.project}-parameters"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS instance
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_db_instance" "this" {
  identifier             = "${local.project}-rds"
  allocated_storage      = var.rds["allocated_storage"]
  max_allocated_storage  = var.rds["max_allocated_storage"]
  storage_type           = var.rds["storage_type"]
  storage_encrypted      = var.rds["storage_encrypted"]
  engine                 = var.rds["engine"]
  engine_version         = var.rds["engine_version"]
  instance_class         = var.rds["instance_class"]
  multi_az               = var.rds["multi_az"]
  db_name                = var.rds["db_name"]
  username               = var.app["brand"]
  password               = random_password.this["rds"].result
  parameter_group_name   = aws_db_parameter_group.this.id
  skip_final_snapshot    = var.rds["skip_final_snapshot"]
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  enabled_cloudwatch_logs_exports = [var.rds["enabled_cloudwatch_logs_exports"]]
  performance_insights_enabled    = var.rds["performance_insights_enabled"]
  copy_tags_to_snapshot           = var.rds["copy_tags_to_snapshot"]
  backup_retention_period         = var.rds["backup_retention_period"]
  delete_automated_backups        = var.rds["delete_automated_backups"]
  deletion_protection             = var.rds["deletion_protection"]
  tags = {
    Name = "${local.project}-rds"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create RDS instance event subscription
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_db_event_subscription" "db_event_subscription" {
  name      = "${local.project}-rds-event-subscription"
  sns_topic = aws_sns_topic.default.arn
  source_type = "db-instance"
  source_ids = [aws_db_instance.this.id]
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
    DBInstanceIdentifier = aws_db_instance.this.id
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
    DBInstanceIdentifier = aws_db_instance.this.id
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
        DBInstanceIdentifier = aws_db_instance.this.id
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
    DBInstanceIdentifier = aws_db_instance.this.id
  }
}
