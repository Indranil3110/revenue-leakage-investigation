-- Revenue leakage due to downgrades and seat reductions

WITH changes AS (
  SELECT
    pc.customer_id,
    DATE_TRUNC('month', pc.change_date)::date AS change_month,
    pc.change_type,
    pc.old_plan,
    pc.new_plan,
    pc.old_seats,
    pc.new_seats
  FROM plan_changes pc
),
plan_prices AS (
  SELECT 'Basic' AS plan, 49 AS price UNION ALL
  SELECT 'Pro', 99 UNION ALL
  SELECT 'Business', 149
),
downgrade_events AS (
  SELECT
    c.customer_id,
    c.change_month,
    c.change_type,
    (pp_old.price * c.old_seats) AS old_mrr,
    (pp_new.price * c.new_seats) AS new_mrr
  FROM changes c
  JOIN plan_prices pp_old
    ON pp_old.plan = c.old_plan
  JOIN plan_prices pp_new
    ON pp_new.plan = c.new_plan
  WHERE
    c.change_type IN ('downgrade','seat_change')
    AND (pp_new.price * c.new_seats) < (pp_old.price * c.old_seats)
)
SELECT
  change_month,
  COUNT(DISTINCT customer_id) AS affected_customers,
  SUM(old_mrr - new_mrr) AS downgrade_leakage_mrr
FROM downgrade_events
GROUP BY 1
ORDER BY 1;
