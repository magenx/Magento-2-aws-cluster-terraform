


////////////////////////////////////////////////////////[ EVENTBRIDGE RULES ]/////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge service role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "eventbridge_service_role" {
  name = "${local.project}-EventBridgeServiceRole"
  description = "Provides EventBridge manage events on your behalf."
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "events.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for EventBridge role to start CodePipeline
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_policy" "eventbridge_service_role" {
  name = "${local.project}-start-codepipeline"
  path = "/service-role/"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codepipeline:StartPipelineExecution"
            ],
            "Resource": [
                "${aws_codepipeline.this.arn}"
            ]
        }
    ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policies to EventBridge role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "eventbridge" {
  policy_arn = aws_iam_policy.eventbridge_service_role.arn
  role       = aws_iam_role.eventbridge_service_role.name
}
resource "aws_iam_role_policy_attachment" "eventbridge_service_role" {
  for_each   = var.eventbridge_policy
  role       = aws_iam_role.eventbridge_service_role.name
  policy_arn = each.value
}
