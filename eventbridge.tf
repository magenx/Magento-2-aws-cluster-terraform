


////////////////////////////////////////////////////////[ EVENTBRIDGE RULES ]/////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EventBridge service role
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge_service_role" {
  name = "${local.project}-EventBridgeServiceRole"
  description = "Provides EventBridge manage events on your behalf."
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for EventBridge role to start CodePipeline
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "eventbridge_start_pipeline" {
  statement {
    sid     = "eventspolicy"
    actions = ["codepipeline:StartPipelineExecution"]
    resources = ["${aws_codepipeline.this.arn}"]
  }
}

resource "aws_iam_policy" "eventbridge_start_pipeline" {
  name        = "${local.project}-eventbridge-start-pipeline"
  description = "EventBridge can start pipeline"
  policy      = data.aws_iam_policy_document.eventbridge_start_pipeline.json
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policies to EventBridge role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "eventbridge_service_role" {
  for_each   = join(aws_iam_policy.eventbridge_start_pipeline.arn, var.eventbridge_policy)
  role       = aws_iam_role.eventbridge_service_role.name
  policy_arn = each.value
}

