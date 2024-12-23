


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
    allow {
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name = "${local.project}-WAF-Protections"
    sampled_requests_enabled = true
  }

  rule {
    name     = "${local.project}-Cloudfront-WAF-media-Protection-rate-based"
    priority = 0

    action {
      count {}
    }

    statement {
      rate_based_statement {
       limit              = 100
       aggregate_key_type = "IP"
       
       scope_down_statement {
         byte_match_statement {
          field_to_match {
              uri_path   {}
              }
          search_string  = "/media/"
          positional_constraint = "STARTS_WITH"

          text_transformation {
            priority   = 0
            type       = "NONE"
           }
         }
       }
     }
  }
      visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.project}-Cloudfront-WAF-Protection-rate-based-rule"
      sampled_requests_enabled   = true
    }
   }
   
   rule {
    name     = "${local.project}-Cloudfront-WAF-static-Protection-rate-based"
    priority = 1

    action {
      count {}
    }

    statement {
      rate_based_statement {
       limit              = 200
       aggregate_key_type = "IP"
       
       scope_down_statement {
         byte_match_statement {
          field_to_match {
              uri_path   {}
              }
          search_string  = "/static/"
          positional_constraint = "STARTS_WITH"

          text_transformation {
            priority   = 0
            type       = "NONE"
           }
         }
       }
     }
    }
      visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.project}-Cloudfront-WAF-static-Protection-rate-based-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name = "AWSManagedRulesCommonRule"
    priority = 2
    override_action {
      none {
      }
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
      none {
      }
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
  rule {
    name = "AWSManagedRulesBotControlRule"
    priority = 4
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "${local.project}-AWSManagedRulesBotControlRule"
      sampled_requests_enabled = true
    }
  }
}
