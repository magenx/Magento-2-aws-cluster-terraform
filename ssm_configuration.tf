


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
assumeRole: ${aws_iam_role.ssm_service_role.arn}
parameters:
  S3ObjectKey:
    type: String
    description: "The S3 object key path"
mainSteps:
  - name: "ExtractInstanceName"
    action: aws:executeScript
    inputs:
      Runtime: python3.11
      Handler: extract_instance_name
      Script: |-
        import re
        def extract_instance_name(event, context):
            s3_object_key = event['S3ObjectKey']
            instance_name = s3_object_key.split('/')[1]
            return { "InstanceName": instance_name }
      InputPayload:
        S3ObjectKey: "{{ S3ObjectKey }}"
    outputs:
      - Name: InstanceName
        Selector: "$.Payload.InstanceName"
        Type: String
  - name: "FilterInstancesByNameTag"
    action: aws:executeAwsApi
    inputs:
      Service: ec2
      Api: DescribeInstances
      Filters:
        - Name: tag:InstanceName
          Values:
            - "{{ ExtractInstanceName.InstanceName }}"
    outputs:
      - Name: InstanceIds
        Selector: "$.Reservations..Instances..InstanceId"
        Type: StringList
  - name: "RunCommandOnInstances"
    action: aws:runCommand
    inputs:
      DocumentName: "AWS-RunShellScript"
      InstanceIds: "{{ FilterInstancesByNameTag.InstanceIds }}"
      Parameters:
        commands:
          - |-
            #!/bin/bash
            sudo pipx install ansible-core
            sudo /root/.local/bin/ansible localhost -m ping > /dev/null 2>&1 && echo "SUCCESS: Ansible ping worked!" || { echo "ERROR: Ansible ping failed!"; exit 1; }
            INSTANCE_NAME=$(metadata tags/instance/InstanceName)
            INSTANCE_IP=$(metadata local-ipv4)
            SETUP_DIRECTORY="/opt/${var.brand}/setup"
            INSTANCE_DIRECTORY="$${SETUP_DIRECTORY}/$${INSTANCE_NAME}"
            mkdir -p "$${INSTANCE_DIRECTORY}"
            touch $${SETUP_DIRECTORY}/init
            S3_OPTIONS="--quiet --exact-timestamps --delete"
            sudo /root/awscli/bin/aws s3 sync "s3://${aws_s3_bucket.this["system"].bucket}/setup/$${INSTANCE_NAME}" "$${INSTANCE_DIRECTORY}" $${S3_OPTIONS}
            find $${INSTANCE_DIRECTORY}/ -type f -name '*.y*ml' -delete
            cd $${INSTANCE_DIRECTORY}/
            unzip -o $${INSTANCE_NAME}.zip
            sudo /root/.local/bin/ansible-playbook -i localhost -c local -e "SSM=True instance_name=$${INSTANCE_NAME} instance_ip=$${INSTANCE_IP}" -v  $${INSTANCE_DIRECTORY}/$${INSTANCE_NAME}.yml
      CloudWatchOutputConfig:
        CloudWatchLogGroupName: "${local.project}-InstanceConfiguration"
        CloudWatchOutputEnabled: true
  - name: "SendExecutionLog"
    action: "aws:executeAwsApi"
    isEnd: true
    inputs:
      Service: "sns"
      Api: "Publish"
      TopicArn: "${aws_sns_topic.default.arn}"
      Subject: "Instance configuration for ${local.project}"
      Message: "Instance {{ ExtractInstanceName.InstanceName }} {{ FilterInstancesByNameTag.InstanceIds }} configuration {{ automation:EXECUTION_ID }} completed at {{ global:DATE_TIME }}"
EOF
}
