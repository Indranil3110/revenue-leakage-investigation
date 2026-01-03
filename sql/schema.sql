-- Revenue Leakage Investigation (B2B Seat-based SaaS)
-- PostgreSQL schema (v1)

-- Optional: keep everything in a dedicated schema
-- CREATE SCHEMA IF NOT EXISTS rev_leakage;
-- SET search_path TO rev_leakage;

DROP TABLE IF EXISTS product_usage_daily CASCADE;
DROP TABLE IF EXISTS support_tickets CASCADE;
DROP TABLE IF EXISTS plan_changes CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS invoices CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

CREATE TABLE customers (
  customer_id       BIGINT PRIMARY KEY,
  signup_date       DATE NOT NULL,
  region            TEXT NOT NULL,
  segment           TEXT NOT NULL CHECK (segment IN ('SMB','Mid-Market','Enterprise'))
);

CREATE TABLE subscriptions (
  subscription_id   BIGINT PRIMARY KEY,
  customer_id       BIGINT NOT NULL REFERENCES customers(customer_id),
  plan              TEXT NOT NULL CHECK (plan IN ('Basic','Pro','Business')),
  seats             INT  NOT NULL CHECK (seats > 0),
  start_date        DATE NOT NULL,
  end_date          DATE,
  status            TEXT NOT NULL CHECK (status IN ('active','canceled'))
);

-- One invoice per customer per month (simplifies analytics)
CREATE TABLE invoices (
  invoice_id        BIGINT PRIMARY KEY,
  customer_id       BIGINT NOT NULL REFERENCES customers(customer_id),
  invoice_month     DATE NOT NULL,  -- use first day of month, e.g., 2025-11-01
  amount_due        NUMERIC(12,2) NOT NULL CHECK (amount_due >= 0),
  due_date          DATE NOT NULL,
  invoice_status    TEXT NOT NULL CHECK (invoice_status IN ('open','paid','void'))
);

-- Payments are attempts/outcomes against an invoice
CREATE TABLE payments (
  payment_id        BIGINT PRIMARY KEY,
  invoice_id        BIGINT NOT NULL REFERENCES invoices(invoice_id),
  attempt_date      DATE NOT NULL,
  amount_paid       NUMERIC(12,2) NOT NULL CHECK (amount_paid >= 0),
  status            TEXT NOT NULL CHECK (status IN ('paid','failed'))
);

-- Plan or seat changes (downgrades/upgrades/seat_change)
CREATE TABLE plan_changes (
  change_id         BIGINT PRIMARY KEY,
  customer_id       BIGINT NOT NULL REFERENCES customers(customer_id),
  change_date       DATE NOT NULL,
  change_type       TEXT NOT NULL CHECK (change_type IN ('upgrade','downgrade','seat_change')),
  old_plan          TEXT CHECK (old_plan IN ('Basic','Pro','Business')),
  new_plan          TEXT CHECK (new_plan IN ('Basic','Pro','Business')),
  old_seats         INT CHECK (old_seats > 0),
  new_seats         INT CHECK (new_seats > 0)
);

-- Daily usage signals (used for early-warning)
CREATE TABLE product_usage_daily (
  customer_id         BIGINT NOT NULL REFERENCES customers(customer_id),
  usage_date          DATE NOT NULL,
  active_users        INT  NOT NULL CHECK (active_users >= 0),
  sessions            INT  NOT NULL CHECK (sessions >= 0),
  core_feature_events INT  NOT NULL CHECK (core_feature_events >= 0),
  PRIMARY KEY (customer_id, usage_date)
);

-- Optional: support tickets add realism (helpful for churn drivers)
CREATE TABLE support_tickets (
  ticket_id         BIGINT PRIMARY KEY,
  customer_id       BIGINT NOT NULL REFERENCES customers(customer_id),
  created_date      DATE NOT NULL,
  severity          TEXT NOT NULL CHECK (severity IN ('low','medium','high'))
);

-- Helpful indexes
CREATE INDEX idx_subscriptions_customer ON subscriptions(customer_id);
CREATE INDEX idx_invoices_customer_month ON invoices(customer_id, invoice_month);
CREATE INDEX idx_payments_invoice ON payments(invoice_id);
CREATE INDEX idx_usage_customer_date ON product_usage_daily(customer_id, usage_date);
CREATE INDEX idx_changes_customer_date ON plan_changes(customer_id, change_date);
CREATE INDEX idx_tickets_customer_date ON support_tickets(customer_id, created_date);

