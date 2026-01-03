# Business Definitions

## Business Context
This project simulates a B2B, seat-based SaaS company offering subscription plans to teams of varying sizes. Revenue is generated on a monthly recurring basis and is impacted by customer churn, billing failures, and plan changes.

---

## Subscription Plans
| Plan | Monthly Price (per seat) |
|-----|--------------------------|
| Basic | $49 |
| Pro | $99 |
| Business | $149 |

---

## Customer Segments
- **SMB**: 1–25 seats
- **Mid-Market**: 26–100 seats
- **Enterprise**: 100+ seats

---

## Revenue Leakage Categories
Revenue leakage is defined as the gap between expected MRR and realized revenue.

### 1. Voluntary Churn
Customers who actively cancel their subscription.

### 2. Involuntary Churn (Billing Failure)
Customers who churn due to failed payments or unresolved billing issues.

### 3. Downgrade Leakage
Revenue loss caused by:
- plan downgrades
- reduction in seat count

### 4. Refunds / Credits (Optional)
Revenue returned to customers due to service issues or billing adjustments.

---

## Churn Definition
A customer is considered churned when:
- their subscription status changes from `active` to `canceled`, or
- billing remains unresolved beyond the dunning period.

---

## At-Risk Customer Definition
A customer is flagged as at-risk if they exhibit early warning signals indicating a high likelihood of churn or revenue reduction within the next 30 days.

