


///////////////////////////////////////////////////////[ AWS WAFv2 RULES ]////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create AWS WAFv2 rules
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_wafv2_web_acl" "this" {
  name        = "${local.project}-WAF-Protections"
  provider    = aws.useast1
  scope       = "CLOUDFRONT"
  description = "${local.project}-WAF-Protections"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name = "${local.project}-WAF-Protections"
    sampled_requests_enabled = true
  }

  rule {
    name     = "${local.project}-country-based"
    priority = 0
    action {
      block {}
    }
    statement {
      geo_match_statement {
        country_codes = var.restricted_countries
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "${local.project}-country-based"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "${local.project}-rate-based"
    priority = 1
    action {
      block {}
    }
    statement {
      rate_based_statement {
       limit              = 300
       aggregate_key_type = "IP"
       evaluation_window_sec = 120
       }
     }
      visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.project}-rate-rule"
      sampled_requests_enabled   = true
    }
   }

  rule {
    name = "AWSManagedRulesCommonRule"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "${local.project}-AWSManagedRulesCommonRule"
      sampled_requests_enabled = true
    }
  }

  rule {
    name = "AWSManagedRulesAmazonIpReputation"
    priority = 3
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "${local.project}-AWSManagedRulesAmazonIpReputation"
      sampled_requests_enabled = true
    }
  }
}
