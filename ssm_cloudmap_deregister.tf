


////////////////////////////////////////[ SYSTEM MANAGER DOCUMENT CLOUDMAP DEREGISTER ]///////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to deregister EC2 instances in Cloudmap Service
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "cloudmap_deregister" {
  name            = "CloudMapDeregister"
  document_format = "YAML"
  document_type   = "Automation"
  content = <<EOF
schemaVersion: "0.3"
description: "Deregister instance from CloudMap on termination"
parameters:
  instanceId:
    type: String
mainSteps:
  - name: DeregisterInstance
    action: aws:runCommand
    inputs:
      DocumentName: "AWS-RunShellScript"
      InstanceIds:
        - "{{ instanceId }}"
      TimeoutSeconds: 60
      Parameters:
        commands:
          - |-
            #!/bin/bash
            INSTANCE_ID="{{ instanceId }}"
            INSTANCE_NAME="$(metadata tags/instance/Instance_name)"
            CLOUDMAP_SERVICE_ID="$(parameterstore $${INSTANCE_NAME^^}_CLOUDMAP_SERVICE_ID)"
            aws servicediscovery deregister-instance \
              --region ${data.aws_region.current.name} \
              --service-id $${CLOUDMAP_SERVICE_ID} \
              --instance-id $${INSTANCE_ID}
        executionTimeout: "60"
EOF
}
