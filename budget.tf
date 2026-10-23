# ---------------------------------------------------------------------------
# Lab-only budget.
#
# The account already has an account-wide budget from the portfolio stack, so
# this one filters on Project=blog-lab. That filter only matches once
# "Project" is an active cost allocation tag (Billing > Cost allocation tags);
# the portfolio stack already uses the key, so it should be listed there.
# ---------------------------------------------------------------------------

resource "aws_budgets_budget" "lab" {
  name         = "${var.name_prefix}-monthly"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$blog-lab"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
