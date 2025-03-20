


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
    assumeRole: ${aws_iam_role.ssm_service_role.arn}
    parameters:
      S3ObjectKey:
        type: String
        description: S3 object key of the revision
    mainSteps:
      - name: CreateDeployment
        action: "aws:executeAwsApi"
        inputs:
          Service: codedeploy
          Api: CreateDeployment
          applicationName: ${aws_codedeploy_app.this["frontend"].name}
          deploymentGroupName: ${aws_codedeploy_deployment_group.this["frontend"].deployment_group_name}
          revision:
            revisionType: S3
            s3Location:
              bucket: ${aws_s3_bucket.this["system"].bucket}
              key: "{{ S3ObjectKey }}"
              bundleType: zip
        outputs:
          - Name: DeploymentId
            Selector: "$.deploymentId"
            Type: String
      - name: "SendExecutionLog"
        action: "aws:executeAwsApi"
        inputs:
          Service: "sns"
          Api: "Publish"
          TopicArn: "${aws_sns_topic.default.arn}"
          Subject: "Latest release deployment for ${local.project}"
          Message: "Latest release {{ S3ObjectKey }} deployment {{ CreateDeployment.DeploymentId }} started {{ global:DATE_TIME }}"
EOF
}
