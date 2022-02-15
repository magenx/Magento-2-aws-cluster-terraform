


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
  family        = "redis6.x"
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
  number_cache_clusters         = length(values(aws_subnet.this).*.id)
  engine                        = "redis"
  engine_version                = var.redis["engine_version"]
  replication_group_id          = "${local.project}-${each.key}-backend"
  replication_group_description = "Replication group for ${var.app["domain"]} ${each.key} backend"
  node_type                     = var.redis["node_type"]
  port                          = var.redis["port"]
  parameter_group_name          = aws_elasticache_parameter_group.this[each.key].id
  security_group_ids            = [aws_security_group.redis.id]
  subnet_group_name             = aws_elasticache_subnet_group.this.name
  automatic_failover_enabled    = var.redis["automatic_failover_enabled"]
  multi_az_enabled              = var.redis["multi_az_enabled"]
  notification_topic_arn        = aws_sns_topic.default.arn
  tags = {
    Name = "${local.project}-${each.key}-backend"
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


