



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
    for_each = { for source_identifier, compliance_resource_types in var.aws_config_rule : 
      source_identifier => compliance_resource_types if compliance_resource_types != ""
    }
    compliance_resource_types = ["${scope.value}"]
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
resource "aws_iam_role" "config" {
  name = "${local.project}-aws-config"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create AWS Config role policy
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}
