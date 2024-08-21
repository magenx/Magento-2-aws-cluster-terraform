


////////////////////////////////////////////////////////[ NGINX CONFIGURATION ]///////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document runShellScript to pull nginx configuration from CodeCommit
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "codecommit_nginx" {
  for_each        = toset(["frontend", "admin"])
  name            = "${local.project}-codecommit-pull-nginx-${each.key}-config-changes"
  document_type   = "Command"
  document_format = "YAML"
  target_type     = "/AWS::EC2::Instance"
  content = <<EOT
---
schemaVersion: "2.2"
description: "Pull nginx ${each.key} configuration changes from CodeCommit"
parameters:
mainSteps:
- action: "aws:runShellScript"
  name: "${var.app["brand"]}CodeCommitPullNginx${title(each.key)}ConfigChanges"
  inputs:
    runCommand:
    - |-
      #!/bin/bash
      cd /etc/nginx
      git fetch origin nginx_${each.key}
      git reset --hard origin/nginx_${each.key}
      git checkout -t origin/nginx_${each.key}
      if nginx -t 2>/dev/null; then systemctl restart nginx; else exit 1; fi
EOT
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge rule to monitor CodeCommit nginx branch state
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "codecommit_nginx" {
  for_each      = toset(["frontend", "admin"])
  name          = "${local.project}-Nginx-${title(each.key)}-Repo-State-Change"
  description   = "CloudWatch monitor nginx ${each.key} repository state change"
  event_pattern = <<EOF
{
	"source": ["aws.codecommit"],
	"detail-type": ["CodeCommit Repository State Change"],
	"resources": ["${aws_codecommit_repository.services.arn}"],
	"detail": {
		"referenceType": ["branch"],
		"referenceName": ["nginx_${each.key}"]
	}
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge target to execute SSM Document
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "codecommit_nginx" {
  for_each  = toset(["frontend", "admin"])
  rule      = aws_cloudwatch_event_rule.codecommit_nginx[each.key].name
  target_id = "${local.project}-Nginx-${title(each.key)}-Config-Deployment-Script"
  arn       = aws_ssm_document.codecommit_nginx[each.key].arn
  role_arn  = aws_iam_role.eventbridge_service_role.arn
 
run_command_targets {
    key    = "tag:Name"
    values = [aws_launch_template.this[each.key].tag_specifications[0].tags.Name]
  }
}
      
