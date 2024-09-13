


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

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy.name
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
  statement {
    sid    = "AllowCodeDeployToASG"
    effect = "Allow"
    actions = [
      "autoscaling:CompleteLifecycleAction",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:PutLifecycleHook",
      "autoscaling:DeleteLifecycleHook",
      "autoscaling:RecordLifecycleActionHeartbeat"
    ]
    resources = ["*"]
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

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess"
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [aws_codestarconnections_connection.this.arn]
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${local.project}-codepipeline-policy"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline.json
}
  
# # ---------------------------------------------------------------------------------------------------------------------#
# GitHub Connection (Version 2)
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codestarconnections_connection" "this" {
  name = "${local.project}-github-connection"
  provider_type = "GitHub"
}

# # ---------------------------------------------------------------------------------------------------------------------#
# CodePipeline to pull new release from GitHub and deploy to ASG instances
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codepipeline" "this" {
  name          = "${local.project}-cdci-pipeline"
  role_arn      = aws_iam_role.codepipeline.arn
  pipeline_type = "V2"
  artifact_store {
    location    = aws_s3_bucket.this["system"].bucket
    type        = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.this.arn
        FullRepositoryId = var.magento["github_repo"]
        BranchName       = "main"
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "Deploy"

    dynamic "action" {
      for_each = { for instance, value in var.ec2 : instance => value if value.service == null }
      content {
        name            = "Deploy_to_${action.key}_ASG"
        category        = "Deploy"
        owner           = "AWS"
        version         = "1"
        provider        = "CodeDeploy"
        input_artifacts = ["source_output"]
        configuration = {
          ApplicationName     = aws_codedeploy_app.this[action.key].name
          DeploymentGroupName = aws_codedeploy_deployment_group.this[action.key].id
        }
      }
    }
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# CodeDeploy Applications for frontend ASG
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codedeploy_app" "this" {
  for_each = { for instance, value in var.ec2 : instance => value if value.service == null }
  name = "${local.project}-codedeploy-app-${each.key}"
  compute_platform = "Server"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# CodeDeploy Deployment Groups for ASGs
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codedeploy_deployment_group" "this" {
  for_each = { for instance, value in var.ec2 : instance => value if value.service == null }
  deployment_group_name  = "${local.project}-deployment-group-${each.key}"
  app_name               = aws_codedeploy_app.this[each.key].name
  service_role_arn       = aws_iam_role.codedeploy.arn
  autoscaling_groups    = [aws_autoscaling_group.this[each.key].name]
  trigger_configuration {
    trigger_events     = ["DeploymentStart","DeploymentSuccess","DeploymentFailure"]
    trigger_name       = "${local.project}-deployment-failure-${each.key}"
    trigger_target_arn = aws_sns_topic.default.arn
  }
}
