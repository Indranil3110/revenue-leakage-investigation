-- Monthly churn rate by segment and plan

WITH base AS (
  SELECT
    DATE_TRUNC('month', s.start_date)::date AS cohort_month,
    DATE_TRUNC('month', s.end_date)::date AS churn_month,
    c.segment,
    s.plan,
    s.customer_id,
    s.status
  FROM subscriptions s
  JOIN customers c
    ON c.customer_id = s.customer_id
),
cohort_size AS (
  SELECT
    cohort_month,
    segment,
    plan,
    COUNT(DISTINCT customer_id) AS cohort_customers
  FROM base
  GROUP BY 1,2,3
),
churn_events AS (
  SELECT
    cohort_month,
    segment,
    plan,
    COUNT(DISTINCT customer_id) AS churned_customers
  FROM base
  WHERE status = 'canceled'
  GROUP BY 1,2,3
)
SELECT
  c.cohort_month,
  c.segment,
  c.plan,
  c.cohort_customers,
  COALESCE(e.churned_customers, 0) AS churned_customers,
  ROUND(
    COALESCE(e.churned_customers, 0)::numeric / c.cohort_customers,
    4
  ) AS churn_rate
FROM cohort_size c
LEFT JOIN churn_events e
  ON e.cohort_month = c.cohort_month
 AND e.segment = c.segment
 AND e.plan = c.plan
ORDER BY 1,2,3;
