


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
