# SQL Developer — Interview Preparation Guide

**Payroll Globant | Client: Google**
**Prepared for Sanath — April 2026**

*Comprehensive coverage of SQL concepts, query patterns, and hands-on scenarios*

---

## 1. SQL Fundamentals & Data Definition Language (DDL)

DDL commands define and modify database structure. These are auto-committed in most RDBMS.

### 1.1 CREATE TABLE

```sql
CREATE TABLE employees (
    employee_id   INT PRIMARY KEY,
    first_name    VARCHAR(50) NOT NULL,
    last_name     VARCHAR(50) NOT NULL,
    department_id INT,
    salary        DECIMAL(12,2) DEFAULT 0.00,
    hire_date     DATE NOT NULL,
    is_active     BIT DEFAULT 1,
    CONSTRAINT fk_dept FOREIGN KEY (department_id)
        REFERENCES departments(department_id)
);
```

### 1.2 ALTER TABLE

```sql
-- Add a column
ALTER TABLE employees ADD email VARCHAR(100);

-- Modify a column
ALTER TABLE employees ALTER COLUMN salary DECIMAL(15,2);

-- Add a constraint
ALTER TABLE employees ADD CONSTRAINT uq_email UNIQUE (email);

-- Drop a column
ALTER TABLE employees DROP COLUMN is_active;
```

### 1.3 DROP & TRUNCATE

```sql
DROP TABLE IF EXISTS temp_data;    -- Removes table + data permanently
TRUNCATE TABLE staging_data;       -- Removes all rows, keeps structure
```

> **Interview Tip:** Explain the difference: DROP removes structure + data, TRUNCATE removes data but keeps structure (faster, no row-level logging), DELETE removes data row-by-row with full logging and WHERE support.

---

## 2. Data Manipulation Language (DML)

### 2.1 INSERT

```sql
-- Single row insert
INSERT INTO employees (employee_id, first_name, last_name, department_id, salary, hire_date)
VALUES (101, 'Sanath', 'Kumar', 10, 95000.00, '2024-01-15');

-- Multi-row insert
INSERT INTO employees (employee_id, first_name, last_name, department_id, salary, hire_date)
VALUES
  (102, 'Priya', 'Sharma', 20, 88000.00, '2024-02-01'),
  (103, 'Ravi', 'Patel', 10, 92000.00, '2024-03-10');

-- Insert from SELECT (ETL pattern)
INSERT INTO payroll_archive (employee_id, pay_period, gross_pay)
SELECT employee_id, pay_period, gross_pay
FROM payroll_current
WHERE pay_period < '2024-01-01';
```

### 2.2 UPDATE

```sql
-- Simple update
UPDATE employees SET salary = salary * 1.10 WHERE department_id = 10;

-- Update with JOIN (T-SQL syntax)
UPDATE e
SET e.department_id = d.new_department_id
FROM employees e
INNER JOIN department_transfers d ON e.employee_id = d.employee_id
WHERE d.transfer_date = CAST(GETDATE() AS DATE);
```

### 2.3 DELETE

```sql
-- Conditional delete
DELETE FROM payroll_current WHERE pay_period < '2023-01-01';

-- Delete with subquery
DELETE FROM employees
WHERE employee_id NOT IN (
    SELECT DISTINCT employee_id FROM payroll_current
);
```

> **Interview Tip:** Google-scale systems deal with billions of rows. Always mention WHERE clauses, batch processing, and transaction safety when discussing DML at scale.

---

## 3. Joins — Complete Reference

Joins are the backbone of relational queries. Understanding when and why to use each type is critical for this role.

| Join Type | Description | Use Case |
|-----------|-------------|----------|
| INNER JOIN | Returns only matching rows from both tables | Get employees with assigned departments |
| LEFT JOIN | All rows from left + matching from right (NULLs for non-matches) | Find employees even without departments |
| RIGHT JOIN | All rows from right + matching from left | Rarely used; restructure as LEFT JOIN |
| FULL OUTER JOIN | All rows from both; NULLs where no match | Data reconciliation between two systems |
| CROSS JOIN | Cartesian product of both tables | Generate all combinations (e.g., date × department) |
| SELF JOIN | Table joined to itself | Find employee-manager hierarchies |

### 3.1 INNER JOIN

```sql
SELECT e.employee_id, e.first_name, d.department_name, e.salary
FROM employees e
INNER JOIN departments d ON e.department_id = d.department_id
WHERE e.is_active = 1;
```

### 3.2 LEFT JOIN — Finding Unmatched Records

```sql
-- Employees with no payroll record (data quality check)
SELECT e.employee_id, e.first_name, e.last_name
FROM employees e
LEFT JOIN payroll p ON e.employee_id = p.employee_id
WHERE p.employee_id IS NULL;
```

> **Interview Tip:** LEFT JOIN + IS NULL is a classic pattern to find orphan records. In payroll systems, this detects employees missing pay records — a critical data integrity check.

### 3.3 FULL OUTER JOIN — Data Reconciliation

```sql
-- Reconcile HR system vs Payroll system
SELECT
    COALESCE(hr.employee_id, pay.employee_id) AS employee_id,
    hr.full_name AS hr_name,
    pay.full_name AS payroll_name,
    CASE
        WHEN hr.employee_id IS NULL THEN 'Missing in HR'
        WHEN pay.employee_id IS NULL THEN 'Missing in Payroll'
        ELSE 'In Both'
    END AS reconciliation_status
FROM hr_employees hr
FULL OUTER JOIN payroll_employees pay
    ON hr.employee_id = pay.employee_id
WHERE hr.employee_id IS NULL OR pay.employee_id IS NULL;
```

### 3.4 SELF JOIN — Employee-Manager Hierarchy

```sql
SELECT
    e.employee_id,
    e.first_name AS employee_name,
    m.first_name AS manager_name
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.employee_id;
```

### 3.5 Multi-Table Join (Payroll Scenario)

```sql
SELECT
    e.employee_id,
    e.first_name + ' ' + e.last_name AS full_name,
    d.department_name,
    p.gross_pay,
    p.deductions,
    p.net_pay,
    p.pay_period
FROM employees e
INNER JOIN departments d ON e.department_id = d.department_id
INNER JOIN payroll p ON e.employee_id = p.employee_id
INNER JOIN tax_brackets t ON p.gross_pay BETWEEN t.min_income AND t.max_income
WHERE p.pay_period = '2025-03';
```

---

## 4. Subqueries & Common Table Expressions (CTEs)

### 4.1 Types of Subqueries

**Scalar Subquery (returns single value)**

```sql
SELECT employee_id, first_name, salary,
    (SELECT AVG(salary) FROM employees) AS company_avg_salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees);
```

**Correlated Subquery (references outer query)**

```sql
-- Employees earning above their department average
SELECT e.employee_id, e.first_name, e.salary, e.department_id
FROM employees e
WHERE e.salary > (
    SELECT AVG(e2.salary)
    FROM employees e2
    WHERE e2.department_id = e.department_id
);
```

**EXISTS Subquery**

```sql
-- Departments that have at least one employee earning > 100K
SELECT d.department_name
FROM departments d
WHERE EXISTS (
    SELECT 1 FROM employees e
    WHERE e.department_id = d.department_id
    AND e.salary > 100000
);
```

> **Interview Tip:** EXISTS is often faster than IN for large datasets because it short-circuits — it stops scanning once a match is found.

### 4.2 Common Table Expressions (CTEs)

CTEs improve readability and allow recursive queries. They are defined using WITH and exist only for the duration of the query.

**Basic CTE**

```sql
WITH department_costs AS (
    SELECT
        department_id,
        SUM(salary) AS total_salary,
        COUNT(*) AS headcount,
        AVG(salary) AS avg_salary
    FROM employees
    WHERE is_active = 1
    GROUP BY department_id
)
SELECT
    d.department_name,
    dc.total_salary,
    dc.headcount,
    dc.avg_salary
FROM department_costs dc
INNER JOIN departments d ON dc.department_id = d.department_id
ORDER BY dc.total_salary DESC;
```

**Multiple CTEs — Chained Analysis**

```sql
WITH monthly_payroll AS (
    SELECT employee_id, pay_period,
        SUM(gross_pay) AS monthly_gross
    FROM payroll
    GROUP BY employee_id, pay_period
),
payroll_stats AS (
    SELECT employee_id,
        AVG(monthly_gross) AS avg_monthly,
        MAX(monthly_gross) AS max_monthly,
        MIN(monthly_gross) AS min_monthly
    FROM monthly_payroll
    GROUP BY employee_id
)
SELECT e.first_name, e.last_name,
    ps.avg_monthly, ps.max_monthly, ps.min_monthly
FROM payroll_stats ps
INNER JOIN employees e ON ps.employee_id = e.employee_id
WHERE ps.max_monthly > ps.avg_monthly * 1.5;
```

**Recursive CTE — Org Hierarchy**

```sql
WITH RECURSIVE org_tree AS (
    -- Anchor: top-level managers
    SELECT employee_id, first_name, manager_id, 1 AS level
    FROM employees WHERE manager_id IS NULL

    UNION ALL

    -- Recursive: employees under each manager
    SELECT e.employee_id, e.first_name, e.manager_id, ot.level + 1
    FROM employees e
    INNER JOIN org_tree ot ON e.manager_id = ot.employee_id
)
SELECT * FROM org_tree ORDER BY level, first_name;
```

> **Interview Tip:** Recursive CTEs are heavily tested at Google. They are used for org hierarchies, BOM (Bill of Materials), and graph traversals. Always mention the anchor member + recursive member + UNION ALL pattern.

---

## 5. Aggregate Functions & GROUP BY

### 5.1 Core Aggregate Functions

| Function | Description | Example |
|----------|-------------|---------|
| COUNT(*) | Count all rows including NULLs | COUNT(*) returns total rows |
| COUNT(column) | Count non-NULL values | COUNT(email) skips NULLs |
| SUM(column) | Sum of all values | SUM(gross_pay) |
| AVG(column) | Average of non-NULL values | AVG(salary) |
| MIN(column) | Minimum value | MIN(hire_date) |
| MAX(column) | Maximum value | MAX(salary) |
| COUNT(DISTINCT col) | Count unique non-NULL values | COUNT(DISTINCT department_id) |

### 5.2 GROUP BY with HAVING

```sql
-- Departments where total payroll exceeds 500K
SELECT
    d.department_name,
    COUNT(e.employee_id) AS headcount,
    SUM(e.salary) AS total_salary,
    AVG(e.salary) AS avg_salary,
    MAX(e.salary) AS max_salary
FROM employees e
INNER JOIN departments d ON e.department_id = d.department_id
WHERE e.is_active = 1
GROUP BY d.department_name
HAVING SUM(e.salary) > 500000
ORDER BY total_salary DESC;
```

> **Interview Tip:** WHERE filters rows BEFORE grouping, HAVING filters groups AFTER aggregation. This is one of the most common interview questions.

### 5.3 Payroll Analytics Example

```sql
-- Monthly payroll summary with year-over-year comparison
SELECT
    YEAR(pay_date) AS pay_year,
    MONTH(pay_date) AS pay_month,
    COUNT(DISTINCT employee_id) AS employees_paid,
    SUM(gross_pay) AS total_gross,
    SUM(deductions) AS total_deductions,
    SUM(net_pay) AS total_net,
    AVG(net_pay) AS avg_net_pay
FROM payroll
GROUP BY YEAR(pay_date), MONTH(pay_date)
ORDER BY pay_year, pay_month;
```

---

## 6. Window Functions — Advanced Analytics

Window functions perform calculations across a set of rows related to the current row WITHOUT collapsing them into groups. This is the most heavily tested topic for SQL Developer roles.

### 6.1 Syntax

```sql
function_name(expression)
    OVER (
        [PARTITION BY column(s)]
        [ORDER BY column(s)]
        [ROWS/RANGE BETWEEN ... AND ...]
    )
```

### 6.2 Ranking Functions

| Function | Behavior | Example: Salaries 100K, 100K, 90K |
|----------|----------|-----------------------------------|
| ROW_NUMBER() | Unique sequential number, no ties | 1, 2, 3 |
| RANK() | Same rank for ties, gaps after ties | 1, 1, 3 |
| DENSE_RANK() | Same rank for ties, no gaps | 1, 1, 2 |
| NTILE(n) | Divides rows into n buckets | NTILE(4) creates quartiles |

**ROW_NUMBER — Rank Employees by Salary within Department**

```sql
SELECT
    employee_id,
    first_name,
    department_id,
    salary,
    ROW_NUMBER() OVER (
        PARTITION BY department_id
        ORDER BY salary DESC
    ) AS salary_rank
FROM employees;
```

**RANK vs DENSE_RANK**

```sql
SELECT
    employee_id,
    salary,
    RANK()       OVER (ORDER BY salary DESC) AS rank_val,
    DENSE_RANK() OVER (ORDER BY salary DESC) AS dense_rank_val,
    ROW_NUMBER() OVER (ORDER BY salary DESC) AS row_num
FROM employees;

-- Result for salaries: 120K, 120K, 100K, 90K
-- rank_val:       1, 1, 3, 4
-- dense_rank_val: 1, 1, 2, 3
-- row_num:        1, 2, 3, 4
```

### 6.3 Duplicate Detection & Removal

This is a critical skill for payroll data — duplicate records can cause double payments.

```sql
-- Step 1: Identify duplicates
WITH duplicates AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY employee_id, pay_period, gross_pay
            ORDER BY created_date DESC  -- Keep the most recent
        ) AS rn
    FROM payroll
)
SELECT * FROM duplicates WHERE rn > 1;

-- Step 2: Delete duplicates (keep rn = 1)
WITH duplicates AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY employee_id, pay_period, gross_pay
            ORDER BY created_date DESC
        ) AS rn
    FROM payroll
)
DELETE FROM duplicates WHERE rn > 1;
```

> **Interview Tip:** This ROW_NUMBER + CTE deletion pattern is one of the most asked questions. Be ready to write it from memory and explain each part.

### 6.4 Aggregate Window Functions

```sql
SELECT
    employee_id,
    department_id,
    salary,
    SUM(salary)   OVER (PARTITION BY department_id) AS dept_total,
    AVG(salary)   OVER (PARTITION BY department_id) AS dept_avg,
    COUNT(*)      OVER (PARTITION BY department_id) AS dept_count,
    salary - AVG(salary) OVER (PARTITION BY department_id) AS diff_from_avg
FROM employees;
```

### 6.5 LAG and LEAD — Compare Across Rows

```sql
-- Month-over-month payroll change
SELECT
    pay_period,
    total_payroll,
    LAG(total_payroll, 1) OVER (ORDER BY pay_period) AS prev_month,
    total_payroll - LAG(total_payroll, 1) OVER (ORDER BY pay_period)
        AS month_over_month_change,
    ROUND(
        (total_payroll - LAG(total_payroll, 1) OVER (ORDER BY pay_period))
        * 100.0 / LAG(total_payroll, 1) OVER (ORDER BY pay_period), 2
    ) AS pct_change
FROM (
    SELECT pay_period, SUM(gross_pay) AS total_payroll
    FROM payroll GROUP BY pay_period
) monthly;
```

### 6.6 Running Totals & Moving Averages

```sql
SELECT
    pay_date,
    daily_amount,
    -- Running total (cumulative sum)
    SUM(daily_amount) OVER (
        ORDER BY pay_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total,
    -- 3-month moving average
    AVG(daily_amount) OVER (
        ORDER BY pay_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3m
FROM daily_payroll;
```

---

## 7. Temporary Tables & Query Optimization

### 7.1 Temporary Tables vs Table Variables vs CTEs

| Feature | Temp Table (#) | Table Variable (@) | CTE |
|---------|---------------|-------------------|-----|
| Scope | Session-level | Batch-level | Single statement |
| Indexing | Yes (create indexes) | Primary key only | No |
| Statistics | Yes (optimizer uses them) | No | No |
| Best For | Large intermediate results | Small datasets (<1000 rows) | Readable multi-step logic |
| Logging | Minimal logging in tempdb | Minimal | None (inline expansion) |

**Temp Table Example**

```sql
-- Create temp table for staged payroll calculation
CREATE TABLE #payroll_staging (
    employee_id   INT,
    gross_pay     DECIMAL(12,2),
    tax_rate      DECIMAL(5,4),
    deductions    DECIMAL(12,2),
    net_pay       DECIMAL(12,2)
);

-- Populate
INSERT INTO #payroll_staging (employee_id, gross_pay, tax_rate, deductions)
SELECT e.employee_id, p.gross_pay, t.rate, p.deductions
FROM employees e
INNER JOIN payroll p ON e.employee_id = p.employee_id
INNER JOIN tax_brackets t ON p.gross_pay BETWEEN t.min_income AND t.max_income;

-- Calculate net pay
UPDATE #payroll_staging
SET net_pay = gross_pay - (gross_pay * tax_rate) - deductions;

-- Use results
SELECT * FROM #payroll_staging WHERE net_pay < 0;  -- Flag anomalies

DROP TABLE #payroll_staging;
```

### 7.2 Indexing Strategies

| Index Type | Description | When to Use |
|------------|-------------|-------------|
| Clustered | Physically sorts table data; only 1 per table | Primary key, most common query filter |
| Non-Clustered | Separate structure pointing to data rows | Columns in WHERE, JOIN, ORDER BY |
| Covering | Includes all columns needed by a query | Avoids key lookup for frequent queries |
| Filtered | Indexes a subset of rows (WHERE clause) | Queries targeting specific status values |
| Columnstore | Column-based storage for analytics | Large aggregate/analytical queries |

```sql
-- Covering index for payroll queries
CREATE NONCLUSTERED INDEX IX_payroll_employee_period
ON payroll (employee_id, pay_period)
INCLUDE (gross_pay, deductions, net_pay);

-- Filtered index for active employees only
CREATE NONCLUSTERED INDEX IX_employees_active
ON employees (department_id, salary)
WHERE is_active = 1;
```

### 7.3 Execution Plan Analysis

Reading execution plans is essential for query tuning. Key operators to watch for:

| Operator | Concern | Resolution |
|----------|---------|------------|
| Table Scan | Full table read, no index used | Add appropriate index |
| Key Lookup | Extra I/O to fetch missing columns | Create covering index with INCLUDE |
| Sort | In-memory/tempdb sort (expensive) | Add index matching ORDER BY |
| Hash Match | Large hash join (high memory) | Ensure join columns are indexed |
| Nested Loop | Good for small datasets, bad for large | Check if index is missing on inner table |
| Parallelism | Query using multiple threads | Not always bad; check MAXDOP settings |

### 7.4 Query Optimization Techniques

**Before and After Optimization**

```sql
-- BEFORE: Slow query with function on indexed column
SELECT * FROM payroll
WHERE YEAR(pay_date) = 2025 AND MONTH(pay_date) = 3;

-- AFTER: SARGable predicate (index-friendly)
SELECT * FROM payroll
WHERE pay_date >= '2025-03-01' AND pay_date < '2025-04-01';

-- BEFORE: SELECT * with unnecessary columns
SELECT * FROM employees e
INNER JOIN payroll p ON e.employee_id = p.employee_id;

-- AFTER: Select only required columns
SELECT e.employee_id, e.first_name, p.net_pay
FROM employees e
INNER JOIN payroll p ON e.employee_id = p.employee_id;
```

> **Interview Tip:** SARGable (Search ARGument able) predicates allow the optimizer to use indexes. Wrapping columns in functions (YEAR(), CONVERT(), ISNULL()) kills index usage. This is a top optimization question.

---

## 8. ETL Patterns in SQL

### 8.1 MERGE Statement (Upsert)

```sql
MERGE INTO employees AS target
USING staging_employees AS source
ON target.employee_id = source.employee_id

WHEN MATCHED AND (
    target.salary <> source.salary OR
    target.department_id <> source.department_id
) THEN
    UPDATE SET
        target.salary = source.salary,
        target.department_id = source.department_id,
        target.modified_date = GETDATE()

WHEN NOT MATCHED BY TARGET THEN
    INSERT (employee_id, first_name, last_name, salary, department_id, hire_date)
    VALUES (source.employee_id, source.first_name, source.last_name,
            source.salary, source.department_id, source.hire_date)

WHEN NOT MATCHED BY SOURCE THEN
    UPDATE SET target.is_active = 0;  -- Soft delete
```

### 8.2 Data Transformation Patterns

```sql
-- PIVOT: Rows to Columns
SELECT employee_id, [January], [February], [March]
FROM (
    SELECT employee_id, month_name, net_pay
    FROM monthly_payroll
) src
PIVOT (
    SUM(net_pay) FOR month_name IN ([January], [February], [March])
) pvt;

-- UNPIVOT: Columns to Rows
SELECT employee_id, benefit_type, amount
FROM employee_benefits
UNPIVOT (
    amount FOR benefit_type IN (health_insurance, dental, vision, retirement_401k)
) unpvt;
```

### 8.3 Data Quality Checks

```sql
-- Comprehensive data validation query
SELECT
    'NULL employee_id' AS issue,
    COUNT(*) AS count
FROM payroll WHERE employee_id IS NULL
UNION ALL
SELECT 'Negative net_pay', COUNT(*)
FROM payroll WHERE net_pay < 0
UNION ALL
SELECT 'Gross < Deductions', COUNT(*)
FROM payroll WHERE gross_pay < deductions
UNION ALL
SELECT 'Duplicate payroll records', COUNT(*) - COUNT(DISTINCT
    CONCAT(employee_id, '|', pay_period))
FROM payroll;
```

---

## 9. Stored Procedures & Error Handling

### 9.1 Stored Procedure with Error Handling

```sql
CREATE PROCEDURE usp_ProcessMonthlyPayroll
    @pay_period VARCHAR(7),    -- e.g., '2025-03'
    @processed_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: Stage gross pay calculations
        INSERT INTO payroll_staging (employee_id, gross_pay, pay_period)
        SELECT e.employee_id,
            CASE e.pay_type
                WHEN 'SALARY' THEN e.annual_salary / 12
                WHEN 'HOURLY' THEN t.total_hours * e.hourly_rate
            END,
            @pay_period
        FROM employees e
        LEFT JOIN timesheet_summary t
            ON e.employee_id = t.employee_id
            AND t.pay_period = @pay_period
        WHERE e.is_active = 1;

        -- Step 2: Apply deductions
        UPDATE ps SET
            ps.tax = ps.gross_pay * tb.rate,
            ps.deductions = ISNULL(d.total_deductions, 0),
            ps.net_pay = ps.gross_pay
                - (ps.gross_pay * tb.rate)
                - ISNULL(d.total_deductions, 0)
        FROM payroll_staging ps
        INNER JOIN tax_brackets tb
            ON ps.gross_pay BETWEEN tb.min_income AND tb.max_income
        LEFT JOIN employee_deductions d
            ON ps.employee_id = d.employee_id;

        -- Step 3: Move to production
        INSERT INTO payroll_final
        SELECT * FROM payroll_staging WHERE pay_period = @pay_period;

        SET @processed_count = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO error_log (procedure_name, error_message, error_time)
        VALUES ('usp_ProcessMonthlyPayroll', ERROR_MESSAGE(), GETDATE());

        THROW;
    END CATCH
END;
```

> **Interview Tip:** Stored procedures in payroll must be transactional. Always wrap in BEGIN TRY / BEGIN CATCH with ROLLBACK. This demonstrates production-level SQL knowledge.

---

## 10. Scenario-Based Interview Questions

### Q1: Find the 2nd highest salary in each department

```sql
WITH ranked AS (
    SELECT employee_id, first_name, department_id, salary,
        DENSE_RANK() OVER (
            PARTITION BY department_id ORDER BY salary DESC
        ) AS dr
    FROM employees
)
SELECT * FROM ranked WHERE dr = 2;
```

### Q2: Find employees with consecutive absent days

```sql
WITH numbered AS (
    SELECT employee_id, absent_date,
        absent_date - ROW_NUMBER() OVER (
            PARTITION BY employee_id ORDER BY absent_date
        ) * INTERVAL '1 day' AS grp
    FROM attendance WHERE status = 'ABSENT'
),
streaks AS (
    SELECT employee_id, MIN(absent_date) AS start_date,
        MAX(absent_date) AS end_date, COUNT(*) AS consecutive_days
    FROM numbered GROUP BY employee_id, grp
)
SELECT * FROM streaks WHERE consecutive_days >= 3;
```

### Q3: Year-over-year salary growth by department

```sql
WITH yearly AS (
    SELECT department_id,
        YEAR(effective_date) AS yr,
        AVG(salary) AS avg_salary
    FROM salary_history
    GROUP BY department_id, YEAR(effective_date)
)
SELECT
    d.department_name,
    y.yr,
    y.avg_salary,
    LAG(y.avg_salary) OVER (
        PARTITION BY y.department_id ORDER BY y.yr
    ) AS prev_year_avg,
    ROUND(
        (y.avg_salary - LAG(y.avg_salary) OVER (
            PARTITION BY y.department_id ORDER BY y.yr
        )) * 100.0 / LAG(y.avg_salary) OVER (
            PARTITION BY y.department_id ORDER BY y.yr
        ), 2
    ) AS yoy_growth_pct
FROM yearly y
INNER JOIN departments d ON y.department_id = d.department_id;
```

### Q4: Detect payroll anomalies (pay > 3 standard deviations)

```sql
WITH stats AS (
    SELECT department_id,
        AVG(gross_pay) AS avg_pay,
        STDEV(gross_pay) AS std_pay
    FROM payroll
    WHERE pay_period = '2025-03'
    GROUP BY department_id
)
SELECT p.employee_id, e.first_name, p.gross_pay,
    s.avg_pay, s.std_pay,
    (p.gross_pay - s.avg_pay) / NULLIF(s.std_pay, 0) AS z_score
FROM payroll p
INNER JOIN employees e ON p.employee_id = e.employee_id
INNER JOIN stats s ON e.department_id = s.department_id
WHERE ABS(p.gross_pay - s.avg_pay) > 3 * s.std_pay;
```

### Q5: Write a query for a payroll dashboard

```sql
SELECT
    d.department_name,
    COUNT(DISTINCT e.employee_id) AS total_employees,
    SUM(p.gross_pay) AS total_gross,
    SUM(p.net_pay) AS total_net,
    SUM(p.gross_pay) - SUM(p.net_pay) AS total_deductions,
    ROUND(AVG(p.net_pay), 2) AS avg_net_pay,
    SUM(CASE WHEN p.net_pay < 0 THEN 1 ELSE 0 END) AS negative_pay_count,
    ROUND(SUM(p.net_pay) * 100.0 / SUM(p.gross_pay), 2) AS net_to_gross_ratio
FROM employees e
INNER JOIN departments d ON e.department_id = d.department_id
INNER JOIN payroll p ON e.employee_id = p.employee_id
WHERE p.pay_period = '2025-03'
GROUP BY d.department_name
ORDER BY total_gross DESC;
```

---

## 11. SQL Logical Order of Execution

Understanding execution order is critical for writing correct queries and answering conceptual questions.

| Order | Clause | Purpose |
|-------|--------|---------|
| 1 | FROM / JOIN | Identify source tables and join them |
| 2 | WHERE | Filter individual rows |
| 3 | GROUP BY | Create groups for aggregation |
| 4 | HAVING | Filter groups after aggregation |
| 5 | SELECT | Choose columns and compute expressions |
| 6 | DISTINCT | Remove duplicate result rows |
| 7 | ORDER BY | Sort the result set |
| 8 | LIMIT / TOP / OFFSET-FETCH | Restrict number of rows returned |

> **Interview Tip:** This is why you cannot use a column alias in WHERE (SELECT runs after WHERE), but you CAN use it in ORDER BY (runs after SELECT). A very common conceptual trap.

---

## 12. Quick Reference — Key Differences

### WHERE vs HAVING

| Feature | WHERE | HAVING |
|---------|-------|--------|
| Filters | Individual rows | Groups (after GROUP BY) |
| Aggregate functions | Not allowed | Allowed |
| Execution order | Before GROUP BY | After GROUP BY |

### DELETE vs TRUNCATE vs DROP

| Feature | DELETE | TRUNCATE | DROP |
|---------|--------|----------|------|
| Removes | Specific rows (WHERE) | All rows | Table + all data |
| Logging | Full row-level logging | Minimal (page deallocation) | Minimal |
| Rollback | Yes (inside transaction) | Yes in SQL Server | No |
| Identity reset | No | Yes (resets seed) | N/A |
| Triggers | Fires DELETE triggers | No triggers fired | No |

### UNION vs UNION ALL

| Feature | UNION | UNION ALL |
|---------|-------|-----------|
| Duplicates | Removes duplicates | Keeps all rows |
| Performance | Slower (sorts to deduplicate) | Faster (no dedup) |
| Use when | Need distinct combined results | Know sets are disjoint or want all rows |

### IN vs EXISTS

| Feature | IN | EXISTS |
|---------|-----|--------|
| Best for | Small subquery result set | Large outer table, correlated checks |
| NULL handling | Fails silently with NULLs in list | Handles NULLs correctly |
| Performance | Materializes full subquery result | Short-circuits on first match |

---

## 13. Final Interview Tips

### Approach Every SQL Question With This Framework

1. **Clarify:** Restate the problem. Ask about edge cases (NULLs, duplicates, scale).
2. **Plan:** Describe your approach before writing. Mention which joins, CTEs, or window functions you will use.
3. **Write:** Build the query incrementally. Start from FROM, add JOINs, then SELECT.
4. **Optimize:** Mention indexing, SARGability, and execution plan considerations.
5. **Validate:** Talk about testing with edge cases — empty tables, NULLs, duplicates, large datasets.

### Google/Globant-Specific Tips

- Google values scalability: always mention how your query handles millions of rows.
- Payroll domain knowledge matters: understand gross pay, deductions, net pay, tax brackets, and pay periods.
- Data integrity is paramount: discuss constraints, validation queries, and reconciliation.
- Be ready to compare SQL dialects: T-SQL (SQL Server) vs PL/SQL (Oracle) vs PostgreSQL vs BigQuery.
- Collaborative mindset: mention working with BAs to translate requirements into queries and with data engineers for pipeline integration.

### Top 10 Concepts to Review the Night Before

1. ROW_NUMBER() for duplicate removal
2. CTE + Window functions combo for analytics
3. LEFT JOIN + IS NULL for orphan detection
4. MERGE statement for upserts
5. GROUP BY + HAVING with multiple aggregates
6. Recursive CTEs for hierarchies
7. LAG/LEAD for period-over-period analysis
8. Indexing strategy (clustered vs non-clustered vs covering)
9. SARGable predicates and query optimization
10. Stored procedures with transaction management

---

*Good luck with your interview, Sanath!*
