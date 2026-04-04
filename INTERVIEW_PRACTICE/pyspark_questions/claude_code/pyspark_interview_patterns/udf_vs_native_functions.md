# PySpark Implementation: UDFs vs Native Functions

## Problem Statement

User Defined Functions (UDFs) allow custom Python logic in PySpark, but they come with significant performance costs. Interviewers frequently ask when UDFs are justified, how to minimize their impact, and how to replace them with native functions. This guide covers:

- Regular Python UDFs (worst performance)
- Pandas UDFs / Vectorized UDFs (better performance)
- Native built-in function alternatives (best performance)
- The serialization overhead that makes UDFs slow
- When UDFs are genuinely necessary

**Key Gotcha:** Regular UDFs serialize data from JVM to Python row-by-row, losing all Catalyst optimizer benefits. Always try native functions first. If you must use a UDF, prefer Pandas UDFs.

---

## Setup

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StringType, IntegerType, DoubleType, ArrayType, StructType, StructField
)
import pandas as pd
import time

spark = SparkSession.builder \
    .appName("UDF vs Native Functions") \
    .master("local[*]") \
    .config("spark.sql.execution.arrow.pyspark.enabled", "true") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")
```

---

## Part 1: The Serialization Problem (Why UDFs Are Slow)

### Conceptual Overview

```
Native Function Path:
  JVM (Catalyst Optimizer) -> Tungsten Execution -> Result
  - Stays entirely in JVM
  - Benefits from whole-stage code generation
  - Operates on columnar binary format

Regular UDF Path:
  JVM -> Serialize to Python (per row) -> Python interpreter -> Serialize back to JVM
  - Data crosses JVM/Python boundary for EVERY row
  - No Catalyst optimization
  - Python GIL limits parallelism
  - Python objects consume more memory than Tungsten format

Pandas UDF Path:
  JVM -> Serialize batch via Arrow -> Pandas (vectorized) -> Serialize back via Arrow
  - Batch serialization (not per-row)
  - Arrow columnar format is efficient
  - NumPy/Pandas vectorized operations
  - Still slower than native, but much better than regular UDFs
```

---

## Part 2: Regular UDF Examples

### Sample Data

```python
data = [
    (1, "alice smith", "2024-01-15", 50000.0),
    (2, "BOB JOHNSON", "2024-02-20", 75000.0),
    (3, "Charlie Brown", "2024-03-10", 62000.0),
    (4, "diana prince", "2024-04-05", 91000.0),
    (5, "EVE DAVIS", "2024-05-25", 48000.0),
]

df = spark.createDataFrame(data, ["id", "name", "hire_date", "salary"])
df.show(truncate=False)
```

```
+---+-------------+----------+-------+
|id |name         |hire_date |salary |
+---+-------------+----------+-------+
|1  |alice smith  |2024-01-15|50000.0|
|2  |BOB JOHNSON  |2024-02-20|75000.0|
|3  |Charlie Brown|2024-03-10|62000.0|
|4  |diana prince |2024-04-05|91000.0|
|5  |EVE DAVIS    |2024-05-25|48000.0|
+---+-------------+----------+-------+
```

### Method 1: Regular UDF (BAD -- for demonstration only)

```python
# Define a regular UDF to title-case a name
@F.udf(StringType())
def title_case_udf(name):
    if name is None:
        return None
    return name.title()

# Define a UDF for a custom salary tier
@F.udf(StringType())
def salary_tier_udf(salary):
    if salary is None:
        return "Unknown"
    if salary >= 90000:
        return "Senior"
    elif salary >= 60000:
        return "Mid"
    else:
        return "Junior"

df_udf = df.withColumn("name_clean", title_case_udf("name")) \
            .withColumn("tier", salary_tier_udf("salary"))

df_udf.show(truncate=False)
```

### Expected Output

```
+---+-------------+----------+-------+-------------+------+
|id |name         |hire_date |salary |name_clean   |tier  |
+---+-------------+----------+-------+-------------+------+
|1  |alice smith  |2024-01-15|50000.0|Alice Smith  |Junior|
|2  |BOB JOHNSON  |2024-02-20|75000.0|Bob Johnson  |Mid   |
|3  |Charlie Brown|2024-03-10|62000.0|Charlie Brown|Mid   |
|4  |diana prince |2024-04-05|91000.0|Diana Prince |Senior|
|5  |EVE DAVIS    |2024-05-25|48000.0|Eve Davis    |Junior|
+---+-------------+----------+-------+-------------+------+
```

### Method 2: Native Function Equivalents (GOOD)

```python
df_native = df.withColumn(
    "name_clean", F.initcap("name")
).withColumn(
    "tier",
    F.when(F.col("salary") >= 90000, "Senior")
     .when(F.col("salary") >= 60000, "Mid")
     .otherwise("Junior")
)

df_native.show(truncate=False)
```

**Same output, dramatically better performance.**

---

## Part 3: Performance Comparison

```python
# Create a large DataFrame for benchmarking
large_df = spark.range(1_000_000).withColumn(
    "value", (F.rand() * 100).cast("double")
)

# --- Regular UDF ---
@F.udf(DoubleType())
def square_udf(x):
    return x * x if x is not None else None

start = time.time()
large_df.withColumn("squared", square_udf("value")).count()
udf_time = time.time() - start

# --- Pandas UDF ---
@F.pandas_udf(DoubleType())
def square_pandas_udf(s: pd.Series) -> pd.Series:
    return s * s

start = time.time()
large_df.withColumn("squared", square_pandas_udf("value")).count()
pandas_udf_time = time.time() - start

# --- Native function ---
start = time.time()
large_df.withColumn("squared", F.col("value") * F.col("value")).count()
native_time = time.time() - start

print(f"Regular UDF:  {udf_time:.3f}s")
print(f"Pandas UDF:   {pandas_udf_time:.3f}s")
print(f"Native:       {native_time:.3f}s")
print(f"UDF vs Native slowdown:       {udf_time / native_time:.1f}x")
print(f"Pandas UDF vs Native slowdown: {pandas_udf_time / native_time:.1f}x")
```

### Typical Results

```
Regular UDF:  8.234s
Pandas UDF:   1.892s
Native:       0.342s
UDF vs Native slowdown:       24.1x
Pandas UDF vs Native slowdown: 5.5x
```

---

## Part 4: Pandas UDFs (Vectorized UDFs)

### Type 1: Series to Series (element-wise transformation)

```python
@F.pandas_udf(StringType())
def custom_title_case(names: pd.Series) -> pd.Series:
    return names.str.title()

df.withColumn("name_clean", custom_title_case("name")).show(truncate=False)
```

### Type 2: Series to Scalar (aggregate function)

```python
@F.pandas_udf(DoubleType())
def weighted_mean(values: pd.Series) -> float:
    """Custom weighted mean -- just an example of aggregate pandas UDF."""
    weights = range(1, len(values) + 1)
    return float(sum(v * w for v, w in zip(values, weights)) / sum(weights))

df.groupBy().agg(weighted_mean("salary").alias("weighted_avg_salary")).show()
```

### Type 3: Iterator of Series to Iterator of Series (for expensive initialization)

```python
from typing import Iterator

@F.pandas_udf(StringType())
def batch_process(batch_iter: Iterator[pd.Series]) -> Iterator[pd.Series]:
    # Expensive initialization done once per partition (e.g., load ML model)
    # model = load_heavy_model()
    
    for batch in batch_iter:
        # Process each batch
        yield batch.str.upper()

df.withColumn("name_upper", batch_process("name")).show(truncate=False)
```

### Type 4: Grouped Map (applyInPandas)

```python
# Apply arbitrary Pandas logic per group
def normalize_salary(pdf: pd.DataFrame) -> pd.DataFrame:
    """Normalize salary within each tier."""
    mean_sal = pdf["salary"].mean()
    std_sal = pdf["salary"].std()
    if std_sal and std_sal > 0:
        pdf["normalized_salary"] = (pdf["salary"] - mean_sal) / std_sal
    else:
        pdf["normalized_salary"] = 0.0
    return pdf

result_schema = StructType([
    StructField("id", IntegerType()),
    StructField("name", StringType()),
    StructField("hire_date", StringType()),
    StructField("salary", DoubleType()),
    StructField("normalized_salary", DoubleType()),
])

# First add tiers using native function
df_with_tier = df.withColumn(
    "tier",
    F.when(F.col("salary") >= 90000, "Senior")
     .when(F.col("salary") >= 60000, "Mid")
     .otherwise("Junior")
)

# Then use applyInPandas with the tier-less schema for the inner function
df_with_tier.groupBy("tier").applyInPandas(
    normalize_salary,
    schema="id int, name string, hire_date string, salary double, tier string, normalized_salary double"
).show(truncate=False)
```

---

## Part 5: Common UDF Replacements with Native Functions

### String Operations

```python
# BAD: UDF for string manipulation
@F.udf(StringType())
def extract_domain_udf(email):
    if email and "@" in email:
        return email.split("@")[1]
    return None

# GOOD: Native functions
emails = spark.createDataFrame(
    [("alice@gmail.com",), ("bob@yahoo.com",), (None,)], ["email"]
)

# Method: split + element_at
emails.withColumn(
    "domain", F.element_at(F.split("email", "@"), 2)
).show()

# Alternative: regexp_extract
emails.withColumn(
    "domain", F.regexp_extract("email", r"@(.+)$", 1)
).show()
```

### Conditional Logic

```python
# BAD: UDF for conditional logic
@F.udf(StringType())
def categorize_udf(value):
    if value > 100: return "high"
    elif value > 50: return "medium"
    else: return "low"

# GOOD: F.when chains
df_cat = spark.createDataFrame([(150,), (75,), (30,)], ["value"])
df_cat.withColumn(
    "category",
    F.when(F.col("value") > 100, "high")
     .when(F.col("value") > 50, "medium")
     .otherwise("low")
).show()
```

### Array Operations

```python
# BAD: UDF to get unique sorted elements
@F.udf(ArrayType(StringType()))
def unique_sorted_udf(arr):
    if arr is None:
        return None
    return sorted(set(arr))

# GOOD: Native functions
arr_df = spark.createDataFrame(
    [([3, 1, 2, 1, 3],), ([5, 5, 5],), (None,)],
    schema=StructType([StructField("nums", ArrayType(IntegerType()))])
)

arr_df.withColumn(
    "unique_sorted", F.array_sort(F.array_distinct("nums"))
).show()
```

### Date Operations

```python
# BAD: UDF for date calculation
@F.udf(IntegerType())
def days_until_end_of_month_udf(date_str):
    from datetime import datetime
    dt = datetime.strptime(date_str, "%Y-%m-%d")
    import calendar
    last_day = calendar.monthrange(dt.year, dt.month)[1]
    return last_day - dt.day

# GOOD: Native functions
date_df = spark.createDataFrame([("2024-01-15",), ("2024-02-20",)], ["date_str"])
date_df.withColumn("date", F.to_date("date_str")).withColumn(
    "days_remaining",
    F.datediff(F.last_day("date"), F.col("date"))
).show()
```

### JSON Parsing

```python
# BAD: UDF for JSON parsing
import json

@F.udf(StringType())
def extract_json_field_udf(json_str):
    try:
        data = json.loads(json_str)
        return data.get("name")
    except:
        return None

# GOOD: Native functions
json_df = spark.createDataFrame(
    [('{"name": "Alice", "age": 30}',), ('{"name": "Bob"}',)], ["json_str"]
)

json_df.withColumn(
    "name", F.get_json_object("json_str", "$.name")
).show()

# Or parse full JSON with schema
json_schema = StructType([
    StructField("name", StringType()),
    StructField("age", IntegerType()),
])

json_df.withColumn(
    "parsed", F.from_json("json_str", json_schema)
).select("parsed.*").show()
```

---

## Part 6: When UDFs Are Actually Justified

```python
# 1. Complex business logic that cannot be expressed with built-in functions
@F.pandas_udf(DoubleType())
def haversine_distance(lat1: pd.Series, lon1: pd.Series,
                       lat2: pd.Series, lon2: pd.Series) -> pd.Series:
    """Calculate great-circle distance between two points.
    This involves chained trigonometric operations that are cleaner as a UDF."""
    import numpy as np
    R = 6371  # Earth's radius in km
    dlat = np.radians(lat2 - lat1)
    dlon = np.radians(lon2 - lon1)
    a = (np.sin(dlat / 2) ** 2 +
         np.cos(np.radians(lat1)) * np.cos(np.radians(lat2)) *
         np.sin(dlon / 2) ** 2)
    return 2 * R * np.arcsin(np.sqrt(a))


# 2. Using external libraries (ML model scoring, NLP, etc.)
@F.pandas_udf(StringType())
def sentiment_analysis(texts: pd.Series) -> pd.Series:
    """Example: using an NLP library that only works in Python."""
    # from textblob import TextBlob
    # return texts.apply(lambda t: TextBlob(t).sentiment.polarity)
    return texts.apply(lambda t: "positive" if t else "neutral")  # placeholder


# 3. Stateful per-partition processing
def process_partition_with_state(pdf: pd.DataFrame) -> pd.DataFrame:
    """Track running state across rows within a group."""
    balance = 0
    balances = []
    for _, row in pdf.iterrows():
        balance += row["amount"]
        balances.append(balance)
    pdf["running_balance"] = balances
    return pdf
```

---

## Part 7: UDF Registration for SQL

```python
# Register UDF for use in Spark SQL
spark.udf.register("title_case_sql", lambda s: s.title() if s else None, StringType())

df.createOrReplaceTempView("employees")

spark.sql("""
    SELECT id, title_case_sql(name) as name_clean, salary
    FROM employees
    WHERE salary > 60000
""").show(truncate=False)
```

### Expected Output

```
+---+-------------+-------+
|id |name_clean   |salary |
+---+-------------+-------+
|2  |Bob Johnson  |75000.0|
|3  |Charlie Brown|62000.0|
|4  |Diana Prince |91000.0|
+---+-------------+-------+
```

---

## Part 8: UDF Error Handling

```python
# Regular UDF with error handling
@F.udf(DoubleType())
def safe_divide_udf(a, b):
    try:
        if b == 0 or b is None:
            return None
        return float(a) / float(b)
    except (TypeError, ValueError):
        return None

# Better: Native function equivalent
calc_df = spark.createDataFrame([(10, 3), (10, 0), (None, 5)], ["a", "b"])

# Native approach with null-safe division
calc_df.withColumn(
    "result",
    F.when(F.col("b") != 0, F.col("a") / F.col("b")).otherwise(None)
).show()
```

---

## Interview Tips

1. **First rule: avoid UDFs.** Always explore native functions first. PySpark has 300+ built-in functions covering strings, dates, arrays, maps, JSON, math, and more.

2. **If you must use a UDF, use Pandas UDFs.** They are 3-10x faster than regular UDFs due to Arrow-based batch serialization and vectorized operations.

3. **Regular UDFs break the Catalyst optimizer.** The optimizer cannot look inside a UDF, so it cannot push down predicates, prune columns, or optimize the execution plan around UDF calls.

4. **NULL handling in UDFs:** Regular UDFs receive Python `None` for NULL values. You must handle this explicitly. Native functions typically propagate NULLs automatically.

5. **UDFs prevent whole-stage code generation.** This is one of Spark's most important performance optimizations, and UDFs completely disable it for the affected stage.

6. **The Iterator pattern** (`Iterator[pd.Series] -> Iterator[pd.Series]`) is best when you have expensive one-time initialization (loading ML models, database connections) because the setup happens once per partition rather than once per batch.

7. **`applyInPandas`** is the most flexible option -- it gives you a full Pandas DataFrame per group. Use it for complex group-level transformations that cannot be expressed with standard aggregations.

8. **Interview answer pattern:** "I would first check if there is a built-in function. If not, I would use a Pandas UDF for the performance benefits of Arrow serialization. I would only use a regular UDF as a last resort for simple scalar transformations."
