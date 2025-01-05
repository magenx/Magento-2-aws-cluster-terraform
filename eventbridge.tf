


////////////////////////////////////////////////////////[ EVENTBRIDGE RULES ]/////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge service role
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "eventbridge_service_role" {
  name = "${local.project}-EventBridgeServiceRole"
  description = "Provides EventBridge manage events on your behalf."
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document association with Auto Scaling Group
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_association" "user_data" {
  for_each = var.ec2
  name     = aws_ssm_document.user_data.name
  targets {
    key    = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.this[each.key].name]
  }
  association_name = "Configuration-for-EC2-instances-in-${aws_autoscaling_group.this[each.key].name}"
  document_version = "$LATEST"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule for S3 bucket object event
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "s3_update" {
  name        = "${local.project}-s3-update-setup"
  description = "Trigger SSM document when s3 system bucket updated"
  event_pattern = jsonencode({
    "source"       : ["aws.s3"],
    "detail-type"  : ["Object Created"],
    "detail"       : {
      "bucket"     : { "name" : [aws_s3_bucket.this["system"].bucket] },
      "object"     : { "key" : [{ "prefix" : "setup/" }] }
    }
  })
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule Target for SSM Document User Data on S3 update
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "s3_update" {
  depends_on = [aws_autoscaling_group.this]
  rule       = aws_cloudwatch_event_rule.s3_update.name
  target_id  = "${local.project}-instance-s3-update-setup"
  arn        = aws_ssm_document.get_user_data.arn
  role_arn   = aws_iam_role.eventbridge_service_role.arn
  input_transformer {
    input_paths = {
      instanceId = "$.detail.EC2InstanceId"
    }
    input_template = <<EOF
    {
    "instanceId": "<instanceId>"
    }
    EOF
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule for EC2 instance termination lifecycle
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "ec2_terminating" {
  name          = "${local.project}-ec2-terminating-rule"
  description   = "Trigger on EC2 instance terminating"
  event_pattern = jsonencode({
    "source" : ["aws.autoscaling"],
    "detail-type" : ["EC2 Instance-terminate Lifecycle Action"],
    "detail" : {
      "LifecycleTransition" : ["autoscaling:EC2_INSTANCE_TERMINATING"],
      "Origin": [ "AutoScalingGroup" ],
      "Destination": [ "EC2" ]
    }
  })
}
resource "aws_cloudwatch_event_rule" "ec2_to_warm_pool" {
  name          = "${local.project}-ec2-to-warm-pool-rule"
  description   = "Trigger on EC2 instances entering the warm pool"
  event_pattern = jsonencode({
  "source": [ "aws.autoscaling" ],
  "detail-type": [ "EC2 Instance-launch Lifecycle Action" ],
  "detail": {
      "Origin": [ "EC2" ],
      "Destination": [ "WarmPool" ]
   }
})
}
resource "aws_cloudwatch_event_rule" "asg_to_warm_pool" {
  name          = "${local.project}-asg-to-warm-pool-rule"
  description   = "Trigger on EC2 instances returning to the warm pool on scale in"
  event_pattern = jsonencode({
  "source": [ "aws.autoscaling" ],
  "detail-type": [ "EC2 Instance-terminate Lifecycle Action" ],
  "detail": {
      "Origin": [ "AutoScalingGroup" ],
      "Destination": [ "WarmPool" ]
   }
})
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule Target for SSM Document CloudMap Deregister
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "ec2_terminating" {
  depends_on = [aws_autoscaling_group.this]
  rule       = aws_cloudwatch_event_rule.ec2_terminating.name
  target_id  = "${local.project}-cloudmap-deregister"
  arn        = aws_ssm_document.cloudmap_deregister.arn
  role_arn   = aws_iam_role.eventbridge_service_role.arn
  input_transformer {
    input_paths = {
      instanceId = "$.detail.EC2InstanceId"
    }
    input_template = <<EOF
    {
    "instanceId": "<instanceId>"
    }
    EOF
  }
}
resource "aws_cloudwatch_event_target" "ec2_to_warm_pool" {
  depends_on = [aws_autoscaling_group.this]
  rule       = aws_cloudwatch_event_rule.ec2_to_warm_pool.name
  target_id  = "${local.project}-cloudmap-deregister"
  arn        = aws_ssm_document.cloudmap_deregister.arn
  role_arn   = aws_iam_role.eventbridge_service_role.arn
  input_transformer {
    input_paths = {
      instanceId = "$.detail.EC2InstanceId"
    }
    input_template = <<EOF
    {
    "instanceId": "<instanceId>"
    }
    EOF
  }
}
resource "aws_cloudwatch_event_target" "asg_to_warm_pool" {
  depends_on = [aws_autoscaling_group.this]
  rule       = aws_cloudwatch_event_rule.asg_to_warm_pool.name
  target_id  = "${local.project}-cloudmap-deregister"
  arn        = aws_ssm_document.cloudmap_deregister.arn
  role_arn   = aws_iam_role.eventbridge_service_role.arn
  input_transformer {
    input_paths = {
      instanceId = "$.detail.EC2InstanceId"
    }
    input_template = <<EOF
    {
    "instanceId": "<instanceId>"
    }
    EOF
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule for EC2 instance launch from warm pool
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "warm_pool_to_asg_launch" {
  name        = "${local.project}-warm-pool-to-asg-launch-ssm"
  description = "Trigger on EC2 instance launching"
  event_pattern = jsonencode({
  "source": [ "aws.autoscaling" ],
  "detail-type": [ "EC2 Instance-launch Lifecycle Action" ],
  "detail": {
      "Origin": [ "WarmPool" ],
      "Destination": [ "AutoScalingGroup" ]
   }
  })
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule Target for SSM Document Bootstrap and refresh configuration
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "warm_pool_to_asg_launch" {
  depends_on = [aws_autoscaling_group.this]
  rule       = aws_cloudwatch_event_rule.warm_pool_to_asg_launch.name
  target_id  = "${local.project}-warm-pool-to-asg-launch-setup"
  arn        = aws_ssm_document.get_user_data.arn
  role_arn   = aws_iam_role.eventbridge_service_role.arn
  input_transformer {
    input_paths = {
      instanceId = "$.detail.EC2InstanceId"
    }
    input_template = <<EOF
    {
    "instanceId": "<instanceId>"
    }
    EOF
  }
}
