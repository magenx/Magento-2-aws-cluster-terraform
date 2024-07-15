


////////////////////////////////////////////////////////[ CODEPIPELINE ]//////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document runShellScript to pull main branch from CodeCommit
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "codecommit_pull_main" {
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
resource "aws_cloudwatch_event_rule" "codecommit_pull_main" {
  name        = "${local.project}-CodeCommit-Repository-State-Change-Main"
  description = "CloudWatch monitor Codecommit repository state change main branch"
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
resource "aws_cloudwatch_event_target" "codecommit_pull_main" {
  rule      = aws_cloudwatch_event_rule.codecommit_pull_main.name
  target_id = "${local.project}-App-Deployment-Script"
  arn       = aws_ssm_document.codecommit_pull_main.arn
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
resource "aws_cloudwatch_log_group" "codecommit_pull_main" {
  name = "${local.project}-codecommit-pull-main"
  tags = {
    Name = "${local.project}-codecommit-pull-main"
  }
}

resource "aws_cloudwatch_log_stream" "codecommit_pull_main" {
  name = "${local.project}-codecommit-pull-main"
  log_group_name = aws_cloudwatch_log_group.codecommit_pull_main.name
}
