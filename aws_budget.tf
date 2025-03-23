


/////////////////////////////////////////////////[ AWS BUDGET NOTIFICATION ]//////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create alert when your budget thresholds are forecasted to exceed
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_budgets_budget" "all" {
  name              = "${local.project}-budget-monthly-forecasted"
  budget_type       = "COST"
  limit_amount      = "1000"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 75
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_sns_topic_arns  = [aws_sns_topic.default.arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_sns_topic_arns  = [aws_sns_topic.default.arn]
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create alert when your Cost Anomaly Detection trigger changes
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ce_anomaly_monitor" "cost" {
  name              = "${local.project}-cost-anomaly-detection"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
  tags = {
    Name = "${local.project}-cost-anomaly-detection"
    }
}

resource "aws_ce_anomaly_subscription" "cost_alert" {
  name      = "${local.project}-cost-anomaly-alert"
  frequency = "IMMEDIATE"
  threshold_expression {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_PERCENTAGE"
        match_options = ["GREATER_THAN_OR_EQUAL"]
        values        = ["15"]
      }
    }
  monitor_arn_list = [
    aws_ce_anomaly_monitor.cost.arn
  ]
  subscriber {
    type    = "SNS"
    address = aws_sns_topic.default.arn
  }
}
