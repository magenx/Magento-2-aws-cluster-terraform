


///////////////////////////////////////////////////[ AWS CERTIFICATE MANAGER ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create ssl certificate for domain and subdomains
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_acm_certificate" "default" {
  domain_name               = "${var.magento["domain"]}"
  subject_alternative_names = ["*.${var.magento["domain"]}"]
  validation_method         = "EMAIL"

lifecycle {
    create_before_destroy   = true
}
tags = {
    Name = "${local.project}-${var.magento["domain"]}-cert"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Validate ssl certificate for domain and subdomains
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_acm_certificate_validation" "default" {
  certificate_arn = aws_acm_certificate.default.arn
}


