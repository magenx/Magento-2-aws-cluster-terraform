


///////////////////////////////////////////////////////////[ EC2 PROFILE ]////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 service role
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    effect = "Allow"
    sid    = "EC2AssumeRole"
  }
}

resource "aws_iam_role" "ec2" {
  for_each = var.ec2
  name        = "${local.project}-EC2InstanceRole-${each.key}"
  description = "Allows EC2 instances to call AWS services on your behalf"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policies to EC2 service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "ec2" {
  for_each = { 
    for entry in setproduct(keys(var.ec2), var.ec2_instance_profile_policy) : 
      "${entry[0]}-${entry[1]}" => { 
        role   = entry[0], 
        policy = entry[1] 
      } 
  }
  role       = aws_iam_role.ec2[each.value.role].name
  policy_arn = each.value.policy
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create inline policy for EC2 service role to publish sns message
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "sns_publish" {
  for_each = var.ec2
  statement {
    sid    = "EC2ProfileSNSPublishPolicy${each.key}"
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [
      aws_sns_topic.default.arn
    ]
  }
}

resource "aws_iam_role_policy" "sns_publish" {
  for_each = var.ec2
  name     = "EC2ProfileSNSPublishPolicy${title(each.key)}"
  role     = aws_iam_role.ec2[each.key].id
  policy = data.aws_iam_policy_document.sns_publish[each.key].json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create inline policy for EC2 service role to send ses emails
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "ses_send" {
  for_each = var.ec2
  statement {
    sid     = "EC2ProfileSESSendPolicy${each.key}"
    effect  = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ses:FromAddress"
      values   = [var.admin_email]
    }
  }
}

resource "aws_iam_role_policy" "ses_send" {
  for_each = var.ec2
  name     = "EC2ProfileSESSendPolicy${title(each.key)}"
  role     = aws_iam_role.ec2[each.key].id
  policy = data.aws_iam_policy_document.ses_send[each.key].json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 Instance Profile
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_instance_profile" "ec2" {
  for_each = var.ec2
  name     = "${local.project}-EC2InstanceProfile-${each.key}"
  role     = aws_iam_role.ec2[each.key].name
}
