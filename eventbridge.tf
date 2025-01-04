


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
#resource "aws_ssm_association" "user_data" {
#  for_each = var.ec2
#  name     = aws_ssm_document.user_data.name
#  targets {
#    key    = "tag:aws:autoscaling:groupName"
#    values = [aws_autoscaling_group.this[each.key].name]
#  }
#  association_name = "Configuration-for-EC2-instances-in-${aws_autoscaling_group.this[each.key].name}"
#  document_version = "$LATEST"
#}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule for S3 bucket object event
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "s3_update" {
  for_each    = var.ec2
  name        = "${local.project}-${each.key}-s3-update-setup"
  description = "Trigger SSM document when s3 system bucket updated for ${each.key}"
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
  for_each  = var.ec2
  rule      = aws_cloudwatch_event_rule.s3_update[each.key].name
  target_id = "${local.project}-${each.key}-instance-s3-update-setup"
  arn       =  aws_ssm_document.user_data.arn
  role_arn  =  aws_iam_role.ec2[each.key].arn
  run_command_targets {
    key    = "tag:Name"
    values = ["${local.project}-${each.key}-ec2"]
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule for EC2 instance termination lifecycle
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "ec2_terminating" {
  for_each    = var.ec2
  name        = "${local.project}-${each.key}-ec2-terminating-rule"
  description = "Trigger on EC2 instance terminating"
  event_pattern = jsonencode({
    "source" : ["aws.autoscaling"],
    "detail-type" : ["EC2 Instance-terminate Lifecycle Action"],
    "detail" : {
      "LifecycleTransition" : ["autoscaling:EC2_INSTANCE_TERMINATING"]
    }
  })
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule Target for SSM Document CloudMap Deregister
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "ec2_terminating" {
  depends_on = [aws_autoscaling_group.this]
  for_each  = var.ec2
  rule      = aws_cloudwatch_event_rule.ec2_terminating[each.key].name
  target_id = "${local.project}-${each.key}-cloudmap-deregister"
  arn       =  aws_ssm_document.cloudmap_deregister.arn
  role_arn  =  aws_iam_role.ec2[each.key].arn
  run_command_targets {
    key    = "tag:Name"
    values = ["${local.project}-${each.key}-ec2"]
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule for EC2 instance launch and warmup lifecycle
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "ec2_launch" {
  for_each    = var.ec2
  name        = "${local.project}-${each.key}-ec2-launch-rule"
  description = "Trigger on EC2 instance launching"
  event_pattern = jsonencode({
    "source" : ["aws.autoscaling"],
    "detail-type" : ["EC2 Instance-launch Lifecycle Action"],
    "detail" : {
      "LifecycleTransition" : ["autoscaling:EC2_INSTANCE_LAUNCH"]
    }
  })
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule Target for SSM Document Bootstrap and refresh configuration
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "ec2_launch" {
  depends_on = [aws_autoscaling_group.this]
  for_each  = var.ec2
  rule      = aws_cloudwatch_event_rule.ec2_launch[each.key].name
  target_id = "${local.project}-${each.key}-instance-launch-setup"
  arn       =  aws_ssm_document.user_data.arn
  role_arn  =  aws_iam_role.ec2[each.key].arn
  run_command_targets {
    key    = "tag:Name"
    values = ["${local.project}-${each.key}-ec2"]
  }
}
