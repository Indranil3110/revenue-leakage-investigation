# Revenue Leakage Investigation for a Subscription Business  
*(Churn & Early Warning Analysis)*

## Overview
Finance and Growth teams observed a recurring gap between expected Monthly Recurring Revenue (MRR) and actual cash collected.

This project simulates an internal analytics investigation for a B2B, seat-based SaaS business to:
- Identify where revenue leakage occurs (churn, billing failures, downgrades)
- Quantify financial impact across customer segments and plans
- Design a rule-based early warning system to flag at-risk customers before revenue loss occurs

The focus is on **decision-oriented analytics**, not model experimentation.

---

## Business Questions
- Which customer segments and plans contribute disproportionately to churn?
- How much revenue is lost due to billing failures versus customer churn?
- Do downgrades and seat reductions represent meaningful revenue leakage?
- Can declining product usage signal churn risk early enough for intervention?

---

## Key Deliverables
- **PostgreSQL data model** for subscriptions, billing, usage, and support activity
- **Revenue leakage metrics** (MRR vs cash collected, billing failures, downgrade impact)
- **Churn cohort and segmentation analysis**
- **Rule-based early warning system** using usage, billing, and support signals
- **Executive memo** summarizing findings and recommendations for stakeholders

---

## Early Warning System
Active customers are evaluated using:
- 30-day usage decline relative to historical baseline
- Repeated failed payment attempts
- Elevated support ticket volume

~10% of active customers are flagged as at risk in a typical month, providing actionable lead time for Customer Success intervention.

---

## Tech Stack
- **SQL** (PostgreSQL, CTEs, windowed aggregations)
- **Python** (pandas, numpy) for synthetic data generation
- **pgAdmin** for database management
- **GitHub** for version control and documentation

---

## Repository Structure
├── sql/
│ ├── schema.sql
│ └── metrics/
│ ├── mrr_monthly.sql
│ ├── leakage_breakdown.sql
│ ├── churn_cohorts.sql
│ ├── churn_by_segment_plan.sql
│ ├── downgrade_leakage.sql
│ └── early_warning_features.sql
├── src/
│ └── generate_data.py
├── docs/
│ └── executive_memo.md
├── dashboards/
├── data/
│ └── raw/ # generated locally, not committed
├── notebooks/
└── requirements.txt


---

## Notes
- All data is **synthetic**, generated to reflect realistic SaaS behavior.
- Thresholds and logic are designed for **interpretability and actionability**.
- Predictive modeling is intentionally optional to prioritize explainable insights.
- Data is generated locally via src/generate_data.py and is not committed.
