


/////////////////////////////////////////////////////////[ AWS CONFIG ]///////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create AWS config rules
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_config_config_rule" "this" {
  depends_on  = [aws_config_configuration_recorder.this]
  for_each    = var.aws_config_rule
  name        = "${local.project}-${each.key}"
  description = "Evaluate your AWS resource configurations for ${each.key} rule"
  source {
    owner             = "AWS"
    source_identifier = each.key
  }
  dynamic "scope" {
    for_each = each.value == "" ? [] : [each.value]
      content {
      compliance_resource_types = ["${scope.value}"]
    }
  }
  tags = {
    Name = "${local.project}-${each.key}"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create AWS Config recorder
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_config_configuration_recorder" "this" {
  name     = "${local.project}-recorder"
  role_arn = aws_iam_role.config.arn
  recording_group {
    all_supported                 = false
    include_global_resource_types = false
    resource_types                = var.resource_types
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create AWS Config recorder status
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_config_configuration_recorder_status" "this" {
  depends_on = [aws_config_delivery_channel.this]
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create AWS Config delivery channel
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_config_delivery_channel" "this" {
  name           = "${local.project}-channel"
  s3_bucket_name = aws_s3_bucket.this["system"].bucket
  s3_key_prefix  = "aws_config"
  sns_topic_arn  = aws_sns_topic.default.arn
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create AWS Config role
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "config_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "config" {
  name = "${local.project}-aws-config"
  assume_role_policy = data.aws_iam_policy_document.config_assume_role.json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create AWS Config role policy
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}
