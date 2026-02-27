# PySpark Implementation: Handling Nulls and Missing Data

## Problem Statement 

Given a dataset with various null and missing values, demonstrate all the key techniques for detecting, filtering, filling, and transforming null data in PySpark. Null handling is a fundamental data engineering skill — interviewers test this to assess your ability to write robust, production-quality data pipelines.

### Sample Data

```
emp_id  name       department  salary  bonus   join_date
E001    Alice      Engineering 95000   5000    2023-01-15
E002    null       Sales       null    3000    2024-03-20
E003    Charlie    null        78000   null    null
E004    Diana      Engineering 92000   4500    2024-06-10
E005    null       null        null    null    2025-01-01
E006    Frank      Sales       85000   null    2024-09-15
```

---

## Method 1: Detecting Nulls

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, isnan, isnull, when, count, sum as spark_sum

# Initialize Spark session
spark = SparkSession.builder.appName("HandlingNulls").getOrCreate()

# Sample data
data = [
    ("E001", "Alice", "Engineering", 95000, 5000, "2023-01-15"),
    ("E002", None, "Sales", None, 3000, "2024-03-20"),
    ("E003", "Charlie", None, 78000, None, None),
    ("E004", "Diana", "Engineering", 92000, 4500, "2024-06-10"),
    ("E005", None, None, None, None, "2025-01-01"),
    ("E006", "Frank", "Sales", 85000, None, "2024-09-15")
]
columns = ["emp_id", "name", "department", "salary", "bonus", "join_date"]
df = spark.createDataFrame(data, columns)

# Count nulls per column
null_counts = df.select(
    [spark_sum(when(col(c).isNull(), 1).otherwise(0)).alias(c) for c in df.columns]
)
null_counts.show()
```

- **Output:**

  | emp_id | name | department | salary | bonus | join_date |
  |--------|------|------------|--------|-------|-----------|
  | 0      | 2    | 2          | 2      | 3     | 1         |

### Null Detection Functions

```python
# isNull() — checks for SQL NULL
df.filter(col("name").isNull()).show()

# isNotNull() — opposite
df.filter(col("salary").isNotNull()).show()

# Filter rows where ANY column is null
df.filter(
    col("name").isNull() | col("department").isNull() |
    col("salary").isNull() | col("bonus").isNull()
).show()

# Percentage of nulls per column
total_rows = df.count()
null_pct = df.select(
    [(spark_sum(when(col(c).isNull(), 1).otherwise(0)) / total_rows * 100).alias(c)
     for c in df.columns]
)
null_pct.show()
```

---

## Method 2: Dropping Nulls

```python
# Drop rows where ANY column is null
df.dropna().show()
# Output: Only E001 and E004 remain (all columns filled)

# Drop rows where ALL columns are null (no row meets this in our data)
df.dropna(how="all").show()

# Drop rows where specific columns are null
df.dropna(subset=["name", "salary"]).show()
# Output: Drops E002, E005 (null name or salary)

# Drop rows with at least 2 nulls
df.dropna(thresh=5).show()
# thresh = minimum non-null values required to keep the row
# 6 columns, thresh=5 means at most 1 null allowed
```

### dropna() Parameters

| Parameter | Meaning | Example |
|-----------|---------|---------|
| `how="any"` | Drop if ANY column is null (default) | `df.dropna()` |
| `how="all"` | Drop only if ALL columns are null | `df.dropna(how="all")` |
| `subset=["col1"]` | Only check specified columns | `df.dropna(subset=["salary"])` |
| `thresh=N` | Keep rows with at least N non-null values | `df.dropna(thresh=4)` |

---

## Method 3: Filling Nulls

```python
# Fill all nulls with a single value (type must match)
df.fillna(0).show()  # Fills numeric nulls with 0
df.fillna("Unknown").show()  # Fills string nulls with "Unknown"

# Fill different columns with different values
df_filled = df.fillna({
    "name": "Unknown",
    "department": "Unassigned",
    "salary": 0,
    "bonus": 0,
    "join_date": "1900-01-01"
})
df_filled.show(truncate=False)
```

- **Output (df_filled):**

  | emp_id | name    | department  | salary | bonus | join_date  |
  |--------|---------|-------------|--------|-------|------------|
  | E001   | Alice   | Engineering | 95000  | 5000  | 2023-01-15 |
  | E002   | Unknown | Sales       | 0      | 3000  | 2024-03-20 |
  | E003   | Charlie | Unassigned  | 78000  | 0     | 1900-01-01 |
  | E004   | Diana   | Engineering | 92000  | 4500  | 2024-06-10 |
  | E005   | Unknown | Unassigned  | 0      | 0     | 2025-01-01 |
  | E006   | Frank   | Sales       | 85000  | 0     | 2024-09-15 |

---

## Method 4: coalesce() — First Non-Null Value

```python
from pyspark.sql.functions import coalesce, lit

# coalesce returns the first non-null value from the arguments
df_coalesce = df.withColumn(
    "effective_bonus",
    coalesce(col("bonus"), col("salary") * 0.05, lit(0))
)
# Logic: Use bonus if available, else 5% of salary, else 0

df_coalesce.select("emp_id", "name", "salary", "bonus", "effective_bonus").show()
```

- **Output:**

  | emp_id | name    | salary | bonus | effective_bonus |
  |--------|---------|--------|-------|-----------------|
  | E001   | Alice   | 95000  | 5000  | 5000.0          |
  | E002   | null    | null   | 3000  | 3000.0          |
  | E003   | Charlie | 78000  | null  | 3900.0          |
  | E004   | Diana   | 92000  | 4500  | 4500.0          |
  | E005   | null    | null   | null  | 0.0             |
  | E006   | Frank   | 85000  | null  | 4250.0          |

---

## Method 5: when/otherwise — Conditional Null Handling

```python
from pyspark.sql.functions import when, avg as spark_avg

# Calculate average salary for filling nulls
avg_salary = df.agg(spark_avg("salary")).collect()[0][0]

# Fill null salary with department average or overall average
from pyspark.sql.window import Window

window_dept = Window.partitionBy("department")

df_smart_fill = df.withColumn(
    "filled_salary",
    when(col("salary").isNotNull(), col("salary"))
    .otherwise(lit(avg_salary).cast("int"))
)

df_smart_fill.select("emp_id", "name", "department", "salary", "filled_salary").show()
```

---

## Method 6: Forward Fill and Backward Fill

```python
from pyspark.sql.functions import last, first
from pyspark.sql.window import Window

# Ordered data for forward fill
ordered_data = [
    ("2025-01-01", 100),
    ("2025-01-02", None),
    ("2025-01-03", None),
    ("2025-01-04", 200),
    ("2025-01-05", None),
    ("2025-01-06", 300)
]
ts_df = spark.createDataFrame(ordered_data, ["date", "value"])

# Forward fill: carry the last non-null value forward
window_ff = Window.orderBy("date").rowsBetween(Window.unboundedPreceding, 0)

ts_filled = ts_df.withColumn(
    "forward_filled",
    last("value", ignorenulls=True).over(window_ff)
)

# Backward fill: carry the next non-null value backward
window_bf = Window.orderBy("date").rowsBetween(0, Window.unboundedFollowing)

ts_filled = ts_filled.withColumn(
    "backward_filled",
    first("value", ignorenulls=True).over(window_bf)
)

ts_filled.show()
```

- **Output:**

  | date       | value | forward_filled | backward_filled |
  |------------|-------|---------------|-----------------|
  | 2025-01-01 | 100   | 100           | 100             |
  | 2025-01-02 | null  | 100           | 200             |
  | 2025-01-03 | null  | 100           | 200             |
  | 2025-01-04 | 200   | 200           | 200             |
  | 2025-01-05 | null  | 200           | 300             |
  | 2025-01-06 | 300   | 300           | 300             |

---

## Method 7: Null-Safe Comparison (eqNullSafe / <=>)

```python
# Normal equality: NULL == NULL returns NULL (not true!)
df.filter(col("name") == None).show()  # Returns 0 rows!

# Null-safe equality: NULL <=> NULL returns true
df.filter(col("name").eqNullSafe(None)).show()  # Returns 2 rows (E002, E005)

# In SQL
df.createOrReplaceTempView("employees")
spark.sql("SELECT * FROM employees WHERE name <=> NULL").show()
```

---

## Method 8: Null Behavior in Aggregations and Joins

```python
# Aggregations: Nulls are IGNORED by default
df.agg(
    spark_avg("salary").alias("avg_salary"),       # Ignores nulls
    count("salary").alias("count_salary"),          # Ignores nulls
    count("*").alias("count_all")                   # Counts all rows
).show()
```

- **Output:**

  | avg_salary | count_salary | count_all |
  |------------|-------------|-----------|
  | 87500.0    | 4           | 6         |

```python
# Joins: NULL keys DON'T match (NULL != NULL in joins)
df1 = spark.createDataFrame([(1, "A"), (None, "B")], ["id", "val1"])
df2 = spark.createDataFrame([(1, "X"), (None, "Y")], ["id", "val2"])

# Inner join: NULL ids do NOT join
df1.join(df2, on="id", how="inner").show()
# Output: Only (1, "A", "X") — nulls don't match
```

---

## Quick Reference: Null Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `isNull()` | Check if column is null | `col("x").isNull()` |
| `isNotNull()` | Check if column is not null | `col("x").isNotNull()` |
| `fillna(val)` | Replace nulls with value | `df.fillna(0)` |
| `dropna()` | Remove rows with nulls | `df.dropna(subset=["col"])` |
| `coalesce()` | First non-null from list | `coalesce(col("a"), col("b"))` |
| `when().otherwise()` | Conditional null handling | `when(col("x").isNull(), ...)` |
| `eqNullSafe()` | Null-safe equality | `col("x").eqNullSafe(None)` |
| `nanvl(col, replacement)` | Replace NaN | For float/double NaN values |
| `last(ignorenulls=True)` | Forward fill | Over ordered window |
| `first(ignorenulls=True)` | Backward fill | Over ordered window |

## Key Interview Talking Points

1. **NULL vs NaN:** `NULL` means missing/unknown. `NaN` (Not a Number) is a float value. `isNull()` checks for NULL; `isnan()` checks for NaN. They are NOT the same.

2. **NULL in aggregations:** `sum()`, `avg()`, `count(col)` all skip nulls. `count("*")` counts all rows including nulls.

3. **NULL in joins:** Two NULL values do NOT match in a join condition. Use `eqNullSafe(<=>)` if you want nulls to match.

4. **NULL in comparisons:** `NULL > 5` is NULL (not false). `NULL == NULL` is NULL (not true). This is SQL's three-valued logic.

5. **NULL ordering:** By default, nulls appear last in ascending order and first in descending order. Use `asc_nulls_first()` or `desc_nulls_last()` to control placement.

6. **Production best practice:** Handle nulls early in the pipeline. Document null-handling decisions. Use `coalesce()` for sensible defaults instead of letting nulls propagate.
