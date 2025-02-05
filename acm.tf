


///////////////////////////////////////////////////[ AWS CERTIFICATE MANAGER ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create ssl certificate for domain and subdomains
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_acm_certificate" "default" {
  domain_name               = "${var.domain}"
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy   = true
  }
  tags = {
    Name = "${local.project}-${var.domain}-cert"
  }
}

resource "aws_acm_certificate" "cloudfront" {
  for_each = data.aws_region.current.name == "us-east-1" ? {} : { "this" = var.domain }
  provider                  = aws.useast1
  domain_name               = "${var.domain}"
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy   = true
  }
  tags = {
    Name = "${local.project}-${var.domain}-cert"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Validate ssl certificate for domain and subdomains
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_acm_certificate_validation" "default" {
  certificate_arn = aws_acm_certificate.default.arn
}

resource "aws_acm_certificate_validation" "cloudfront" {
  for_each = data.aws_region.current.name == "us-east-1" ? {} : { "this" = aws_acm_certificate.cloudfront["this"] }
  provider        = aws.useast1
  certificate_arn = each.value.arn
}
