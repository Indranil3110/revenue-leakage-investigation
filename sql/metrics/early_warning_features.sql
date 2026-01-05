-- Early Warning Features (Rule-based)
-- One row per customer, as-of each customer's most recent usage date.
-- Flags active customers at risk based on usage decline, billing failures, and support ticket volume.

WITH customer_last_date AS (
  SELECT
    customer_id,
    MAX(usage_date) AS as_of_date
  FROM product_usage_daily
  GROUP BY customer_id
),

-- Recent (last 30 days) usage per customer
usage_recent AS (
  SELECT
    u.customer_id,
    COUNT(*) FILTER (
      WHERE u.usage_date > ld.as_of_date - INTERVAL '30 days'
    ) AS recent_days,
    SUM(CASE
        WHEN u.usage_date > ld.as_of_date - INTERVAL '30 days'
        THEN u.core_feature_events ELSE 0 END
    ) AS recent_events
  FROM product_usage_daily u
  JOIN customer_last_date ld
    ON ld.customer_id = u.customer_id
  GROUP BY u.customer_id
),

-- Baseline usage: days 31–60 before as_of_date
usage_baseline AS (
  SELECT
    u.customer_id,
    COUNT(*) FILTER (
      WHERE u.usage_date BETWEEN ld.as_of_date - INTERVAL '60 days'
                            AND ld.as_of_date - INTERVAL '31 days'
    ) AS baseline_days,
    SUM(CASE
        WHEN u.usage_date BETWEEN ld.as_of_date - INTERVAL '60 days'
                              AND ld.as_of_date - INTERVAL '31 days'
        THEN u.core_feature_events ELSE 0 END
    ) AS baseline_events
  FROM product_usage_daily u
  JOIN customer_last_date ld
    ON ld.customer_id = u.customer_id
  GROUP BY u.customer_id
),

-- Usage drop ratio based on per-day averages
usage_features AS (
  SELECT
    r.customer_id,
    r.recent_days,
    r.recent_events,
    b.baseline_days,
    b.baseline_events,
    CASE
      WHEN b.baseline_days >= 10
       AND r.recent_days >= 10
       AND b.baseline_events > 0
      THEN ROUND(
        (
          (b.baseline_events::numeric / b.baseline_days) -
          (r.recent_events::numeric / r.recent_days)
        ) / (b.baseline_events::numeric / b.baseline_days),
        2
      )
      ELSE 0
    END AS usage_drop_ratio_30d
  FROM usage_recent r
  LEFT JOIN usage_baseline b
    ON b.customer_id = r.customer_id
),

-- Failed payments in last 30 days relative to customer as_of_date
billing_features AS (
  SELECT
    i.customer_id,
    COUNT(*) FILTER (
      WHERE p.status = 'failed'
        AND p.attempt_date > ld.as_of_date - INTERVAL '30 days'
    ) AS failed_payments_30d
  FROM invoices i
  JOIN payments p
    ON p.invoice_id = i.invoice_id
  JOIN customer_last_date ld
    ON ld.customer_id = i.customer_id
  GROUP BY i.customer_id
),

-- Tickets in last 30 days relative to customer as_of_date
ticket_features AS (
  SELECT
    t.customer_id,
    COUNT(*) FILTER (
      WHERE t.created_date > ld.as_of_date - INTERVAL '30 days'
    ) AS tickets_30d
  FROM support_tickets t
  JOIN customer_last_date ld
    ON ld.customer_id = t.customer_id
  GROUP BY t.customer_id
)

SELECT
  c.customer_id,
  c.segment,
  c.region,
  s.plan,
  s.seats,

  COALESCE(u.usage_drop_ratio_30d, 0) AS usage_drop_ratio_30d,
  COALESCE(b.failed_payments_30d, 0)  AS failed_payments_30d,
  COALESCE(t.tickets_30d, 0)          AS tickets_30d,

  CASE
    WHEN COALESCE(u.usage_drop_ratio_30d, 0) >= 0.20 THEN 1
    WHEN COALESCE(b.failed_payments_30d, 0)  >= 2    THEN 1
    WHEN COALESCE(t.tickets_30d, 0)          >= 3    THEN 1
    ELSE 0
  END AS at_risk_flag,

  CASE
    WHEN COALESCE(u.usage_drop_ratio_30d, 0) >= 0.20 THEN 'Significant usage decline'
    WHEN COALESCE(b.failed_payments_30d, 0)  >= 2    THEN 'Repeated payment failures'
    WHEN COALESCE(t.tickets_30d, 0)          >= 3    THEN 'High support ticket volume'
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
ORDER BY at_risk_flag DESC, usage_drop_ratio_30d DESC, failed_payments_30d DESC, tickets_30d DESC;
