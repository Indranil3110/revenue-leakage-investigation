-- Monthly churn by cohort (based on subscription start month)

WITH base AS (
  SELECT
    s.customer_id,
    DATE_TRUNC('month', s.start_date)::date AS cohort_month,
    DATE_TRUNC('month', s.end_date)::date AS churn_month,
    s.status
  FROM subscriptions s
),
cohort_size AS (
  SELECT
    cohort_month,
    COUNT(DISTINCT customer_id) AS cohort_customers
  FROM base
  GROUP BY 1
),
churn_events AS (
  SELECT
    cohort_month,
    churn_month,
    COUNT(DISTINCT customer_id) AS churned_customers
  FROM base
  WHERE status = 'canceled'
  GROUP BY 1,2
)
SELECT
  c.cohort_month,
  e.churn_month,
  c.cohort_customers,
  e.churned_customers,
  ROUND(
    e.churned_customers::numeric / c.cohort_customers,
    4
  ) AS churn_rate
FROM churn_events e
JOIN cohort_size c
  ON c.cohort_month = e.cohort_month
ORDER BY 1,2;
