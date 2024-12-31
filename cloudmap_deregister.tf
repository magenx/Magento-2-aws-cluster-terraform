


////////////////////////////////////////[ SYSTEM MANAGER DOCUMENT CLOUDMAP DEREGISTER ]///////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to deregister EC2 instances in Cloudmap Service
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "cloudmap_deregister" {
  name            = "CloudMapDeregister"
  document_format = "YAML"
  document_type   = "Command"
  content = <<EOF
schemaVersion: "2.2"
description: "CloudMap Deregister"
mainSteps:
  - name: "CloudMapInstanceDeRegistration"
    action: "aws:runShellScript"
    inputs:
      runCommand:
        - |-
          #!/bin/bash
          INSTANCE_ID="$(metadata instance-id)"
          INSTANCE_NAME="$(metadata tags/instance/Instance_name)"
          CLOUDMAP_SERVICE_ID="$(parameterstore $${INSTANCE_NAME^^}_CLOUDMAP_SERVICE_ID)"
          aws servicediscovery deregister-instance \
            --region ${data.aws_region.current.name} \
            --service-id $${CLOUDMAP_SERVICE_ID} \
            --instance-id $${INSTANCE_ID}
EOF
}
