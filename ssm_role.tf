


/////////////////////////////////////////////////////////[ SSM ROLE POLICY ]//////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM role to execute automations and documents
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "ssm_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "ssm_service_role" {
  name               = "${local.project}-SSMServiceRole"
  description        = "Provides SSM manage automations on your behalf."
  assume_role_policy = data.aws_iam_policy_document.ssm_assume_role.json
}
data "aws_iam_policy_document" "ssm_policy" {
  statement {
    effect    = "Allow"
    actions   = [
      "ec2:Describe*",
      "codedeploy:CreateDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision",
      "codedeploy:GetApplicationRevision",
      "tag:GetResources",
      "sns:Publish",
      "ssm:DescribeInstanceInformation",
      "ssm:StartAutomationExecution",
      "ssm:GetAutomationExecution",
      "ssm:SendCommand",
      "ssm:ListCommands",
      "ssm:ListCommandInvocations",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "route53:CreateHealthCheck",
      "servicediscovery:Get*",
      "servicediscovery:List*",
      "servicediscovery:RegisterInstance",
      "servicediscovery:DeregisterInstance",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}
resource "aws_iam_policy" "ssm_policy" {
  name   = "${local.project}-SSMPolicy"
  policy = data.aws_iam_policy_document.ssm_policy.json
}
resource "aws_iam_role_policy_attachment" "ssm_policy_attach" {
  role       = aws_iam_role.ssm_service_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}
