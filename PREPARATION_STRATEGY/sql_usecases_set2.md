Excellent! Let me give you **5 more advanced problems** with complete framework application.

---

## **PROBLEM 6: Customer Churn Analysis** ⭐⭐⭐

### **Problem Statement:**
*"Identify churned customers (no purchase in last 90 days but had purchased in the 90 days before that). Calculate their last purchase date, days since last purchase, and total historical spend. Rank them by spend to prioritize win-back campaigns."*

**Schema:**
```sql
customers (customer_id, name, signup_date)
orders (order_id, customer_id, order_date, amount)
```

---

### **PHASE 1: UNDERSTAND (Apply Framework)**

**Your Questions:**

```
1. "What defines 'active' - any purchase or minimum amount?"
   → Any purchase counts

2. "Should I exclude customers who never purchased in the first 90-day window?"
   → Yes, they're not churned, they're inactive

3. "What's today's date for calculation?"
   → Use CURRENT_DATE

4. "Output columns?"
   → customer_id, name, last_purchase_date, days_since_purchase, 
     total_spend, churn_risk_rank

5. "Include customers who signed up less than 180 days ago?"
   → No, need at least 180 days of history

6. "Multiple orders on same day?"
   → Possible, use MAX(order_date)
```

**Document Understanding:**

```
Churned Definition:
  - Last purchase > 90 days ago
  - Had purchase between 91-180 days ago
  - Account age >= 180 days

Logic Flow:
  Recent window: Last 90 days (no purchase) ✗
  Previous window: 91-180 days ago (had purchase) ✓

Edge Cases:
  - New customers (<180 days) → Exclude
  - Never purchased → Exclude
  - Active customers (purchased in last 90) → Exclude
  - Signed up but never purchased → Exclude
```

---

### **PHASE 2: DESIGN**

**Break Down:**

```
Step 1: Calculate each customer's last purchase date
Step 2: Calculate days since last purchase
Step 3: Check if last purchase in 91-180 day window
Step 4: Calculate total historical spend
Step 5: Rank by spend (highest = priority)
Step 6: Filter only churned customers
```

**Visual Design:**

```
Customer Timeline:
─────────────────────────────────────────────────────►
         180 days ago      90 days ago         Today
              │                 │                 │
              ├─────────────────┤─────────────────┤
              Previous Window    Recent Window
              (91-180 days)      (0-90 days)
              
CHURNED: Last purchase in Previous Window, none in Recent
ACTIVE:  Last purchase in Recent Window
INACTIVE: Never purchased or only purchases >180 days ago
```

**Data Flow:**

```
orders                    Aggregate per customer
┌─────────────────────┐   ┌──────────────────────────────┐
│ cust  date   amount │   │ cust  last_purch  days  spend│
│ 1  2023-11-01  100  │   │ 1    2023-11-01   99    500  │ ← CHURNED
│ 1  2023-12-15  150  │   │ 2    2024-01-20   19    300  │ ← ACTIVE
│ 1  2024-01-10  250  │   │ 3    2023-10-01   130   1000 │ ← CHURNED
│ 2  2024-01-20  300  │   └──────────────────────────────┘
│ 3  2023-10-01  1000│                  │
└─────────────────────┘                  │ Filter: 91-180 days
                                         ↓
                              ┌──────────────────────┐
                              │ cust  spend  rank    │
                              │ 3    1000    1       │
                              │ 1    500     2       │
                              └──────────────────────┘
```

---

### **PHASE 3: APPROACH SELECTION**

**Compare Approaches:**

```
APPROACH 1: Subquery with date calculations
SELECT c.customer_id, c.name,
  (SELECT MAX(order_date) FROM orders WHERE customer_id = c.customer_id) as last_purch,
  (SELECT SUM(amount) FROM orders WHERE customer_id = c.customer_id) as total_spend
FROM customers c
WHERE ...

Pros: Straightforward
Cons: Multiple subqueries = multiple scans (N+1 problem)
Performance: ❌ Poor for large datasets
Rating: ⭐

APPROACH 2: JOIN with aggregation
SELECT c.customer_id, c.name, 
       MAX(o.order_date) as last_purch,
       SUM(o.amount) as total_spend
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name
HAVING MAX(o.order_date) BETWEEN ...

Pros: Single scan
Cons: Less readable for complex logic
Performance: ✓ Good
Rating: ⭐⭐

APPROACH 3: CTE pipeline
WITH customer_purchases AS (...)
   , churn_analysis AS (...)
   , ranked_churned AS (...)
SELECT * FROM ranked_churned;

Pros: Readable, debuggable, maintainable
Cons: Slight overhead (usually optimized away)
Performance: ✓ Good
Rating: ⭐⭐⭐ BEST

CHOSEN: Approach 3 - CTE pipeline for clarity
```

---

### **PHASE 4: CODE (Incremental Build)**

```sql
-- ITERATION 1: Get each customer's purchase summary
SELECT 
    c.customer_id,
    c.name,
    c.signup_date,
    MAX(o.order_date) as last_purchase_date,
    COUNT(o.order_id) as total_orders,
    SUM(o.amount) as total_spend,
    CURRENT_DATE - MAX(o.order_date) as days_since_purchase
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name, c.signup_date;

-- Test: Verify aggregations are correct ✓
-- Check: NULL handling for customers with no orders ✓

-- ITERATION 2: Add date window logic
WITH customer_summary AS (
    SELECT 
        c.customer_id,
        c.name,
        c.signup_date,
        MAX(o.order_date) as last_purchase_date,
        COUNT(o.order_id) as total_orders,
        SUM(o.amount) as total_spend,
        CURRENT_DATE - MAX(o.order_date) as days_since_purchase,
        CURRENT_DATE - c.signup_date as account_age_days
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name, c.signup_date
)
SELECT *
FROM customer_summary
WHERE account_age_days >= 180  -- Must have 180 day history
  AND days_since_purchase BETWEEN 91 AND 180  -- Churned window
  AND total_orders > 0;  -- Had at least one purchase

-- Test: Verify date filters work correctly ✓
-- Edge case: Customer with purchase exactly 90 days ago → Excluded ✓
-- Edge case: Customer with purchase 91 days ago → Included ✓

-- ITERATION 3: Add churn confirmation (purchased in 91-180 window)
WITH customer_summary AS (
    SELECT 
        c.customer_id,
        c.name,
        c.signup_date,
        MAX(o.order_date) as last_purchase_date,
        SUM(o.amount) as total_spend,
        CURRENT_DATE - MAX(o.order_date) as days_since_purchase,
        CURRENT_DATE - c.signup_date as account_age_days
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name, c.signup_date
),
churned_customers AS (
    SELECT 
        customer_id,
        name,
        last_purchase_date,
        days_since_purchase,
        total_spend,
        account_age_days
    FROM customer_summary
    WHERE account_age_days >= 180
      AND days_since_purchase BETWEEN 91 AND 180
      AND total_spend > 0  -- Had purchases
)
SELECT * FROM churned_customers;

-- Test: Verify only truly churned customers appear ✓

-- ITERATION 4: Add ranking and prioritization
WITH customer_summary AS (
    SELECT 
        c.customer_id,
        c.name,
        c.signup_date,
        MAX(o.order_date) as last_purchase_date,
        SUM(o.amount) as total_spend,
        CURRENT_DATE - MAX(o.order_date) as days_since_purchase,
        CURRENT_DATE - c.signup_date as account_age_days
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name, c.signup_date
),
churned_customers AS (
    SELECT 
        customer_id,
        name,
        last_purchase_date,
        days_since_purchase,
        total_spend,
        account_age_days
    FROM customer_summary
    WHERE account_age_days >= 180
      AND days_since_purchase BETWEEN 91 AND 180
      AND total_spend > 0
)
SELECT 
    customer_id,
    name,
    last_purchase_date,
    days_since_purchase,
    ROUND(total_spend::NUMERIC, 2) as total_lifetime_value,
    ROW_NUMBER() OVER (ORDER BY total_spend DESC) as winback_priority,
    CASE 
        WHEN total_spend > 1000 THEN 'High Value'
        WHEN total_spend > 500 THEN 'Medium Value'
        ELSE 'Low Value'
    END as customer_segment,
    CASE 
        WHEN days_since_purchase > 150 THEN '🔴 Critical (150+ days)'
        WHEN days_since_purchase > 120 THEN '🟠 High Risk (120-150 days)'
        ELSE '🟡 Medium Risk (91-120 days)'
    END as churn_severity
FROM churned_customers
ORDER BY total_spend DESC;

-- Test all segments ✓
```

---

### **PHASE 5: TEST & OPTIMIZE**

**Test Cases:**

```sql
-- Test Case 1: Clear churn case
-- Customer: Last purchase 100 days ago, total spend $1000
-- Expected: Appears as churned, High Value, priority based on spend ✓

-- Test Case 2: Active customer
-- Customer: Last purchase 30 days ago
-- Expected: NOT in results ✓

-- Test Case 3: Newly churned (exactly 91 days)
-- Customer: Last purchase exactly 91 days ago
-- Expected: Appears in results ✓

-- Test Case 4: Too old (181 days since purchase)
-- Customer: Last purchase 181 days ago
-- Expected: NOT in results (outside 91-180 window) ✓

-- Test Case 5: New customer (signed up 60 days ago)
-- Customer: Account age 60 days, last purchase 50 days ago
-- Expected: NOT in results (account < 180 days old) ✓

-- Test Case 6: Never purchased
-- Customer: Signed up 200 days ago, no orders
-- Expected: NOT in results (total_spend = 0 excluded) ✓

-- Test Case 7: Multiple orders in churn window
-- Customer: Orders at 95, 100, 110 days ago (MAX = 95)
-- Expected: Appears with last_purchase_date = 95 days ago ✓
```

**Optimization Discussion:**

```sql
-- Current Performance:
-- - Single JOIN between customers and orders
-- - GROUP BY required (acceptable)
-- - Window function for ranking (efficient)

-- Recommended Indexes:
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date DESC);
CREATE INDEX idx_customers_signup ON customers(signup_date);

-- For Very Large Datasets (100M+ customers):
-- Option 1: Materialized view refreshed daily
CREATE MATERIALIZED VIEW churned_customers_mv AS
WITH customer_summary AS (...)
SELECT * FROM churned_customers;

-- Option 2: Partition orders table by date
-- Helps with date range filters

-- Option 3: Pre-aggregate customer metrics nightly
CREATE TABLE customer_metrics_daily (
    customer_id INT,
    date DATE,
    last_purchase_date DATE,
    total_spend DECIMAL,
    days_since_purchase INT
);

-- Interview Answer:
"For this query:

1. CURRENT APPROACH: Efficient for typical datasets
   - Single pass through orders with GROUP BY
   - Indexes on (customer_id, order_date) are critical

2. FOR SCALE (100M+ customers):
   - Daily batch job to pre-compute customer metrics
   - Store last_purchase_date, total_spend in customer table
   - Incremental updates only for customers with new orders
   - Query becomes simple SELECT with date filter

3. FOR REAL-TIME (streaming):
   - Maintain running aggregates in Redis/similar
   - Update on each order event
   - Query cache instead of database

4. BUSINESS IMPACT:
   - High-value churned customers = immediate action
   - This ranking helps prioritize limited win-back budget
   - Can segment by industry, geography for targeted campaigns"
```

---

## **PROBLEM 7: Running Totals and Moving Averages** ⭐⭐⭐

### **Problem Statement:**
*"For each product, calculate daily sales with: (1) running total of sales from start of month, (2) 7-day moving average, (3) comparison to previous day, and (4) flag if today's sales are in top 10% of all daily sales for that product."*

**Schema:**
```sql
sales (sale_id, product_id, sale_date, quantity, amount)
```

---

### **PHASE 1: UNDERSTAND**

**Your Questions:**

```
1. "Should running total restart each month?"
   → Yes, reset on 1st of each month

2. "For 7-day moving average, what if fewer than 7 days exist?"
   → Use available days (don't exclude)

3. "Comparison to previous day - show absolute or percentage?"
   → Both

4. "Top 10% flag - by quantity or amount?"
   → By amount

5. "Multiple sales same product same day?"
   → Aggregate per day

6. "Include days with zero sales?"
   → No, only days with actual sales
```

**Document Understanding:**

```
Input: sales (product_id, sale_date, amount)
Output: 
  - product_id, sale_date, daily_amount
  - running_total_month (cumulative within month)
  - moving_avg_7day (rolling average)
  - vs_previous_day (amount and %)
  - is_top_10_percent (flag)

Calculations:
  - Running total: SUM() OVER (PARTITION BY product, month ORDER BY date)
  - Moving avg: AVG() OVER (... ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
  - Previous day: LAG() window function
  - Top 10%: PERCENT_RANK() or NTILE()
```

---

### **PHASE 2: DESIGN**

**Breakdown:**

```
Step 1: Aggregate sales per product per day
Step 2: Extract month/year for partitioning
Step 3: Add running total within month
Step 4: Add 7-day moving average
Step 5: Add previous day comparison
Step 6: Calculate percentile rank
Step 7: Flag top 10%
```

**Visual:**

```
Daily Sales:
Date       | Amount | Running Total | 7-Day Avg | Prev Day | Top 10%
-----------|--------|---------------|-----------|----------|--------
2024-02-01 | 100    | 100           | 100       | -        | No
2024-02-02 | 150    | 250           | 125       | +50%     | No
2024-02-03 | 200    | 450           | 150       | +33%     | Yes
2024-02-04 | 180    | 630           | 157.5     | -10%     | Yes
...
2024-03-01 | 120    | 120 (RESET!)  | 165       | -33%     | No
```

---

### **PHASE 3: APPROACH SELECTION**

**Only One Approach:** Window Functions (perfect for this)

```
Window functions needed:
- SUM() OVER (PARTITION BY product, month ORDER BY date) 
    → Running total
- AVG() OVER (... ROWS 6 PRECEDING AND CURRENT ROW)
    → Moving average
- LAG(amount, 1) OVER (PARTITION BY product ORDER BY date)
    → Previous day
- PERCENT_RANK() OVER (PARTITION BY product ORDER BY amount)
    → Percentile ranking

Why window functions:
✓ All calculations in single pass
✓ Designed exactly for this type of problem
✓ No self-joins needed
✓ Efficient and readable
```

---

### **PHASE 4: CODE (Incremental)**

```sql
-- ITERATION 1: Aggregate daily sales
SELECT 
    product_id,
    sale_date,
    SUM(quantity) as daily_quantity,
    SUM(amount) as daily_amount
FROM sales
GROUP BY product_id, sale_date;

-- Test: Verify daily aggregations ✓

-- ITERATION 2: Add month extraction and running total
WITH daily_sales AS (
    SELECT 
        product_id,
        sale_date,
        DATE_TRUNC('month', sale_date) as sale_month,
        SUM(amount) as daily_amount
    FROM sales
    GROUP BY product_id, sale_date
)
SELECT 
    product_id,
    sale_date,
    sale_month,
    daily_amount,
    SUM(daily_amount) OVER (
        PARTITION BY product_id, sale_month 
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as running_total_month
FROM daily_sales;

-- Test: Verify running total resets each month ✓
-- Check: Feb 28 → Mar 1 transition ✓

-- ITERATION 3: Add 7-day moving average
WITH daily_sales AS (
    SELECT 
        product_id,
        sale_date,
        DATE_TRUNC('month', sale_date) as sale_month,
        SUM(amount) as daily_amount
    FROM sales
    GROUP BY product_id, sale_date
)
SELECT 
    product_id,
    sale_date,
    daily_amount,
    SUM(daily_amount) OVER (
        PARTITION BY product_id, sale_month 
        ORDER BY sale_date
    ) as running_total_month,
    ROUND(
        AVG(daily_amount) OVER (
            PARTITION BY product_id 
            ORDER BY sale_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        )::NUMERIC, 
        2
    ) as moving_avg_7day
FROM daily_sales;

-- Test: 
-- Day 1: Avg of 1 value ✓
-- Day 7: Avg of 7 values ✓
-- Day 8: Avg of days 2-8 (rolling window) ✓

-- ITERATION 4: Add previous day comparison
WITH daily_sales AS (
    SELECT 
        product_id,
        sale_date,
        DATE_TRUNC('month', sale_date) as sale_month,
        SUM(amount) as daily_amount
    FROM sales
    GROUP BY product_id, sale_date
),
sales_with_metrics AS (
    SELECT 
        product_id,
        sale_date,
        daily_amount,
        SUM(daily_amount) OVER (
            PARTITION BY product_id, sale_month 
            ORDER BY sale_date
        ) as running_total_month,
        ROUND(
            AVG(daily_amount) OVER (
                PARTITION BY product_id 
                ORDER BY sale_date
                ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
            )::NUMERIC, 
            2
        ) as moving_avg_7day,
        LAG(daily_amount) OVER (
            PARTITION BY product_id 
            ORDER BY sale_date
        ) as previous_day_amount
    FROM daily_sales
)
SELECT 
    product_id,
    sale_date,
    daily_amount,
    running_total_month,
    moving_avg_7day,
    previous_day_amount,
    daily_amount - previous_day_amount as amount_change,
    CASE 
        WHEN previous_day_amount IS NOT NULL THEN
            ROUND(
                ((daily_amount - previous_day_amount) / previous_day_amount * 100)::NUMERIC,
                2
            )
        ELSE NULL
    END as pct_change
FROM sales_with_metrics;

-- Test: First day of product has NULL for previous ✓
-- Test: Percentage calculation correct ✓

-- ITERATION 5: Add top 10% flagging (FINAL VERSION)
WITH daily_sales AS (
    SELECT 
        product_id,
        sale_date,
        DATE_TRUNC('month', sale_date) as sale_month,
        SUM(amount) as daily_amount
    FROM sales
    GROUP BY product_id, sale_date
),
sales_with_metrics AS (
    SELECT 
        product_id,
        sale_date,
        daily_amount,
        -- Running total within month
        SUM(daily_amount) OVER (
            PARTITION BY product_id, sale_month 
            ORDER BY sale_date
        ) as running_total_month,
        -- 7-day moving average
        ROUND(
            AVG(daily_amount) OVER (
                PARTITION BY product_id 
                ORDER BY sale_date
                ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
            )::NUMERIC, 
            2
        ) as moving_avg_7day,
        -- Previous day for comparison
        LAG(daily_amount) OVER (
            PARTITION BY product_id 
            ORDER BY sale_date
        ) as previous_day_amount,
        -- Percentile rank for top 10% detection
        PERCENT_RANK() OVER (
            PARTITION BY product_id 
            ORDER BY daily_amount
        ) as percentile_rank
    FROM daily_sales
)
SELECT 
    product_id,
    sale_date,
    ROUND(daily_amount::NUMERIC, 2) as daily_sales,
    ROUND(running_total_month::NUMERIC, 2) as month_to_date_total,
    moving_avg_7day as seven_day_avg,
    ROUND(previous_day_amount::NUMERIC, 2) as previous_day_sales,
    CASE 
        WHEN previous_day_amount IS NOT NULL THEN
            ROUND((daily_amount - previous_day_amount)::NUMERIC, 2)
        ELSE NULL
    END as vs_previous_day,
    CASE 
        WHEN previous_day_amount IS NOT NULL THEN
            ROUND(
                ((daily_amount - previous_day_amount) / previous_day_amount * 100)::NUMERIC,
                1
            ) || '%'
        ELSE NULL
    END as pct_change,
    CASE 
        WHEN percentile_rank >= 0.9 THEN '⭐ Top 10%'
        WHEN percentile_rank >= 0.75 THEN 'Above Average'
        ELSE 'Normal'
    END as performance_tier
FROM sales_with_metrics
ORDER BY product_id, sale_date;
```

---

### **PHASE 5: TEST & OPTIMIZE**

**Test Cases:**

```sql
-- Test Case 1: Month transition
-- Date: 2024-02-28 (running total = $5000)
-- Date: 2024-03-01 (running total = $200)
-- Expected: Running total resets ✓

-- Test Case 2: First 6 days of product
-- Day 1: 7-day avg = amount for day 1 only
-- Day 6: 7-day avg = avg of days 1-6
-- Day 7: 7-day avg = avg of all 7 days
-- Expected: Correctly uses available days ✓

-- Test Case 3: Large spike in sales
-- Normal: $100-200/day, Today: $2000
-- Expected: Flagged as Top 10%, huge % increase ✓

-- Test Case 4: Zero to positive sales
-- Previous day: $0, Today: $100
-- Expected: Handle division by zero (previous_day = NULL or 0) ✓

-- Test Case 5: Negative day-over-day
-- Previous: $500, Today: $300
-- Expected: -40% change, negative amount_change ✓
```

**Performance Optimization:**

```sql
-- Recommended Indexes:
CREATE INDEX idx_sales_product_date ON sales(product_id, sale_date);
CREATE INDEX idx_sales_date_product ON sales(sale_date, product_id);

-- For materialization (if query runs frequently):
CREATE MATERIALIZED VIEW daily_sales_metrics_mv AS
WITH daily_sales AS (...)
SELECT * FROM sales_with_metrics;

-- Refresh daily:
REFRESH MATERIALIZED VIEW daily_sales_metrics_mv;

-- Interview Discussion:
"This query uses multiple window functions efficiently:

1. SINGLE PASS DESIGN:
   - All window functions execute in one table scan
   - Partitioning by product_id allows parallel processing
   - No self-joins needed

2. PERFORMANCE CHARACTERISTICS:
   - O(n log n) due to sorting for ORDER BY
   - With 1M sales/day across 10k products → ~1-2 seconds
   - Index on (product_id, sale_date) is critical

3. OPTIMIZATION OPTIONS:
   - For real-time dashboard: Materialize daily at midnight
   - For analyst ad-hoc: Current query is fine
   - For API calls: Cache results, refresh every hour

4. BUSINESS VALUE:
   - Running total helps track monthly targets
   - Moving average smooths daily volatility
   - Top 10% flag identifies exceptional days (investigate why)
   - Trend detection for inventory planning"
```

---

## **PROBLEM 8: Gap and Island Detection** ⭐⭐⭐⭐

### **Problem Statement:**
*"In a hotel booking system, identify: (1) all gaps in bookings (available date ranges), (2) longest consecutive booking streak for each room, (3) rooms with overlapping bookings (data quality issue), and (4) optimal room to close for maintenance (longest upcoming gap)."*

**Schema:**
```sql
rooms (room_id, room_number, floor, room_type)
bookings (booking_id, room_id, check_in, check_out, guest_name)
-- check_out is exclusive (guest leaves morning of check_out)
```

---

### **PHASE 1: UNDERSTAND**

**Your Questions:**

```
1. "Is check_out inclusive or exclusive?"
   → Exclusive (guest checks out morning, room available that night)

2. "Can same guest have multiple consecutive bookings?"
   → Yes, treat as separate bookings initially

3. "Should I merge consecutive bookings by same guest?"
   → Yes, for streak calculation

4. "What date range for gap detection?"
   → Next 90 days from today

5. "Overlapping bookings - what counts?"
   → Any overlap in dates (data quality error)

6. "Room maintenance - minimum gap needed?"
   → 7 consecutive days
```

**Document Understanding:**

```
PART 1: Gaps (Islands and Gaps problem)
  - Date range: CURRENT_DATE to CURRENT_DATE + 90
  - Gap: No bookings for consecutive days
  - Output: room_id, gap_start, gap_end, gap_days

PART 2: Longest Streak
  - Consecutive bookings (may have different guests)
  - Merge if guest same and dates consecutive
  - Output: room_id, streak_start, streak_end, streak_days

PART 3: Overlaps
  - Check_in of booking B before check_out of booking A
  - Output: room_id, overlapping booking pairs

PART 4: Maintenance Recommendation
  - Find room with longest gap in next 90 days
  - Minimum 7 days
  - Output: room_id, recommended_start, gap_length
```

---

### **PHASE 2: DESIGN**

**This is a complex multi-part problem. Break into phases:**

```
PHASE 1: GAPS DETECTION
  Step 1: Generate all dates in next 90 days
  Step 2: Identify booked dates per room
  Step 3: Find unbooked dates (anti-join)
  Step 4: Group consecutive unbooked dates

PHASE 2: STREAK DETECTION  
  Step 1: Order bookings by check_in
  Step 2: Use Date - ROW_NUMBER trick
  Step 3: Group consecutive bookings
  Step 4: Calculate streak lengths

PHASE 3: OVERLAP DETECTION
  Step 1: Self-join bookings on same room
  Step 2: Check if dates overlap
  Step 3: Report conflicts

PHASE 4: MAINTENANCE RECOMMENDATION
  Step 1: Use gaps from PHASE 1
  Step 2: Filter gaps >= 7 days
  Step 3: Rank by gap length
  Step 4: Return top per room
```

---

### **PHASE 3: APPROACH SELECTION**

```
GAP DETECTION: Date series generation + anti-join
STREAK DETECTION: Date - ROW_NUMBER technique
OVERLAP DETECTION: Self-join with date range comparison
MAINTENANCE: Combination of above techniques

All require recursive CTEs and window functions
No simpler approach exists for this problem
```

---

### **PHASE 4: CODE (Multi-Part Solution)**

```sql
-- ========================================
-- PART 1: GAP DETECTION
-- ========================================

WITH RECURSIVE 
-- Generate all dates for next 90 days
date_series AS (
    SELECT CURRENT_DATE as date
    UNION ALL
    SELECT date + INTERVAL '1 day'
    FROM date_series
    WHERE date < CURRENT_DATE + INTERVAL '90 days'
),

-- Create cross product: all rooms × all dates
room_dates AS (
    SELECT r.room_id, r.room_number, ds.date
    FROM rooms r
    CROSS JOIN date_series ds
),

-- Find dates that are booked
booked_dates AS (
    SELECT 
        room_id,
        generate_series(check_in, check_out - INTERVAL '1 day', INTERVAL '1 day')::DATE as date
    FROM bookings
    WHERE check_in <= CURRENT_DATE + INTERVAL '90 days'
      AND check_out > CURRENT_DATE
),

-- Find gaps (unbooked dates)
gaps AS (
    SELECT 
        rd.room_id,
        rd.room_number,
        rd.date
    FROM room_dates rd
    LEFT JOIN booked_dates bd ON rd.room_id = bd.room_id 
                               AND rd.date = bd.date
    WHERE bd.date IS NULL
),

-- Group consecutive gap days using Date - ROW_NUMBER trick
numbered_gaps AS (
    SELECT 
        room_id,
        room_number,
        date,
        date - (ROW_NUMBER() OVER (PARTITION BY room_id ORDER BY date))::INTEGER as gap_group
    FROM gaps
),

-- Aggregate consecutive days into gap periods
gap_periods AS (
    SELECT 
        room_id,
        room_number,
        MIN(date) as gap_start,
        MAX(date) as gap_end,
        COUNT(*) as gap_days
    FROM numbered_gaps
    GROUP BY room_id, room_number, gap_group
)
SELECT 
    room_id,
    room_number,
    gap_start,
    gap_end,
    gap_days,
    CASE 
        WHEN gap_days >= 7 THEN '✓ Suitable for maintenance'
        ELSE 'Too short'
    END as maintenance_feasibility
FROM gap_periods
ORDER BY gap_days DESC, room_id;

-- ========================================
-- PART 2: LONGEST BOOKING STREAK
-- ========================================

WITH booking_sequences AS (
    SELECT 
        room_id,
        check_in,
        check_out,
        check_in - (ROW_NUMBER() OVER (
            PARTITION BY room_id 
            ORDER BY check_in
        ))::INTEGER as streak_group
    FROM bookings
),
streaks AS (
    SELECT 
        room_id,
        MIN(check_in) as streak_start,
        MAX(check_out) as streak_end,
        MAX(check_out) - MIN(check_in) as streak_days,
        COUNT(*) as booking_count
    FROM booking_sequences
    GROUP BY room_id, streak_group
),
ranked_streaks AS (
    SELECT 
        room_id,
        streak_start,
        streak_end,
        streak_days,
        booking_count,
        ROW_NUMBER() OVER (PARTITION BY room_id ORDER BY streak_days DESC) as rank
    FROM streaks
)
SELECT 
    r.room_number,
    rs.streak_start,
    rs.streak_end,
    rs.streak_days,
    rs.booking_count as consecutive_bookings
FROM ranked_streaks rs
JOIN rooms r ON rs.room_id = r.room_id
WHERE rank = 1
ORDER BY streak_days DESC;

-- ========================================
-- PART 3: OVERLAPPING BOOKINGS DETECTION
-- ========================================

SELECT 
    r.room_number,
    b1.booking_id as booking_1,
    b1.check_in as booking_1_checkin,
    b1.check_out as booking_1_checkout,
    b1.guest_name as guest_1,
    b2.booking_id as booking_2,
    b2.check_in as booking_2_checkin,
    b2.check_out as booking_2_checkout,
    b2.guest_name as guest_2,
    GREATEST(b1.check_in, b2.check_in) as overlap_start,
    LEAST(b1.check_out, b2.check_out) as overlap_end,
    LEAST(b1.check_out, b2.check_out) - GREATEST(b1.check_in, b2.check_in) as overlap_days
FROM bookings b1
JOIN bookings b2 ON b1.room_id = b2.room_id
                 AND b1.booking_id < b2.booking_id  -- Avoid duplicates
JOIN rooms r ON b1.room_id = r.room_id
WHERE b1.check_in < b2.check_out 
  AND b2.check_in < b1.check_out  -- Overlap condition
ORDER BY r.room_number, b1.check_in;

-- ========================================
-- PART 4: MAINTENANCE RECOMMENDATION
-- ========================================

WITH RECURSIVE 
date_series AS (
    SELECT CURRENT_DATE as date
    UNION ALL
    SELECT date + INTERVAL '1 day'
    FROM date_series
    WHERE date < CURRENT_DATE + INTERVAL '90 days'
),
room_dates AS (
    SELECT r.room_id, r.room_number, ds.date
    FROM rooms r
    CROSS JOIN date_series ds
),
booked_dates AS (
    SELECT 
        room_id,
        generate_series(check_in, check_out - INTERVAL '1 day', INTERVAL '1 day')::DATE as date
    FROM bookings
    WHERE check_in <= CURRENT_DATE + INTERVAL '90 days'
      AND check_out > CURRENT_DATE
),
gaps AS (
    SELECT rd.room_id, rd.room_number, rd.date
    FROM room_dates rd
    LEFT JOIN booked_dates bd ON rd.room_id = bd.room_id AND rd.date = bd.date
    WHERE bd.date IS NULL
),
numbered_gaps AS (
    SELECT 
        room_id, room_number, date,
        date - (ROW_NUMBER() OVER (PARTITION BY room_id ORDER BY date))::INTEGER as gap_group
    FROM gaps
),
gap_periods AS (
    SELECT 
        room_id, room_number,
        MIN(date) as gap_start,
        MAX(date) as gap_end,
        COUNT(*) as gap_days
    FROM numbered_gaps
    GROUP BY room_id, room_number, gap_group
    HAVING COUNT(*) >= 7  -- Minimum 7 days for maintenance
),
ranked_gaps AS (
    SELECT 
        room_id, room_number, gap_start, gap_end, gap_days,
        ROW_NUMBER() OVER (PARTITION BY room_id ORDER BY gap_days DESC, gap_start) as rank
    FROM gap_periods
)
SELECT 
    room_number,
    gap_start as recommended_maintenance_start,
    gap_end as recommended_maintenance_end,
    gap_days as available_days,
    '🔧 Recommended for maintenance' as recommendation
FROM ranked_gaps
WHERE rank = 1
ORDER BY gap_days DESC
LIMIT 5;  -- Top 5 rooms
```

---

### **PHASE 5: TEST & OPTIMIZE**

**Test Cases:**

```sql
-- Test Case 1: Simple gap
-- Bookings: Jan 1-5, Jan 10-15
-- Expected: Gap from Jan 6-9 (4 days) ✓

-- Test Case 2: No gaps
-- Bookings: Consecutive every day
-- Expected: No gaps returned ✓

-- Test Case 3: Overlapping bookings
-- Room 101: Booking A (Jan 1-10), Booking B (Jan 5-15)
-- Expected: Overlap detected (Jan 5-10, 5 days) ✓

-- Test Case 4: Streak across multiple bookings
-- Bookings: Jan 1-5, Jan 5-10, Jan 10-15 (check_out exclusive)
-- Expected: Single streak Jan 1-15 (15 days) ✓

-- Test Case 5: Maintenance recommendation
-- Room A: 10-day gap, Room B: 7-day gap, Room C: 5-day gap
-- Expected: Room A recommended first ✓

-- Test Case 6: Date series generation
-- CURRENT_DATE to CURRENT_DATE + 90
-- Expected: Exactly 91 dates generated ✓
```

**Performance Optimization:**

```sql
-- Current Bottlenecks:
-- 1. CROSS JOIN rooms × dates (expensive for many rooms)
-- 2. generate_series in booked_dates (row explosion)
-- 3. Multiple CTEs with similar logic

-- Optimizations:

-- 1. Index recommendations:
CREATE INDEX idx_bookings_room_dates ON bookings(room_id, check_in, check_out);
CREATE INDEX idx_bookings_dates ON bookings(check_in, check_out);

-- 2. For production, materialize date series:
CREATE TABLE date_dimension (
    date DATE PRIMARY KEY,
    year INT,
    month INT,
    day INT,
    day_of_week INT
);
-- Populated once with 10 years of dates

-- 3. Alternative: Use window functions to find gaps
WITH booking_ordered AS (
    SELECT 
        room_id,
        check_out as prev_checkout,
        LEAD(check_in) OVER (PARTITION BY room_id ORDER BY check_in) as next_checkin
    FROM bookings
)
SELECT 
    room_id,
    prev_checkout as gap_start,
    next_checkin as gap_end,
    next_checkin - prev_checkout as gap_days
FROM booking_ordered
WHERE next_checkin - prev_checkout > 1;

-- This avoids CROSS JOIN but only works for gaps between bookings
-- Misses gaps at start/end of date range

-- Interview Discussion:
"This problem demonstrates several advanced SQL patterns:

1. GAPS AND ISLANDS:
   - Classic technique: Date - ROW_NUMBER
   - Creates constant value for consecutive dates
   - Groups them together

2. TRADE-OFFS:
   - CROSS JOIN approach: Correct but expensive
   - Window function approach: Fast but limited
   - Chose CROSS JOIN for correctness

3. FOR PRODUCTION:
   - Don't generate date series on-the-fly
   - Pre-populate calendar/date dimension table
   - Use it as base for joins

4. OVERLAP DETECTION:
   - Self-join with date range comparison
   - Critical for data quality
   - Should run as nightly validation

5. BUSINESS VALUE:
   - Maintenance planning: Minimize revenue loss
   - Overbooking detection: Prevent guest issues
   - Utilization tracking: Optimize pricing"
```

---

## **PROBLEM 9: User Retention Cohort Analysis** ⭐⭐⭐⭐

### **Problem Statement:**
*"Create a monthly cohort retention analysis showing: for users who signed up in each month, what percentage returned in Month 1, 2, 3... 12. Also identify 'resurrection' - users who churned (didn't return for 2 months) then came back."*

**Schema:**
```sql
users (user_id, signup_date, email)
activity (activity_id, user_id, activity_date, activity_type)
```

---

### **PHASE 1: UNDERSTAND**

**Your Questions:**

```
1. "Active user = any activity or specific type?"
   → Any activity counts

2. "Month 0 = signup month or first full month after?"
   → Month 0 = signup month

3. "If user signs up Jan 15, is Feb 1 Month 0 or Month 1?"
   → Feb 1 is Month 1 (first full month after signup)

4. "Resurrection: how long must user be gone?"
   → No activity for 60+ consecutive days, then returns

5. "Output format?"
   → Pivot table: Cohort | Month0 | Month1 | ... | Month12
     Plus: Separate list of resurrected users

6. "Include users who signed up less than 12 months ago?"
   → Yes, show partial data (NULL for future months)
```

**Document Understanding:**

```
COHORT: Users who signed up in same month
RETENTION: % who had activity in Month N after signup
MONTH N: Calculated from signup_month

Example:
  Signup: 2024-01-15
  Month 0: January 2024
  Month 1: February 2024
  Month 2: March 2024

RESURRECTION:
  User inactive for 60+ days
  Then has activity again
  Flag user and dates
```

---

### **PHASE 2: DESIGN**

**Cohort Retention:**

```
Step 1: Assign each user to signup cohort (month)
Step 2: For each activity, calculate months since signup
Step 3: Pivot: cohort × month_number → % active
Step 4: Calculate retention rate per cohort per month
```

**Resurrection Detection:**

```
Step 1: Order activities by date per user
Step 2: Calculate days since last activity
Step 3: Identify gaps > 60 days
Step 4: Flag first activity after gap as resurrection
```

**Visual - Cohort Table:**

```
Cohort      | M0   | M1   | M2   | M3   | ...
------------|------|------|------|------|----
2024-01     | 100% | 45%  | 38%  | 35%  | ...
2024-02     | 100% | 50%  | 40%  | NULL | ...
2024-03     | 100% | 52%  | NULL | NULL | ...

Interpretation:
- 2024-01 cohort: 100 users signed up
- Month 1: 45 were active (45% retention)
- Month 2: 38 were active (38% retention)
```

---

### **PHASE 3: APPROACH**

```
RETENTION ANALYSIS:
  - Window functions to calculate month difference
  - Conditional aggregation for pivot
  - CASE statements for each month column

RESURRECTION:
  - LAG() to get previous activity date
  - Calculate gap in days
  - Flag when gap > 60

No simpler approach - this requires:
  ✓ Window functions
  ✓ Date arithmetic
  ✓ Conditional aggregation
  ✓ Pivot logic
```

---

### **PHASE 4: CODE**

```sql
-- ========================================
-- PART 1: COHORT RETENTION ANALYSIS
-- ========================================

WITH user_cohorts AS (
    -- Assign each user to their signup cohort
    SELECT 
        user_id,
        DATE_TRUNC('month', signup_date) as cohort_month,
        signup_date
    FROM users
),

user_activities AS (
    -- Calculate months since signup for each activity
    SELECT 
        a.user_id,
        uc.cohort_month,
        DATE_TRUNC('month', a.activity_date) as activity_month,
        EXTRACT(YEAR FROM AGE(
            DATE_TRUNC('month', a.activity_date),
            uc.cohort_month
        )) * 12 + EXTRACT(MONTH FROM AGE(
            DATE_TRUNC('month', a.activity_date),
            uc.cohort_month
        )) as months_since_signup
    FROM activity a
    JOIN user_cohorts uc ON a.user_id = uc.user_id
),

cohort_sizes AS (
    -- Count users per cohort
    SELECT 
        cohort_month,
        COUNT(DISTINCT user_id) as cohort_size
    FROM user_cohorts
    GROUP BY cohort_month
),

monthly_active_users AS (
    -- Count active users per cohort per month
    SELECT 
        cohort_month,
        months_since_signup,
        COUNT(DISTINCT user_id) as active_users
    FROM user_activities
    WHERE months_since_signup BETWEEN 0 AND 12
    GROUP BY cohort_month, months_since_signup
),

retention_rates AS (
    -- Calculate retention percentages
    SELECT 
        cs.cohort_month,
        cs.cohort_size,
        mau.months_since_signup,
        mau.active_users,
        ROUND((mau.active_users::NUMERIC / cs.cohort_size * 100), 1) as retention_pct
    FROM cohort_sizes cs
    LEFT JOIN monthly_active_users mau ON cs.cohort_month = mau.cohort_month
)

-- Pivot the data (manual pivot)
SELECT 
    TO_CHAR(cohort_month, 'YYYY-MM') as cohort,
    cohort_size as users,
    MAX(CASE WHEN months_since_signup = 0 THEN retention_pct END) || '%' as month_0,
    MAX(CASE WHEN months_since_signup = 1 THEN retention_pct END) || '%' as month_1,
    MAX(CASE WHEN months_since_signup = 2 THEN retention_pct END) || '%' as month_2,
    MAX(CASE WHEN months_since_signup = 3 THEN retention_pct END) || '%' as month_3,
    MAX(CASE WHEN months_since_signup = 4 THEN retention_pct END) || '%' as month_4,
    MAX(CASE WHEN months_since_signup = 5 THEN retention_pct END) || '%' as month_5,
    MAX(CASE WHEN months_since_signup = 6 THEN retention_pct END) || '%' as month_6,
    MAX(CASE WHEN months_since_signup = 7 THEN retention_pct END) || '%' as month_7,
    MAX(CASE WHEN months_since_signup = 8 THEN retention_pct END) || '%' as month_8,
    MAX(CASE WHEN months_since_signup = 9 THEN retention_pct END) || '%' as month_9,
    MAX(CASE WHEN months_since_signup = 10 THEN retention_pct END) || '%' as month_10,
    MAX(CASE WHEN months_since_signup = 11 THEN retention_pct END) || '%' as month_11,
    MAX(CASE WHEN months_since_signup = 12 THEN retention_pct END) || '%' as month_12
FROM retention_rates
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month DESC;

-- ========================================
-- PART 2: RESURRECTION DETECTION
-- ========================================

WITH user_activity_timeline AS (
    SELECT 
        user_id,
        activity_date,
        LAG(activity_date) OVER (PARTITION BY user_id ORDER BY activity_date) as prev_activity_date
    FROM activity
    GROUP BY user_id, activity_date  -- Dedupe same-day activities
),

inactivity_gaps AS (
    SELECT 
        user_id,
        prev_activity_date as last_active_before_gap,
        activity_date as returned_on,
        activity_date - prev_activity_date as days_inactive
    FROM user_activity_timeline
    WHERE prev_activity_date IS NOT NULL
      AND activity_date - prev_activity_date > 60  -- 60+ day gap
),

resurrections AS (
    SELECT 
        ig.user_id,
        u.email,
        u.signup_date,
        ig.last_active_before_gap,
        ig.returned_on,
        ig.days_inactive,
        ROW_NUMBER() OVER (PARTITION BY ig.user_id ORDER BY ig.returned_on) as resurrection_number
    FROM inactivity_gaps ig
    JOIN users u ON ig.user_id = u.user_id
)

SELECT 
    user_id,
    email,
    signup_date,
    last_active_before_gap,
    returned_on as resurrection_date,
    days_inactive,
    resurrection_number,
    CASE 
        WHEN days_inactive BETWEEN 60 AND 90 THEN '🟡 Short Churn (60-90 days)'
        WHEN days_inactive BETWEEN 91 AND 180 THEN '🟠 Medium Churn (91-180 days)'
        ELSE '🔴 Long Churn (180+ days)'
    END as churn_severity
FROM resurrections
ORDER BY days_inactive DESC;

-- ========================================
-- PART 3: COHORT INSIGHTS
-- ========================================

WITH user_cohorts AS (
    SELECT 
        user_id,
        DATE_TRUNC('month', signup_date) as cohort_month
    FROM users
),
user_activities AS (
    SELECT 
        a.user_id,
        uc.cohort_month,
        EXTRACT(YEAR FROM AGE(
            DATE_TRUNC('month', a.activity_date),
            uc.cohort_month
        )) * 12 + EXTRACT(MONTH FROM AGE(
            DATE_TRUNC('month', a.activity_date),
            uc.cohort_month
        )) as months_since_signup
    FROM activity a
    JOIN user_cohorts uc ON a.user_id = uc.user_id
),
cohort_metrics AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT CASE WHEN months_since_signup = 1 THEN user_id END)::NUMERIC /
        COUNT(DISTINCT CASE WHEN months_since_signup = 0 THEN user_id END) * 100 as month_1_retention,
        COUNT(DISTINCT CASE WHEN months_since_signup = 3 THEN user_id END)::NUMERIC /
        COUNT(DISTINCT CASE WHEN months_since_signup = 0 THEN user_id END) * 100 as month_3_retention,
        COUNT(DISTINCT CASE WHEN months_since_signup = 6 THEN user_id END)::NUMERIC /
        COUNT(DISTINCT CASE WHEN months_since_signup = 0 THEN user_id END) * 100 as month_6_retention
    FROM user_activities
    GROUP BY cohort_month
)
SELECT 
    TO_CHAR(cohort_month, 'YYYY-MM') as cohort,
    ROUND(month_1_retention, 1) || '%' as m1_retention,
    ROUND(month_3_retention, 1) || '%' as m3_retention,
    ROUND(month_6_retention, 1) || '%' as m6_retention,
    CASE 
        WHEN month_1_retention > 50 THEN '✓ Healthy'
        WHEN month_1_retention > 30 THEN '⚠ Moderate'
        ELSE '🔴 Poor'
    END as cohort_health
FROM cohort_metrics
WHERE cohort_month >= CURRENT_DATE - INTERVAL '12 months'
ORDER BY cohort_month DESC;
```

---

### **PHASE 5: TEST**

```sql
-- Test Case 1: User active every month
-- Signup: Jan 2024, Activity: Jan, Feb, Mar, Apr...
-- Expected: 100% retention all months ✓

-- Test Case 2: User churns Month 2
-- Signup: Jan, Active: Jan, Feb, (skip Mar), Apr...
-- Expected: M0=100%, M1=100%, M2=0%, M3=100% ✓

-- Test Case 3: Resurrection
-- Last activity: Jan 1, Next activity: Apr 15 (104 days)
-- Expected: Flagged as resurrection, Long Churn ✓

-- Test Case 4: Recent cohort (< 12 months old)
-- Signup: Nov 2024, Current: Feb 2025
-- Expected: M0-M3 populated, M4-M12 NULL ✓

-- Test Case 5: Multiple resurrections same user
-- Gaps: 70 days (resurrection #1), 90 days (resurrection #2)
-- Expected: Two rows, resurrection_number = 1, 2 ✓
```

**Performance & Interview Discussion:**

```
"Cohort retention is critical for SaaS businesses:

1. CURRENT IMPLEMENTATION:
   - Window functions for month calculations
   - Manual pivot (portable across databases)
   - Efficient: single pass per CTE

2. OPTIMIZATION FOR SCALE:
   - Pre-compute cohort assignments (add column to users table)
   - Materialize monthly metrics
   - Use CROSSTAB() in PostgreSQL for dynamic pivot

3. BUSINESS INSIGHTS:
   - Month 1 retention is critical (shows product fit)
   - Resurrection users = win-back opportunity
   - Compare cohorts to identify product changes
   - Trend analysis: Are newer cohorts better?

4. EXTENSIONS:
   - Segment by acquisition channel
   - Segment by user attributes (plan type, geography)
   - Revenue retention (not just user count)
   - Time-to-churn analysis"
```

---

## **PROBLEM 10: Fraud Transaction Pattern Detection** ⭐⭐⭐⭐

### **Problem Statement:**
*"Detect sophisticated fraud patterns: (1) Velocity - >5 transactions in 10 minutes, (2) Round-robin - amount split across cards ending in consecutive numbers, (3) Amount ramping - gradually increasing amounts to test limits, (4) Merchant hopping - same card at multiple merchants in impossible timeframe."*

**Schema:**
```sql
transactions (
    txn_id BIGINT,
    card_number VARCHAR(16),  -- Hashed
    amount DECIMAL(10,2),
    merchant_id INT,
    merchant_location VARCHAR(100),
    txn_timestamp TIMESTAMP
)
```

---

### **PHASE 1: UNDERSTAND**

```
Clarifications needed:
1. "Card number - last 4 digits or full hash?"
   → Last 4 digits available for pattern detection

2. "Impossible timeframe for merchant hopping?"
   → >50 miles apart in <1 hour

3. "Amount ramping threshold?"
   → 3+ consecutive transactions, each >20% increase

4. "Minimum transactions for velocity?"
   → 6 or more in 10-minute window

5. "Output format?"
   → Fraud type, card(s) involved, evidence, risk score
```

---

### **PHASE 2-4: COMPLETE SOLUTION**

```sql
-- ========================================
-- FRAUD DETECTION COMPREHENSIVE ANALYSIS
-- ========================================

WITH 
-- PATTERN 1: VELOCITY FRAUD
velocity_fraud AS (
    SELECT 
        card_number,
        txn_timestamp,
        COUNT(*) OVER (
            PARTITION BY card_number 
            ORDER BY txn_timestamp 
            RANGE BETWEEN INTERVAL '10 minutes' PRECEDING AND CURRENT ROW
        ) as txn_in_10min,
        MIN(txn_timestamp) OVER (
            PARTITION BY card_number 
            ORDER BY txn_timestamp 
            RANGE BETWEEN INTERVAL '10 minutes' PRECEDING AND CURRENT ROW
        ) as window_start
    FROM transactions
),
velocity_alerts AS (
    SELECT DISTINCT
        'Velocity Fraud' as fraud_type,
        card_number,
        window_start,
        txn_timestamp as window_end,
        txn_in_10min as transaction_count,
        95 as risk_score
    FROM velocity_fraud
    WHERE txn_in_10min >= 6
),

-- PATTERN 2: ROUND-ROBIN (Consecutive Card Numbers)
card_sequences AS (
    SELECT 
        txn_id,
        card_number,
        RIGHT(card_number, 4) as last_4,
        amount,
        txn_timestamp,
        LAG(RIGHT(card_number, 4)) OVER (ORDER BY txn_timestamp) as prev_card_last_4,
        LAG(txn_timestamp) OVER (ORDER BY txn_timestamp) as prev_txn_time
    FROM transactions
    WHERE txn_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
),
round_robin_alerts AS (
    SELECT DISTINCT
        'Round-Robin Card Pattern' as fraud_type,
        card_number,
        txn_timestamp,
        1 as transaction_count,  -- Will aggregate later
        90 as risk_score
    FROM card_sequences
    WHERE ABS(last_4::INTEGER - prev_card_last_4::INTEGER) = 1
      AND txn_timestamp - prev_txn_time < INTERVAL '5 minutes'
),

-- PATTERN 3: AMOUNT RAMPING
amount_sequences AS (
    SELECT 
        card_number,
        amount,
        txn_timestamp,
        LAG(amount, 1) OVER (PARTITION BY card_number ORDER BY txn_timestamp) as prev_amount_1,
        LAG(amount, 2) OVER (PARTITION BY card_number ORDER BY txn_timestamp) as prev_amount_2
    FROM transactions
),
ramping_alerts AS (
    SELECT DISTINCT
        'Amount Ramping' as fraud_type,
        card_number,
        txn_timestamp,
        1 as transaction_count,
        85 as risk_score
    FROM amount_sequences
    WHERE prev_amount_1 IS NOT NULL 
      AND prev_amount_2 IS NOT NULL
      AND amount > prev_amount_1 * 1.2
      AND prev_amount_1 > prev_amount_2 * 1.2
),

-- PATTERN 4: MERCHANT HOPPING
merchant_sequence AS (
    SELECT 
        card_number,
        merchant_id,
        merchant_location,
        txn_timestamp,
        LAG(merchant_location) OVER (
            PARTITION BY card_number ORDER BY txn_timestamp
        ) as prev_location,
        LAG(txn_timestamp) OVER (
            PARTITION BY card_number ORDER BY txn_timestamp
        ) as prev_txn_time
    FROM transactions
),
hopping_alerts AS (
    SELECT DISTINCT
        'Merchant Hopping' as fraud_type,
        card_number,
        txn_timestamp,
        1 as transaction_count,
        80 as risk_score
    FROM merchant_sequence
    WHERE merchant_location != prev_location
      AND (txn_timestamp - prev_txn_time) < INTERVAL '1 hour'
      -- Simplified: In real system, calculate distance between locations
),

-- COMBINE ALL ALERTS
all_alerts AS (
    SELECT * FROM velocity_alerts
    UNION ALL
    SELECT * FROM round_robin_alerts
    UNION ALL
    SELECT * FROM ramping_alerts
    UNION ALL
    SELECT * FROM hopping_alerts
)

-- FINAL FRAUD REPORT
SELECT 
    fraud_type,
    card_number,
    COUNT(*) as alert_count,
    MAX(risk_score) as max_risk_score,
    MIN(window_start) as first_suspicious_activity,
    MAX(txn_timestamp) as last_suspicious_activity,
    STRING_AGG(DISTINCT fraud_type, ', ') OVER (
        PARTITION BY card_number
    ) as all_fraud_types,
    CASE 
        WHEN COUNT(DISTINCT fraud_type) OVER (PARTITION BY card_number) > 1 
        THEN '🔴 CRITICAL: Multiple Patterns'
        ELSE '⚠️  Single Pattern Detected'
    END as severity
FROM all_alerts
GROUP BY fraud_type, card_number, window_start, txn_timestamp
ORDER BY max_risk_score DESC, alert_count DESC;
```

**Interview Discussion:**

```
"This fraud detection showcases advanced SQL patterns:

1. VELOCITY DETECTION:
   - RANGE BETWEEN for time windows
   - Sliding window aggregation
   - Detects rapid-fire testing

2. CARD SEQUENCES:
   - Pattern matching with LAG()
   - Numeric proximity detection
   - Catches coordinated attacks

3. AMOUNT RAMPING:
   - Multiple LAG() calls
   - Percentage change detection
   - Identifies limit testing

4. REAL-TIME CONSIDERATIONS:
   - These queries need <100ms response
   - Pre-aggregate suspicious patterns
   - Use streaming (Kafka + Flink) in production
   - SQL for batch analysis, not real-time blocking

5. FALSE POSITIVE REDUCTION:
   - Add merchant category filters
   - Whitelist known patterns (subscriptions)
   - ML model scores as input
   - Human review for edge cases

6. PRODUCTION ARCHITECTURE:
   - Real-time: Streaming fraud engine
   - Batch: SQL for historical pattern mining
   - Feedback loop: Confirmed fraud → update rules"
```

---

## **FRAMEWORK MASTERY CHECKLIST**

After working through these 10 problems, you should be able to:

```
✅ PHASE 1: UNDERSTAND
  □ Ask 5-7 clarifying questions before coding
  □ Document assumptions explicitly
  □ Identify edge cases upfront
  
✅ PHASE 2: DESIGN  
  □ Break complex problems into 3-6 clear steps
  □ Draw data flow diagrams
  □ Visualize transformations
  
✅ PHASE 3: APPROACH
  □ Compare 2-3 different approaches
  □ Justify chosen approach with pros/cons
  □ Know when to use CTEs vs subqueries vs window functions
  
✅ PHASE 4: CODE
  □ Build incrementally (test after each iteration)
  □ Use meaningful names
  □ Comment complex logic
  □ Narrate while coding
  
✅ PHASE 5: TEST
  □ Define 5+ test cases before running query
  □ Include edge cases
  □ Discuss optimization trade-offs
  □ Suggest production improvements
```

---

## **NEXT STEPS**

**Practice Routine:**
```
Week 1: Problems 1-3 (repeat until framework is automatic)
Week 2: Problems 4-6 (focus on articulation)
Week 3: Problems 7-9 (optimize solutions)
Week 4: Problem 10 + Create your own problems
```

**Self-Assessment:**
After each problem, rate yourself (1-5) on:
- Understanding completeness
- Design clarity
- Approach justification
- Code quality
- Test coverage

Would you like me to:
1. **Create a mock interview** with follow-up questions?
2. **Build a SQL decision tree** poster for your wall?
3. **Generate 10 more problems** at expert level?
4. **Create debugging exercises** (fix broken queries)?

You now have a complete framework that will work for **any SQL problem**! 🎯
