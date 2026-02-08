Excellent! Let me create a **comprehensive SQL problem types cheat sheet** that you can print and keep handy.

---

# **SQL Problem Types - Complete Cheat Sheet**

## **TABLE OF CONTENTS**

```
1. Ranking & Top-N Problems
2. Running/Cumulative Calculations  
3. Time-Series & Gap Analysis
4. Hierarchical/Tree Structures
5. Self-Referencing Problems
6. Comparison Problems (vs Average/Previous)
7. Pivot & Unpivot
8. Pattern Matching & Sequences
9. Graph/Network Problems
10. Deduplication & Data Quality
11. Statistical Aggregations
12. Complex Filtering
```

---

## **PROBLEM TYPE 1: Ranking & Top-N**

### **Trigger Words:**
```
"top N", "highest", "lowest", "rank", "best", "worst", 
"nth highest", "per group", "for each category"
```

### **Key Pattern:**
```sql
-- Template: Top N per group
WITH ranked AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY group_col ORDER BY value_col DESC) as rn
    FROM table_name
)
SELECT * FROM ranked WHERE rn <= N;
```

### **Function Choice Matrix:**

| Need | Use | Why |
|------|-----|-----|
| Unique ranks, skip on ties | `ROW_NUMBER()` | 1,2,3,4,5 |
| Unique ranks, no gaps | `DENSE_RANK()` | 1,2,2,3,4 |
| Allow ties, skip numbers | `RANK()` | 1,2,2,4,5 |
| Percentile ranking | `PERCENT_RANK()` | 0.0 to 1.0 |
| Divide into N buckets | `NTILE(N)` | Quartiles, deciles |

### **Examples:**

```sql
-- Example 1: Top 3 salaries per department
SELECT dept, name, salary
FROM (
    SELECT 
        dept, name, salary,
        DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC) as rank
    FROM employees
) ranked
WHERE rank <= 3;

-- Example 2: 2nd highest salary (handle ties)
SELECT DISTINCT salary
FROM (
    SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) as rank
    FROM employees
) ranked
WHERE rank = 2;

-- Example 3: Top 10% of earners
SELECT *
FROM (
    SELECT *, NTILE(10) OVER (ORDER BY salary DESC) as decile
    FROM employees
) bucketed
WHERE decile = 1;
```

### **Common Pitfalls:**

```sql
-- ❌ WRONG: Using LIMIT with groups
SELECT * FROM employees ORDER BY salary DESC LIMIT 3;
-- Only gives top 3 overall, not per department

-- ✓ CORRECT: Use window function
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) as rn
    FROM employees
) WHERE rn <= 3;
```

---

## **PROBLEM TYPE 2: Running/Cumulative Calculations**

### **Trigger Words:**
```
"running total", "cumulative sum", "rolling average", 
"moving average", "YTD", "MTD", "progressive"
```

### **Key Pattern:**
```sql
-- Template: Running total
SELECT 
    date,
    amount,
    SUM(amount) OVER (ORDER BY date) as running_total
FROM transactions;
```

### **Frame Clause Options:**

```sql
-- Cumulative from start
SUM(x) OVER (ORDER BY date 
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)

-- Moving average (last 7 rows)
AVG(x) OVER (ORDER BY date 
             ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)

-- Centered window (3 before, 3 after)
AVG(x) OVER (ORDER BY date 
             ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING)

-- All rows in partition
SUM(x) OVER (PARTITION BY category)  -- No ORDER BY = all rows
```

### **Examples:**

```sql
-- Example 1: Running total by month
SELECT 
    month,
    revenue,
    SUM(revenue) OVER (ORDER BY month) as ytd_revenue
FROM monthly_sales;

-- Example 2: 7-day moving average
SELECT 
    date,
    daily_sales,
    AVG(daily_sales) OVER (
        ORDER BY date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as moving_avg_7day
FROM sales;

-- Example 3: Running total per category
SELECT 
    category,
    date,
    amount,
    SUM(amount) OVER (
        PARTITION BY category 
        ORDER BY date
    ) as category_running_total
FROM transactions;

-- Example 4: Difference from previous row
SELECT 
    date,
    value,
    value - LAG(value) OVER (ORDER BY date) as change_from_previous
FROM metrics;
```

### **Quick Reference:**

| Need | Function | Frame |
|------|----------|-------|
| Running total | `SUM()` | `UNBOUNDED PRECEDING` |
| Moving average (N rows) | `AVG()` | `N-1 PRECEDING` |
| Previous value | `LAG(col, 1)` | No frame |
| Next value | `LEAD(col, 1)` | No frame |
| First in group | `FIRST_VALUE()` | `UNBOUNDED PRECEDING` |
| Last in group | `LAST_VALUE()` | `UNBOUNDED FOLLOWING` |

---

## **PROBLEM TYPE 3: Time-Series & Gap Analysis**

### **Trigger Words:**
```
"consecutive", "gaps", "missing dates", "streak", 
"continuous", "islands", "fill missing"
```

### **Key Pattern:**
```sql
-- Template: Find gaps in sequence
WITH expected AS (
    -- Generate complete sequence
    SELECT generate_series(min_val, max_val) as expected_value
),
actual AS (
    SELECT DISTINCT value FROM table_name
)
SELECT expected_value as missing_value
FROM expected
WHERE NOT EXISTS (
    SELECT 1 FROM actual WHERE actual.value = expected.expected_value
);
```

### **Common Patterns:**

```sql
-- Pattern 1: Generate date series (fill gaps)
WITH RECURSIVE date_series AS (
    SELECT DATE '2024-01-01' as date
    UNION ALL
    SELECT date + INTERVAL '1 day'
    FROM date_series
    WHERE date < DATE '2024-12-31'
)
SELECT * FROM date_series;

-- Pattern 2: Identify consecutive groups (islands)
WITH numbered AS (
    SELECT 
        value,
        date,
        ROW_NUMBER() OVER (ORDER BY date) as rn,
        date - (ROW_NUMBER() OVER (ORDER BY date) * INTERVAL '1 day') as grp
    FROM events
)
SELECT 
    MIN(date) as streak_start,
    MAX(date) as streak_end,
    COUNT(*) as streak_length
FROM numbered
GROUP BY grp
ORDER BY streak_start;

-- Pattern 3: Detect gaps
SELECT 
    date,
    LEAD(date) OVER (ORDER BY date) as next_date,
    LEAD(date) OVER (ORDER BY date) - date as gap_days
FROM events
WHERE LEAD(date) OVER (ORDER BY date) - date > 1;
```

### **Examples:**

```sql
-- Example 1: Find missing transaction IDs
WITH RECURSIVE all_ids AS (
    SELECT 1 as id
    UNION ALL
    SELECT id + 1 FROM all_ids WHERE id < 1000
)
SELECT id as missing_id
FROM all_ids
WHERE NOT EXISTS (SELECT 1 FROM transactions WHERE transaction_id = id);

-- Example 2: Consecutive login streak
WITH daily_logins AS (
    SELECT DISTINCT user_id, DATE(login_time) as login_date
    FROM user_logins
),
streaks AS (
    SELECT 
        user_id,
        login_date,
        login_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date) * INTERVAL '1 day') as streak_group
    FROM daily_logins
)
SELECT 
    user_id,
    MIN(login_date) as streak_start,
    MAX(login_date) as streak_end,
    COUNT(*) as days_in_streak
FROM streaks
GROUP BY user_id, streak_group
HAVING COUNT(*) >= 7  -- 7+ day streaks
ORDER BY days_in_streak DESC;
```

---

## **PROBLEM TYPE 4: Hierarchical/Tree Structures**

### **Trigger Words:**
```
"organizational chart", "manager-employee", "parent-child",
"category tree", "bill of materials", "recursive", "all ancestors",
"all descendants", "reporting chain"
```

### **Key Pattern:**
```sql
-- Template: Traverse hierarchy (top-down)
WITH RECURSIVE hierarchy AS (
    -- Anchor: Start at root
    SELECT id, name, parent_id, 1 as level
    FROM table_name
    WHERE parent_id IS NULL
    
    UNION ALL
    
    -- Recursive: Get children
    SELECT t.id, t.name, t.parent_id, h.level + 1
    FROM table_name t
    JOIN hierarchy h ON t.parent_id = h.id
)
SELECT * FROM hierarchy;
```

### **Direction Templates:**

```sql
-- TOP-DOWN: Root to leaves
WHERE parent_id IS NULL  -- Start
JOIN ON t.parent_id = h.id  -- Find children

-- BOTTOM-UP: Leaf to root
WHERE id = specific_leaf  -- Start
JOIN ON h.parent_id = t.id  -- Find parents

-- SIBLINGS: Same parent
SELECT t2.*
FROM table_name t1
JOIN table_name t2 ON t1.parent_id = t2.parent_id
WHERE t1.id = specific_id AND t2.id != specific_id;
```

### **Examples:**

```sql
-- Example 1: Employee reporting chain to CEO
WITH RECURSIVE chain AS (
    SELECT emp_id, name, manager_id, 0 as levels_to_ceo
    FROM employees
    WHERE emp_id = 123  -- Specific employee
    
    UNION ALL
    
    SELECT e.emp_id, e.name, e.manager_id, c.levels_to_ceo + 1
    FROM employees e
    JOIN chain c ON c.manager_id = e.emp_id
)
SELECT * FROM chain ORDER BY levels_to_ceo DESC;

-- Example 2: All subordinates (direct + indirect)
WITH RECURSIVE subordinates AS (
    SELECT emp_id, name, manager_id
    FROM employees
    WHERE emp_id = 456  -- Manager's ID
    
    UNION ALL
    
    SELECT e.emp_id, e.name, e.manager_id
    FROM employees e
    JOIN subordinates s ON e.manager_id = s.emp_id
)
SELECT * FROM subordinates WHERE emp_id != 456;

-- Example 3: Category path
WITH RECURSIVE category_path AS (
    SELECT 
        category_id, 
        category_name, 
        parent_id,
        category_name as path
    FROM categories
    WHERE parent_id IS NULL
    
    UNION ALL
    
    SELECT 
        c.category_id, 
        c.category_name, 
        c.parent_id,
        cp.path || ' > ' || c.category_name
    FROM categories c
    JOIN category_path cp ON c.parent_id = cp.category_id
)
SELECT * FROM category_path;
```

### **Cycle Detection:**

```sql
-- Always add cycle protection!
WITH RECURSIVE hierarchy AS (
    SELECT id, parent_id, ARRAY[id] as path
    FROM table_name
    WHERE parent_id IS NULL
    
    UNION ALL
    
    SELECT t.id, t.parent_id, h.path || t.id
    FROM table_name t
    JOIN hierarchy h ON t.parent_id = h.id
    WHERE NOT (t.id = ANY(h.path))  -- Prevent cycles
      AND ARRAY_LENGTH(h.path, 1) < 100  -- Depth limit
)
SELECT * FROM hierarchy;
```

---

## **PROBLEM TYPE 5: Self-Referencing Problems**

### **Trigger Words:**
```
"compare to previous", "lag/lead", "pairs", 
"same table twice", "cartesian product with condition"
```

### **Key Patterns:**

```sql
-- Pattern 1: Self-join for comparisons
SELECT a.id, b.id
FROM table_name a
JOIN table_name b ON a.some_col = b.some_col AND a.id != b.id;

-- Pattern 2: Window function (avoid self-join)
SELECT 
    id,
    value,
    LAG(value) OVER (ORDER BY date) as previous_value
FROM table_name;
```

### **Examples:**

```sql
-- Example 1: Employees earning more than their manager
SELECT e.name as employee, e.salary, m.name as manager, m.salary
FROM employees e
JOIN employees m ON e.manager_id = m.emp_id
WHERE e.salary > m.salary;

-- Example 2: Find duplicate records
SELECT a.*
FROM records a
JOIN records b ON a.email = b.email AND a.id < b.id;
-- a.id < b.id prevents double counting

-- Example 3: Customers who bought same product multiple times
SELECT c1.customer_id, c1.product_id, COUNT(*) as times_purchased
FROM purchases c1
JOIN purchases c2 ON c1.customer_id = c2.customer_id 
                  AND c1.product_id = c2.product_id
                  AND c1.purchase_id != c2.purchase_id
GROUP BY c1.customer_id, c1.product_id;

-- Example 4: Month-over-month change (window function - better)
SELECT 
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) as prev_month_revenue,
    revenue - LAG(revenue) OVER (ORDER BY month) as mom_change,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) / 
          LAG(revenue) OVER (ORDER BY month) * 100, 2) as mom_change_pct
FROM monthly_revenue;
```

### **When to Use Each:**

| Scenario | Approach | Why |
|----------|----------|-----|
| Compare to previous/next row | Window function (LAG/LEAD) | More efficient |
| Find duplicates | Self-join with id < id | Classic pattern |
| All pairs comparison | Self-join with id != id | Need all combinations |
| Running comparisons | Window function | Single pass |

---

## **PROBLEM TYPE 6: Comparison Problems**

### **Trigger Words:**
```
"above average", "below median", "compared to group",
"deviation from", "outliers", "percentile"
```

### **Key Pattern:**
```sql
-- Template: Compare to group aggregate
SELECT *
FROM table_name t
JOIN (
    SELECT group_col, AVG(value) as avg_value
    FROM table_name
    GROUP BY group_col
) agg ON t.group_col = agg.group_col
WHERE t.value > agg.avg_value;
```

### **Window Function Alternative (Better):**

```sql
-- Better: Use window function (single pass)
SELECT *
FROM (
    SELECT 
        *,
        AVG(value) OVER (PARTITION BY group_col) as group_avg
    FROM table_name
) t
WHERE value > group_avg;
```

### **Examples:**

```sql
-- Example 1: Students scoring above class average
SELECT 
    student_name,
    score,
    class_avg,
    score - class_avg as points_above_avg
FROM (
    SELECT 
        student_name,
        score,
        AVG(score) OVER (PARTITION BY class) as class_avg
    FROM test_scores
) t
WHERE score > class_avg;

-- Example 2: Products with price > 2 standard deviations from mean
SELECT 
    product_name,
    price,
    avg_price,
    stddev_price,
    (price - avg_price) / stddev_price as z_score
FROM (
    SELECT 
        product_name,
        price,
        AVG(price) OVER () as avg_price,
        STDDEV(price) OVER () as stddev_price
    FROM products
) t
WHERE ABS((price - avg_price) / stddev_price) > 2;

-- Example 3: Sales above monthly median
SELECT 
    date,
    sales_amount,
    monthly_median
FROM (
    SELECT 
        date,
        sales_amount,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sales_amount) 
            OVER (PARTITION BY DATE_TRUNC('month', date)) as monthly_median
    FROM daily_sales
) t
WHERE sales_amount > monthly_median;
```

---

## **PROBLEM TYPE 7: Pivot & Unpivot**

### **Trigger Words:**
```
"rows to columns", "columns to rows", "crosstab",
"transpose", "wide to long", "long to wide"
```

### **Key Patterns:**

```sql
-- Pattern 1: Pivot (rows to columns)
SELECT 
    row_identifier,
    SUM(CASE WHEN column_value = 'A' THEN amount ELSE 0 END) as A,
    SUM(CASE WHEN column_value = 'B' THEN amount ELSE 0 END) as B,
    SUM(CASE WHEN column_value = 'C' THEN amount ELSE 0 END) as C
FROM table_name
GROUP BY row_identifier;

-- Pattern 2: Unpivot (columns to rows)
SELECT row_id, 'col1' as metric, col1 as value FROM table_name
UNION ALL
SELECT row_id, 'col2' as metric, col2 as value FROM table_name
UNION ALL
SELECT row_id, 'col3' as metric, col3 as value FROM table_name;
```

### **Examples:**

```sql
-- Example 1: Sales by product (rows) and month (columns)
SELECT 
    product_name,
    SUM(CASE WHEN month = 1 THEN sales ELSE 0 END) as Jan,
    SUM(CASE WHEN month = 2 THEN sales ELSE 0 END) as Feb,
    SUM(CASE WHEN month = 3 THEN sales ELSE 0 END) as Mar
FROM monthly_sales
GROUP BY product_name;

-- Example 2: Unpivot quarterly results
SELECT employee_id, 'Q1' as quarter, Q1_sales as sales FROM quarterly_data
UNION ALL
SELECT employee_id, 'Q2' as quarter, Q2_sales as sales FROM quarterly_data
UNION ALL
SELECT employee_id, 'Q3' as quarter, Q3_sales as sales FROM quarterly_data
UNION ALL
SELECT employee_id, 'Q4' as quarter, Q4_sales as sales FROM quarterly_data;

-- Example 3: Dynamic pivot (PostgreSQL crosstab)
SELECT * FROM crosstab(
    'SELECT region, quarter, revenue FROM sales ORDER BY 1,2',
    'SELECT DISTINCT quarter FROM sales ORDER BY 1'
) AS ct(region text, Q1 numeric, Q2 numeric, Q3 numeric, Q4 numeric);
```

---

## **PROBLEM TYPE 8: Pattern Matching & Sequences**

### **Trigger Words:**
```
"sequence", "pattern", "in order", "followed by",
"specific sequence", "state transition"
```

### **Key Pattern:**
```sql
-- Template: Find sequence A → B → C
WITH sequence_check AS (
    SELECT 
        user_id,
        event_type,
        timestamp,
        LEAD(event_type, 1) OVER (PARTITION BY user_id ORDER BY timestamp) as next_1,
        LEAD(event_type, 2) OVER (PARTITION BY user_id ORDER BY timestamp) as next_2
    FROM events
)
SELECT DISTINCT user_id
FROM sequence_check
WHERE event_type = 'A' AND next_1 = 'B' AND next_2 = 'C';
```

### **Examples:**

```sql
-- Example 1: Users who viewed product, added to cart, then purchased
WITH user_journey AS (
    SELECT 
        user_id,
        event_type,
        product_id,
        timestamp,
        LEAD(event_type, 1) OVER (PARTITION BY user_id, product_id ORDER BY timestamp) as next_event,
        LEAD(event_type, 2) OVER (PARTITION BY user_id, product_id ORDER BY timestamp) as event_after_next
    FROM user_events
)
SELECT DISTINCT user_id, product_id
FROM user_journey
WHERE event_type = 'view' 
  AND next_event = 'add_to_cart'
  AND event_after_next = 'purchase';

-- Example 2: Stock went up 3 days in a row
WITH price_changes AS (
    SELECT 
        date,
        close_price,
        LAG(close_price, 1) OVER (ORDER BY date) as prev_1,
        LAG(close_price, 2) OVER (ORDER BY date) as prev_2
    FROM stock_prices
)
SELECT date
FROM price_changes
WHERE close_price > prev_1 
  AND prev_1 > prev_2;

-- Example 3: Find 3+ consecutive failed login attempts
WITH login_attempts AS (
    SELECT 
        user_id,
        timestamp,
        success,
        SUM(CASE WHEN success = false THEN 1 ELSE 0 END) OVER (
            PARTITION BY user_id 
            ORDER BY timestamp 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) as failures_in_window
    FROM login_log
)
SELECT DISTINCT user_id
FROM login_attempts
WHERE failures_in_window >= 3;
```

---

## **PROBLEM TYPE 9: Graph/Network Problems**

### **Trigger Words:**
```
"connected", "path between", "shortest route", 
"network", "relationships", "friends of friends"
```

### **Key Pattern:**
```sql
-- Template: Find connections (BFS/DFS)
WITH RECURSIVE connections AS (
    -- Start node
    SELECT node_id, 0 as distance, ARRAY[node_id] as path
    FROM nodes
    WHERE node_id = start_node
    
    UNION
    
    -- Traverse edges
    SELECT 
        e.to_node,
        c.distance + 1,
        c.path || e.to_node
    FROM connections c
    JOIN edges e ON c.node_id = e.from_node
    WHERE NOT (e.to_node = ANY(c.path))  -- Avoid cycles
      AND c.distance < max_distance
)
SELECT * FROM connections;
```

### **Examples:**

```sql
-- Example 1: Shortest path in social network
WITH RECURSIVE friend_path AS (
    SELECT 
        user_id,
        friend_id,
        1 as degree,
        ARRAY[user_id, friend_id] as path
    FROM friendships
    WHERE user_id = 123  -- Start user
    
    UNION
    
    SELECT 
        fp.user_id,
        f.friend_id,
        fp.degree + 1,
        fp.path || f.friend_id
    FROM friend_path fp
    JOIN friendships f ON fp.friend_id = f.user_id
    WHERE NOT (f.friend_id = ANY(fp.path))
      AND fp.degree < 6  -- 6 degrees of separation
)
SELECT * 
FROM friend_path
WHERE friend_id = 456  -- Target user
ORDER BY degree
LIMIT 1;

-- Example 2: Find all reachable nodes
WITH RECURSIVE reachable AS (
    SELECT node_id, 1 as is_reachable
    FROM nodes
    WHERE node_id = 1
    
    UNION
    
    SELECT e.to_node, 1
    FROM edges e
    JOIN reachable r ON e.from_node = r.node_id
)
SELECT node_id FROM reachable;
```

---

## **PROBLEM TYPE 10: Deduplication & Data Quality**

### **Trigger Words:**
```
"duplicates", "unique", "distinct", "remove duplicates",
"keep first/last", "consolidate"
```

### **Key Patterns:**

```sql
-- Pattern 1: Keep first occurrence
SELECT DISTINCT ON (key_column) *
FROM table_name
ORDER BY key_column, timestamp;  -- PostgreSQL

-- Pattern 2: Window function approach (works everywhere)
SELECT *
FROM (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY key_col ORDER BY timestamp) as rn
    FROM table_name
) t
WHERE rn = 1;

-- Pattern 3: Group by all columns
SELECT col1, col2, col3, COUNT(*)
FROM table_name
GROUP BY col1, col2, col3
HAVING COUNT(*) > 1;  -- Find duplicates
```

### **Examples:**

```sql
-- Example 1: Remove duplicate emails, keep most recent
SELECT *
FROM (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_date DESC) as rn
    FROM users
) t
WHERE rn = 1;

-- Example 2: Find all duplicate records
SELECT 
    email,
    COUNT(*) as duplicate_count,
    STRING_AGG(user_id::TEXT, ', ') as user_ids
FROM users
GROUP BY email
HAVING COUNT(*) > 1;

-- Example 3: Merge duplicate records (keep newest data)
WITH ranked AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC) as rn
    FROM customer_records
)
SELECT 
    customer_id,
    MAX(name) as name,  -- Take non-null values
    MAX(email) as email,
    MAX(phone) as phone
FROM ranked
GROUP BY customer_id;
```

---

## **PROBLEM TYPE 11: Statistical Aggregations**

### **Trigger Words:**
```
"median", "percentile", "standard deviation", "variance",
"distribution", "quartiles", "outliers"
```

### **Key Functions:**

```sql
-- Common statistical functions
AVG(column)                      -- Mean
STDDEV(column)                   -- Standard deviation
VARIANCE(column)                 -- Variance
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY column)  -- Median
MODE() WITHIN GROUP (ORDER BY column)                -- Mode

-- Percentiles
PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY col) -- Q1
PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY col) -- Q2 (median)
PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY col) -- Q3
```

### **Examples:**

```sql
-- Example 1: Complete statistical summary
SELECT 
    department,
    COUNT(*) as count,
    AVG(salary) as mean_salary,
    STDDEV(salary) as stddev_salary,
    MIN(salary) as min_salary,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary) as q1,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY salary) as median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) as q3,
    MAX(salary) as max_salary
FROM employees
GROUP BY department;

-- Example 2: Identify outliers (IQR method)
WITH stats AS (
    SELECT 
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary) as q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) as q3
    FROM employees
),
bounds AS (
    SELECT 
        q1 - 1.5 * (q3 - q1) as lower_bound,
        q3 + 1.5 * (q3 - q1) as upper_bound
    FROM stats
)
SELECT *
FROM employees, bounds
WHERE salary < lower_bound OR salary > upper_bound;

-- Example 3: Z-score calculation
SELECT 
    name,
    salary,
    (salary - avg_salary) / stddev_salary as z_score
FROM employees,
LATERAL (
    SELECT AVG(salary) as avg_salary, STDDEV(salary) as stddev_salary
    FROM employees
) stats
WHERE ABS((salary - avg_salary) / stddev_salary) > 2;
```

---

## **PROBLEM TYPE 12: Complex Filtering**

### **Trigger Words:**
```
"exclude", "not in", "except", "without", 
"all except", "everything but", "anti-join"
```

### **Key Patterns:**

```sql
-- Pattern 1: NOT EXISTS (best performance)
SELECT *
FROM table_a a
WHERE NOT EXISTS (
    SELECT 1 FROM table_b b WHERE b.id = a.id
);

-- Pattern 2: LEFT JOIN with NULL check
SELECT a.*
FROM table_a a
LEFT JOIN table_b b ON a.id = b.id
WHERE b.id IS NULL;

-- Pattern 3: NOT IN (be careful with NULLs!)
SELECT *
FROM table_a
WHERE id NOT IN (SELECT id FROM table_b WHERE id IS NOT NULL);

-- Pattern 4: EXCEPT (set difference)
SELECT id FROM table_a
EXCEPT
SELECT id FROM table_b;
```

### **Examples:**

```sql
-- Example 1: Customers who never purchased
SELECT c.*
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
);

-- Example 2: Products not ordered in last 30 days
SELECT p.*
FROM products p
LEFT JOIN orders o ON p.product_id = o.product_id 
                   AND o.order_date >= CURRENT_DATE - INTERVAL '30 days'
WHERE o.product_id IS NULL;

-- Example 3: Students who took class A but not class B
SELECT student_id
FROM enrollments
WHERE class_id = 'A'
  AND student_id NOT IN (
      SELECT student_id 
      FROM enrollments 
      WHERE class_id = 'B'
  );

-- Example 4: Find gaps in coverage
SELECT 
    employee_id,
    date + INTERVAL '1 day' as gap_start,
    LEAD(date) OVER (PARTITION BY employee_id ORDER BY date) - INTERVAL '1 day' as gap_end
FROM shifts
WHERE LEAD(date) OVER (PARTITION BY employee_id ORDER BY date) - date > 1;
```

---

## **QUICK DECISION TREE**

```
┌──────────────────────────────────────────────────────────┐
│ WHICH SQL PATTERN DO I NEED?                            │
├──────────────────────────────────────────────────────────┤
│                                                          │
│ Need top/bottom N?                                       │
│ └→ ROW_NUMBER() / RANK() / DENSE_RANK()                 │
│                                                          │
│ Compare to previous/next row?                            │
│ └→ LAG() / LEAD()                                        │
│                                                          │
│ Running total or moving average?                         │
│ └→ SUM/AVG() OVER (ORDER BY ... ROWS BETWEEN)           │
│                                                          │
│ Compare to group aggregate?                              │
│ └→ Window function with PARTITION BY                    │
│                                                          │
│ Find missing values in sequence?                         │
│ └→ Recursive CTE to generate series + LEFT JOIN         │
│                                                          │
│ Traverse hierarchy or graph?                             │
│ └→ Recursive CTE                                         │
│                                                          │
│ Need to pivot (rows to columns)?                         │
│ └→ CASE WHEN with GROUP BY                              │
│                                                          │
│ Find duplicates?                                         │
│ └→ GROUP BY ... HAVING COUNT(*) > 1                     │
│                                                          │
│ Remove duplicates?                                       │
│ └→ ROW_NUMBER() ... WHERE rn = 1                        │
│                                                          │
│ Find records NOT in another table?                       │
│ └→ NOT EXISTS or LEFT JOIN ... WHERE NULL               │
│                                                          │
│ Statistical analysis?                                    │
│ └→ PERCENTILE_CONT, STDDEV, VARIANCE                    │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## **PERFORMANCE OPTIMIZATION CHEAT SHEET**

```sql
┌─────────────────────────────────────────────────────────────┐
│ OPTIMIZATION RULES                                          │
├─────────────────────────────────────────────────────────────┤
│ 1. Filter early (WHERE before JOIN when possible)          │
│ 2. Use EXISTS instead of COUNT(*) > 0                       │
│ 3. Use window functions instead of self-joins               │
│ 4. Index columns in WHERE, JOIN, ORDER BY                   │
│ 5. Avoid SELECT * (specify needed columns)                  │
│ 6. Use UNION ALL instead of UNION (if duplicates OK)        │
│ 7. Use CTEs for readability, but consider materialization   │
│ 8. Be cautious with NOT IN (can be slow with NULLs)         │
│ 9. Use LIMIT when testing (don't scan entire table)         │
│ 10. Partition large tables by commonly filtered columns     │
└─────────────────────────────────────────────────────────────┘
```

---

## **COMMON GOTCHAS & SOLUTIONS**

```sql
┌───────────────────────────────────────────────────────────────┐
│ GOTCHA                          │ SOLUTION                    │
├───────────────────────────────────────────────────────────────┤
│ NULLs in NOT IN                 │ Add WHERE col IS NOT NULL   │
│ Division by zero                │ Use NULLIF(denominator, 0)  │
│ String concatenation with NULL  │ Use COALESCE(col, '')       │
│ Date arithmetic across timezones│ Normalize to UTC first      │
│ GROUP BY with NULL keys         │ NULLs form their own group  │
│ Aggregate in WHERE clause       │ Use HAVING instead          │
│ Window function in WHERE        │ Use subquery or CTE         │
│ Self-join Cartesian explosion   │ Add proper join condition   │
│ Recursive CTE infinite loop     │ Add depth limit             │
│ VARCHAR comparison case-sensitive│ Use LOWER() or ILIKE        │
└───────────────────────────────────────────────────────────────┘
```

---

## **SYNTAX QUICK REFERENCE**

### **Window Function Syntax:**
```sql
function_name([arguments]) OVER (
    [PARTITION BY partition_columns]
    [ORDER BY sort_columns]
    [ROWS|RANGE BETWEEN frame_start AND frame_end]
)
```

### **CTE Syntax:**
```sql
WITH cte_name AS (
    SELECT ...
),
cte_name2 AS (
    SELECT ... FROM cte_name ...
)
SELECT ... FROM cte_name2;
```

### **Recursive CTE Syntax:**
```sql
WITH RECURSIVE cte_name AS (
    -- Anchor (base case)
    SELECT ...
    
    UNION [ALL]
    
    -- Recursive (iterative case)
    SELECT ...
    FROM cte_name
    WHERE termination_condition
)
SELECT ... FROM cte_name;
```

---

## **PRINTABLE QUICK REFERENCE CARD**

```
╔════════════════════════════════════════════════════════════╗
║              SQL PROBLEM TYPES QUICK REF                   ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║ TOP N PER GROUP         → ROW_NUMBER() PARTITION BY        ║
║ RUNNING TOTAL           → SUM() OVER (ORDER BY)            ║
║ PREVIOUS/NEXT VALUE     → LAG() / LEAD()                   ║
║ COMPARE TO GROUP AVG    → AVG() OVER (PARTITION BY)        ║
║ FIND GAPS               → Recursive CTE + generate_series  ║
║ HIERARCHY TRAVERSAL     → Recursive CTE                    ║
║ DUPLICATES              → GROUP BY HAVING COUNT(*) > 1     ║
║ REMOVE DUPLICATES       → ROW_NUMBER() WHERE rn = 1        ║
║ PIVOT                   → CASE WHEN + GROUP BY             ║
║ ANTI-JOIN               → NOT EXISTS or LEFT JOIN + NULL   ║
║ MEDIAN                  → PERCENTILE_CONT(0.5)             ║
║ PERCENTILE              → PERCENTILE_CONT(p)               ║
║                                                            ║
║ PERFORMANCE TIPS:                                          ║
║ • Filter early (WHERE before JOIN)                         ║
║ • Index JOIN/WHERE columns                                 ║
║ • Window function > Self-join                              ║
║ • EXISTS > COUNT(*) > 0                                    ║
║ • UNION ALL > UNION                                        ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
```

---

## **INTERVIEW PATTERN RECOGNITION**

When you see this phrase → Think this pattern:

| Interview Phrase | SQL Pattern |
|-----------------|-------------|
| "for each group" | PARTITION BY |
| "top 3" | ROW_NUMBER() WHERE rn <= 3 |
| "compared to average" | Window function with AVG() OVER |
| "consecutive" | Recursive CTE or ROW_NUMBER() trick |
| "running total" | SUM() OVER (ORDER BY) |
| "hierarchy" / "reporting chain" | Recursive CTE |
| "without duplicates" | DISTINCT or ROW_NUMBER() |
| "changed from previous" | LAG() or LEAD() |
| "in every category" | GROUP BY HAVING COUNT(DISTINCT) = total |
| "never did X" | NOT EXISTS or LEFT JOIN NULL |

---

**Print this cheat sheet and keep it visible during practice!**

Would you like me to:
1. **Create problem examples** for each pattern type?
2. **Build a flowchart** for pattern selection?
3. **Make a condensed 1-page version** for quick reference?
4. **Add database-specific syntax differences** (MySQL vs PostgreSQL vs SQL Server)?

This cheat sheet covers 95% of SQL interview problems! 🎯
