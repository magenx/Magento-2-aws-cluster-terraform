


/////////////////////////////////////////////////////[ AUTOSCALING CONFIGURATION ]////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Launch Template for Autoscaling Groups
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_launch_template" "this" {
  for_each = var.ec2
  name = "${local.project}-${each.key}-ltpl"
  iam_instance_profile { name = aws_iam_instance_profile.ec2[each.key].name }
  image_id = data.aws_ami.distro.id
  instance_type = each.value.instance_type
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = each.value.volume_size
      volume_type = "gp3"
      encrypted   = true
      delete_on_termination = true
    }
  }
  dynamic "block_device_mappings" {
    for_each = each.key == "mariadb" ? [1] : []
    content {
      device_name = "/dev/xvdb"
      ebs {
        volume_size = "250"
        volume_type = "gp3"
        encrypted   = true
        delete_on_termination = false
      }
    }
  }
  monitoring { enabled = true }
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.ec2[each.key].id]
  }
  dynamic "tag_specifications" {
    for_each = toset(["instance","spot-instance-request"])
    content {
       resource_type = tag_specifications.key
       tags = merge(
         local.default_tags,
         {
          Name = "${local.project}-${each.key}-ec2"
          Instance_name = each.key
          Hostname = "${each.key}.${var.brand}.internal"
          Config = "s3_system_setup"
        }
      )
    }
  }
  tag_specifications {
       resource_type = "volume"
       tags = merge(
         local.default_tags,
         {
          Name = "${local.project}-${each.key}-volume"
          Instance_name = each.key
        }
      )
    }
  user_data = base64encode(<<EOF
#!/bin/bash
# update and install
apt -qq update
apt -qqy remove --purge awscli
apt -qqy install unzip
# install ssm manager
mkdir /tmp/ssm
cd /tmp/ssm
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_arm64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
# install aws cli v2
mkdir /tmp/awscli
cd /tmp/awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
bash ./aws/install
EOF
  )
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
  depends_on = [aws_ssm_parameter.aws_env]
  for_each = var.ec2
  name = "${local.project}-${each.key}-asg"
  vpc_zone_identifier = values(aws_subnet.this).*.id
  desired_capacity    = each.value.desired_capacity
  min_size            = each.value.min_size
  max_size            = each.value.max_size
  health_check_grace_period = var.asg["health_check_grace_period"]
  health_check_type         = var.asg["health_check_type"]
  target_group_arns  = each.key == "varnish" ? [aws_lb_target_group.this.arn] : []
  launch_template {
      id      = aws_launch_template.this[each.key].id
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
    for_each = merge(local.default_tags,{Name="${local.project}-${each.key}-asg"})
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
# Create lifecycle transition notification for EC2 instance launch and terminate
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "autoscaling_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["autoscaling.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "autoscaling" {
  name = "${local.project}-autoscaling-role"
  assume_role_policy = data.aws_iam_policy_document.autoscaling_assume_role_policy.json
}
data "aws_iam_policy_document" "lifecycle_hook" {
  statement {
    actions = ["sns:Publish"]
    resources = [
        aws_sns_topic.default.arn
    ]
  }
}
resource "aws_iam_policy" "lifecycle_hook" {
  name        = "${local.project}-lifecycle-hook"
  description = "Policy for Auto Scaling to publish to SNS for lifecycle hooks"
  policy = data.aws_iam_policy_document.lifecycle_hook.json
}
resource "aws_iam_role_policy_attachment" "lifecycle_hook" {
  policy_arn = aws_iam_policy.lifecycle_hook.arn
  role       = aws_iam_role.autoscaling.name
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch alarm for disk_used_percent metric
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "disk_free_alarm" {
  for_each            = var.ec2
  alarm_name          = "${local.project}-${each.key}-disk-free-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "used_percent"
  namespace           = "${local.project}"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Triggered when disk used percent exceeds 80%"
  actions_enabled     = true
  dimensions = { AutoScalingGroupName = aws_autoscaling_group.this[each.key].name }
  alarm_actions = [aws_sns_topic.default.arn]
  ok_actions = [aws_sns_topic.default.arn]
  insufficient_data_actions = [aws_sns_topic.default.arn]
}
