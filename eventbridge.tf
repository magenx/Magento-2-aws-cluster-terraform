


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
  name               = "${local.project}-EventBridgeServiceRole"
  description        = "Provides EventBridge manage events on your behalf."
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}
data "aws_iam_policy_document" "eventbridge_policy" {
  statement {
    effect    = "Allow"
    actions   = [
      "ssm:StartAutomationExecution",
      "ssm:GetAutomationExecution",
      "sqs:SendMessage",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "servicediscovery:DeregisterInstance"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}
resource "aws_iam_policy" "eventbridge_policy" {
  name   = "${local.project}-EventBridgePolicy"
  policy = data.aws_iam_policy_document.eventbridge_policy.json
}
resource "aws_iam_role_policy_attachment" "eventbridge_policy_attach" {
  role       = aws_iam_role.eventbridge_service_role.name
  policy_arn = aws_iam_policy.eventbridge_policy.arn
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule for S3 bucket object event for setup update
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "s3_setup_update" {
  name        = "${local.project}-s3-setup-update"
  description = "Trigger SSM document when s3 system bucket setup updated"
  event_pattern = jsonencode({
    "source": ["aws.s3"],
    "detail-type"  : ["Object Created"],
    "detail"       : {
      "bucket"     : { "name" : [aws_s3_bucket.this["system"].bucket] },
      "object"     : { "key" : [{ "prefix" : "setup/" }] }
    }
  })
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule Target for SSM Document configuration on S3 update
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "s3_setup_update" {
  depends_on = [aws_autoscaling_group.this]
  rule       = aws_cloudwatch_event_rule.s3_setup_update.name
  target_id  = "${local.project}-s3-system-setup-update"
  arn        = aws_ssm_document.configuration.arn
  role_arn   = aws_iam_role.eventbridge_service_role.arn
  dead_letter_config {
    arn = aws_sqs_queue.dead_letter_queue.arn
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule for S3 bucket object event for release update
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "s3_release_update" {
  name        = "${local.project}-s3-release-update"
  description = "Trigger SSM document when s3 system bucket release updated"
  event_pattern = jsonencode({
    "source": ["aws.s3"],
    "detail-type"  : ["Object Created"],
    "detail"       : {
      "bucket"     : { "name" : [aws_s3_bucket.this["system"].bucket] },
      "object"     : { "key" : [{ "prefix" : "release/" }] }
    }
  })
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule Target for SSM Document S3 release update
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "s3_release_update" {
  depends_on = [aws_autoscaling_group.this]
  rule      = aws_cloudwatch_event_rule.s3_release_update.name
  target_id = "${local.project}-s3-system-release-update"
  arn       = aws_ssm_document.release.arn
  role_arn  = aws_iam_role.eventbridge_service_role.arn
  dead_letter_config {
    arn = aws_sqs_queue.dead_letter_queue.arn
  }
  input_transformer {
    input_paths = {
      ApplicationName     = aws_codedeploy_app.this["frontend"].name,
      DeploymentGroupName = aws_codedeploy_deployment_group.this["frontend"].name,
      S3Bucket            = "$.detail.requestParameters.bucketName",
      S3ObjectKey         = "$.detail.requestParameters.key"
    }
    input_template = <<EOF
    {
      "ApplicationName": aws_codedeploy_app.this["frontend"].name,
      "DeploymentGroupName": aws_codedeploy_deployment_group.this["frontend"].name,
      "S3Bucket": "<S3Bucket>",
      "S3ObjectKey": "<S3ObjectKey>",
      "AutomationAssumeRole": aws_iam_role.eventbridge_service_role.arn
    }
    EOT
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
  dead_letter_config {
    arn = aws_sqs_queue.dead_letter_queue.arn
  }
  input_transformer {
    input_paths = {
      InstanceId = "$.detail.EC2InstanceId"
      AutoScalingGroupName = "$.detail.AutoScalingGroupName"
    }
    input_template = <<EOF
    {
    "InstanceId": "<InstanceId>",
    "AutoScalingGroupName": "<AutoScalingGroupName>"
    }
    EOF
  }
}
