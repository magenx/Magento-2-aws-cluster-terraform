


/////////////////////////////////////////////////////[ AUTOSCALING CONFIGURATION ]////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Launch Template for Autoscaling Groups
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_launch_template" "this" {
  for_each = var.ec2
  name = "${local.project}-${each.key}-ltpl"
  iam_instance_profile { name = aws_iam_instance_profile.ec2[each.key].name }
  image_id = element(values(data.external.packer[each.key].result), 0)
  instance_type = each.value.instance_type
  monitoring { enabled = true }
  network_interfaces { 
    associate_public_ip_address = true
    security_groups = [aws_security_group.ec2[each.key].id]
  }
  dynamic "tag_specifications" {
    for_each = toset(["instance","volume"])
    content {
       resource_type = tag_specifications.key
       tags = merge(
         data.aws_default_tags.this.tags,
         {
          Name = "${local.project}-${each.key}-ec2",
          Hostname = "${each.key}.${aws_route53_zone.this.name}"
        }
      )
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  update_default_version = true
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${local.project}-${each.key}-ltpl"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling Groups
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_group" "this" {
  for_each = var.ec2
  name = "${local.project}-${each.key}-asg"
  vpc_zone_identifier = [values(aws_subnet.this).0.id]
  desired_capacity    = each.value.desired_capacity
  min_size            = each.value.min_size
  max_size            = each.value.max_size
  health_check_grace_period = var.asg["health_check_grace_period"]
  health_check_type         = var.asg["health_check_type"]
  target_group_arns  = [aws_lb_target_group.this[each.key].arn]
  dynamic "warm_pool" {
    for_each = each.value.warm_pool == "enabled" ? [var.ec2] : []
    content {
      pool_state                  = "Hibernated"
      min_size                    = each.value.min_size
      max_group_prepared_capacity = each.value.min_size
    }
  }
  launch_template {
    name    = aws_launch_template.this[each.key].name
    version = "$Latest"
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      skip_matching = false
      scale_in_protected_instances = "Refresh"
    }
  }
  lifecycle {
    create_before_destroy = true
  }
  dynamic "tag" {
    for_each = merge(data.aws_default_tags.this.tags,{Name="${local.project}-${each.key}-asg"})
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling groups actions for SNS topic email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_notification" "this" {
for_each = aws_autoscaling_group.this 
group_names = [
    aws_autoscaling_group.this[each.key].name
  ]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = aws_sns_topic.default.arn
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling policy for scale-out
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_policy" "scaleout" {
  for_each               = { for instance, value in var.ec2 : instance => value if value.max_size > 1 }
  name                   = "${local.project}-${each.key}-asp-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this[each.key].name
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch alarm metric to execute Autoscaling policy for scale-out
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "scaleout" {
  for_each            = { for instance, value in var.ec2 : instance => value if value.max_size > 1 }
  alarm_name          = "${local.project}-${each.key} scale-out alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.asp["evaluation_periods_out"]
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.asp["period"]
  statistic           = "Average"
  threshold           = var.asp["out_threshold"]
  dimensions = {
    AutoScalingGroupName  = aws_autoscaling_group.this[each.key].name
  }
  alarm_description = "${each.key} scale-out alarm - CPU exceeds ${var.asp["out_threshold"]} percent"
  alarm_actions     = [aws_autoscaling_policy.scaleout[each.key].arn]
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Autoscaling policy for scale-in
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_policy" "scalein" {
  for_each               = { for instance, value in var.ec2 : instance => value if value.max_size > 1 }
  name                   = "${local.project}-${each.key}-asp-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this[each.key].name
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch alarm metric to execute Autoscaling policy for scale-in
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "scalein" {
  for_each            = { for instance, value in var.ec2 : instance => value if value.max_size > 1 }
  alarm_name          = "${local.project}-${each.key} scale-in alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.asp["evaluation_periods_in"]
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.asp["period"]
  statistic           = "Average"
  threshold           = var.asp["in_threshold"]
  dimensions = {
    AutoScalingGroupName  = aws_autoscaling_group.this[each.key].name
  }
  alarm_description = "${each.key} scale-in alarm - CPU less than ${var.asp["in_threshold"]} percent"
  alarm_actions     = [aws_autoscaling_policy.scalein[each.key].arn]
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create lifecycle transition notification for MariaDB instance termination
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_autoscaling_lifecycle_hook" "this" {
  name                    = "${local.project} mariadb"
  autoscaling_group_name  = aws_autoscaling_group.this["mariadb"].name
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  role_arn                = aws_iam_instance_profile.ec2["mariadb"].name
  notification_target_arn = aws_sns_topic.default.arn
  heartbeat_timeout       = 300
}
