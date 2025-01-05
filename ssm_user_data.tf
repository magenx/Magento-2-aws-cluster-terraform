


/////////////////////////////////////////////[ SYSTEM MANAGER DOCUMENT USER DATA ]////////////////////////////////////////

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
  association_name = "InitEC2WithUserData-${aws_autoscaling_group.this[each.key].name}"
  document_version = "$LATEST"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to get InitEC2WithUserData document
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "get_user_data" {
  name            = "GetInitEC2WithUserData"
  document_format = "YAML"
  document_type   = "Automation"
  content = <<EOF
schemaVersion: "0.3"
description: "Automate execution of InitEC2WithUserData on an instance"
parameters:
  instanceId:
    type: String
mainSteps:
  - name: ExecuteInitEC2WithUserData
    action: aws:runCommand
    inputs:
      DocumentName: "InitEC2WithUserData"
      InstanceIds:
        - "{{ instanceId }}"
      TimeoutSeconds: 120
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to configure EC2 instances in Auto Scaling Group
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "user_data" {
  name            = "InitEC2WithUserData"
  document_format = "YAML"
  document_type   = "Command"
  content = <<EOF
schemaVersion: "2.2"
description: "Init EC2 instance with UserData"
parameters:
  instanceId:
    type: String
mainSteps:
  - name: "SendNotification"
    action: "aws:executeAwsApi"
    inputs:
      Service: "sns"
      Api: "Publish"
      TopicArn: ${aws_sns_topic.default.arn}
      Message: "Init EC2 with user_data @ {{ instanceId }}"
  - name: "WebStackCleanup"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          #!/bin/bash
          if [ ! -f "/root/webstack_clean" ]; then
            WEB_STACK_CHECK="mysql* rabbitmq* elasticsearch opensearch percona-server* maria* php* nginx* apache* ufw varnish* certbot* redis* webmin"
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
          apt -qqy install jq apt-transport-https lsb-release ca-certificates curl gnupg software-properties-common snmp syslog-ng-core
  - name: "ParameterstoreQueryScript"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          cat <<'END' > /usr/local/bin/parameterstore
          #!/bin/bash
          parameterstore() {
              local KEY=$1
              local PARAMETER_NAME="/${local.project}/${local.environment}/$${KEY}"
              aws ssm get-parameter --name "$${PARAMETER_NAME}" --with-decryption --query 'Parameter.Value' --output text
          }
          if [ "$#" -eq 0 ]; then
              echo "Usage: $0 <parameter-key>"
              echo "Example: $0 BRAND"
              exit 1
          fi
          KEY=$1
          parameterstore "$${KEY}"
          END
          chmod +x /usr/local/bin/parameterstore
  - name: "EC2MetadataQueryScript"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          cat <<'END' > /usr/local/bin/metadata
          #!/bin/bash
          METADATA_URL="http://169.254.169.254/latest"
          # Function to get metadata
          metadata() {
              local FIELD=$1
              # Fetch the token
              TOKEN=$(curl -sSf -X PUT "$${METADATA_URL}/api/token" \
                  -H "X-aws-ec2-metadata-token-ttl-seconds: 300") || {
                  echo "Error: Unable to fetch token. Ensure IMDSv2 is enabled." >&2
                  exit 1
              }
              # Fetch the metadata value
              curl -sSf -X GET "$${METADATA_URL}/meta-data/$${FIELD}" \
                  -H "X-aws-ec2-metadata-token: $${TOKEN}" || {
                  echo "Error: Unable to fetch metadata for field $${FIELD}." >&2
                  exit 1
              }
          }
          if [ "$#" -eq 0 ]; then
              echo "Usage: $0 <metadata-field>"
              echo "Example: $0 instance-id"
              exit 1
          fi
          FIELD=$1
          metadata "$${FIELD}"
          END
          chmod +x /usr/local/bin/metadata
  - name: "LatestReleaseDeployment"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          #!/bin/bash
          # Get latest release package
          LATEST_RELEASE=$(aws s3 ls s3://${aws_s3_bucket.this["system"].bucket}/releases/ --recursive | sort | tail -n 1 | awk '{print $3}')
          SHARED_DIRECTORY="/home/${var.brand}/shared"
          LATEST_RELEASE_DIRECTORY="/home/${var.brand}/releases/$${LATEST_RELEASE}"
          mkdir -p $${LATEST_RELEASE_DIRECTORY}/pub
          # Symlink shared folders
          ln -nfs "$${SHARED_DIRECTORY}/var" "$${LATEST_RELEASE_DIRECTORY}/var"
          ln -nfs "$${SHARED_DIRECTORY}/pub/media" "$${LATEST_RELEASE_DIRECTORY}/pub/media"
          # Sync latest release package
          aws s3 sync "s3://${aws_s3_bucket.this["system"].bucket}/releases/$${LATEST_RELEASE}" "$${LATEST_RELEASE_DIRECTORY}"
          # Ensure the new release directory exists
          if [ ! -d "$${LATEST_RELEASE_DIRECTORY}" ]; then
            echo "New release directory not found!"
            echo "Deployment error!"
            exit 1
          fi
          # Check if the directory is an EFS mount
          if ! df -T "$${LATEST_RELEASE_DIRECTORY}/pub/media" | grep -q "efs"; then
            echo "The media directory is not an EFS mount."
            echo "Deployment error!"
            exit 1
          fi
          # Unzip lastest release package
          cd $${LATEST_RELEASE_DIRECTORY}
          unzip '*.zip' && rm -f *.zip
          # Perform symlink swap to point to the new release
          ln -nfs "$${LATEST_RELEASE_DIRECTORY}" "$${PUBLIC_HTML}"
  - name: "InstanceConfiguration"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          #!/bin/bash
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
          OPTIONS="--quiet --exact-timestamps --delete"
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
  - name: "CloudMapInstanceRegistration"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          #!/bin/bash
          INSTANCE_IP="$(metadata local-ipv4)"
          INSTANCE_ID="$(metadata instance-id)"
          INSTANCE_NAME="$(metadata tags/instance/Instance_name)"
          INSTANCE_HOSTNAME="$(metadata tags/instance/Hostname)"
          CLOUDMAP_SERVICE_ID="$(parameterstore $${INSTANCE_NAME^^}_CLOUDMAP_SERVICE_ID)"
          if ! grep -q "$${INSTANCE_IP}  $${INSTANCE_HOSTNAME}" /etc/hosts; then
            echo "$${INSTANCE_IP}  $${INSTANCE_HOSTNAME}" >> /etc/hosts
          fi
          hostnamectl set-hostname $${INSTANCE_HOSTNAME}
          aws servicediscovery register-instance \
            --region ${data.aws_region.current.name} \
            --service-id $${CLOUDMAP_SERVICE_ID} \
            --instance-id $${INSTANCE_ID} \
            --attributes AWS_INSTANCE_IPV4=$${INSTANCE_IP}
  - name: "InstallCloudWatchAgent"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          #!/bin/bash
          INSTANCE_NAME="$(metadata tags/instance/Instance_name)"
          cd /tmp
          wget https://amazoncloudwatch-agent.s3.amazonaws.com/debian/arm64/latest/amazon-cloudwatch-agent.deb
          dpkg -i amazon-cloudwatch-agent.deb
          /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:amazon-cloudwatch-agent-$${INSTANCE_NAME}.json
EOF
}
