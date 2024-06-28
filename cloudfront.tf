


////////////////////////////////////////////////////////[ CLOUDFRONT ]////////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudFront distribution with S3 origin
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "CloudFront origin access identity"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  retain_on_delete    = false
  is_ipv6_enabled     = true
  http_version        = http2and3
  web_acl_id          = aws_wafv2_web_acl.this.arn
  price_class         = "PriceClass_100"
  comment             = "${var.app["domain"]} assets"
  
  origin {
    domain_name = aws_s3_bucket.this["media"].bucket_regional_domain_name
    origin_id   = "${var.app["domain"]}-media-assets"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
    }
	  
    custom_header {
      name  = "X-Magenx-Header"
      value = random_uuid.this.result
    }
  }
  
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.app["domain"]}-media-assets"

    viewer_protocol_policy = "https-only"

    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.media.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.media.id
  }
  
  origin {
    domain_name = aws_elb.this["external"].dns_name
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
    minimum_protocol_version = "TLSv1.2_2021"
  }
  
  tags = {
    Name = "${local.project}-cloudfront"
  }
}


