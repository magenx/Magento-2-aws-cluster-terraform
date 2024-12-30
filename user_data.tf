


/////////////////////////////////////////////[ SYSTEM MANAGER DOCUMENT USER DATA ]////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to configure EC2 instances in Auto Scaling Group
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "user_data" {
  name            = "BootstrappingEC2WithUserData"
  document_format = "YAML"
  document_type   = "Command"
  content = <<EOF
schemaVersion: "2.2"
description: "Bootstrapping EC2 instance with UserData"
mainSteps:
  - name: "WebStackCleanup"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          if [ ! -f "/root/webstack_clean" ]; then
            WEB_STACK_CHECK="mysql* rabbitmq* elasticsearch opensearch percona-server* maria* php* nginx* apache* ufw varnish* certbot* redis* webmin awscli"
            INSTALLED_PACKAGES="$(apt -qq list --installed $${WEB_STACK_CHECK} 2> /dev/null | cut -d'/' -f1 | tr '\n' ' ')"
            if [ ! -z "$${INSTALLED_PACKAGES}" ]; then
              apt -qq -y remove --purge "$${INSTALLED_PACKAGES}"
            fi
          fi
          touch /root/webstack_clean
  - name: "InstallBasePackages"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          apt -qqy update
          apt -qqy install jq apt-transport-https lsb-release ca-certificates curl gnupg software-properties-common snmp syslog-ng-core snapd
          if ! grep -q 'snap' ~/.bashrc; then
            echo 'export PATH=$PATH:/snap/bin' >> ~/.bashrc
            . ~/.bashrc
          fi
          snap list | grep -q "^amazon-ssm-agent" || snap install amazon-ssm-agent --classic
          snap list | grep -q "^aws-cli" || snap install aws-cli --classic
  - name: "ParameterstoreQueryScript"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          cat <<END > /usr/local/bin/parameterstore
          #!/bin/bash
          parameterstore() {
              local key=$$1
              aws ssm get-parameter --name "${AWS_ENVIRONMENT}" --query 'Parameter.Value' --output text | jq -r ".$${key}"
          }
          if [ "$$#" -eq 0 ]; then
              echo "Usage: $$0 <parameter-key>"
              echo "Example: $$0 BRAND"
              exit 1
          fi
          key=$$1
          parameterstore "$${key}"
          END
          chmod +x /usr/local/bin/parameterstore
  - name: "EC2MetadataQueryScript"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          cat <<END > /usr/local/bin/metadata
          #!/bin/bash
          METADATA_URL="http://169.254.169.254/latest"
          # Function to get metadata
          metadata() {
              local FIELD=$$1
              # Fetch the token
              TOKEN=$(curl -sSf -X PUT "$${METADATA_URL}/api/token" \
                  -H "X-aws-ec2-metadata-token-ttl-seconds: 300") || {
                  echo "Error: Unable to fetch token. Ensure IMDSv2 is enabled." >&2
                  exit 1
              }
              # Fetch the metadata value
              curl -sSf -X GET "$${METADATA_URL}/meta-data/${FIELD}" \
                  -H "X-aws-ec2-metadata-token: $${TOKEN}" || {
                  echo "Error: Unable to fetch metadata for field '$${FIELD}'." >&2
                  exit 1
              }
          }
          if [ "$$#" -eq 0 ]; then
              echo "Usage: $$0 <metadata-field>"
              echo "Example: $$0 instance-id"
              exit 1
          fi
          FIELD=$$1
          metadata "$$FIELD"
          END
          chmod +x /usr/local/bin/metadata
  - name: "InstanceConfiguration"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          # Create local setup directories
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

          # Download configuration files from s3
          OPTIONS="--quiet --exact-timestamps --delete --checksum-mode ENABLED --checksum-algorithm SHA256"
          aws s3 sync "s3://${aws_s3_bucket.this["system"].bucket}/setup/instance" "$${INIT_DIRECTORY}" $${OPTIONS} && \
          aws s3 sync "s3://${aws_s3_bucket.this["system"].bucket}/setup/$${INSTANCE_NAME}" "$${INSTANCE_DIRECTORY}" $${OPTIONS}

          # Check if both sync commands were successful
          if [ $? -eq 0 ]; then
              # Execute scripts in order from INIT_DIRECTORY
              for SCRIPT in $(ls "$${INIT_DIRECTORY}"/*.sh | sort); do
                  LOG_FILE="$${LOG_DIRECTORY}/$(basename "$${SCRIPT}").log"
                  HASH_FILE="$${HASH_DIRECTORY}/$(basename "$${SCRIPT}").md5sum"
                  NEW_HASH=$(md5sum "$${SCRIPT}" | awk '{print $1}')        
                  if [ ! -f "$${HASH_FILE}" ] || [ "$${NEW_HASH}" != "$(cat "$${HASH_FILE}")" ]; then
                      echo "$${NEW_HASH}" > "$${HASH_FILE}"
                      echo -e "\n$(date) Running: $${SCRIPT}" | tee -a "$${LOG_FILE}"
                      bash "$${SCRIPT}" >>"$${LOG_FILE}" 2>&1
                  fi
              done
              # Execute scripts in order from INSTANCE_DIRECTORY
              for SCRIPT in $(ls "$${INSTANCE_DIRECTORY}"/*.sh | sort); do
                  LOG_FILE="$${LOG_DIRECTORY}/$(basename "$${SCRIPT}").log"
                  HASH_FILE="$${HASH_DIRECTORY}/$(basename "$${SCRIPT}").md5sum"
                  NEW_HASH=$(md5sum "$${SCRIPT}" | awk '{print $1}')        
                  if [ ! -f "$${HASH_FILE}" ] || [ "$${NEW_HASH}" != "$(cat "$${HASH_FILE}")" ]; then
                      echo "$${NEW_HASH}" > "$${HASH_FILE}"
                      echo -e "\n$(date) Running: $${SCRIPT}" | tee -a "$${LOG_FILE}"
                      bash "$${SCRIPT}" >>"$${LOG_FILE}" 2>&1
                  fi
              done
          else
              echo "Error syncing files from S3"
          fi
  - name: "InstallCloudWatchAgent"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          cd /tmp
          wget https://amazoncloudwatch-agent.s3.amazonaws.com/debian/arm64/latest/amazon-cloudwatch-agent.deb
          dpkg -i amazon-cloudwatch-agent.deb
          /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:amazon-cloudwatch-agent-${INSTANCE_NAME}.json
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Emit events to EventBridge
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket_notification" "this" {
  bucket      = aws_s3_bucket.this["system"].id
  eventbridge = true
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document association with Auto Scaling Group
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_association" "user_data" {
  for_each = var.ec2
  name     = aws_ssm_document.user_data.name
  targets {
    key    = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.this[each.key].name]
  }
  association_name = "Configuration-for-EC2-instances-in-${aws_autoscaling_group.this[each.key].name}"
  document_version = "$LATEST"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule for S3 bucket object event
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "s3_update" {
  for_each    = var.ec2
  name        = "${local.project}-${each.key}-s3-update-setup"
  description = "Trigger SSM document when s3 system bucket updated for ${each.key}"
  event_pattern = jsonencode({
    "source"       : ["aws.s3"],
    "detail-type"  : ["Object Created"],
    "detail"       : {
      "bucket"     : { "name" : [aws_s3_bucket.this["system"].bucket] },
      "object"     : { "key" : [{ "prefix" : "setup/" }] }
    }
  })
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule Target for SSM Document
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "instance_setup" {
  depends_on = [aws_autoscaling_group.this]
  for_each  = var.ec2
  rule      = aws_cloudwatch_event_rule.s3_update[each.key].name
  target_id = "${local.project}-${each.key}-instance-setup"
  arn       =  aws_ssm_document.user_data.arn
  role_arn  =  aws_iam_role.ec2[each.key].arn
  run_command_targets {
    key    = "tag:Name"
    values = ["${local.project}-${each.key}-ec2"]
  }
}
