


//////////////////////////////////////////////[ SYSTEM MANAGER DOCUMENT RELEASE ]/////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to check and deploy latest release on EC2 from S3
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "release" {
  name            = "LatestReleaseDeployment"
  document_format = "YAML"
  document_type   = "Automation"
  content = <<EOF
schemaVersion: "0.3"
description: "Latest release deployment step"
parameters:
  EventSource:
    type: String
    description: "Event Source"
    default: ""
  LogFileName:
    type: String
    description: "SSM Document Execution log file"
    default: "/tmp/ssm_execution_log.txt"
  Force:
    type: String
    description: "Force SSM Document Steps Execution"
    default: "false"
mainSteps:
  - name: "LatestReleaseDeployment"
    action: "aws:runCommand"
    inputs:
      DocumentName: "AWS-RunShellScript"
      Parameters:
        commands:
          - |-
            #!/bin/bash
            echo "Start release check step $(date)" >> {{ LogFileName }}
            LATEST_RELEASE=$(aws s3 ls s3://${aws_s3_bucket.this["system"].bucket}/releases/ --recursive | sort | tail -n 1 | awk '{print $3}')
            if [ -z "$${LATEST_RELEASE}" ]; then
              echo "-- Release directory not found or empty" >> {{ LogFileName }}
              exit 1
            fi
            RELEASES_DIRECTORY="/home/${var.brand}/releases"
            for DIRECTORY in $${RELEASES_DIRECTORY}/*; do
              if [ "$(basename "$${DIRECTORY}")" == "$${LATEST_RELEASE}" ]; then
                echo "-- [INFO]: Release directory [$${LATEST_RELEASE}] already exists" >> {{ LogFileName }}
                exit 1
              fi
            done 
            echo "-- Latest release found: [$${LATEST_RELEASE}]" >> {{ LogFileName }}
            SHARED_DIRECTORY="/home/${var.brand}/shared"
            LATEST_RELEASE_DIRECTORY="/home/${var.brand}/releases/$${LATEST_RELEASE}"
            mkdir -p $${LATEST_RELEASE_DIRECTORY}/pub
            ln -nfs "$${SHARED_DIRECTORY}/var" "$${LATEST_RELEASE_DIRECTORY}/var"
            ln -nfs "$${SHARED_DIRECTORY}/pub/media" "$${LATEST_RELEASE_DIRECTORY}/pub/media"
            aws s3 sync "s3://${aws_s3_bucket.this["system"].bucket}/releases/$${LATEST_RELEASE}" "$${LATEST_RELEASE_DIRECTORY}"
            if ! df -T "$${LATEST_RELEASE_DIRECTORY}/pub/media" | grep -q "efs"; then
              echo "-- [ERROR]: The media directory is not an EFS mount" >> {{ LogFileName }}
              exit 1
            fi
            cd $${LATEST_RELEASE_DIRECTORY}
            unzip $${LATEST_RELEASE}.zip && rm -f $${LATEST_RELEASE}.zip
            if [[ $? -eq 0 ]]; then
              echo "-- The archive with the new release has been unpacked" >> {{ LogFileName }}
            else
              echo "-- [ERROR]: The archive is broken" >> {{ LogFileName }}
              exit 1
            fi
            ln -nfs "$${LATEST_RELEASE_DIRECTORY}" "$${PUBLIC_HTML}"
  - name: "SendExecutionLog"
    action: "aws:executeAutomation"
    inputs:
      DocumentName: "SendExecutionLog"
      RuntimeParameters:
        EventSource:
        - {{ EventSource }}
EOF
}
