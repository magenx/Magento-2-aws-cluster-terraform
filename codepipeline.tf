


////////////////////////////////////////////////////////[ CODEPIPELINE ]//////////////////////////////////////////////////
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeDeploy role
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "codedeploy_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name        = "${local.project}-codedeploy-role"
  description = "Allows CodeDeploy to call AWS services on your behalf."
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume_role.json
  tags = {
    Name = "${local.project}-codedeploy-role"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for CodeDeploy role
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "codedeploy" {
  statement {
    sid       = "AllowCodeDeploySNSAlertTrigger"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.default.arn]
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policy for CodeDeploy role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy" "codedeploy" {
  role   = aws_iam_role.codedeploy.name
  policy = data.aws_iam_policy_document.codedeploy.json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for CodeBuild role
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "codebuild" {
  name        = "${local.project}-codebuild-role"
  description = "Allows CodeBuild to call AWS services on your behalf."
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
  tags = {
    Name = "${local.project}-codebuild-role"
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodePipeline role
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "codepipeline_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name        = "${local.project}-codepipeline-role"
  description = "Allows CodePipeline to call AWS services on your behalf."
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role.json
  tags = {
    Name = "${local.project}-codepipeline-role"
  }
}
