


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
    description: The project name
    default: ${local.project}
  Environment:
    type: String
    description: The environment
    default: ${local.environment}
mainSteps:
  - name: ConstructParameterPath
    action: aws:executeScript
    nextStep: GetCloudMapServiceId
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
  - name: "GetCloudMapServiceId"
    action: aws:executeAwsApi
    nextStep: DeregisterInstanceFromCloudMap
    inputs:
      Service: ssm
      Api: GetParameter
      Name: "{{ ConstructParameterPath.ParameterPath }}"
    outputs:
      - Name: CloudMapServiceId
        Selector: $.Parameter.Value
        Type: String
  - name: "DeregisterInstanceFromCloudMap"
    action: aws:executeAwsApi
    inputs:
      Service: servicediscovery
      Api: DeregisterInstance
      ServiceId: "{{ GetCloudMapServiceId.CloudMapServiceId }}"
      InstanceId: "{{ InstanceId }}"
  - name: "SendExecutionLog"
    action: "aws:executeAwsApi"
    inputs:
      Service: "sns"
      Api: "Publish"
      TopicArn: "${aws_sns_topic.default.arn}"
      Subject: "Deregister instance from CloudMap on termination ${local.project}-${local.environment}-{{ InstanceId }}"
      Message: "Deregister {{ InstanceId }} from CloudMap on termination {{ automation:EXECUTION_ID }} completed at {{ global:DATE_TIME }}"
EOF
}
