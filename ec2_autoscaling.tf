


/////////////////////////////////////////////////////[ AUTOSCALING CONFIGURATION ]////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "ec2" {
  for_each = var.ec2
  name = "${local.project}-EC2InstanceRole-${each.key}"
  description = "Allows EC2 instances to call AWS services on your behalf"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policies to EC2 service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "ec2" {
  for_each = { for policy in [ for role,policy in setproduct(keys(var.ec2),var.ec2_instance_profile_policy): { role = policy[0] , policy = policy[1]} ] : "${policy.role}-${policy.policy}" => policy }
  role       = aws_iam_role.ec2[each.value.role].name
  policy_arn = each.value.policy
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create inline policy for EC2 service role to publish sns message
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy" "sns_publish" {
  for_each = var.ec2
  name = "${local.project}EC2ProfileSNS${title(each.key)}"
  role = aws_iam_role.ec2[each.key].id

  policy = jsonencode({
  Version = "2012-10-17",
  Statement = [
    {
      Sid    = "EC2ProfileSNSPublishPolicy${each.key}",
      Effect = "Allow",
      Action = [
            "sns:Publish"
      ],
      Resource = aws_sns_topic.default.arn
 }]
})
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create inline policy for EC2 service role to limit CodeCommit access
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy" "codecommit_access" {
  for_each = var.ec2
  name = "${local.project}PolicyCodeCommitAccess${title(each.key)}"
  role = aws_iam_role.ec2[each.key].id

  policy = jsonencode({
  Version = "2012-10-17",
  Statement = [
    {
      Sid    = "codecommitaccessapp${each.key}",
      Effect = "Allow",
      Action = [
            "codecommit:Get*",
            "codecommit:List*",
            "codecommit:GitPull"
      ],
      Resource = aws_codecommit_repository.app.arn
      Condition = {
                StringEqualsIfExists = {
                    "codecommit:References" = ["refs/heads/main"]
      }
   }
},
     {
      Sid    = "codecommitaccessservices${each.key}", 
      Effect = "Allow",
      Action = [
            "codecommit:Get*",
            "codecommit:List*",
            "codecommit:GitPull"
      ],
      Resource = aws_codecommit_repository.services.arn
    }]
})
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 Instance Profile
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_instance_profile" "ec2" {
  for_each = var.ec2
  name     = "${local.project}-EC2InstanceProfile-${each.key}"
  role     = aws_iam_role.ec2[each.key].name
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 ebs default encryption
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Launch Template for Autoscaling Groups - user_data converted
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_launch_template" "this" {
  for_each = var.ec2
  name = "${local.project}-${each.key}-ltpl"
  iam_instance_profile { name = aws_iam_instance_profile.ec2[each.key].name }
  image_id = element(values(data.external.packer[each.key].result), 0)
  instance_type = each.value
  monitoring { enabled = var.asg["monitoring"] }
  network_interfaces { 
    associate_public_ip_address = true
    security_groups = [aws_security_group.ec2.id]
  }
  dynamic "tag_specifications" {
    for_each = toset(["instance","volume"])
    content {
       resource_type = tag_specifications.key
       tags = merge(var.default_tags,{ Name = "${local.project}-${each.key}-ec2" })
    }
  }
  user_data = base64encode(data.template_file.user_data[each.key].rendered)
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
  vpc_zone_identifier = values(aws_subnet.this).*.id
  desired_capacity    = var.asg["desired_capacity"]
  min_size            = var.asg["min_size"]
  max_size            = var.asg["max_size"]
  health_check_grace_period = var.asg["health_check_grace_period"]
  health_check_type         = var.asg["health_check_type"]
  target_group_arns  = [aws_lb_target_group.this[each.key].arn]
  dynamic "warm_pool" {
    for_each = var.asg["warm_pool"] == "enabled" ? [var.ec2] : []
    content {
      pool_state                  = "Stopped"
      min_size                    = var.asg["min_size"]
      max_group_prepared_capacity = var.asg["max_size"]
    }
  }
  launch_template {
    name    = aws_launch_template.this[each.key].name
    version = "$Latest"
  }
  instance_refresh {
     strategy = "Rolling"
  }
  lifecycle {
    create_before_destroy = true
  }
  dynamic "tag" {
    for_each = merge(var.default_tags,{Name="${local.project}-${each.key}-asg"})
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
  for_each               = var.ec2
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
  for_each            = var.ec2
  alarm_name          = "${local.project} ${each.key} scale-out alarm"
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
  for_each               = var.ec2
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
  for_each            = var.ec2
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


