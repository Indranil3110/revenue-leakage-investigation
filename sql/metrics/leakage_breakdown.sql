-- Leakage breakdown: expected vs collected and unpaid due to failed payments
-- This treats "billing leakage" as invoices where payment status is failed.

WITH invoice_pay AS (
  SELECT
    i.invoice_month,
    i.invoice_id,
    i.customer_id,
    i.amount_due,
    MAX(CASE WHEN p.status = 'paid' THEN 1 ELSE 0 END) AS has_paid,
    MAX(CASE WHEN p.status = 'failed' THEN 1 ELSE 0 END) AS has_failed
  FROM invoices i
  LEFT JOIN payments p
    ON p.invoice_id = i.invoice_id
  WHERE i.invoice_status <> 'void'
  GROUP BY 1,2,3,4
),
agg AS (
  SELECT
    invoice_month,
    SUM(amount_due) AS expected_mrr,
    SUM(CASE WHEN has_paid = 1 THEN amount_due ELSE 0 END) AS collected_mrr,
    SUM(CASE WHEN has_paid = 0 AND has_failed = 1 THEN amount_due ELSE 0 END) AS billing_failure_leakage,
    SUM(CASE WHEN has_paid = 0 AND has_failed = 0 THEN amount_due ELSE 0 END) AS other_unpaid_leakage
  FROM invoice_pay
  GROUP BY 1
)
SELECT
  invoice_month,
  expected_mrr,
  collected_mrr,
  (expected_mrr - collected_mrr) AS total_leakage,
  billing_failure_leakage,
  other_unpaid_leakage
FROM agg
ORDER BY invoice_month;
