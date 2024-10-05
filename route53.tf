


/////////////////////////////////////////////////////[ ROUTE53 MAIN ZONE RECORD ]/////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Route53 zone with cname record domain -> cloudfront
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_route53_zone" "main" {
  name = var.domain
}

resource "aws_route53_record" "cname" {
  zone_id = aws_route53_zone.main.id
  name    = var.domain
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = true
  }
}
