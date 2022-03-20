


////////////////////////////////////////////////////////[ CODEPIPELINE ]//////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeDeploy role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "codedeploy" {
  name = "${local.project}-codedeploy-role"
  description  = "Allows CodeDeploy to call AWS services on your behalf."
  path = "/service-role/"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codedeploy.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = {
     Name = "${local.project}-codedeploy-role"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for CodeDeploy role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_policy" "codedeploy" {
  name = "${local.project}-codedeploy-policy"
  path = "/service-role/"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCodeDeploySNSAlertTrigger",
            "Effect": "Allow",
            "Action": "sns:Publish",
            "Resource": "${aws_sns_topic.default.arn}"
        }
    ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policy for CodeDeploy role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "codedeploy" {
  policy_arn = aws_iam_policy.codedeploy.arn
  role       = aws_iam_role.codedeploy.id
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeBuild role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "codebuild" {
  name = "${local.project}-codebuild-role"
  description = "Allows CodeBuild to call AWS services on your behalf."
  path = "/service-role/"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codebuild.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = {
     Name = "${local.project}-codebuild-role"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for CodeBuild role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_policy" "codebuild" {
  name = "${local.project}-codebuild-policy"
  path = "/service-role/"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
      "Sid": "AllowCodeBuildGitPullActions",
      "Effect": "Allow",
      "Action": [
        "codecommit:GitPull"
      ],
      "Resource": "${aws_codecommit_repository.app.arn}"
    },
    {
      "Sid": "AllowCodeBuildGitPushActions",
      "Effect": "Allow",
      "Action": [
        "codecommit:GitPush"
      ],
      "Resource": "${aws_codecommit_repository.app.arn}",
      "Condition": {
                "StringEqualsIfExists": {
                    "codecommit:References": [
                        "refs/heads/build"
                     ]
                }
          }
    },
    {
      "Sid": "AllowCodeBuildGetParameters",
      "Effect": "Allow",
      "Action": [
	"ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/*"
    },
    {
      "Sid": "AllowCodebuildCreateLogs",
      "Effect": "Allow",
      "Action": [
         "logs:PutLogEvents",
         "logs:CreateLogStream"
      ],
      "Resource": "${aws_cloudwatch_log_group.codebuild.arn}:*"
     }
  ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policy for CodeBuild role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "codebuild" {
  policy_arn = aws_iam_policy.codebuild.arn
  role       = aws_iam_role.codebuild.id
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

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodePipeline role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "codepipeline" {
  name = "${local.project}-codepipeline-role"
  description = "Allows CodePipeline to call AWS services on your behalf."
  path = "/service-role/"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codepipeline.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = {
     Name = "${local.project}-codepipeline-role"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for CodePipeline role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_policy" "codepipeline" {
  name = "${local.project}-codepipeline-policy"
  path = "/service-role/"
  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [{
			"Sid": "AllowCodeCommitActions",
			"Effect": "Allow",
			"Action": [
				"codecommit:GetCommit",
				"codecommit:GetRepository",
				"codecommit:GetBranch"
			],
			"Resource": "${aws_codecommit_repository.app.arn}"
		},
		{
			"Sid": "AllowCodeStarConnectionActions",
			"Effect": "Allow",
			"Action": [
				"codestar-connections:UseConnection"
			],
			"Resource": aws_codestarconnections_connection.github.arn,
			"Condition": {
				"ForAllValues:StringEquals": {
					"codestar-connections:FullRepositoryId": var.app["source_repo"]
				}
			}
		},
		{
			"Sid": "AllowCodeBuildActions",
			"Effect": "Allow",
			"Action": [
				"codebuild:StartBuild",
				"codebuild:StartBuildBatch",
				"codebuild:BatchGetBuilds",
				"codebuild:BatchGetBuildBatches"
			],
			"Resource": "${aws_codebuild_project.this.arn}"
		}
	]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policy for CodePipeline role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "codepipeline" {
  policy_arn = aws_iam_policy.codepipeline.arn
  role       = aws_iam_role.codepipeline.id
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge rule to monitor CodeCommit repository state
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "codecommit_build" {
  name        = "${local.project}-CodeCommit-Repository-State-Change-Build"
  description = "CloudWatch monitor magento repository state change build branch"
  event_pattern = <<EOF
{
	"source": ["aws.codecommit"],
	"detail-type": ["CodeCommit Repository State Change"],
	"resources": ["${aws_codecommit_repository.app.arn}"],
    "detail": {
     "event": [
       "referenceUpdated"
      ],
		 "referenceType": ["branch"],
		 "referenceName": ["build"]
	}
}
EOF
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
# Create CodeDeploy group
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codedeploy_deployment_group" "this" {
  app_name              = aws_codedeploy_app.this.name
  deployment_group_name = "${local.project}-deployment-group"
  service_role_arn      = aws_iam_role.codedeploy.arn
  
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  ec2_tag_set {
    dynamic "ec2_tag_filter" {
      for_each = {for name,type in var.ec2: name => type if name != "varnish"}
      content {
        key   = "Name"
        type  = "KEY_AND_VALUE"
        value = aws_launch_template.this[ec2_tag_filter.key].tag_specifications[0].tags.Name
      }
    }
  }
	
  trigger_configuration {
    trigger_events     = ["DeploymentFailure","DeploymentSuccess"]
    trigger_name       = "${local.project}-deployment-alert"
    trigger_target_arn = aws_sns_topic.default.arn
  }

  auto_rollback_configuration {
    enabled = false
  }
  
  tags = {
    Name = "${local.project}-deployment-group"
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
    image                       = "aws/codebuild/standard:5.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
    type                        = "LINUX_CONTAINER"
	  
    environment_variable {
      name  = "PARAMETERSTORE"
      value = "${aws_ssm_parameter.env.name}"
      type  = "PARAMETER_STORE"
    }
    
    environment_variable {
      name  = "PHP_VERSION"
      value = "${var.app["php_version"]}"
      type  = "PLAINTEXT"
    }
  }
	
  vpc_config {
    vpc_id             = aws_vpc.this.id
    subnets            = values(aws_subnet.this).*.id
    security_group_ids = [
      aws_security_group.ec2.id
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
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
    type                = "CODEPIPELINE"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodePipeline configuration
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codepipeline" "this" {
  name       = "${local.project}-codepipeline"
  depends_on = [aws_iam_role.codepipeline]
  role_arn   = aws_iam_role.codepipeline.arn
  tags       = {
     Name = "${local.project}-codepipeline"
  }

  artifact_store {
    location = aws_s3_bucket.this["system"].bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      category = "Source"
      configuration = {
        "BranchName"           = "build"
        "OutputArtifactFormat" = "CODEBUILD_CLONE_REF"
        "PollForSourceChanges" = "false"
        "RepositoryName"       = aws_codecommit_repository.app.repository_name
      }
      input_artifacts = []
      name            = "Source"
      namespace       = "SourceVariables"
      output_artifacts = [
        "SourceArtifact",
      ]
      owner     = "AWS"
      provider  = "CodeCommit"
      region    = data.aws_region.current.name
      run_order = 1
      version   = "1"
    }
  }
  stage {
    name = "Build"

    action {
      category = "Build"
      configuration = {
        "ProjectName" = aws_codebuild_project.this.id
      }
      input_artifacts = [
        "SourceArtifact",
      ]
      name      = "Build"
      namespace = "BuildVariables"
      output_artifacts = [
        "BuildArtifact",
      ]
      owner     = "AWS"
      provider  = "CodeBuild"
      region    = data.aws_region.current.name
      run_order = 1
      version   = "1"
    }
  }
  stage {
    name = "Deploy"

    action {
      category = "Deploy"
      configuration = {
                BucketName = aws_s3_bucket.this["backup"].bucket
                Extract    = false
                ObjectKey  = "deploy/${local.project}.zip"
                }
      input_artifacts = [
        "BuildArtifact",
      ]
      name             = "Deploy"
      namespace        = "DeployVariables"
      output_artifacts = []
      owner            = "AWS"
      provider         = "S3"
      region           = data.aws_region.current.name
      run_order        = 1
      version          = "1"
    }
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
  event_pattern = <<EOF
{
	"source": ["aws.codecommit"],
	"detail-type": ["CodeCommit Repository State Change"],
	"resources": ["${aws_codecommit_repository.app.arn}"],
	"detail": {
		"referenceType": ["branch"],
		"referenceName": ["main"]
	}
}
EOF
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

