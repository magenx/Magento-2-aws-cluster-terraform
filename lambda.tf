


///////////////////////////////////////////////////[ LAMBDA IMAGE OPTIMIZATION ]//////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Lambda IAM role and attach policy permissions
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/lambda/${aws_lambda_function.image_optimization.function_name}/"
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
    resources = ["*"]
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
# Create Lambda permissions for CloudFront
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lambda_permission" "this" {
  provider      = aws.useast1
  statement_id  = "AllowCloudFrontServicePrincipal"
  action        = "lambda:InvokeFunctionUrl"
  function_name = aws_lambda_function.image_optimization.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.this.arn
  qualifier     = aws_lambda_alias.image_optimization.name
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Lambda function npm package
# # ---------------------------------------------------------------------------------------------------------------------#
resource "null_resource" "npm_install" {
  provisioner "local-exec" {
    command = "cd ${abspath(path.root)}/lambda/image_optimization && npm install"
  }
  triggers = {
    always_run = "${filesha256("${abspath(path.root)}/lambda/image_optimization/index.mjs")}"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Lambda function zip archive 
# # ---------------------------------------------------------------------------------------------------------------------#
data "archive_file" "lambda_image_optimization" {
  depends_on       = [null_resource.npm_install]
  type             = "zip"
  source_dir       = "${abspath(path.root)}/lambda/image_optimization"
  output_file_mode = "0666"
  output_path      = "${abspath(path.root)}/lambda/image_optimization.zip"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Lambda function with variables
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lambda_function" "image_optimization" {
  provider      = aws.useast1
  function_name = "${local.project}-image-optimization"
  role          = aws_iam_role.lambda.arn
  filename      = data.archive_file.lambda_image_optimization.output_path
  source_code_hash = data.archive_file.lambda_image_optimization.output_base64sha256
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  memory_size   = 256
  timeout       = 30
  publish       = true
  environment {
    variables = {
      s3BucketRegion             = aws_s3_bucket.this["media"].region
      originalImageBucketName    = aws_s3_bucket.this["media"].id
      transformedImageBucketName = aws_s3_bucket.this["media-optimized"].id
      transformedImageCacheTTL   = "max-age=31622400"
      maxImageSize               = "4700000"
   }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Lambda function url
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lambda_function_url" "image_optimization" {
  provider           = aws.useast1
  function_name      = aws_lambda_function.image_optimization.function_name
  qualifier          = aws_lambda_alias.image_optimization.name
  authorization_type = "AWS_IAM"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Lambda function alias
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lambda_alias" "image_optimization" {
  provider         = aws.useast1
  name             = "${local.project}-image-optimization"
  description      = "Lambda image optimization alias for ${local.project}"
  function_name    = aws_lambda_function.image_optimization.arn
  function_version = "$LATEST"
}
