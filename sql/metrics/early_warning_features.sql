-- Early warning features for churn / revenue leakage
-- Snapshot as of the most recent date in product_usage_daily

WITH last_date AS (
  SELECT MAX(usage_date) AS as_of_date
  FROM product_usage_daily
),

-- Aggregate usage in recent windows
usage_windows AS (
  SELECT
    u.customer_id,
    SUM(CASE WHEN u.usage_date > ld.as_of_date - INTERVAL '7 days' THEN u.core_feature_events ELSE 0 END) AS usage_7d,
    SUM(CASE WHEN u.usage_date > ld.as_of_date - INTERVAL '14 days' THEN u.core_feature_events ELSE 0 END) AS usage_14d,
    SUM(CASE WHEN u.usage_date > ld.as_of_date - INTERVAL '30 days' THEN u.core_feature_events ELSE 0 END) AS usage_30d
  FROM product_usage_daily u
  CROSS JOIN last_date ld
  GROUP BY u.customer_id
),

-- Historical baseline (prior 30–60 day window)
usage_baseline AS (
  SELECT
    u.customer_id,
    SUM(CASE
        WHEN u.usage_date BETWEEN ld.as_of_date - INTERVAL '60 days'
                              AND ld.as_of_date - INTERVAL '31 days'
        THEN u.core_feature_events ELSE 0 END
    ) AS baseline_usage
  FROM product_usage_daily u
  CROSS JOIN last_date ld
  GROUP BY u.customer_id
),

usage_features AS (
  SELECT
    w.customer_id,
    w.usage_7d,
    w.usage_14d,
    w.usage_30d,
    b.baseline_usage,
    CASE
      WHEN b.baseline_usage > 0
      THEN ROUND((b.baseline_usage - w.usage_30d) / b.baseline_usage, 2)
      ELSE 0
    END AS usage_drop_ratio_30d
  FROM usage_windows w
  LEFT JOIN usage_baseline b
    ON b.customer_id = w.customer_id
),

-- Failed payments in last 30 days
billing_features AS (
  SELECT
    i.customer_id,
    COUNT(*) FILTER (
      WHERE p.status = 'failed'
        AND p.attempt_date > (SELECT as_of_date FROM last_date) - INTERVAL '30 days'
    ) AS failed_payments_30d
  FROM invoices i
  JOIN payments p
    ON p.invoice_id = i.invoice_id
  GROUP BY i.customer_id
),

-- Support tickets in last 30 days
ticket_features AS (
  SELECT
    customer_id,
    COUNT(*) FILTER (
      WHERE created_date > (SELECT as_of_date FROM last_date) - INTERVAL '30 days'
    ) AS tickets_30d
  FROM support_tickets
  GROUP BY customer_id
)

SELECT
  c.customer_id,
  c.segment,
  s.plan,
  COALESCE(u.usage_drop_ratio_30d, 0) AS usage_drop_ratio_30d,
  COALESCE(b.failed_payments_30d, 0) AS failed_payments_30d,
  COALESCE(t.tickets_30d, 0) AS tickets_30d,

  -- Rule-based risk flag
  CASE
    WHEN COALESCE(u.usage_drop_ratio_30d, 0) >= 0.40 THEN 1
    WHEN COALESCE(b.failed_payments_30d, 0) >= 2 THEN 1
    WHEN COALESCE(t.tickets_30d, 0) >= 3 THEN 1
    ELSE 0
  END AS at_risk_flag,

  -- Human-readable reason (first matching reason)
  CASE
    WHEN COALESCE(u.usage_drop_ratio_30d, 0) >= 0.40 THEN 'Significant usage decline'
    WHEN COALESCE(b.failed_payments_30d, 0) >= 2 THEN 'Repeated payment failures'
    WHEN COALESCE(t.tickets_30d, 0) >= 3 THEN 'High support ticket volume'
    ELSE 'No immediate risk signal'
  END AS risk_reason

FROM customers c
JOIN subscriptions s
  ON s.customer_id = c.customer_id
LEFT JOIN usage_features u
  ON u.customer_id = c.customer_id
LEFT JOIN billing_features b
  ON b.customer_id = c.customer_id
LEFT JOIN ticket_features t
  ON t.customer_id = c.customer_id
WHERE s.status = 'active'
ORDER BY at_risk_flag DESC, usage_drop_ratio_30d DESC;
