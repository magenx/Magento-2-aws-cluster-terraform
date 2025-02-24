


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
description: "Instance configuration"
parameters:
  InstanceIds:
    type: String
    description: The target instance id
  EventSource:
    type: String
    description: "Event Source"
    default: ""
mainSteps:
  - name: "InstanceConfiguration"
    action: "aws:runCommand"
    inputs:
      DocumentName: "AWS-RunShellScript"
      Parameters:
        commands:
          - |-
            #!/bin/bash
            INSTANCE_NAME=$(metadata tags/instance/Instance_name)
            SETUP_DIRECTORY="/opt/${var.brand}/setup"
            LOG_DIRECTORY="$${SETUP_DIRECTORY}/log"
            HASH_DIRECTORY="$${SETUP_DIRECTORY}/.hash"
            INIT_DIRECTORY="$${SETUP_DIRECTORY}/instance"
            INSTANCE_DIRECTORY="$${SETUP_DIRECTORY}/$${INSTANCE_NAME}"
            mkdir -p "$${LOG_DIRECTORY}"
            mkdir -p "$${HASH_DIRECTORY}"
            mkdir -p "$${INIT_DIRECTORY}"
            mkdir -p "$${INSTANCE_DIRECTORY}"
            touch $${SETUP_DIRECTORY}/init
            OPTIONS="--quiet --exact-timestamps --delete"
            aws s3 sync "s3://${aws_s3_bucket.this["system"].bucket}/setup/instance" "$${INIT_DIRECTORY}" $${OPTIONS} && \
            aws s3 sync "s3://${aws_s3_bucket.this["system"].bucket}/setup/$${INSTANCE_NAME}" "$${INSTANCE_DIRECTORY}" $${OPTIONS}
            if [ $? -eq 0 ]; then
                for SCRIPT in $(ls "$${INIT_DIRECTORY}"/*.sh | sort); do
                    LOG_FILE="$${LOG_DIRECTORY}/$(basename "$${SCRIPT}").log"
                    HASH_FILE="$${HASH_DIRECTORY}/$(basename "$${SCRIPT}").md5sum"
                    NEW_HASH=$(md5sum "$${SCRIPT}" | awk '{print $1}')        
                    if [ ! -f "$${HASH_FILE}" ] || [ "$${NEW_HASH}" != "$(cat "$${HASH_FILE}")" ]; then
                        echo "$${NEW_HASH}" > "$${HASH_FILE}"
                        echo -e "\n$(date)\nRunning: $${SCRIPT}" >> "$${LOG_FILE}"
                        bash "$${SCRIPT}" >>"$${LOG_FILE}" 2>&1
                    fi
                done
                for SCRIPT in $(ls "$${INSTANCE_DIRECTORY}"/*.sh | sort); do
                    LOG_FILE="$${LOG_DIRECTORY}/$(basename "$${SCRIPT}").log"
                    HASH_FILE="$${HASH_DIRECTORY}/$(basename "$${SCRIPT}").md5sum"
                    NEW_HASH=$(md5sum "$${SCRIPT}" | awk '{print $1}')        
                    if [ ! -f "$${HASH_FILE}" ] || [ "$${NEW_HASH}" != "$(cat "$${HASH_FILE}")" ]; then
                        echo "$${NEW_HASH}" > "$${HASH_FILE}"
                        echo -e "\n$(date)\nRunning: $${SCRIPT}" >> "$${LOG_FILE}"
                        bash "$${SCRIPT}" >>"$${LOG_FILE}" 2>&1
                    fi
                done
            else
                echo "-- [ERROR]: Configuration files not found"
            fi
      Targets:
        - Key: "InstanceIds"
          Values:
            - "{{ InstanceIds }}"
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
      Subject: "Instance Configuration ${local.project}-{{ InstanceIds }}"
      Message: "Instance Configuration {{ automation:EXECUTION_ID }} completed at {{ global:DATE_TIME }}"
EOF
}
