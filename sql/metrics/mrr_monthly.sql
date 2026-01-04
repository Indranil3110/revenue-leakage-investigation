-- MRR by month, plan, segment, region
-- Assumption: invoices represent expected monthly charges (amount_due)

WITH invoice_base AS (
  SELECT
    i.invoice_month,
    c.segment,
    c.region,
    s.plan,
    SUM(i.amount_due) AS expected_mrr
  FROM invoices i
  JOIN customers c
    ON c.customer_id = i.customer_id
  JOIN subscriptions s
    ON s.customer_id = i.customer_id
  WHERE i.invoice_status <> 'void'
  GROUP BY 1,2,3,4
),
cash_collected AS (
  SELECT
    i.invoice_month,
    c.segment,
    c.region,
    s.plan,
    SUM(CASE WHEN p.status = 'paid' THEN p.amount_paid ELSE 0 END) AS cash_collected
  FROM invoices i
  JOIN payments p
    ON p.invoice_id = i.invoice_id
  JOIN customers c
    ON c.customer_id = i.customer_id
  JOIN subscriptions s
    ON s.customer_id = i.customer_id
  WHERE i.invoice_status <> 'void'
  GROUP BY 1,2,3,4
)
SELECT
  b.invoice_month,
  b.segment,
  b.region,
  b.plan,
  b.expected_mrr,
  COALESCE(cc.cash_collected, 0) AS cash_collected,
  (b.expected_mrr - COALESCE(cc.cash_collected, 0)) AS leakage_gap
FROM invoice_base b
LEFT JOIN cash_collected cc
  ON cc.invoice_month = b.invoice_month
 AND cc.segment = b.segment
 AND cc.region = b.region
 AND cc.plan = b.plan
ORDER BY 1,2,3,4;
