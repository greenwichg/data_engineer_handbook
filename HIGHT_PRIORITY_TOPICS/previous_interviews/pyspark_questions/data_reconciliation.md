# PySpark Implementation: Data Reconciliation (Two-Source Comparison)

## Problem Statement 

Given two versions of the same dataset — a **source** (upstream system extract) and a **target** (data warehouse table) — compare them to find all **additions, deletions, and modifications**. Then produce a reconciliation report showing the row counts, match rate, and detailed change log. This is an essential data engineering pattern for validating ETL pipelines, auditing data quality, and implementing change data capture (CDC).

### Sample Data

**Source (Today's Extract):**
```
id   name       email              salary   dept
1    Alice      alice@new.com      120000   Engineering
2    Bob        bob@co.com         95000    Marketing
3    Charlie    charlie@co.com     110000   Engineering
5    Eve        eve@co.com         88000    Sales
6    Frank      frank@co.com       72000    Marketing
```

**Target (Current Warehouse):**
```
id   name       email              salary   dept
1    Alice      alice@co.com       115000   Engineering
2    Bob        bob@co.com         95000    Marketing
3    Charlie    charlie@co.com     110000   Engineering
4    Diana      diana@co.com       98000    Sales
```

### Expected Reconciliation

| id | change_type | details |
|----|------------|---------|
| 1  | MODIFIED   | email changed (alice@co.com → alice@new.com), salary changed (115000 → 120000) |
| 2  | UNCHANGED  | — |
| 3  | UNCHANGED  | — |
| 4  | DELETED    | In target but not in source |
| 5  | ADDED      | In source but not in target |
| 6  | ADDED      | In source but not in target |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, lit, coalesce, concat, concat_ws, \
    md5, array, count, sum as spark_sum
from pyspark.sql.types import StringType

# Initialize Spark session
spark = SparkSession.builder.appName("DataReconciliation").getOrCreate()

# Source data (today's extract)
source_data = [
    (1, "Alice", "alice@new.com", 120000, "Engineering"),
    (2, "Bob", "bob@co.com", 95000, "Marketing"),
    (3, "Charlie", "charlie@co.com", 110000, "Engineering"),
    (5, "Eve", "eve@co.com", 88000, "Sales"),
    (6, "Frank", "frank@co.com", 72000, "Marketing")
]
source = spark.createDataFrame(source_data, ["id", "name", "email", "salary", "dept"])

# Target data (current warehouse)
target_data = [
    (1, "Alice", "alice@co.com", 115000, "Engineering"),
    (2, "Bob", "bob@co.com", 95000, "Marketing"),
    (3, "Charlie", "charlie@co.com", 110000, "Engineering"),
    (4, "Diana", "diana@co.com", 98000, "Sales")
]
target = spark.createDataFrame(target_data, ["id", "name", "email", "salary", "dept"])

# =========================================
# Step 1: Find ADDED records (in source, not in target)
# =========================================
added = source.join(target, on="id", how="left_anti") \
    .withColumn("change_type", lit("ADDED"))

# =========================================
# Step 2: Find DELETED records (in target, not in source)
# =========================================
deleted = target.join(source, on="id", how="left_anti") \
    .withColumn("change_type", lit("DELETED"))

# =========================================
# Step 3: Find MODIFIED and UNCHANGED (in both)
# =========================================
# Join source and target on the key
s = source.alias("s")
t = target.alias("t")

common = s.join(t, col("s.id") == col("t.id"), "inner")

# Compare non-key columns using hash
compare_cols = ["name", "email", "salary", "dept"]

# Build hash of all non-key columns for quick comparison
common_with_hash = common.withColumn(
    "source_hash",
    md5(concat_ws("||",
        *[col(f"s.{c}").cast("string") for c in compare_cols]
    ))
).withColumn(
    "target_hash",
    md5(concat_ws("||",
        *[col(f"t.{c}").cast("string") for c in compare_cols]
    ))
)

# Classify as MODIFIED or UNCHANGED
modified = common_with_hash.filter(
    col("source_hash") != col("target_hash")
).select(
    col("s.id"), col("s.name"), col("s.email"), col("s.salary"), col("s.dept")
).withColumn("change_type", lit("MODIFIED"))

unchanged = common_with_hash.filter(
    col("source_hash") == col("target_hash")
).select(
    col("s.id"), col("s.name"), col("s.email"), col("s.salary"), col("s.dept")
).withColumn("change_type", lit("UNCHANGED"))

# =========================================
# Step 4: Combine all results
# =========================================
reconciled = added.unionByName(deleted).unionByName(modified).unionByName(unchanged)
reconciled.orderBy("id").show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1-2: Anti-Joins for Additions and Deletions

```
Source IDs: {1, 2, 3, 5, 6}
Target IDs: {1, 2, 3, 4}

ADDED = Source - Target = {5, 6}     (left_anti: source vs target)
DELETED = Target - Source = {4}      (left_anti: target vs source)
COMMON = Source ∩ Target = {1, 2, 3} (inner join)
```

#### Step 3: Hash Comparison for Modifications

For each common record, hash all non-key columns and compare:

| id | source_hash | target_hash | match? |
|----|------------|------------|--------|
| 1  | abc123...  | def456...  | NO → MODIFIED |
| 2  | xyz789...  | xyz789...  | YES → UNCHANGED |
| 3  | ghi012...  | ghi012...  | YES → UNCHANGED |

---

## Extension: Detailed Column-Level Change Report

```python
# For MODIFIED records, show exactly which columns changed
detailed = s.join(t, col("s.id") == col("t.id"), "inner")

# Check each column individually
for c in compare_cols:
    detailed = detailed.withColumn(
        f"{c}_changed",
        when(col(f"s.{c}") != col(f"t.{c}"), True).otherwise(False)
    ).withColumn(
        f"{c}_diff",
        when(col(f"s.{c}") != col(f"t.{c}"),
             concat(col(f"t.{c}").cast("string"), lit(" → "), col(f"s.{c}").cast("string")))
        .otherwise(lit(None))
    )

# Filter to only changed records
change_details = detailed.filter(
    col("name_changed") | col("email_changed") |
    col("salary_changed") | col("dept_changed")
)

# Show changes
change_details.select(
    col("s.id").alias("id"),
    "name_diff", "email_diff", "salary_diff", "dept_diff"
).show(truncate=False)
```

- **Output:**

  | id | name_diff | email_diff                    | salary_diff      | dept_diff |
  |----|-----------|-------------------------------|------------------|-----------|
  | 1  | null      | alice@co.com → alice@new.com  | 115000 → 120000  | null      |

---

## Extension: Reconciliation Summary Report

```python
# Summary statistics
summary = reconciled.groupBy("change_type").agg(
    count("*").alias("row_count")
)

# Add percentages
total = reconciled.count()
summary = summary.withColumn(
    "percentage",
    spark_round(col("row_count") / lit(total) * 100, 1)
)

summary.orderBy("change_type").show(truncate=False)

# Overall metrics
print(f"Source count: {source.count()}")
print(f"Target count: {target.count()}")
print(f"Added: {added.count()}")
print(f"Deleted: {deleted.count()}")
print(f"Modified: {modified.count()}")
print(f"Unchanged: {unchanged.count()}")
print(f"Match rate: {unchanged.count() / source.count() * 100:.1f}%")
```

- **Output:**

  | change_type | row_count | percentage |
  |------------|-----------|-----------|
  | ADDED      | 2         | 33.3      |
  | DELETED    | 1         | 16.7      |
  | MODIFIED   | 1         | 16.7      |
  | UNCHANGED  | 2         | 33.3      |

---

## Extension: Handle Composite Keys

```python
# When the primary key is multiple columns
composite_source = spark.createDataFrame([
    ("US", "2025-01", 1000), ("US", "2025-02", 1200),
    ("UK", "2025-01", 800), ("UK", "2025-03", 950)
], ["country", "month", "revenue"])

composite_target = spark.createDataFrame([
    ("US", "2025-01", 1000), ("US", "2025-02", 1100),
    ("UK", "2025-01", 800), ("UK", "2025-02", 750)
], ["country", "month", "revenue"])

key_cols = ["country", "month"]
value_cols = ["revenue"]

# Anti-joins on composite key
added_composite = composite_source.join(composite_target, on=key_cols, how="left_anti")
deleted_composite = composite_target.join(composite_source, on=key_cols, how="left_anti")

# Modified detection
cs = composite_source.alias("cs")
ct = composite_target.alias("ct")

join_cond = [col(f"cs.{k}") == col(f"ct.{k}") for k in key_cols]

modified_composite = cs.join(ct, join_cond, "inner").filter(
    col("cs.revenue") != col("ct.revenue")
).select(
    *[col(f"cs.{k}") for k in key_cols],
    col("ct.revenue").alias("old_revenue"),
    col("cs.revenue").alias("new_revenue")
)

print("Added:"); added_composite.show()
print("Deleted:"); deleted_composite.show()
print("Modified:"); modified_composite.show()
```

---

## Method 2: Using SQL

```python
source.createOrReplaceTempView("source_data")
target.createOrReplaceTempView("target_data")

spark.sql("""
    -- Full reconciliation in one query using FULL OUTER JOIN
    SELECT
        COALESCE(s.id, t.id) AS id,
        CASE
            WHEN t.id IS NULL THEN 'ADDED'
            WHEN s.id IS NULL THEN 'DELETED'
            WHEN MD5(CONCAT_WS('||', s.name, s.email, CAST(s.salary AS STRING), s.dept))
              != MD5(CONCAT_WS('||', t.name, t.email, CAST(t.salary AS STRING), t.dept))
            THEN 'MODIFIED'
            ELSE 'UNCHANGED'
        END AS change_type,
        s.name AS new_name, t.name AS old_name,
        s.email AS new_email, t.email AS old_email,
        s.salary AS new_salary, t.salary AS old_salary
    FROM source_data s
    FULL OUTER JOIN target_data t ON s.id = t.id
    ORDER BY COALESCE(s.id, t.id)
""").show(truncate=False)
```

**The full outer join approach** is more concise — it handles all four cases (added, deleted, modified, unchanged) in a single join by checking which side is null.

---

## Method 3: Using EXCEPT for Quick Mismatch Detection

```python
# Quick check: are there ANY differences?
source_minus_target = source.exceptAll(target)
target_minus_source = target.exceptAll(source)

print(f"Rows in source but not in target (exact match): {source_minus_target.count()}")
print(f"Rows in target but not in source (exact match): {target_minus_source.count()}")

# If both are 0, the datasets are identical
if source_minus_target.count() == 0 and target_minus_source.count() == 0:
    print("Datasets are IDENTICAL")
else:
    print("Datasets DIFFER — run full reconciliation")
    source_minus_target.show()
```

**Use case:** Quick validation before running the full column-level comparison.

---

## Key Interview Talking Points

1. **Three-pronged approach:** Anti-join for additions, reverse anti-join for deletions, inner join + hash comparison for modifications. This covers all cases efficiently.

2. **Hash comparison vs column-by-column:** `md5(concat_ws(...))` is fast for detecting whether any column changed. Column-by-column comparison tells you exactly what changed. Use hash first, then detail only for changed rows.

3. **Full outer join alternative:** A single full outer join with CASE WHEN can detect all four states (added, deleted, modified, unchanged) in one pass. More concise but harder to read.

4. **EXCEPT for quick validation:** `source.exceptAll(target)` checks if datasets are identical row-by-row. It's the fastest way to answer "are these two datasets the same?" but doesn't tell you which keys differ.

5. **Real-world use cases:**
   - ETL pipeline validation (does target match source after load?)
   - Data migration verification (old system vs new system)
   - CDC implementation (what changed since last extract?)
   - Audit logging (track all changes for compliance)
   - A/B data pipeline testing (compare output of old vs new logic)
