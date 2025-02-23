


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
# Create custom policy for EC2 instance profile
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "ec2_custom" {
  for_each = var.ec2
  statement {
    sid    = "EC2ProfileASGDescribePolicy${each.key}"
    effect = "Allow"
    actions = [
      "autoscaling:Describe*"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "EC2ProfileGetParameterPolicy${each.key}"
    effect = "Allow"
    actions = [
      "ssm:GetParameter"
    ]
    resources = ["*"]
  }
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
}

resource "aws_iam_role_policy" "ec2_custom" {
  for_each = var.ec2
  name     = "EC2ProfileCustomPolicy${title(each.key)}"
  role     = aws_iam_role.ec2[each.key].id
  policy = data.aws_iam_policy_document.ec2_custom[each.key].json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create inline policy for EC2 maridb service role to attach/detach vulume
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "attach_detach_volume" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:AttachVolume",
      "ec2:DetachVolume",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeVolumes"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_attach_detach_policy" {
  name   = "MariaDBEC2AttachDetachPolicy"
  role   = aws_iam_role.ec2["mariadb"].id
  policy = data.aws_iam_policy_document.attach_detach_volume.json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EC2 Instance Profile
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_instance_profile" "ec2" {
  for_each = var.ec2
  name     = "${local.project}-EC2InstanceProfile-${each.key}"
  role     = aws_iam_role.ec2[each.key].name
}
