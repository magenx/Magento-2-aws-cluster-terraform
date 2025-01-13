


////////////////////////////////////////[ SYSTEM MANAGER DOCUMENT CLOUDMAP DEREGISTER ]///////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to deregister EC2 instances in Cloudmap Service
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "cloudmap_deregister" {
  name            = "CloudMapDeregister"
  document_format = "YAML"
  document_type   = "Automation"
  content = <<EOF
schemaVersion: '0.3'
description: Deregister instance from CloudMap on termination
parameters:
  InstanceId:
    type: String
    description: The ID of the instance to deregister
  AutoScalingGroupName:
    type: String
    description: The name of the Auto Scaling Group
  Project:
    type: String
    default: ${local.project}
    description: The project name
  Environment:
    type: String
    default: ${local.environment}
    description: The environment
mainSteps:
  - name: ConstructParameterPath
    action: aws:executeScript
    nextStep: GetCloudMapServiceId
    isEnd: false
    inputs:
      Runtime: python3.11
      Handler: construct_parameter_path
      InputPayload:
        AutoScalingGroupName: '{{ AutoScalingGroupName }}'
        Project: '{{ Project }}'
        Environment: '{{ Environment }}'
      Script: |-
        def construct_parameter_path(event, context):
            print("Received event:", event)
            asg_name = event['AutoScalingGroupName']
            project = event['Project']
            environment = event['Environment']
            service_group = asg_name.split('-')[2]
            parameter_path = f"/{project}/{environment}/{service_group.upper()}_CLOUDMAP_SERVICE_ID"
            return {"ParameterPath": parameter_path}
    outputs:
      - Name: ParameterPath
        Selector: $.Payload.ParameterPath
        Type: String
  - name: GetCloudMapServiceId
    action: aws:executeAwsApi
    nextStep: DeregisterInstanceFromCloudMap
    isEnd: false
    inputs:
      Service: ssm
      Api: GetParameter
      Name: '{{ ConstructParameterPath.ParameterPath }}'
    outputs:
      - Name: CloudMapServiceId
        Selector: $.Parameter.Value
        Type: String
  - name: DeregisterInstanceFromCloudMap
    action: aws:executeAwsApi
    isEnd: true
    inputs:
      Service: servicediscovery
      Api: DeregisterInstance
      ServiceId: '{{ GetCloudMapServiceId.CloudMapServiceId }}'
      InstanceId: '{{ InstanceId }}'
EOF
}
