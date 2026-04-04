# PySpark Implementation: Calculate Median Without Built-in Functions

## Problem Statement
Given a table of employee salaries by department, calculate the exact median salary per department using only window functions — without using `percentile_approx()` or any built-in median function. This is a classic interview question that tests deep understanding of window functions, row numbering, and conditional logic.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("MedianWithoutBuiltin").getOrCreate()

data = [
    ("Engineering", "Alice", 95000),
    ("Engineering", "Bob", 85000),
    ("Engineering", "Charlie", 110000),
    ("Engineering", "Diana", 90000),
    ("Engineering", "Eve", 100000),
    ("Sales", "Frank", 60000),
    ("Sales", "Grace", 70000),
    ("Sales", "Henry", 65000),
    ("Sales", "Ivy", 80000),
    ("HR", "Jack", 55000),
    ("HR", "Karen", 60000),
]

columns = ["department", "name", "salary"]
df = spark.createDataFrame(data, columns)
df.show()
```

```
+-----------+-------+------+
| department|   name|salary|
+-----------+-------+------+
|Engineering|  Alice| 95000|
|Engineering|    Bob| 85000|
|Engineering|Charlie|110000|
|Engineering|  Diana| 90000|
|Engineering|    Eve|100000|
|      Sales|  Frank| 60000|
|      Sales|  Grace| 70000|
|      Sales|  Henry| 65000|
|      Sales|   Ivy| 80000|
|         HR|   Jack| 55000|
|         HR|  Karen| 60000|
+-----------+-------+------+
```

### Expected Output
```
+-----------+-------+
| department| median|
+-----------+-------+
|Engineering|  95000|
|      Sales|  67500|
|         HR|  57500|
+-----------+-------+
```
- Engineering (5 values): sorted = [85000, 90000, **95000**, 100000, 110000] → middle value = 95000
- Sales (4 values): sorted = [60000, **65000, 70000**, 80000] → average of two middle values = 67500
- HR (2 values): sorted = [**55000, 60000**] → average of two middle values = 57500

---

## Method 1: row_number + count + filter (Recommended)

```python
# Step 1: Count employees per department and assign row numbers
window_dept = Window.partitionBy("department").orderBy("salary")

df_numbered = df.withColumn(
    "rn", F.row_number().over(window_dept)
).withColumn(
    "cnt", F.count("*").over(Window.partitionBy("department"))
)

# Step 2: Identify the median row(s)
# For odd count: middle row is at position (cnt + 1) / 2
# For even count: middle rows are at cnt/2 and cnt/2 + 1
df_median_rows = df_numbered.filter(
    (F.col("rn") == F.floor((F.col("cnt") + 1) / 2)) |
    (F.col("rn") == F.ceil((F.col("cnt") + 1) / 2))
)

# Step 3: Average the median row(s) per department
result = df_median_rows.groupBy("department").agg(
    F.avg("salary").alias("median")
)
result.show()
```

### Step-by-Step Explanation

#### Step 1: Add row numbers and counts
- **Output (df_numbered):**

  | department  | name    | salary | rn | cnt |
  |-------------|---------|--------|----|-----|
  | Engineering | Bob     | 85000  | 1  | 5   |
  | Engineering | Diana   | 90000  | 2  | 5   |
  | Engineering | Alice   | 95000  | 3  | 5   |
  | Engineering | Eve     | 100000 | 4  | 5   |
  | Engineering | Charlie | 110000 | 5  | 5   |
  | Sales       | Frank   | 60000  | 1  | 4   |
  | Sales       | Henry   | 65000  | 2  | 4   |
  | Sales       | Grace   | 70000  | 3  | 4   |
  | Sales       | Ivy     | 80000  | 4  | 4   |
  | HR          | Jack    | 55000  | 1  | 2   |
  | HR          | Karen   | 60000  | 2  | 2   |

#### Step 2: Identify median positions
- **Engineering (cnt=5):** floor((5+1)/2)=3, ceil((5+1)/2)=3 → row 3 only (Alice, 95000)
- **Sales (cnt=4):** floor((4+1)/2)=2, ceil((4+1)/2)=3 → rows 2 and 3 (Henry 65000, Grace 70000)
- **HR (cnt=2):** floor((2+1)/2)=1, ceil((2+1)/2)=2 → rows 1 and 2 (Jack 55000, Karen 60000)

#### Step 3: Average the median rows
- Engineering: avg(95000) = 95000
- Sales: avg(65000, 70000) = 67500
- HR: avg(55000, 60000) = 57500

---

## Method 2: Using percentRank() or ntile()

```python
# Approach: Use percent_rank to find the row(s) closest to the 50th percentile
window_dept = Window.partitionBy("department").orderBy("salary")

df_pct = df.withColumn(
    "pct_rank", F.percent_rank().over(window_dept)
).withColumn(
    "cnt", F.count("*").over(Window.partitionBy("department"))
)

# For odd count: the exact middle has pct_rank = 0.5
# For even count: take the two rows straddling 0.5
# General approach: find rows where pct_rank is closest to 0.5
df_median_candidates = df_pct.filter(
    (F.col("pct_rank") <= 0.5)
    | (F.col("pct_rank") == F.lit(0.0))  # handles cnt=1
)

# Keep the highest pct_rank <= 0.5 and the next one
window_rank = Window.partitionBy("department").orderBy(F.desc("pct_rank"))
result_pct = (
    df_median_candidates
    .withColumn("rn", F.row_number().over(window_rank))
    .filter(F.col("rn") <= 2)
    .groupBy("department")
    .agg(F.avg("salary").alias("median"))
)
result_pct.show()
```

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("salaries")

result_sql = spark.sql("""
    WITH numbered AS (
        SELECT
            department,
            salary,
            ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary) AS rn,
            COUNT(*) OVER (PARTITION BY department) AS cnt
        FROM salaries
    )
    SELECT
        department,
        AVG(salary) AS median
    FROM numbered
    WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
    GROUP BY department
    ORDER BY department
""")
result_sql.show()
```

---

## Method 4: Self-Join Counting Approach (No Window Functions at All)

```python
# For each salary, count how many salaries are <= it and >= it
# The median is where both counts >= half the total

df.createOrReplaceTempView("salaries")

result_no_window = spark.sql("""
    SELECT
        s1.department,
        AVG(s1.salary) AS median
    FROM salaries s1
    WHERE (
        SELECT COUNT(*) FROM salaries s2
        WHERE s2.department = s1.department AND s2.salary <= s1.salary
    ) >= (
        SELECT COUNT(*) FROM salaries s3
        WHERE s3.department = s1.department
    ) / 2.0
    AND (
        SELECT COUNT(*) FROM salaries s4
        WHERE s4.department = s1.department AND s4.salary >= s1.salary
    ) >= (
        SELECT COUNT(*) FROM salaries s5
        WHERE s5.department = s1.department
    ) / 2.0
    GROUP BY s1.department
""")
result_no_window.show()
```

- **Note:** This approach uses no window functions at all — it's O(n²) but demonstrates pure relational thinking.

---

## Comparison of Methods

| Method | Window Functions? | Handles Even Count? | Performance | Interview Value |
|--------|-------------------|---------------------|-------------|-----------------|
| row_number + count | Yes | Yes — averages two middle rows | Best | Highest — clean and correct |
| percent_rank | Yes | Yes — but trickier logic | Good | Shows alternate approach |
| SQL with FLOOR/CEIL | Yes | Yes | Best | Easiest to explain |
| Self-join counting | No | Yes | O(n²) — worst | Shows deep relational thinking |

## Key Interview Talking Points

1. **Odd vs even count:** The core challenge. For odd counts, there is a single middle element. For even counts, the median is the average of the two middle elements.
2. **`floor((cnt+1)/2)` and `ceil((cnt+1)/2)`:** This formula elegantly handles both cases — for odd counts they produce the same value, for even counts they produce consecutive values.
3. **Why not `percentile_approx()`?** It's approximate (as the name suggests) and gives slightly different results on small datasets. Interviews often want the exact median.
4. **row_number() vs rank():** Use `row_number()` here — if two employees have the same salary, `rank()` would give them the same rank, potentially skipping the true median position.
5. **Performance:** The window function approach is O(n log n) per partition (due to sorting). For very large datasets, `percentile_approx()` with a high accuracy parameter is more practical.
6. This is one of the most commonly asked SQL/PySpark interview questions — interviewers want to see you handle the odd/even edge case correctly.
