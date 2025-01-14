


////////////////////////////////////////[ SYSTEM MANAGER DOCUMENT SEND EXECUTION LOG ]////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to send ssm execution log
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "sendexecutionlog" {
  name            = "SendExecutionLog"
  document_format = "YAML"
  document_type   = "Automation"
  content = <<EOF
schemaVersion: "0.3"
description: "Instance configuration step"
parameters:
  EventSource:
    type: String
    description: "Event Source for SSM Document Execution"
    default: "aws.autoscaling"
  Force:
    type: String
    description: "Force SSM Document Steps Execution"
    default: "false"
  LogFileName:
    type: String
    description: "SSM Document Execution log file"
    default: "/tmp/ssm_execution_log.txt"
mainSteps:
  - name: "SendExecutionLog"
    action: "aws:runCommand"
    inputs:
      DocumentName: "AWS-RunShellScript"
      Parameters:
        commands:
          - |-
            #!/bin/bash
            echo "---------------|{{ EventSource }}|----------------" >> {{ LogFileName }}
            echo "Instance uptime: $(uptime)" >> {{ LogFileName }}
            echo "INSTANCE_ID: $(metadata instance-id)" >> {{ LogFileName }}
            echo "INSTANCE_NAME: $(metadata tags/instance/Instance_name)" >> {{ LogFileName }}
            echo "INSTANCE_HOSTNAME: $(hostname)" >> {{ LogFileName }}
            echo "SSM Document is complete: $(date)" >> {{ LogFileName }}
            aws sns publish \
              --topic-arn ${aws_sns_topic.default.arn} \
              --subject "SSM Document [{{ EventSource }}] execution on $(metadata tags/instance/Instance_name)" \
              --message file://{{ LogFileName }}
EOF
}
