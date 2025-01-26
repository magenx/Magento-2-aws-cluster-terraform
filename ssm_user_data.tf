


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
# Create SSM Document to configure EC2 instances in Auto Scaling Group
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "user_data" {
  name            = "InitEC2WithUserData"
  document_format = "YAML"
  document_type   = "Automation"
  content = <<EOF
schemaVersion: "0.3"
description: "Init EC2 instance with UserData"
parameters:
  LogFileName:
    type: String
    description: "SSM Document Execution log file"
    default: "/tmp/ssm_execution_log.txt"
mainSteps:
  - name: "WebStackCleanup"
    action: "aws:runCommand"
    inputs:
      DocumentName: "AWS-RunShellScript"
      Parameters:
        commands:
          - |-
            #!/bin/bash
            echo "Start document $(date)" > {{ LogFileName }}
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
  - name: "WriteHelperScripts"
    action: "aws:runCommand"
    inputs:
      DocumentName: "AWS-RunShellScript"
      Parameters:
        commands:
          - |-
            ### Parameterstore request script
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
            ### EC2 Metadata Request Script
            cat <<'END' > /usr/local/bin/metadata
            #!/bin/bash
            METADATA_URL="http://169.254.169.254/latest"
            metadata() {
                local FIELD=$1
                TOKEN=$(curl -sSf -X PUT "$${METADATA_URL}/api/token" \
                    -H "X-aws-ec2-metadata-token-ttl-seconds: 300") || {
                    echo "Error: Unable to fetch token. Ensure IMDSv2 is enabled." >&2
                    exit 1
                }
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
            ### Write leader instance script
            cat <<'END' > /usr/local/bin/leader
            INSTANCE_ID=$(metadata instance-id)
            LEADER_INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.this["frontend"].name} --region ${data.aws_region.current.name} --output json | \
              jq -r '.AutoScalingGroups[].Instances[] | select(.LifecycleState=="InService") | .InstanceId' | sort | head -1)
            [ "$${LEADER_INSTANCE_ID}" = "$${INSTANCE_ID}" ]
            END
            chmod +x /usr/local/bin/leader
  - name: "LatestReleaseDeployment"
    action: "aws:executeAutomation"
    inputs:
      DocumentName: "LatestReleaseDeployment"
      Targets:
        - Key: "tag:${keys(local.ec2_setup)[0]}"
          Values:
            - ${values(local.ec2_setup)}
  - name: "InstanceConfiguration"
    action: "aws:executeAutomation"
    inputs:
      DocumentName: "InstanceConfiguration"
      Targets:
        - Key: "tag:${keys(local.ec2_setup)[0]}"
          Values:
            - ${values(local.ec2_setup)}
  - name: "CloudMapInstanceRegistration"
    action: "aws:runCommand"
    inputs:
      DocumentName: "AWS-RunShellScript"
      Parameters:
        commands:
          - |-
            #!/bin/bash
            echo "Start CloudMap registration step $(date)" >> {{ LogFileName }}
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
    action: "aws:runCommand"
    inputs:
      DocumentName: "AWS-RunShellScript"
      Parameters:
        commands:
          - |-
            #!/bin/bash
            echo "Start Amazon Cloud Watch Agent installation step:" >> {{ LogFileName }}
            INSTANCE_NAME="$(metadata tags/instance/Instance_name)"
            cd /tmp
            wget https://amazoncloudwatch-agent.s3.amazonaws.com/debian/arm64/latest/amazon-cloudwatch-agent.deb
            dpkg -i amazon-cloudwatch-agent.deb
            /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:/cloudwatch-agent/amazon-cloudwatch-agent-$${INSTANCE_NAME}.json
  - name: "SendExecutionLog"
    action: "aws:executeAutomation"
    inputs:
      DocumentName: "SendExecutionLog"
      Targets:
        - Key: "tag:${keys(local.ec2_setup)[0]}"
          Values:
            - values(local.ec2_setup)
EOF
}
