


//////////////////////////////////////////////////////////[ S3 BUCKET ]///////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create S3 bucket
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket" "this" {
  for_each      = var.s3
  bucket        = "${local.project}-${each.key}"
  force_destroy = true
  tags = {
    Name        = "${local.project}-${each.key}"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create S3 bucket ownership configuration
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create S3 bucket versioning
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket_versioning" "this" {
  bucket   = aws_s3_bucket.this["state"].id
  versioning_configuration {
    status = "Enabled"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create S3 bucket encryption
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = aws_s3_bucket.this[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Block public access acl for internal S3 buckets
# # ---------------------------------------------------------------------------------------------------------------------#	  
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this
  bucket = aws_s3_bucket.this[each.key].id  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Cleanup maedia optimized bucket filter
# # ---------------------------------------------------------------------------------------------------------------------#	  
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this["media-optimized"].id
  rule {
    id     = "${local.project}-cleanup-images"
    status = "Enabled"
    expiration {
      days = 365
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy to limit S3 media bucket access
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "media" {
  statement {
    sid       = "AllowCloudFrontAccess"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this["media"].arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.this.iam_arn]
   }
  }

  statement {
    sid       = "AllowLambdaGet"
    effect    = "Allow"
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this["media"].arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.lambda.arn]
    }
  }

  statement {
    sid       = "AllowEC2PutObject"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.this["media"].arn}/*"]
    principals {
      type        = "AWS"
      identifiers = values(aws_iam_role.ec2)[*].arn
    }
    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpc"
      values   = [aws_vpc.this.id]
    }
  }

  statement {
    sid       = "AllowEC2GetObject"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectAcl"]
    resources = ["${aws_s3_bucket.this["media"].arn}/*"]
    principals {
      type        = "AWS"
      identifiers = values(aws_iam_role.ec2)[*].arn
    }
  }

  statement {
    sid       = "AllowEC2ListBucket"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
    resources = ["${aws_s3_bucket.this["media"].arn}","${aws_s3_bucket.this["media"].arn}/*"]
    principals {
      type        = "AWS"
      identifiers = values(aws_iam_role.ec2)[*].arn
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy to limit S3 media optimized bucket access
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "mediaoptimized" {
  statement {
    sid       = "AllowLambdaGetPut"
    effect    = "Allow"
    actions = ["s3:PutObject","s3:GetObject"]
    resources = ["${aws_s3_bucket.this["media-optimized"].arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.lambda.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "mediaoptimized" {
  bucket = aws_s3_bucket.this["media-optimized"].id
  policy = data.aws_iam_policy_document.mediaoptimized.json
}

resource "aws_s3_bucket_policy" "media" {
  bucket = aws_s3_bucket.this["media"].id
  policy = data.aws_iam_policy_document.media.json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create S3 bucket policy for ALB to write access logs
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "system" {
 statement {
    sid    = "AllowSSMAgentS3Access"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.this["system"].arn}/*"
    ]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }

  statement {
    sid    = "ALBWriteLogs"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = ["${aws_s3_bucket.this["system"].arn}/ALB/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.current.arn]
    }
  }

  statement {
    sid    = "AllowCodebuildS3Access"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.this["system"].arn}/*"
    ]
    principals {
      type        = "AWS"
      identifiers = [
        aws_iam_role.codebuild.arn,
        aws_iam_role.codepipeline.arn,
        aws_iam_role.config.arn
      ]
    }
  }

  statement {
    sid    = "CloudFrontAccess"
    effect = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.this["system"].arn}/CloudFront/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = ["arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"]
    }
  }

  statement {
    sid       = "AllowLambdaGet"
    effect    = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = ["${aws_s3_bucket.this["system"].arn}/lambda/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.lambda.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "system" {
  bucket = aws_s3_bucket.this["system"].id
  policy = data.aws_iam_policy_document.system.json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create S3 bucket policy for CodePipeline access
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "backup" {
  statement {
    actions   = ["s3:PutObject"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.this["backup"].arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [
        aws_iam_role.codebuild.arn,
        aws_iam_role.codepipeline.arn,
        aws_iam_role.codedeploy.arn
      ]
    }
  }
  version = "2012-10-17"
}

resource "aws_s3_bucket_policy" "backup" {
  bucket = aws_s3_bucket.this["backup"].id
  policy = data.aws_iam_policy_document.backup.json
}


