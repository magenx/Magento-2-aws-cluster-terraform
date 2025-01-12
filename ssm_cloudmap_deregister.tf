


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
  InstanceId:
    type: String
    description: "The ID of the instance to deregister"
  AutoScalingGroupName:
    type: String
    description: "The name of the Auto Scaling Group"
mainSteps:
  - name: ConstructParameterKey
    action: aws:executeScript
    inputs:
      Runtime: python3.8
      Handler: construct_parameter_key
      Script: |
        def construct_parameter_key(event, context):
            asg_name = event['AutoScalingGroupName']
            # Convert ASG name to uppercase and append _CLOUDMAP_SERVICE_ID
            service_name = asg_name.upper() + "_CLOUDMAP_SERVICE_ID"
            return {"ServiceName": service_name}
    outputs:
      - Name: ServiceName
        Selector: "$.ServiceName"
        Type: String

  - name: GetCloudMapServiceId
    action: aws:executeAwsApi
    inputs:
      Service: ssm
      Api: GetParameter
      Name: "/${local.project}/${local.environment}/{{ ConstructParameterKey.ServiceName }}"
    outputs:
      - Name: CloudMapServiceId
        Selector: "$.Parameter.Value"
        Type: String
  - name: DeregisterInstance
    action: aws:executeAwsApi
    inputs:
      Service: servicediscovery
      Api: DeregisterInstance
      InstanceId: "{{ InstanceId }}"
      ServiceId: "{{ GetCloudMapServiceId.CloudMapServiceId }}"
 executionTimeout: "60"
EOF
}
