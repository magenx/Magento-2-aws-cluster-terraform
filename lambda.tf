


///////////////////////////////////////////////////[ LAMBDA IMAGE OPTIMIZATION ]//////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Lambda IAM role and attach policy permissions
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/lambda/${aws_lambda_function.image_optimization.last_modified}"
  retention_in_days = 7
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid    = "LambdaLog"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [aws_cloudwatch_log_group.lambda.arn]
  }

  statement {
    sid    = "LambdaAccess"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda" {
  name        = "${local.project}-lambda"
  path        = "/"
  description = "IAM policy for lambda"
  policy      = data.aws_iam_policy_document.lambda.json
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.project}-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Lambda function zip archive 
# # ---------------------------------------------------------------------------------------------------------------------#
data "archive_file" "lambda_image_optimization" {
  type             = "zip"
  source_file      = "${abspath(path.root)}/lambda/image_optimization/index.mjs"
  output_file_mode = "0666"
  output_path      = "${abspath(path.root)}/lambda/image_optimization/index.mjs.zip"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Upload Lambda function zip archive to s3 bucket
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_object" "lambda_image_optimization" {
  depends_on = [data.archive_file.lambda_image_optimization]
  bucket     = aws_s3_bucket.this["system"].id
  key        = "lambda/image_optimization/index.js.zip"
  source     = data.archive_file.lambda_image_optimization.output_path
  etag       = filemd5(data.archive_file.lambda_image_optimization.output_path)
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Lambda function with variables
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lambda_function" "image_optimization" {
  depends_on    = [aws_s3_object.lambda_image_optimization]
  function_name = "${local.project}-image-optimization"
  role          = aws_iam_role.lambda.arn
  s3_bucket     = aws_s3_bucket.this["system"].id
  s3_key        = aws_s3_object.lambda_image_optimization.key
  runtime       = "nodejs18.x"
  handler       = "index.handler"
  memory_size   = 1500
  timeout       = 60
  environment {
    variables = {
      originalImageBucketName    = aws_s3_bucket.this["media"].id
      transformedImageBucketName = aws_s3_bucket.this["media-optimized"].id
      transformedImageCacheTTL   = "max-age=31622400"
      maxImageSize               = "4700000"
   }
  }
  vpc_config {
    subnet_ids = values(aws_subnet.this).*.id 
    security_group_ids = [aws_security_group.lambda.id]
  }
}
