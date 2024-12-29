


/////////////////////////////////////////////[ SYSTEM MANAGER DOCUMENT USER DATA ]////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to configure EC2 instances in Auto Scaling Group
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "user_data" {
  name          = "BootstrappingEC2WithUserData"
  document_format = "YAML"
  document_type = "Command"
  content = <<EOF
schemaVersion: "2.2"
description: "Bootstrapping EC2 instance with UserData"
mainSteps:
  - name: "BootstrappingEC2"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          # Create local setup directories
          SETUP_DIRECTORY="/opt/${var.brand}"
          LOG_DIRECTORY="$${SETUP_DIRECTORY}/setup/log"
          HASH_DIRECTORY="$${SETUP_DIRECTORY}/setup/.hash"
          INIT_DIRECTORY="$${SETUP_DIRECTORY}/setup/instance"
          INSTANCE_DIRECTORY="$${SETUP_DIRECTORY}/setup/{{ INSTANCE_NAME }}"
          mkdir -p "$${LOG_DIRECTORY}"
          mkdir -p "$${HASH_DIRECTORY}"
          mkdir -p "$${INIT_DIRECTORY}"
          mkdir -p "$${INSTANCE_DIRECTORY}"
          touch $${SETUP_DIRECTORY}/init

          # Download configuration files from s3
          OPTIONS="--quiet --exact-timestamps --delete --checksum-mode ENABLED --checksum-algorithm SHA256"
          aws s3 sync "s3://${aws_s3_bucket.this["system"].bucket}/setup/instance" "$${INIT_DIRECTORY}" $${OPTIONS} && \
          aws s3 sync "s3://${aws_s3_bucket.this["system"].bucket}/setup/{{ INSTANCE_NAME }}" "$${INSTANCE_DIRECTORY}" $${OPTIONS}

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
#resource "aws_ssm_association" "user_data" {
#  for_each = var.ec2
#  name     = aws_ssm_document.user_data.name
#  targets {
#    key    = "tag:aws:autoscaling:groupName"
#    values = [aws_autoscaling_group.this[each.key].name]
#  }
#  association_name = "Configuration-for-EC2-instances-in-${aws_autoscaling_group.this[each.key].name}"
#  document_version = "$LATEST"
#}
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
      "object"     : { "key" : [{ "prefix" : "setup/${each.key}/" }] }
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
