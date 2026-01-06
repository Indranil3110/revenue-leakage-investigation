# Executive Summary  
**Revenue Leakage Investigation – Churn & Early Warning Analysis**

## 1. Context

Finance and Growth teams observed a recurring gap between expected Monthly Recurring Revenue (MRR) and actual cash collected over recent quarters.

This analysis simulates an internal investigation for a subscription-based SaaS business to:
- Identify where revenue leakage occurs (churn, billing failures, downgrades)
- Quantify the financial impact across customer segments and plans
- Design an early-warning system to proactively flag at-risk customers before revenue loss occurs


## 2. Key Findings

### 2.1 Revenue Leakage Is Multi-Dimensional
Revenue loss is not driven by churn alone. Analysis shows three primary contributors:
- **Customer churn**, which permanently removes recurring revenue
- **Billing failures**, where invoices are issued but cash is not collected
- **Downgrades and seat reductions**, which reduce MRR without full customer loss

This highlights the need to monitor both customer behavior and operational signals when assessing revenue health.

---

### 2.2 Churn Is Concentrated in SMB and Lower-Tier Plans
Cohort and segment analysis shows that:
- **SMB customers churn at materially higher rates** than Mid-Market and Enterprise customers
- **Basic and Pro plans exhibit higher churn** relative to Business plans
- Enterprise customers demonstrate the lowest churn and highest revenue stability

These patterns suggest churn risk is driven by price sensitivity and lower product entrenchment.

---

### 2.3 Billing Failures Represent a Meaningful Source of Revenue Leakage
Monthly leakage analysis indicates that:
- Most invoices are successfully paid
- However, **a non-trivial share of MRR is lost due to failed payment attempts**
- Billing-related leakage is episodic but spikes around churn events and in SMB segments

This implies revenue loss can often be mitigated without customer churn through better billing intervention.

---

### 2.4 Early Warning Signals Can Identify At-Risk Active Customers
A rule-based early warning system was developed using product usage, billing, and support activity.

Key results:
- **~10% of active customers were flagged as at risk** in a given month
- The dominant risk driver was a **significant decline in product usage over the prior 30 days**
- Billing failures and elevated support ticket volume appeared as secondary risk indicators

These signals provide actionable lead time to intervene before revenue loss occurs.
