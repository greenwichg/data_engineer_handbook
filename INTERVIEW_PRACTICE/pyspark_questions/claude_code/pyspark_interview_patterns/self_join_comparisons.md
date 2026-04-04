# PySpark Implementation: Self-Join Comparisons

## Problem Statement

Given an employee table, find all employees who earn **more than their direct manager**. This is the classic self-join interview question — it tests your ability to join a table with itself to compare rows within the same dataset. Variations include finding pairs, detecting anomalies, and building comparisons between related records.

### Sample Data

```
emp_id  emp_name   salary   manager_id
E001    Alice      120000   null
E002    Bob        95000    E001
E003    Charlie    130000   E001
E004    Diana      88000    E002
E005    Eve        100000   E002
E006    Frank      75000    E003
```

### Expected Output (Employees Earning More Than Their Manager)

| emp_name | emp_salary | manager_name | manager_salary |
|----------|-----------|--------------|----------------|
| Charlie  | 130000    | Alice        | 120000         |
| Eve      | 100000    | Bob          | 95000          |

---

## Method 1: Self-Join with Aliases

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col

# Initialize Spark session
spark = SparkSession.builder.appName("SelfJoin").getOrCreate()

# Sample data
data = [
    ("E001", "Alice", 120000, None),
    ("E002", "Bob", 95000, "E001"),
    ("E003", "Charlie", 130000, "E001"),
    ("E004", "Diana", 88000, "E002"),
    ("E005", "Eve", 100000, "E002"),
    ("E006", "Frank", 75000, "E003")
]
columns = ["emp_id", "emp_name", "salary", "manager_id"]
df = spark.createDataFrame(data, columns)

# Self-join: employee table joined with itself
# Left side = employee, Right side = manager
emp = df.alias("emp")
mgr = df.alias("mgr")

result = emp.join(
    mgr,
    col("emp.manager_id") == col("mgr.emp_id"),
    "inner"
).filter(
    col("emp.salary") > col("mgr.salary")
).select(
    col("emp.emp_name").alias("emp_name"),
    col("emp.salary").alias("emp_salary"),
    col("mgr.emp_name").alias("manager_name"),
    col("mgr.salary").alias("manager_salary")
)

result.show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Create Two References to the Same Table
- `emp = df.alias("emp")` — the employee side
- `mgr = df.alias("mgr")` — the manager side
- Both point to the same data, but with different aliases so we can reference columns unambiguously.

#### Step 2: Join on manager_id = emp_id

| emp.emp_name | emp.salary | emp.manager_id | mgr.emp_name | mgr.salary | mgr.emp_id |
|-------------|-----------|----------------|-------------|-----------|------------|
| Bob         | 95000     | E001           | Alice       | 120000    | E001       |
| Charlie     | 130000    | E001           | Alice       | 120000    | E001       |
| Diana       | 88000     | E002           | Bob         | 95000     | E002       |
| Eve         | 100000    | E002           | Bob         | 95000     | E002       |
| Frank       | 75000     | E003           | Charlie     | 130000    | E003       |

Alice is excluded (no manager → no match in inner join).

#### Step 3: Filter where emp.salary > mgr.salary

| emp_name | emp_salary | manager_name | manager_salary |
|----------|-----------|--------------|----------------|
| Charlie  | 130000    | Alice        | 120000         |
| Eve      | 100000    | Bob          | 95000          |

---

## Method 2: Products Frequently Bought Together (Pair Finding)

```python
# Given a table of orders, find pairs of products bought by the same customer

order_data = [
    ("C001", "Laptop"), ("C001", "Mouse"), ("C001", "Keyboard"),
    ("C002", "Laptop"), ("C002", "Monitor"),
    ("C003", "Mouse"), ("C003", "Keyboard"),
    ("C004", "Laptop"), ("C004", "Mouse"), ("C004", "Monitor")
]
orders_df = spark.createDataFrame(order_data, ["customer_id", "product"])

# Self-join to find product pairs bought together
o1 = orders_df.alias("o1")
o2 = orders_df.alias("o2")

pairs = o1.join(
    o2,
    (col("o1.customer_id") == col("o2.customer_id")) &
    (col("o1.product") < col("o2.product")),  # Avoid duplicates and self-pairs
    "inner"
).select(
    col("o1.product").alias("product_1"),
    col("o2.product").alias("product_2")
)

# Count how often each pair is bought together
from pyspark.sql.functions import count

pair_counts = pairs.groupBy("product_1", "product_2") \
    .agg(count("*").alias("times_bought_together")) \
    .orderBy(col("times_bought_together").desc())

pair_counts.show(truncate=False)
```

- **Output:**

  | product_1 | product_2 | times_bought_together |
  |-----------|-----------|----------------------|
  | Laptop    | Mouse     | 3                    |
  | Laptop    | Monitor   | 2                    |
  | Mouse     | Keyboard  | 2                    |
  | Keyboard  | Laptop    | 1                    |
  | Keyboard  | Mouse     | 1                    |
  | Monitor   | Mouse     | 1                    |

**Key trick:** `col("o1.product") < col("o2.product")` ensures:
- No self-pairs (Laptop, Laptop)
- No reverse duplicates — (Laptop, Mouse) but not also (Mouse, Laptop)

---

## Method 3: Find Consecutive Salary Ranks Within Department

```python
from pyspark.sql.functions import lead
from pyspark.sql.window import Window

dept_data = [
    ("D01", "Alice", 95000), ("D01", "Bob", 88000),
    ("D01", "Charlie", 92000), ("D01", "Diana", 88000),
    ("D02", "Eve", 110000), ("D02", "Frank", 105000)
]
dept_df = spark.createDataFrame(dept_data, ["dept", "name", "salary"])

# Self-join to find all pairs where one earns more than another in same dept
e1 = dept_df.alias("e1")
e2 = dept_df.alias("e2")

comparisons = e1.join(
    e2,
    (col("e1.dept") == col("e2.dept")) &
    (col("e1.name") != col("e2.name")) &
    (col("e1.salary") > col("e2.salary")),
    "inner"
).select(
    col("e1.dept"),
    col("e1.name").alias("higher_paid"),
    col("e1.salary").alias("higher_salary"),
    col("e2.name").alias("lower_paid"),
    col("e2.salary").alias("lower_salary")
)

comparisons.orderBy("dept", col("e1.salary").desc()).show(truncate=False)
```

---

## Method 4: Find Duplicate / Near-Duplicate Records

```python
from pyspark.sql.functions import abs as spark_abs, datediff, to_date

# Find potential duplicate transactions (same customer, similar amount, close dates)
txn_data = [
    ("T001", "C001", "2025-01-10", 500),
    ("T002", "C001", "2025-01-11", 500),
    ("T003", "C001", "2025-03-15", 500),
    ("T004", "C002", "2025-01-10", 300),
    ("T005", "C002", "2025-01-10", 300)
]
txn_df = spark.createDataFrame(txn_data, ["txn_id", "customer_id", "txn_date", "amount"])
txn_df = txn_df.withColumn("txn_date", to_date(col("txn_date")))

# Self-join to find potential duplicates
t1 = txn_df.alias("t1")
t2 = txn_df.alias("t2")

potential_dupes = t1.join(
    t2,
    (col("t1.customer_id") == col("t2.customer_id")) &
    (col("t1.amount") == col("t2.amount")) &
    (col("t1.txn_id") < col("t2.txn_id")) &  # Avoid self-match and reverse pairs
    (spark_abs(datediff(col("t1.txn_date"), col("t2.txn_date"))) <= 3),  # Within 3 days
    "inner"
).select(
    col("t1.txn_id").alias("txn_1"),
    col("t2.txn_id").alias("txn_2"),
    col("t1.customer_id"),
    col("t1.amount"),
    col("t1.txn_date").alias("date_1"),
    col("t2.txn_date").alias("date_2")
)

potential_dupes.show(truncate=False)
```

- **Output:**

  | txn_1 | txn_2 | customer_id | amount | date_1     | date_2     |
  |-------|-------|-------------|--------|------------|------------|
  | T001  | T002  | C001        | 500    | 2025-01-10 | 2025-01-11 |
  | T004  | T005  | C002        | 300    | 2025-01-10 | 2025-01-10 |

  T003 is not flagged — it's 2+ months apart from T001/T002.

---

## Method 5: Using SQL

```python
df.createOrReplaceTempView("employees")

# Employees earning more than their manager
spark.sql("""
    SELECT
        e.emp_name,
        e.salary AS emp_salary,
        m.emp_name AS manager_name,
        m.salary AS manager_salary
    FROM employees e
    INNER JOIN employees m ON e.manager_id = m.emp_id
    WHERE e.salary > m.salary
""").show(truncate=False)
```

---

## Self-Join Patterns Summary

| Pattern | Join Condition | Filter | Use Case |
|---------|---------------|--------|----------|
| Compare to parent | `child.parent_id = parent.id` | `child.val > parent.val` | Employee vs manager |
| Find pairs | `a.group = b.group AND a.id < b.id` | None or similarity check | Co-purchased products |
| Find duplicates | `a.key = b.key AND a.id < b.id` | Similarity threshold | Dedup transactions |
| Compare all in group | `a.group = b.group AND a.id != b.id` | `a.val > b.val` | Rank within group |

## Key Interview Talking Points

1. **Always use aliases:** Self-joins require distinct aliases (`emp`, `mgr`) to reference columns unambiguously.

2. **Avoid duplicates with `<`:** When finding pairs, use `a.id < b.id` (not `!=`) to get each pair exactly once. `!=` would give both (A,B) and (B,A).

3. **Performance:** Self-joins produce a Cartesian product within each group. For N employees per department, it's O(N^2) comparisons. Consider broadcasting if one side is small, or use window functions when possible.

4. **Window functions as alternative:** Many self-join problems can be solved with `lag`/`lead`/`row_number` — often more efficient. But interviewers may specifically ask for the self-join approach.

5. **Common interview questions using self-joins:**
   - "Employees earning more than their manager"
   - "Products frequently bought together"
   - "Find students scoring higher than the class average" (self-join with aggregate)
   - "Detect duplicate or fraudulent transactions"
   - "Find all flights with connecting routes" (airports table self-join)
