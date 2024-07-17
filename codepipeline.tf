


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
# Create policy for CodeBuild role
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "codebuild" {
  statement {
    sid       = "AllowCodeBuildGetParameters"
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/*"]
  }

  statement {
    sid       = "AllowCodebuildCreateLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.codebuild.arn}:*"]
  }

  statement {
    sid       = "AllowCodebuildDescribe"
    effect    = "Allow"
    actions   = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AllowCodebuildCreateNetworkInterface"
    effect    = "Allow"
    actions   = ["ec2:CreateNetworkInterfacePermission"]
    resources = ["arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:network-interface/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:Subnet"
      values   = values(aws_subnet.this)[*].arn
    }
    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["codebuild.amazonaws.com"]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policy for CodeBuild role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy" "codebuild" {
  role   = aws_iam_role.codebuild.name
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

# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policy for CodePipeline role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy" "codepipeline" {
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline.json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge rule to monitor CodeCommit repository state
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "codecommit_build" {
  name        = "${local.project}-CodeCommit-Repository-State-Change-Build"
  description = "CloudWatch monitor magento repository state change build branch"
  
  event_pattern = jsonencode({
    source       = ["aws.codecommit"],
    detail-type  = ["CodeCommit Repository State Change"],
    resources    = [aws_codecommit_repository.app.arn],
    detail = {
      event         = ["referenceUpdated"],
      referenceType = ["branch"],
      referenceName = ["build"]
    }
  })
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge target to execute SSM Document
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "codepipeline_build" {
  rule      = aws_cloudwatch_event_rule.codecommit_build.name
  target_id = "${local.project}-Start-CodePipeline"
  arn       = aws_codepipeline.this.arn
  role_arn  = aws_iam_role.eventbridge_service_role.arn
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeDeploy app
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codedeploy_app" "this" {
  name = "${local.project}-deployment-app"
  tags = {
    Name = "${local.project}-deployment-app"
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document runShellScript to pull main branch from CodeCommit
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "git_pull_main" {
  name          = "${local.project}-codecommit-pull-main-changes"
  document_type = "Command"
  document_format = "YAML"
  target_type   = "/AWS::EC2::Instance"
  content = <<EOT
---
schemaVersion: "2.2"
description: "Pull code changes from CodeCommit main branch"
parameters:
mainSteps:
- action: "aws:runShellScript"
  name: "${replace(local.project,"-","")}CodeCommitPullMainChanges"
  inputs:
    runCommand:
    - |-
      #!/bin/bash
      cd /home/${var.app["brand"]}/public_html
      su ${var.app["brand"]} -s /bin/bash -c "git fetch origin"
      su ${var.app["brand"]} -s /bin/bash -c "git reset --hard origin/main"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:db:status --no-ansi -n"
      if [[ $? -ne 0 ]]; then
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:upgrade --keep-generated --no-ansi -n"
      fi
      systemctl restart php*fpm.service
      systemctl restart nginx.service
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento cache:flush"
EOT
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge rule to monitor CodeCommit repository state
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "codecommit_main" {
  name        = "${local.project}-CodeCommit-Repository-State-Change-Main"
  description = "CloudWatch monitor magento repository state change main branch"
  event_pattern = jsonencode({
    source       = ["aws.codecommit"]
    detail-type  = ["CodeCommit Repository State Change"]
    resources    = [aws_codecommit_repository.app.arn]
    detail = {
      referenceType = ["branch"]
      referenceName = ["main"]
    }
  })
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge target to execute SSM Document
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "codecommit_main" {
  rule      = aws_cloudwatch_event_rule.codecommit_main.name
  target_id = "${local.project}-App-Deployment-Script"
  arn       = aws_ssm_document.git_pull_main.arn
  role_arn  = aws_iam_role.eventbridge_service_role.arn
 
dynamic "run_command_targets" {
    for_each = {for name,type in var.ec2: name => type if name != "varnish"}
    content {
      key      = "tag:Name"
      values   = [aws_launch_template.this[run_command_targets.key].tag_specifications[0].tags.Name]
    }
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
