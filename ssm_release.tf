


//////////////////////////////////////////////[ SYSTEM MANAGER DOCUMENT RELEASE ]/////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to check and deploy latest release on EC2 from S3
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "release" {
  name            = "LatestReleaseDeployment"
  document_type   = "Automation"
  document_format = "YAML"
  content = <<EOF
    schemaVersion: "0.3"
    description: Start a CodeDeploy release deployment with a new S3 revision
    assumeRole: "{{ AutomationAssumeRole }}"
    parameters:
      ApplicationName:
        type: String
        description: Name of the CodeDeploy application
      DeploymentGroupName:
        type: String
        description: Name of the CodeDeploy deployment group
      S3Bucket:
        type: String
        description: S3 bucket containing the revision
      S3ObjectKey:
        type: String
        description: S3 object key of the revision
    mainSteps:
      - name: StartDeployment
        action: "aws:executeAwsApi"
        inputs:
          Service: codedeploy
          Api: CreateDeployment
          ApplicationName: "{{ ApplicationName }}"
          DeploymentGroupName: "{{ DeploymentGroupName }}"
          Revision:
            RevisionType: S3
            S3Location:
              Bucket: "{{ S3Bucket }}"
              Key: "{{ S3ObjectKey }}"
 - name: "SendExecutionLog"
    action: "aws:executeAwsApi"
    inputs:
      Service: "sns"
      Api: "Publish"
      TopicArn: "${aws_sns_topic.default.arn}"
      Subject: "Latest release deployment ${local.project}"
      Message: "Latest release {{ S3ObjectKey }} deployment {{ automation:EXECUTION_ID }} completed at {{ global:DATE_TIME }}"
EOF
}
