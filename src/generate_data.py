import os
import numpy as np
import pandas as pd

# ---------------------------
# Config
# ---------------------------
SEED = 42
N_CUSTOMERS = 2000
START_DATE = pd.Timestamp("2024-01-01")
END_DATE = pd.Timestamp("2025-12-31")   # overall dataset end
USAGE_DAYS = 240                        # per-customer rolling daily usage window
DROP_WINDOW_DAYS = 30                   # drop window leading into churn or risk period

OUTPUT_DIR = os.path.join("data", "raw")

PLANS = ["Basic", "Pro", "Business"]
PLAN_PRICE_PER_SEAT = {"Basic": 49, "Pro": 99, "Business": 149}

SEGMENTS = ["SMB", "Mid-Market", "Enterprise"]
REGIONS = ["NA", "EMEA", "APAC", "LATAM"]

SEGMENT_SEAT_RANGE = {
    "SMB": (3, 25),
    "Mid-Market": (26, 100),
    "Enterprise": (101, 400),
}

# Segment tendencies (tunable)
SEGMENT_VOL_CHURN_P_MONTH = {"SMB": 0.030, "Mid-Market": 0.018, "Enterprise": 0.010}
SEGMENT_INV_CHURN_P_MONTH = {"SMB": 0.010, "Mid-Market": 0.007, "Enterprise": 0.004}
SEGMENT_FAILED_PAY_P = {"SMB": 0.080, "Mid-Market": 0.050, "Enterprise": 0.025}

# Churners: usage drops by 35–70% in last 30 days before churn end_date
DROP_MIN, DROP_MAX = 0.35, 0.70

# Active-but-at-risk simulation (to demonstrate early warning on active customers)
AT_RISK_ACTIVE_P = 0.10            # 10% of active customers show risk signals
ACTIVE_DROP_MIN, ACTIVE_DROP_MAX = 0.20, 0.55
AT_RISK_ACTIVE_BILLING_P = 0.20    # 20% of at-risk actives have failures in last month
AT_RISK_ACTIVE_TICKETS_P = 0.15    # 15% of at-risk actives get ticket spike


def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def month_start_series(start: pd.Timestamp, end: pd.Timestamp) -> pd.DatetimeIndex:
    """Month starts from start to end inclusive."""
    return pd.date_range(start=start, end=end, freq="MS")


def random_date_between(rng: np.random.Generator, start: pd.Timestamp, end: pd.Timestamp) -> pd.Timestamp:
    delta_days = max((end - start).days, 0)
    return start + pd.Timedelta(days=int(rng.integers(0, delta_days + 1)))


def main():
    rng = np.random.default_rng(SEED)
    ensure_dir(OUTPUT_DIR)

    # ---------------------------
    # 1) customers
    # ---------------------------
    customer_ids = np.arange(1, N_CUSTOMERS + 1, dtype=np.int64)

    signup_dates = [
        random_date_between(rng, START_DATE, END_DATE - pd.Timedelta(days=120))
        for _ in customer_ids
    ]
    segments = rng.choice(SEGMENTS, size=N_CUSTOMERS, p=[0.60, 0.30, 0.10])
    regions = rng.choice(REGIONS, size=N_CUSTOMERS, p=[0.55, 0.20, 0.15, 0.10])

    customers = pd.DataFrame({
        "customer_id": customer_ids,
        "signup_date": pd.to_datetime(signup_dates).date,
        "region": regions,
        "segment": segments
    })

    # ---------------------------
    # 2) subscriptions (1 per customer for v1)
    # ---------------------------
    subscription_ids = np.arange(1, N_CUSTOMERS + 1, dtype=np.int64)

    plan_probs_by_segment = {
        "SMB": [0.60, 0.35, 0.05],
        "Mid-Market": [0.25, 0.55, 0.20],
        "Enterprise": [0.05, 0.35, 0.60],
    }

    plans, seats, start_dates, end_dates, statuses = [], [], [], [], []

    for _, row in customers.iterrows():
        seg = row["segment"]
        plan = rng.choice(PLANS, p=plan_probs_by_segment[seg])

        seat_low, seat_high = SEGMENT_SEAT_RANGE[seg]
        seat_count = int(rng.integers(seat_low, seat_high + 1))

        sub_start = pd.Timestamp(row["signup_date"]) + pd.Timedelta(days=int(rng.integers(0, 14)))
        sub_start = min(sub_start, END_DATE)

        months_active = int(rng.integers(4, 24))
        candidate_end = (sub_start + pd.DateOffset(months=months_active)).to_period("M").to_timestamp(how="start")

        vol_p = SEGMENT_VOL_CHURN_P_MONTH[seg]
        inv_p = SEGMENT_INV_CHURN_P_MONTH[seg]

        churn_type = None
        if rng.random() < 0.45:
            churn_type = "voluntary" if rng.random() < (vol_p / (vol_p + inv_p)) else "involuntary"

        if churn_type is None:
            sub_end = pd.NaT
            status = "active"
        else:
            sub_end = min(candidate_end, END_DATE)
            if (sub_end - sub_start).days < 60:
                sub_end = min(sub_start + pd.Timedelta(days=60), END_DATE)
            status = "canceled"

        plans.append(plan)
        seats.append(seat_count)
        start_dates.append(sub_start.date())
        end_dates.append(sub_end.date() if pd.notna(sub_end) else None)
        statuses.append(status)

    subscriptions = pd.DataFrame({
        "subscription_id": subscription_ids,
        "customer_id": customer_ids,
        "plan": plans,
        "seats": seats,
        "start_date": start_dates,
        "end_date": end_dates,
        "status": statuses
    })

    # ---------------------------
    # Active-but-at-risk customer set (for early warning demo)
    # ---------------------------
    active_customers = subscriptions.loc[subscriptions["status"] == "active", "customer_id"].astype(int).tolist()
    n_at_risk = int(len(active_customers) * AT_RISK_ACTIVE_P)
    at_risk_active_set = set(rng.choice(active_customers, size=n_at_risk, replace=False)) if n_at_risk > 0 else set()

    # ---------------------------
    # 3) plan_changes
    # ---------------------------
    changes = []
    change_id = 1

    for _, sub in subscriptions.iterrows():
        cust_id = int(sub["customer_id"])
        seg = customers.loc[customers["customer_id"] == cust_id, "segment"].iloc[0]
        start = pd.Timestamp(sub["start_date"])
        end = pd.Timestamp(sub["end_date"]) if sub["end_date"] else END_DATE

        n_changes = int(rng.integers(0, 3)) if seg != "Enterprise" else int(rng.integers(0, 4))

        current_plan = sub["plan"]
        current_seats = int(sub["seats"])

        for _ in range(n_changes):
            change_date = random_date_between(rng, start + pd.Timedelta(days=30), min(end, END_DATE))
            change_type = rng.choice(["upgrade", "downgrade", "seat_change"], p=[0.25, 0.35, 0.40])

            old_plan, new_plan = current_plan, current_plan
            old_seats, new_seats = current_seats, current_seats

            if change_type in ["upgrade", "downgrade"]:
                idx = PLANS.index(current_plan)
                if change_type == "upgrade" and idx < len(PLANS) - 1:
                    new_plan = PLANS[idx + 1]
                elif change_type == "downgrade" and idx > 0:
                    new_plan = PLANS[idx - 1]
                else:
                    change_type = "seat_change"

            if change_type == "seat_change":
                seat_low, seat_high = SEGMENT_SEAT_RANGE[seg]
                delta = int(np.round(current_seats * rng.uniform(-0.25, 0.25)))
                new_seats = int(np.clip(current_seats + delta, seat_low, seat_high))

            changes.append({
                "change_id": change_id,
                "customer_id": cust_id,
                "change_date": change_date.date(),
                "change_type": change_type,
                "old_plan": old_plan,
                "new_plan": new_plan,
                "old_seats": old_seats,
                "new_seats": new_seats
            })
            change_id += 1

            current_plan = new_plan
            current_seats = new_seats

    plan_changes = pd.DataFrame(changes)

    # ---------------------------
    # 4) invoices + 5) payments
    # ---------------------------
    invoices_rows = []
    payments_rows = []
    invoice_id = 1
    payment_id = 1

    plan_changes_sorted = plan_changes.sort_values(["customer_id", "change_date"]) if not plan_changes.empty else plan_changes

    def plan_state_at(customer_id: int, month_start: pd.Timestamp, base_plan: str, base_seats: int):
        plan = base_plan
        seats_ = base_seats
        if plan_changes_sorted.empty:
            return plan, seats_
        cust_changes = plan_changes_sorted[plan_changes_sorted["customer_id"] == customer_id]
        if cust_changes.empty:
            return plan, seats_
        relevant = cust_changes[pd.to_datetime(cust_changes["change_date"]) <= month_start]
        for _, ch in relevant.iterrows():
            if ch["change_type"] in ("upgrade", "downgrade"):
                plan = ch["new_plan"]
            if pd.notna(ch["new_seats"]):
                seats_ = int(ch["new_seats"])
        return plan, seats_

    last_month_start = END_DATE.to_period("M").to_timestamp(how="start") - pd.DateOffset(months=1)

    for _, sub in subscriptions.iterrows():
        cust_id = int(sub["customer_id"])
        seg = customers.loc[customers["customer_id"] == cust_id, "segment"].iloc[0]

        sub_start = pd.Timestamp(sub["start_date"]).to_period("M").to_timestamp(how="start")
        sub_end = (
            pd.Timestamp(sub["end_date"]).to_period("M").to_timestamp(how="start")
            if sub["end_date"]
            else END_DATE.to_period("M").to_timestamp(how="start")
        )

        months = month_start_series(sub_start, sub_end)
        base_plan = sub["plan"]
        base_seats = int(sub["seats"])

        for m in months:
            plan_m, seats_m = plan_state_at(cust_id, m, base_plan, base_seats)
            amount_due = PLAN_PRICE_PER_SEAT[plan_m] * seats_m
            due_date = (m + pd.offsets.MonthBegin(1)) - pd.Timedelta(days=1)

            failed_p = SEGMENT_FAILED_PAY_P[seg]
            will_fail = rng.random() < failed_p

            invoice_status = "open"
            payment_status = "failed" if will_fail else "paid"
            amount_paid = 0.0 if will_fail else float(amount_due)

            attempt_date = due_date - pd.Timedelta(days=int(rng.integers(0, 5)))

            # For churners: more failures near the end
            if sub["status"] == "canceled" and sub["end_date"]:
                end_m = pd.Timestamp(sub["end_date"]).to_period("M").to_timestamp(how="start")
                if m >= (end_m - pd.DateOffset(months=2)):
                    if rng.random() < min(0.75, failed_p + 0.35):
                        payment_status = "failed"
                        amount_paid = 0.0

            # For at-risk ACTIVE customers: inject failures in last month (small subset)
            if sub["status"] == "active" and cust_id in at_risk_active_set:
                if m >= last_month_start and rng.random() < AT_RISK_ACTIVE_BILLING_P:
                    payment_status = "failed"
                    amount_paid = 0.0

            if payment_status == "paid":
                invoice_status = "paid"

            invoices_rows.append({
                "invoice_id": invoice_id,
                "customer_id": cust_id,
                "invoice_month": m.date(),
                "amount_due": round(float(amount_due), 2),
                "due_date": due_date.date(),
                "invoice_status": invoice_status
            })

            payments_rows.append({
                "payment_id": payment_id,
                "invoice_id": invoice_id,
                "attempt_date": attempt_date.date(),
                "amount_paid": round(float(amount_paid), 2),
                "status": payment_status
            })

            invoice_id += 1
            payment_id += 1

    invoices = pd.DataFrame(invoices_rows)
    payments = pd.DataFrame(payments_rows)

    # ---------------------------
    # 6) product_usage_daily  (FIXED + active-risk simulation)
    # ---------------------------
    usage_rows = []
    subs_map = subscriptions.set_index("customer_id")

    for cust_id in customer_ids:
        sub = subs_map.loc[cust_id]
        seg = customers.loc[customers["customer_id"] == cust_id, "segment"].iloc[0]
        seats_ = int(sub["seats"])

        cust_start = pd.Timestamp(sub["start_date"])
        cust_end = pd.Timestamp(sub["end_date"]) if sub["end_date"] else END_DATE
        usage_end_cust = min(cust_end, END_DATE)

        usage_start_cust = usage_end_cust - pd.Timedelta(days=USAGE_DAYS - 1)
        usage_start_cust = max(usage_start_cust, cust_start)

        if usage_start_cust > usage_end_cust:
            continue

        usage_dates = pd.date_range(usage_start_cust, usage_end_cust, freq="D")

        if seg == "SMB":
            dau_ratio = rng.uniform(0.35, 0.65)
        elif seg == "Mid-Market":
            dau_ratio = rng.uniform(0.40, 0.70)
        else:
            dau_ratio = rng.uniform(0.45, 0.75)

        base_active_users = max(1, int(round(seats_ * dau_ratio)))
        base_sessions = max(1, int(round(base_active_users * rng.uniform(1.5, 3.0))))
        base_events = max(1, int(round(base_sessions * rng.uniform(2.0, 6.0))))

        churn_end = pd.Timestamp(sub["end_date"]) if (sub["status"] == "canceled" and sub["end_date"] is not None) else None
        churn_drop_factor = rng.uniform(DROP_MIN, DROP_MAX) if churn_end is not None else None

        # Active risk drop factor (one per customer, stable across days)
        active_drop_factor = rng.uniform(ACTIVE_DROP_MIN, ACTIVE_DROP_MAX) if (churn_end is None and int(cust_id) in at_risk_active_set) else None

        for d in usage_dates:
            active_users = int(max(0, round(base_active_users * rng.uniform(0.85, 1.15))))
            sessions = int(max(0, round(base_sessions * rng.uniform(0.85, 1.20))))
            events = int(max(0, round(base_events * rng.uniform(0.80, 1.25))))

            # Churners: drop in the 30 days leading into churn
            if churn_end is not None:
                days_to_churn = (churn_end - d).days
                if 0 <= days_to_churn <= DROP_WINDOW_DAYS:
                    active_users = int(round(active_users * (1.0 - churn_drop_factor)))
                    sessions = int(round(sessions * (1.0 - churn_drop_factor)))
                    events = int(round(events * (1.0 - churn_drop_factor)))

            # Active-but-at-risk: drop in the last 30 days of their available window
            if churn_end is None and active_drop_factor is not None:
                days_from_end = (usage_end_cust - d).days
                if 0 <= days_from_end <= DROP_WINDOW_DAYS:
                    active_users = int(round(active_users * (1.0 - active_drop_factor)))
                    sessions = int(round(sessions * (1.0 - active_drop_factor)))
                    events = int(round(events * (1.0 - active_drop_factor)))

            usage_rows.append({
                "customer_id": int(cust_id),
                "usage_date": d.date(),
                "active_users": int(max(0, active_users)),
                "sessions": int(max(0, sessions)),
                "core_feature_events": int(max(0, events))
            })

    product_usage_daily = pd.DataFrame(usage_rows)

    # ---------------------------
    # 7) support_tickets
    # ---------------------------
    tickets_rows = []
    ticket_id = 1

    for cust_id in customer_ids:
        seg = customers.loc[customers["customer_id"] == cust_id, "segment"].iloc[0]
        sub = subs_map.loc[cust_id]

        base_tickets = {"SMB": (0, 3), "Mid-Market": (1, 5), "Enterprise": (2, 8)}[seg]
        n_tickets = int(rng.integers(base_tickets[0], base_tickets[1] + 1))

        if sub["status"] == "canceled":
            n_tickets += int(rng.integers(0, 3))

        # Ticket spike for some at-risk active customers
        if int(cust_id) in at_risk_active_set and rng.random() < AT_RISK_ACTIVE_TICKETS_P:
            n_tickets += int(rng.integers(2, 6))

        for _ in range(n_tickets):
            created = random_date_between(rng, START_DATE, END_DATE)
            severity = rng.choice(["low", "medium", "high"], p=[0.65, 0.28, 0.07])

            tickets_rows.append({
                "ticket_id": ticket_id,
                "customer_id": int(cust_id),
                "created_date": created.date(),
                "severity": severity
            })
            ticket_id += 1

    support_tickets = pd.DataFrame(tickets_rows)

    # ---------------------------
    # Write CSVs
    # ---------------------------
    customers.to_csv(os.path.join(OUTPUT_DIR, "customers.csv"), index=False)
    subscriptions.to_csv(os.path.join(OUTPUT_DIR, "subscriptions.csv"), index=False)
    plan_changes.to_csv(os.path.join(OUTPUT_DIR, "plan_changes.csv"), index=False)
    invoices.to_csv(os.path.join(OUTPUT_DIR, "invoices.csv"), index=False)
    payments.to_csv(os.path.join(OUTPUT_DIR, "payments.csv"), index=False)
    product_usage_daily.to_csv(os.path.join(OUTPUT_DIR, "product_usage_daily.csv"), index=False)
    support_tickets.to_csv(os.path.join(OUTPUT_DIR, "support_tickets.csv"), index=False)

    print("✅ Data generated in:", OUTPUT_DIR)
    print("Files:")
    for f in [
        "customers.csv",
        "subscriptions.csv",
        "plan_changes.csv",
        "invoices.csv",
        "payments.csv",
        "product_usage_daily.csv",
        "support_tickets.csv",
    ]:
        print(" -", f)


if __name__ == "__main__":
    main()
