# PySpark Implementation: Find Missing Sequence Numbers

## Problem Statement
Given a table of invoices with invoice numbers that should be sequential, find all missing invoice numbers in the sequence. This is a common data quality check pattern asked in interviews — it applies to order IDs, ticket numbers, check numbers, or any sequential identifier.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("MissingSequenceNumbers").getOrCreate()

data = [
    (1001, "2025-01-01", 250.00),
    (1002, "2025-01-02", 130.00),
    (1004, "2025-01-04", 320.00),
    (1005, "2025-01-05", 180.00),
    (1008, "2025-01-08", 410.00),
    (1010, "2025-01-10", 550.00),
]

columns = ["invoice_no", "invoice_date", "amount"]
df = spark.createDataFrame(data, columns)
df.show()
```

```
+----------+------------+------+
|invoice_no|invoice_date|amount|
+----------+------------+------+
|      1001|  2025-01-01| 250.0|
|      1002|  2025-01-02| 130.0|
|      1004|  2025-01-04| 320.0|
|      1005|  2025-01-05| 180.0|
|      1008|  2025-01-08| 410.0|
|      1010|  2025-01-10| 550.0|
+----------+------------+------+
```

### Expected Output
```
+------------------+
|missing_invoice_no|
+------------------+
|              1003|
|              1006|
|              1007|
|              1009|
+------------------+
```

---

## Method 1: Generate Full Sequence and Anti-Join (Recommended)

```python
# Step 1: Find the min and max invoice numbers
bounds = df.agg(
    F.min("invoice_no").alias("min_no"),
    F.max("invoice_no").alias("max_no"),
).collect()[0]

min_no = bounds["min_no"]
max_no = bounds["max_no"]

# Step 2: Generate the complete sequence from min to max
full_sequence = spark.range(min_no, max_no + 1).withColumnRenamed("id", "invoice_no")

# Step 3: Anti-join to find missing numbers
missing = full_sequence.join(
    df.select("invoice_no"),
    on="invoice_no",
    how="left_anti"
)
missing.orderBy("invoice_no").show()
```

### Step-by-Step Explanation

#### Step 1: Find min and max
- **What happens:** Scans the DataFrame once to find boundaries: min=1001, max=1010.

#### Step 2: Generate full sequence
- **What happens:** `spark.range(1001, 1011)` creates a DataFrame with all integers from 1001 to 1010.
- **Output (full_sequence):**

  | invoice_no |
  |------------|
  | 1001       |
  | 1002       |
  | 1003       |
  | ...        |
  | 1010       |

#### Step 3: Left anti-join
- **What happens:** Keeps only numbers from the full sequence that do NOT exist in the original data.
- **Output:** 1003, 1006, 1007, 1009

---

## Method 2: Using lag() to Detect Gaps

```python
from pyspark.sql.window import Window

# Step 1: Order and compute the gap to the previous invoice number
window_spec = Window.orderBy("invoice_no")
with_gaps = df.withColumn("prev_no", F.lag("invoice_no").over(window_spec))

# Step 2: Find rows where the gap is more than 1
gaps = with_gaps.filter(
    (F.col("prev_no").isNotNull()) &
    (F.col("invoice_no") - F.col("prev_no") > 1)
).select(
    F.col("prev_no").alias("gap_start"),
    F.col("invoice_no").alias("gap_end"),
)

# Step 3: Explode the gaps into individual missing numbers
missing = gaps.select(
    F.explode(
        F.sequence(F.col("gap_start") + 1, F.col("gap_end") - 1)
    ).alias("missing_invoice_no")
)
missing.orderBy("missing_invoice_no").show()
```

### Step-by-Step Explanation

#### Step 1: Compute previous invoice number with lag()
- **Output (with_gaps):**

  | invoice_no | prev_no |
  |------------|---------|
  | 1001       | null    |
  | 1002       | 1001    |
  | 1004       | 1002    |
  | 1005       | 1004    |
  | 1008       | 1005    |
  | 1010       | 1008    |

#### Step 2: Filter where gap > 1
- **Output (gaps):**

  | gap_start | gap_end |
  |-----------|---------|
  | 1002      | 1004    |
  | 1005      | 1008    |
  | 1008      | 1010    |

#### Step 3: Explode each gap into individual numbers
- **What happens:** `sequence(1003, 1003)` → [1003], `sequence(1006, 1007)` → [1006, 1007], `sequence(1009, 1009)` → [1009]
- **Output:** 1003, 1006, 1007, 1009

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("invoices")

result_sql = spark.sql("""
    WITH bounds AS (
        SELECT MIN(invoice_no) AS min_no, MAX(invoice_no) AS max_no
        FROM invoices
    ),
    full_seq AS (
        SELECT EXPLODE(SEQUENCE(min_no, max_no)) AS invoice_no
        FROM bounds
    )
    SELECT f.invoice_no AS missing_invoice_no
    FROM full_seq f
    LEFT ANTI JOIN invoices i ON f.invoice_no = i.invoice_no
    ORDER BY f.invoice_no
""")
result_sql.show()
```

---

## Variation: Missing Sequences per Group

Find missing invoice numbers per branch/store:

```python
branch_data = [
    ("East", 101), ("East", 102), ("East", 105),
    ("West", 201), ("West", 203), ("West", 204),
]

branch_df = spark.createDataFrame(branch_data, ["branch", "invoice_no"])

# Get min/max per branch
bounds_per_branch = branch_df.groupBy("branch").agg(
    F.min("invoice_no").alias("min_no"),
    F.max("invoice_no").alias("max_no"),
)

# Generate full sequences per branch
full_per_branch = bounds_per_branch.select(
    "branch",
    F.explode(F.sequence(F.col("min_no"), F.col("max_no"))).alias("invoice_no"),
)

# Anti-join to find missing
missing_per_branch = full_per_branch.join(
    branch_df, on=["branch", "invoice_no"], how="left_anti"
)
missing_per_branch.orderBy("branch", "invoice_no").show()
```

**Output:**
```
+------+----------+
|branch|invoice_no|
+------+----------+
|  East|       103|
|  East|       104|
|  West|       202|
+------+----------+
```

---

## Comparison of Methods

| Method | Scalability | Handles Large Gaps? | Handles Groups? |
|--------|-------------|---------------------|-----------------|
| Generate + Anti-Join | Best for moderate ranges | Yes — generates all numbers | Easy with per-group bounds |
| lag() + explode | Best for large sparse ranges | Yes — only expands gaps | Requires partitionBy in window |
| Spark SQL | Same as Method 1 | Yes | Yes |

## Key Interview Talking Points

1. **spark.range()** is the most efficient way to generate a numeric sequence — it creates a distributed DataFrame without collecting to the driver.
2. **lag() approach** is more memory-efficient when the total range is huge but gaps are small, since it only materializes the missing numbers.
3. **sequence() function** (Spark 2.4+) generates an array of integers between two values — combined with `explode()`, it avoids collecting to the driver.
4. Always clarify with the interviewer: "Should I find gaps within the existing range, or do you know the expected full range (e.g., 1001–1050)?"
5. This pattern is commonly combined with **data quality checks** — missing sequence numbers may indicate dropped records, failed inserts, or ETL issues.
