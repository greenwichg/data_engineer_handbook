# PySpark Implementation: Find the Nth Highest Salary

## Problem Statement 

Given an employee dataset with salaries, find the **Nth highest salary** across the entire company and also **per department**. This is arguably the most classic SQL/PySpark interview question. Interviewers typically start with "find the 2nd highest salary" and then generalize to Nth.

### Sample Data

```
emp_id  emp_name    department  salary
E001    Alice       Engineering 95000
E002    Bob         Engineering 95000
E003    Charlie     Engineering 88000
E004    Diana       Sales       82000
E005    Eve         Sales       75000
E006    Frank       HR          72000
E007    Grace       HR          68000
E008    Hank        HR          72000
```

### Expected Output: 2nd Highest Salary Overall
**Answer: 88000**

### Expected Output: 2nd Highest Salary Per Department

| department  | second_highest_salary |
|-------------|----------------------|
| Engineering | 88000                |
| Sales       | 75000                |
| HR          | 68000                |

---

## Method 1: Using dense_rank() — Overall Nth Highest

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, dense_rank, desc
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("NthHighestSalary").getOrCreate()

# Sample data
data = [
    ("E001", "Alice", "Engineering", 95000),
    ("E002", "Bob", "Engineering", 95000),
    ("E003", "Charlie", "Engineering", 88000),
    ("E004", "Diana", "Sales", 82000),
    ("E005", "Eve", "Sales", 75000),
    ("E006", "Frank", "HR", 72000),
    ("E007", "Grace", "HR", 68000),
    ("E008", "Hank", "HR", 72000)
]

columns = ["emp_id", "emp_name", "department", "salary"]
df = spark.createDataFrame(data, columns)

N = 2  # Change this to find Nth highest

# Window over all rows, ordered by salary descending
window_all = Window.orderBy(desc("salary"))

# Add dense_rank
df_ranked = df.withColumn("rnk", dense_rank().over(window_all))

# Filter for Nth
nth_highest = df_ranked.filter(col("rnk") == N)

nth_highest.show()
```

### Step-by-Step Explanation

#### Step 1: Add dense_rank over all rows
- **What happens:** Ranks all employees by salary descending. Ties get the same rank.
- **Output (df_ranked):**

  | emp_id | emp_name | department  | salary | rnk |
  |--------|----------|-------------|--------|-----|
  | E001   | Alice    | Engineering | 95000  | 1   |
  | E002   | Bob      | Engineering | 95000  | 1   |
  | E003   | Charlie  | Engineering | 88000  | 2   |
  | E004   | Diana    | Sales       | 82000  | 3   |
  | E005   | Eve      | Sales       | 75000  | 4   |
  | E006   | Frank    | HR          | 72000  | 5   |
  | E008   | Hank     | HR          | 72000  | 5   |
  | E007   | Grace    | HR          | 68000  | 6   |

  **Note:** Alice and Bob both get rank 1 (same salary). Charlie gets rank 2 (not 3) because `dense_rank` has no gaps.

#### Step 2: Filter rnk == 2
- **Output (nth_highest):**

  | emp_id | emp_name | department  | salary | rnk |
  |--------|----------|-------------|--------|-----|
  | E003   | Charlie  | Engineering | 88000  | 2   |

  **The 2nd highest salary is 88000.**

---

## Method 2: Per-Department Nth Highest

```python
# Window partitioned by department
window_dept = Window.partitionBy("department").orderBy(desc("salary"))

# Add dense_rank per department
df_dept_ranked = df.withColumn("rnk", dense_rank().over(window_dept))

# Filter for Nth per department
nth_per_dept = df_dept_ranked.filter(col("rnk") == N) \
    .select("department", col("salary").alias("second_highest_salary")) \
    .distinct()

nth_per_dept.show()
```

### Step-by-Step Explanation

#### Step 1: dense_rank per department
- **Output (df_dept_ranked):**

  | emp_id | emp_name | department  | salary | rnk |
  |--------|----------|-------------|--------|-----|
  | E001   | Alice    | Engineering | 95000  | 1   |
  | E002   | Bob      | Engineering | 95000  | 1   |
  | E003   | Charlie  | Engineering | 88000  | 2   |
  | E004   | Diana    | Sales       | 82000  | 1   |
  | E005   | Eve      | Sales       | 75000  | 2   |
  | E006   | Frank    | HR          | 72000  | 1   |
  | E008   | Hank     | HR          | 72000  | 1   |
  | E007   | Grace    | HR          | 68000  | 2   |

#### Step 2: Filter rnk == 2
- **Output (nth_per_dept):**

  | department  | second_highest_salary |
  |-------------|----------------------|
  | Engineering | 88000                |
  | Sales       | 75000                |
  | HR          | 68000                |

---

## Method 3: Using Subquery/Distinct Approach (No Window Functions)

```python
from pyspark.sql.functions import countDistinct, col

# Get distinct salaries
distinct_salaries = df.select("salary").distinct().orderBy(desc("salary"))

# Collect and index (works for small datasets)
salary_list = [row.salary for row in distinct_salaries.collect()]
nth_salary = salary_list[N - 1]  # 0-indexed

print(f"The {N}nd highest salary is: {nth_salary}")

# Get employees with that salary
result = df.filter(col("salary") == nth_salary)
result.show()
```

- **Explanation:** Simple approach that collects distinct salaries, sorts them, and picks the Nth value. Works for small data but **NOT recommended for large datasets** since `collect()` brings all data to the driver.

---

## Method 4: Using SQL (Spark SQL)

```python
# Register as temp view
df.createOrReplaceTempView("employees")

# SQL approach
nth_sql = spark.sql("""
    SELECT * FROM (
        SELECT *,
            DENSE_RANK() OVER (ORDER BY salary DESC) as rnk
        FROM employees
    ) ranked
    WHERE rnk = 2
""")

nth_sql.show()

# Per department
nth_dept_sql = spark.sql("""
    SELECT department, salary as second_highest_salary
    FROM (
        SELECT *,
            DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) as rnk
        FROM employees
    ) ranked
    WHERE rnk = 2
""")

nth_dept_sql.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| All salaries are the same | Everyone gets rank 1, no Nth salary | Return null or message |
| N > number of distinct salaries | Filter returns empty DataFrame | Check count before filtering |
| Null salaries | Nulls are placed last in ordering | Filter nulls first: `df.filter(col("salary").isNotNull())` |
| N = 1 | Returns the highest salary | Works with same code |

## Key Interview Talking Points

1. **Why dense_rank over rank?**
   - `dense_rank`: 1, 1, 2, 3 — no gaps, so "2nd highest" means the actual 2nd distinct value.
   - `rank`: 1, 1, 3, 4 — gaps after ties, so "2nd highest" might not exist if there are ties at rank 1.

2. **Follow-up: "What if the table has billions of rows?"**
   - Use `approx_percentile()` for approximate Nth highest.
   - Or use `orderBy` + `limit(N)` on distinct salaries to avoid full ranking.

3. **Follow-up: "Can you do it without window functions?"**
   - Self-join: count how many distinct salaries are higher.
   - Subquery with `LIMIT` and `OFFSET`.

4. **Correlated subquery in SQL:**
   ```sql
   SELECT DISTINCT salary FROM employees e1
   WHERE N-1 = (SELECT COUNT(DISTINCT salary) FROM employees e2 WHERE e2.salary > e1.salary)
   ```
