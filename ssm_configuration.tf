


/////////////////////////////////////////[ SYSTEM MANAGER DOCUMENT EC2 CONFIGURATION ]////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to check and configure EC2 instance webstack
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "configuration" {
  name            = "InstanceConfiguration"
  document_format = "YAML"
  document_type   = "Automation"
  content = <<EOF
schemaVersion: "0.3"
description: "Runs Ansible Playbook to configure EC2 instance"
parameters:
  InstanceIds:
    type: String
    description: The target instance ids
    default: ""
  EventSource:
    type: String
    description: "Event source"
    default: "aws.autoscaling"
mainSteps:
  - name: "RunAnsiblePlaybook"
    action: aws:runCommand
    inputs:
      InstanceIds:
        - "{{ InstanceIds }}"
      DocumentName: AWS-ApplyAnsiblePlaybooks
      Parameters:
        SourceType: "S3"
        SourceInfo:
          path: "https://${aws_s3_bucket.this["system"].bucket_domain_name}/setup/"
        InstallDependencies: "False"
        ExtraVariables: "SSM=True"
        Check: "False"
        Verbose: "-v"
        TimeoutSeconds: "120"
  - name: "SendExecutionLog"
    action: "aws:executeAwsApi"
    isEnd: true
    inputs:
      Service: "sns"
      Api: "Publish"
      TopicArn: "${aws_sns_topic.default.arn}"
      Subject: "Instance {{ InstanceIds }} configuration for ${local.project}"
      Message: "Instance {{ InstanceIds }} configuration {{ automation:EXECUTION_ID }} completed at {{ global:DATE_TIME }}"
EOF
}
