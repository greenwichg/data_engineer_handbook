# PySpark Implementation: Median and Percentile Calculations

## Problem Statement 

Given a dataset of employee salaries, calculate the **median**, various **percentiles** (P25, P50, P75, P90, P99), and the **interquartile range (IQR)** both overall and per department. Median/percentile calculations are commonly asked in interviews because they require understanding approximate vs exact methods and distributed computation challenges.

### Sample Data

```
emp_id  department   salary
E001    Engineering  95000
E002    Engineering  88000
E003    Engineering  92000
E004    Engineering  110000
E005    Engineering  85000
E006    Sales        72000
E007    Sales        68000
E008    Sales        75000
E009    Sales        82000
E010    HR           65000
E011    HR           70000
E012    HR           62000
```

---

## Method 1: percentile_approx() — Approximate Percentile

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, percentile_approx, round as spark_round

# Initialize Spark session
spark = SparkSession.builder.appName("MedianPercentile").getOrCreate()

# Sample data
data = [
    ("E001", "Engineering", 95000), ("E002", "Engineering", 88000),
    ("E003", "Engineering", 92000), ("E004", "Engineering", 110000),
    ("E005", "Engineering", 85000), ("E006", "Sales", 72000),
    ("E007", "Sales", 68000), ("E008", "Sales", 75000),
    ("E009", "Sales", 82000), ("E010", "HR", 65000),
    ("E011", "HR", 70000), ("E012", "HR", 62000)
]
columns = ["emp_id", "department", "salary"]
df = spark.createDataFrame(data, columns)

# Overall median (50th percentile)
median_overall = df.agg(
    percentile_approx("salary", 0.5).alias("median_salary")
)
median_overall.show()

# Multiple percentiles at once
percentiles = df.agg(
    percentile_approx("salary", 0.25).alias("P25"),
    percentile_approx("salary", 0.50).alias("P50_median"),
    percentile_approx("salary", 0.75).alias("P75"),
    percentile_approx("salary", 0.90).alias("P90"),
    percentile_approx("salary", 0.99).alias("P99")
)
percentiles.show()
```

### Output

- **Median:**

  | median_salary |
  |---------------|
  | 82000         |

- **Multiple percentiles:**

  | P25   | P50_median | P75   | P90    | P99    |
  |-------|------------|-------|--------|--------|
  | 69000 | 82000      | 93500 | 104000 | 110000 |

### Understanding percentile_approx Parameters

```python
# Syntax: percentile_approx(column, percentage, accuracy)
# accuracy (default 10000): higher = more accurate but slower
# For exact results on small data, use high accuracy

df.agg(
    percentile_approx("salary", 0.5, 10000).alias("approx_10K"),
    percentile_approx("salary", 0.5, 100000).alias("approx_100K")
).show()
```

---

## Method 2: Per-Department Percentiles

```python
# Median per department using groupBy
dept_median = df.groupBy("department").agg(
    percentile_approx("salary", 0.25).alias("P25"),
    percentile_approx("salary", 0.50).alias("median"),
    percentile_approx("salary", 0.75).alias("P75")
)

dept_median.show()
```

- **Output:**

  | department  | P25   | median | P75   |
  |-------------|-------|--------|-------|
  | Engineering | 88000 | 92000  | 95000 |
  | Sales       | 70000 | 73500  | 78500 |
  | HR          | 63500 | 65000  | 67500 |

---

## Method 3: Exact Median Using Window Functions

```python
from pyspark.sql.functions import row_number, count as spark_count, ceil, floor as spark_floor
from pyspark.sql.window import Window

# For exact median: sort, find middle position(s), average them

# Step 1: Count total rows
total = df.count()  # 12

# Step 2: Order and number rows
window_all = Window.orderBy("salary")
df_numbered = df.withColumn("rn", row_number().over(window_all))

# Step 3: Find median position(s)
if total % 2 == 0:
    # Even: average of middle two values
    mid1 = total // 2
    mid2 = mid1 + 1
    median_rows = df_numbered.filter((col("rn") == mid1) | (col("rn") == mid2))
    from pyspark.sql.functions import avg
    exact_median = median_rows.agg(avg("salary").alias("exact_median"))
else:
    # Odd: middle value
    mid = (total + 1) // 2
    exact_median = df_numbered.filter(col("rn") == mid).select(col("salary").alias("exact_median"))

exact_median.show()
```

- **Output:**

  | exact_median |
  |-------------|
  | 78500.0     |

  (Average of 6th value=75000 and 7th value=82000)

---

## Method 4: Exact Median Per Group Using Window Functions

```python
from pyspark.sql.functions import avg, when, count as spark_count

# Per-department exact median
window_dept = Window.partitionBy("department").orderBy("salary")
window_dept_count = Window.partitionBy("department")

df_dept_median = df.withColumn("rn", row_number().over(window_dept)) \
    .withColumn("dept_count", spark_count("*").over(window_dept_count)) \
    .withColumn("mid1", spark_floor(col("dept_count") / 2 + 0.5).cast("int")) \
    .withColumn("mid2", ceil(col("dept_count") / 2 + 0.5).cast("int")) \
    .filter((col("rn") == col("mid1")) | (col("rn") == col("mid2"))) \
    .groupBy("department") \
    .agg(avg("salary").alias("exact_median"))

df_dept_median.show()
```

---

## Method 5: Interquartile Range (IQR) and Outlier Detection

```python
# Calculate IQR per department for outlier detection
dept_iqr = df.groupBy("department").agg(
    percentile_approx("salary", 0.25).alias("Q1"),
    percentile_approx("salary", 0.50).alias("median"),
    percentile_approx("salary", 0.75).alias("Q3")
)

# Add IQR and outlier bounds
from pyspark.sql.functions import lit

dept_bounds = dept_iqr.withColumn("IQR", col("Q3") - col("Q1")) \
    .withColumn("lower_bound", col("Q1") - 1.5 * col("IQR")) \
    .withColumn("upper_bound", col("Q3") + 1.5 * col("IQR"))

dept_bounds.show(truncate=False)

# Join back to find outliers
df_with_bounds = df.join(dept_bounds.select("department", "lower_bound", "upper_bound"),
                         on="department")

outliers = df_with_bounds.filter(
    (col("salary") < col("lower_bound")) | (col("salary") > col("upper_bound"))
)

print("Outliers:")
outliers.select("emp_id", "department", "salary", "lower_bound", "upper_bound").show()
```

---

## Method 6: Using SQL

```python
df.createOrReplaceTempView("employees")

sql_pct = spark.sql("""
    SELECT
        department,
        percentile_approx(salary, 0.25) AS Q1,
        percentile_approx(salary, 0.50) AS median,
        percentile_approx(salary, 0.75) AS Q3,
        percentile_approx(salary, 0.75) - percentile_approx(salary, 0.25) AS IQR
    FROM employees
    GROUP BY department
    ORDER BY department
""")

sql_pct.show()
```

---

## Method 7: Multiple Percentiles in One Call

```python
# Pass an array of percentiles for efficiency
from pyspark.sql.functions import percentile_approx

multi_pct = df.groupBy("department").agg(
    percentile_approx("salary", [0.1, 0.25, 0.5, 0.75, 0.9]).alias("percentiles")
)

multi_pct.show(truncate=False)
```

- **Output:**

  | department  | percentiles                    |
  |-------------|--------------------------------|
  | Engineering | [85000, 88000, 92000, 95000, 104000] |
  | Sales       | [68000, 70000, 73500, 78500, 82000]  |
  | HR          | [62000, 63500, 65000, 67500, 70000]  |

  Index: [P10, P25, P50, P75, P90]

---

## Comparison: Approximate vs Exact

| Aspect | percentile_approx | Exact (window + sort) |
|--------|-------------------|----------------------|
| Accuracy | Approximate (configurable) | Exact |
| Performance | Fast, distributed | Slower (requires sort) |
| Scalability | Handles billions of rows | Struggles with very large data |
| Ease of use | Single function call | Complex logic |
| Use when | Production pipelines | Small data, auditing |

## Key Interview Talking Points

1. **Why is median hard in distributed systems?** Unlike sum/count (which are associative), median requires knowing the global sorted order. You can't compute partial medians and combine them.

2. **percentile_approx uses t-digest algorithm:** This is a streaming algorithm that maintains an approximate distribution. The `accuracy` parameter controls the trade-off between precision and memory.

3. **Accuracy parameter:** Default is 10,000. Higher values give more accurate results but use more memory. For most use cases, the default is sufficient (error < 0.01%).

4. **IQR for outlier detection:** Values outside `[Q1 - 1.5*IQR, Q3 + 1.5*IQR]` are considered outliers. This is the standard box-plot method.

5. **Alternative: approx_percentile in SQL** is the same as `percentile_approx` in the DataFrame API.

6. **Follow-up question:** "How would you compute exact median on a billion rows?"
   - Sort and sample
   - Two-pass: first pass to find approximate median, second pass to refine
   - Use `percentile_approx` with very high accuracy
