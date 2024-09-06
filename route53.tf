


/////////////////////////////////////////////////////[ ROUTE53 MAIN ZONE RECORD ]/////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Route53 zone with cname record domain -> cloudfront
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_route53_zone" "main" {
  name = var.magento["domain"]
}
resource "aws_route53_record" "cname" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.magento["domain"]
  type    = "CNAME"
  ttl     = 300
  records = [aws_cloudfront_distribution.this.domain_name]
}
