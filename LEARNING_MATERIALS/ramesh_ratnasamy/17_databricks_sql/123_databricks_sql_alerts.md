# Databricks - SQL Alerts

## Introduction

Let's talk about SQL Alerts -- a feature in Databricks SQL that lets you set up automated
notifications based on query results. Alerts are how you turn passive dashboards into active
monitoring. Instead of checking a dashboard every morning to see if something went wrong,
you configure an alert that notifies you automatically when a metric crosses a threshold.

This is a straightforward but important topic. Alerts are commonly used for data quality
monitoring, pipeline health checks, SLA compliance, and business metric anomalies.

## How Alerts Work

```
Alert Workflow:

  ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
  │  Saved   │────▶│  Alert   │────▶│ Schedule │────▶│  Notify  │
  │  Query   │     │  Config  │     │  (cron)  │     │  (email/ │
  │          │     │          │     │          │     │  webhook)│
  └──────────┘     └──────────┘     └──────────┘     └──────────┘

1. Start with a saved query that returns a value to monitor
2. Configure an alert condition (threshold)
3. Set a schedule for how often to check
4. Configure notification destinations (email, Slack, webhook)
```

## Creating an Alert

### Step 1: Write the Monitoring Query

The query must return a **single value** that can be evaluated against a threshold:

```sql
-- Alert query: Count of failed pipeline runs in the last hour
SELECT COUNT(*) AS failed_runs
FROM production.monitoring.pipeline_runs
WHERE status = 'FAILED'
  AND start_time >= CURRENT_TIMESTAMP - INTERVAL 1 HOUR;

-- Alert query: Data freshness check
SELECT
    TIMESTAMPDIFF(MINUTE, MAX(ingested_at), CURRENT_TIMESTAMP) AS minutes_since_update
FROM production.finance.transactions;

-- Alert query: Data quality check
SELECT
    ROUND(
        SUM(CASE WHEN amount IS NULL OR amount <= 0 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    ) AS pct_invalid_records
FROM production.finance.transactions
WHERE transaction_date = CURRENT_DATE;

-- Alert query: Business metric monitoring
SELECT SUM(amount) AS daily_revenue
FROM production.finance.transactions
WHERE transaction_date = CURRENT_DATE;
```

### Step 2: Configure the Alert

```
Alert Configuration:

┌──────────────────────────────────────────────────────────────┐
│ Create Alert                                                 │
│                                                              │
│  Name:          [Pipeline Failure Alert]                      │
│                                                              │
│  Query:         [Failed Pipeline Runs ▼]                     │
│                 (select a saved query)                        │
│                                                              │
│  Trigger when:  [Value column ▼]                             │
│                 [failed_runs]                                │
│                                                              │
│  Condition:     [is above ▼]  [0]                            │
│                                                              │
│  Available conditions:                                       │
│    - is above (>)                                            │
│    - is above or equals (>=)                                 │
│    - is below (<)                                            │
│    - is below or equals (<=)                                 │
│    - equals (=)                                              │
│    - does not equal (!=)                                     │
│    - is empty (NULL)                                         │
│    - is not empty (NOT NULL)                                 │
│                                                              │
│  Refresh:       [Every 5 minutes ▼]                          │
│                                                              │
│  Notification:  [On each evaluation ▼]                       │
│                 Options:                                      │
│                   - Just once (until condition resets)        │
│                   - On each evaluation (every time true)     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Step 3: Set Up Notification Destinations

```
Notification Destinations:

┌────────────────────┬──────────────────────────────────────────┐
│ Destination Type   │ Description                              │
├────────────────────┼──────────────────────────────────────────┤
│ Email              │ Send alert to email addresses            │
│                    │ (individual or distribution list)        │
├────────────────────┼──────────────────────────────────────────┤
│ Slack              │ Post alert to a Slack channel            │
│                    │ (via Slack webhook integration)          │
├────────────────────┼──────────────────────────────────────────┤
│ Webhook            │ Send HTTP POST to a custom endpoint      │
│                    │ (integrate with PagerDuty, Opsgenie,     │
│                    │  custom systems, etc.)                   │
└────────────────────┴──────────────────────────────────────────┘

Configuration (in workspace settings):
  Admin Console → Notification Destinations → Add Destination
  → Choose type (Email, Slack, Webhook)
  → Configure endpoint details
```

## Alert States

```
Alert States:

┌───────────┐     ┌───────────┐     ┌───────────┐
│ UNKNOWN   │────▶│ TRIGGERED │────▶│    OK     │
│ (initial) │     │ (condition│     │ (condition│
│           │     │  is TRUE) │     │ is FALSE) │
└───────────┘     └─────┬─────┘     └─────┬─────┘
                        │                 │
                        │   Condition     │ Condition
                        │   becomes       │ becomes
                        │   FALSE         │ TRUE
                        │                 │
                        └─────────────────┘

State transitions:
  UNKNOWN → TRIGGERED  (first evaluation finds condition TRUE)
  UNKNOWN → OK         (first evaluation finds condition FALSE)
  TRIGGERED → OK       (condition is no longer TRUE)
  OK → TRIGGERED       (condition becomes TRUE again)
```

## Alert Schedule Options

```
Refresh Schedule:

┌──────────────────────────────────────────────┐
│ How often to evaluate the alert:             │
│                                              │
│  - Every 1 minute                            │
│  - Every 5 minutes                           │
│  - Every 10 minutes                          │
│  - Every 15 minutes                          │
│  - Every 30 minutes                          │
│  - Every 1 hour                              │
│  - Every 2 hours                             │
│  - Daily (at specified time)                 │
│  - Weekly (at specified day and time)        │
│  - Custom cron expression                    │
│                                              │
│ NOTE: The alert query runs on a SQL Warehouse│
│ each time it's evaluated. More frequent =    │
│ more compute cost.                           │
└──────────────────────────────────────────────┘
```

## Common Alert Patterns

### Data Quality Alert

```sql
-- Alert: Notify if more than 5% of records have null order IDs
SELECT
    ROUND(
        SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    ) AS null_pct
FROM production.finance.transactions
WHERE transaction_date = CURRENT_DATE;

-- Alert condition: null_pct is above 5
```

### Data Freshness Alert

```sql
-- Alert: Notify if data hasn't been updated in 2 hours
SELECT
    TIMESTAMPDIFF(MINUTE, MAX(ingested_at), CURRENT_TIMESTAMP) AS minutes_stale
FROM production.finance.transactions;

-- Alert condition: minutes_stale is above 120
```

### Pipeline Health Alert

```sql
-- Alert: Notify on any pipeline failure
SELECT COUNT(*) AS failures
FROM production.monitoring.dlt_event_log
WHERE event_type = 'flow_progress'
  AND details:flow_progress:status = 'FAILED'
  AND timestamp >= CURRENT_TIMESTAMP - INTERVAL 1 HOUR;

-- Alert condition: failures is above 0
```

### Business Metric Alert

```sql
-- Alert: Notify if daily revenue drops below expected threshold
SELECT SUM(amount) AS daily_revenue
FROM production.finance.transactions
WHERE transaction_date = CURRENT_DATE;

-- Alert condition: daily_revenue is below 10000
```

### Record Count Alert

```sql
-- Alert: Notify if no new records were loaded today
SELECT COUNT(*) AS new_records
FROM production.finance.transactions
WHERE transaction_date = CURRENT_DATE;

-- Alert condition: new_records equals 0
```

## Alerts vs Other Monitoring

```
Monitoring Options in Databricks:

┌─────────────────────┬──────────────────────────────────────────┐
│ Mechanism           │ Best For                                 │
├─────────────────────┼──────────────────────────────────────────┤
│ SQL Alerts          │ Business metrics, data quality, SLAs     │
│                     │ (simple threshold-based checks)          │
├─────────────────────┼──────────────────────────────────────────┤
│ DLT Expectations    │ In-pipeline data quality enforcement     │
│                     │ (embedded in the pipeline code)          │
├─────────────────────┼──────────────────────────────────────────┤
│ Job Notifications   │ Pipeline/job success or failure          │
│                     │ (execution-level monitoring)             │
├─────────────────────┼──────────────────────────────────────────┤
│ Audit Logs          │ Security and access monitoring           │
│                     │ (who did what, when)                     │
├─────────────────────┼──────────────────────────────────────────┤
│ External monitoring │ Infrastructure, advanced anomaly         │
│ (CloudWatch, etc.)  │ detection, custom dashboards             │
└─────────────────────┴──────────────────────────────────────────┘
```

## Key Exam Points

1. **Alerts are based on saved queries** -- the query must return a value to evaluate
2. **Alert conditions** support: above, below, equals, not equals, empty, not empty
3. **Three alert states**: UNKNOWN (initial), TRIGGERED (condition true), OK (condition false)
4. **Notification destinations**: email, Slack, and webhooks
5. **Alerts run on a schedule** -- each evaluation runs the query on a SQL Warehouse
6. **Notification frequency**: "just once" (until reset) or "on each evaluation" (every time
   condition is true)
7. **Common use cases**: data quality checks, data freshness monitoring, pipeline failures,
   business metric thresholds
8. **Alert queries should return a single value** that can be compared against a threshold
9. **More frequent evaluations = more compute cost** (query runs on SQL Warehouse each time)
10. **SQL Alerts complement** DLT expectations (pipeline-level) and job notifications
    (execution-level) for comprehensive monitoring
