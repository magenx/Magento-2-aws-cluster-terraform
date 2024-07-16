


////////////////////////////////////////////////////////[ CLOUDFRONT ]////////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudFront distribution with Lambda to S3 origin failower
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "CloudFront origin access identity"
}

resource "aws_cloudfront_origin_access_control" "this" {
    name             = "${local.project}-coac-lambda"
    description      = "Cloudfront origin access control for ${local.project} lambda function"
    signing_behavior = "always"
    signing_protocol = "sigv4"
    origin_access_control_origin_type = "lambda"
}

resource "aws_cloudfront_function" "this" {
  publish = true
  name    = "${local.project}-urlrewrite"  
  comment = "UrlRewrite function for ${local.project} image optimization"
  runtime = "cloudfront-js-2.0"
  code    = file("${abspath(path.root)}/cloudfront/index.js")
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  retain_on_delete    = false # <- needs variable
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  web_acl_id          = aws_wafv2_web_acl.this.arn
  price_class         = "PriceClass_100"
  comment             = "${var.app["domain"]} pub/media pub/static assets"
  
  origin {
    domain_name = aws_s3_bucket.this["media"].bucket_regional_domain_name
    origin_id   = "${var.app["domain"]}-media-assets"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = aws_s3_bucket.this["media-optimized"].bucket_regional_domain_name
    origin_id   = "${var.app["domain"]}-media-optimized-assets"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = aws_lambda_function.image_optimization.invoke_arn
    origin_id   = "${var.app["domain"]}-lambda-image-optimization"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
   }
   origin_shield {
        enabled               = true  # <- needs variable
        origin_shield_region  = local.origin_shield_region
   }
  }
  
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.app["domain"]}-media-assets"
    viewer_protocol_policy   = "https-only"
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.media.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.media.id

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.image_optimization.qualified_arn
      include_body = false
    }

    function_association {
      event_type = "viewer-request"
      function_arn = aws_cloudfront_function.this.arn
    }
  }

  origin_group {
    origin_id         = "${var.app["domain"]}-S3-lambda-image-optimization"
    failover_criteria {
      status_codes = [403, 500, 503, 504]
    }
    member {
      origin_id = "${var.app["domain"]}-media-optimized-assets"
    }
    member {
      origin_id = "${var.app["domain"]}-lambda-image-optimization"
    }
  }
  
  origin {
    domain_name = aws_lb.this["external"].dns_name
    origin_id   = "${var.app["domain"]}-static-assets"
    custom_origin_config {
       http_port              = 80
       https_port             = 443
       origin_protocol_policy = "https-only"
       origin_ssl_protocols   = ["TLSv1.2"]
   }
    custom_header {
      name  = "X-Magenx-Header"
      value = random_uuid.this.result
   }
 }

  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.app["domain"]}-static-assets"
	
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.static.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.static.id

    viewer_protocol_policy = "https-only"
    compress               = true
}

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.this["system"].bucket_domain_name
    prefix          = "${local.project}-cloudfront-logs"
  }
  
 restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = var.restricted_countries
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  
  tags = {
    Name = "${local.project}-cloudfront"
  }
}


