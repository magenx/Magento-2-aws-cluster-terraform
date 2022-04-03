


//////////////////////////////////////////////////////////[ ELASTICACHE ]/////////////////////////////////////////////////
  
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElastiCache subnet group in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_elasticache_subnet_group" "this" {
  description = "ElastiCache Subnet for ${replace(local.project,"-"," ")}"
  name       = "${local.project}-elasticache-subnet"
  subnet_ids = values(aws_subnet.this).*.id 
  tags = {
    Name = "${local.project}-elasticache-subnet"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElastiCache parameter groups
# # ---------------------------------------------------------------------------------------------------------------------#		  
resource "aws_elasticache_parameter_group" "this" {
  for_each      = toset(var.redis["name"])
  name          = "${local.project}-${each.key}-parameter"
  family        = var.redis["family"]
  description   = "Parameter group for ${var.app["domain"]} ${each.key} backend"
  parameter {
    name  = "cluster-enabled"
    value = "no"
  }
  tags = {
    Name = "${local.project}-${each.key}-parameter"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElastiCache - Redis Replication group - session + cache
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_elasticache_replication_group" "this" {
  for_each                      = toset(var.redis["name"])
  description                   = "Replication group for ${var.app["domain"]} ${each.key} backend"
  num_cache_clusters            = var.redis["num_cache_clusters"]
  at_rest_encryption_enabled    = var.redis["at_rest_encryption_enabled"]
  engine                        = "redis"
  engine_version                = var.redis["engine_version"]
  replication_group_id          = "${local.project}-${each.key}-backend"
  node_type                     = var.redis["node_type"]
  port                          = var.redis["port"]
  parameter_group_name          = aws_elasticache_parameter_group.this[each.key].id
  security_group_ids            = [aws_security_group.redis.id]
  subnet_group_name             = aws_elasticache_subnet_group.this.name
  automatic_failover_enabled    = var.redis["num_cache_clusters"] > 1 ? true : false
  multi_az_enabled              = var.redis["num_cache_clusters"] > 1 ? true : false
  notification_topic_arn        = aws_sns_topic.default.arn
  
  log_delivery_configuration {
    destination        = aws_cloudwatch_log_group.redis[each.key].name
    destination_type   = "cloudwatch-logs"
    log_format         = "text"
    log_type           = "engine-log"
  }
  
  tags = {
    Name = "${local.project}-${each.key}-backend"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch log group for redis
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_log_group" "redis" {
  for_each  = toset(var.redis["name"])
  name      = "${local.project}-${each.key}-redis"

  tags = {
    Name = "${local.project}-${each.key}-redis"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch CPU Utilization metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "elasticache_cpu" {
  for_each            = aws_elasticache_replication_group.this
  alarm_name          = "${local.project}-elasticache-${each.key}-cpu-utilization"
  alarm_description   = "Redis cluster CPU utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.this[each.key].id
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch Freeable Memory metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "elasticache_memory" {
  for_each            = aws_elasticache_replication_group.this
  alarm_name          = "${local.project}-elasticache-${each.key}-freeable-memory"
  alarm_description   = "Redis cluster freeable memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = "60"
  statistic           = "Average"
  threshold           = 10000000
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.this[each.key].id
  }
}
