


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

resource "aws_iam_role_policy" "codedeploy" {
  role   = aws_iam_role.codedeploy.name
  policy = data.aws_iam_policy_document.codedeploy.json
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeBuild role
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${local.project}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
  tags = {
    Name = "${local.project}-codebuild-role"
  }
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess"
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "codepipeline:PollForJobs",
      "codepipeline:GetPipelineExecution",
      "codepipeline:GetPipeline",
      "codepipeline:ListPipelineExecutions"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "CodeBuildCustomPolicy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
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
      namespace        = "SourceVariables"
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
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }
  stage {
    name = "Deploy"
  
    action {
      name     = "Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      run_order = 1
      configuration = {
        NotificationArn = aws_sns_topic.default.arn
        CustomData      = "Approve codepipeline [#{codepipeline.PipelineExecutionId}] Deploy action for ${local.project} [#{SourceVariables.AuthorDate} - #{SourceVariables.CommitId} - #{SourceVariables.CommitMessage}]"
      }
    }
    dynamic "action" {
      for_each = { for instance, value in var.ec2 : instance => value if value.service == null }
      content {
        name            = "Deploy_to_${action.key}_ASG"
        category        = "Deploy"
        owner           = "AWS"
        version         = "1"
        run_order       = 2
        provider        = "CodeDeploy"
        input_artifacts = ["build_output"]
        configuration = {
          ApplicationName     = aws_codedeploy_app.this[action.key].name
          DeploymentGroupName = aws_codedeploy_deployment_group.this[action.key].deployment_group_name
        }
      }
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeBuild project
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codebuild_project" "this" {
  badge_enabled          = false
  build_timeout          = 60
  description            = "${local.project}-codebuild-project"
  name                   = "${local.project}-codebuild-project"
  queued_timeout         = 480
  depends_on             = [aws_iam_role.codebuild]
  service_role           = aws_iam_role.codebuild.arn
	
  tags = {
    Name = "${local.project}-codebuild-project"
  }

  artifacts {
    encryption_disabled    = false
    name                   = "${local.project}-codebuild-project"
    override_artifact_name = false
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  cache {
    modes = []
    type  = "NO_CACHE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_LARGE"
    image                       = "aws/codebuild/standard:7.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
    type                        = "LINUX_CONTAINER"
	  
  environment_variable {
      name  = "AWS_ENVIRONMENT"
      value = "${aws_ssm_parameter.aws_env.name}"
      type  = "PARAMETER_STORE"
  }
  environment_variable {
      name  = "MAGENTO_ENV"
      value = "${aws_ssm_parameter.magento_env.name}"
      type  = "PARAMETER_STORE"
  }
  environment_variable {
      name  = "COMPOSER_AUTH"
      value = "${aws_ssm_parameter.composer_auth.name}"
      type  = "PARAMETER_STORE"
  }
  environment_variable {
      name  = "CODEDEPLOY_APPSPEC"
      value = "${aws_ssm_parameter.codedeploy_appspec.name}"
      type  = "PARAMETER_STORE"
  }
  environment_variable {
      name  = "PHP_VERSION"
      value = "${var.magento["php_version"]}"
      type  = "PLAINTEXT"
    }
  }
	
  vpc_config {
    vpc_id             = aws_vpc.this.id
    subnets            = [values(aws_subnet.this).0.id]
    security_group_ids = [
      for k, v in aws_security_group.ec2 : v.id if var.ec2[k].service == null
    ]
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = aws_cloudwatch_log_stream.codebuild.name
      status      = "ENABLED"
    }

  s3_logs {
      status = "DISABLED"
    }
  }

  source {
    buildspec           = "${file("${abspath(path.root)}/codepipeline/buildspec.yml")}"
    type                = "CODEPIPELINE"
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
# # ---------------------------------------------------------------------------------------------------------------------#
# CodePipeline webhook to check GitHub repository
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codepipeline_webhook" "push" {
  name            = "${local.project}-github-push-webhook"
  target_action   = "Source"
  target_pipeline = aws_codepipeline.this.name
  authentication  = "GITHUB_HMAC"
  authentication_configuration {
    secret_token  = var.github_secret_token
  }
  filter {
    json_path    = "$.pull_request.base.ref"
    match_equals = "refs/heads/main"
  }
  filter {
    json_path    = "$.pull_request.state"
    match_equals = "closed"
  }
  filter {
    json_path    = "$.pull_request.merged"
    match_equals = "true"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch log group and log stream for CodeBuild logs
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_log_group" "codebuild" {
  name = "${local.project}-codebuild-project"
  tags = {
    Name = "${local.project}-codebuild-project"
  }
}
resource "aws_cloudwatch_log_stream" "codebuild" {
  name = "${local.project}-codebuild-project"
  log_group_name = aws_cloudwatch_log_group.codebuild.name
}
