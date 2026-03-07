# PySpark Implementation: Change Detection and Diffing

## Problem Statement
Given two snapshots of the same employees table (yesterday and today), classify every record into
one of four categories: **INSERT** (new in today), **UPDATE** (exists in both but values changed),
**DELETE** (missing from today), or **UNCHANGED**. Implement this using two approaches:
1. Full outer join with coalesce-based comparison.
2. Hash-based change detection using MD5 of the entire row.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

spark = SparkSession.builder.appName("ChangeDetection").getOrCreate()

# Yesterday's snapshot
yesterday_data = [
    (1, "Alice",   "Engineering", 95000),
    (2, "Bob",     "Marketing",   72000),
    (3, "Carol",   "Engineering", 88000),
    (4, "Dave",    "Sales",       67000),
    (5, "Eve",     "Marketing",   71000),
]

# Today's snapshot
today_data = [
    (1, "Alice",   "Engineering", 98000),   # UPDATE: salary changed
    (2, "Bob",     "Marketing",   72000),   # UNCHANGED
    (3, "Carol",   "Data",        92000),   # UPDATE: dept + salary changed
    (5, "Eve",     "Marketing",   71000),   # UNCHANGED
    (6, "Frank",   "Sales",       65000),   # INSERT: new employee
]
# Dave (id=4) is absent from today -> DELETE

schema = StructType([
    StructField("emp_id", IntegerType()),
    StructField("name", StringType()),
    StructField("department", StringType()),
    StructField("salary", IntegerType()),
])

df_yesterday = spark.createDataFrame(yesterday_data, schema)
df_today = spark.createDataFrame(today_data, schema)
```

### Expected Output

| emp_id | name  | department  | salary | change_type |
|--------|-------|-------------|--------|-------------|
| 1      | Alice | Engineering | 98000  | UPDATE      |
| 2      | Bob   | Marketing   | 72000  | UNCHANGED   |
| 3      | Carol | Data        | 92000  | UPDATE      |
| 4      | Dave  | Sales       | 67000  | DELETE      |
| 5      | Eve   | Marketing   | 71000  | UNCHANGED   |
| 6      | Frank | Sales       | 65000  | INSERT      |

---

## Method 1: Full Outer Join with Column Comparison (Recommended)
```python
# Alias the DataFrames for clarity
y = df_yesterday.alias("y")
t = df_today.alias("t")

# Full outer join on the business key (emp_id)
joined = y.join(t, on="emp_id", how="full_outer")

# Classify each row
change_detected = joined.select(
    coalesce(col("y.emp_id"), col("t.emp_id")).alias("emp_id"),
    coalesce(col("t.name"), col("y.name")).alias("name"),
    coalesce(col("t.department"), col("y.department")).alias("department"),
    coalesce(col("t.salary"), col("y.salary")).alias("salary"),
    when(col("y.emp_id").isNull(), lit("INSERT"))
    .when(col("t.emp_id").isNull(), lit("DELETE"))
    .when(
        (col("y.name") != col("t.name")) |
        (col("y.department") != col("t.department")) |
        (col("y.salary") != col("t.salary")),
        lit("UPDATE")
    )
    .otherwise(lit("UNCHANGED"))
    .alias("change_type")
)

change_detected.orderBy("emp_id").show()

# Summary counts
change_detected.groupBy("change_type").count().show()
```

### Step-by-Step Explanation

**Step 1 -- Full outer join produces a wide row with both sides:**

| y.emp_id | y.name | y.department | y.salary | t.emp_id | t.name | t.department | t.salary |
|----------|--------|--------------|----------|----------|--------|--------------|----------|
| 1        | Alice  | Engineering  | 95000    | 1        | Alice  | Engineering  | 98000    |
| 2        | Bob    | Marketing    | 72000    | 2        | Bob    | Marketing    | 72000    |
| 3        | Carol  | Engineering  | 88000    | 3        | Carol  | Data         | 92000    |
| 4        | Dave   | Sales        | 67000    | null     | null   | null         | null     |
| 5        | Eve    | Marketing    | 71000    | 5        | Eve    | Marketing    | 71000    |
| null     | null   | null         | null     | 6        | Frank  | Sales        | 65000    |

**Step 2 -- Classification logic:**
- Row 4: `t.emp_id IS NULL` -> DELETE (record disappeared).
- Row 6: `y.emp_id IS NULL` -> INSERT (new record appeared).
- Row 1: Both sides present, `y.salary (95000) != t.salary (98000)` -> UPDATE.
- Row 2: Both sides present, all columns match -> UNCHANGED.

**Step 3 -- coalesce picks the "current" value** for the output:
- For INSERTs, values come from today.
- For DELETEs, values come from yesterday (the last known state).
- For UPDATEs, values come from today (the new state).

---

## Method 2: Hash-Based Change Detection
```python
# Compute an MD5 hash of all non-key columns to detect changes
value_cols = ["name", "department", "salary"]

df_y_hashed = df_yesterday.withColumn(
    "row_hash", md5(concat_ws("||", *[col(c).cast("string") for c in value_cols]))
)

df_t_hashed = df_today.withColumn(
    "row_hash", md5(concat_ws("||", *[col(c).cast("string") for c in value_cols]))
)

# Full outer join on emp_id, compare hashes
joined_hash = df_y_hashed.alias("y").join(
    df_t_hashed.alias("t"),
    on="emp_id",
    how="full_outer"
)

result_hash = joined_hash.select(
    coalesce(col("y.emp_id"), col("t.emp_id")).alias("emp_id"),
    coalesce(col("t.name"), col("y.name")).alias("name"),
    coalesce(col("t.department"), col("y.department")).alias("department"),
    coalesce(col("t.salary"), col("y.salary")).alias("salary"),
    when(col("y.emp_id").isNull(), lit("INSERT"))
    .when(col("t.emp_id").isNull(), lit("DELETE"))
    .when(col("y.row_hash") != col("t.row_hash"), lit("UPDATE"))
    .otherwise(lit("UNCHANGED"))
    .alias("change_type")
)

result_hash.orderBy("emp_id").show()
```

### Why Use Hashing?
When the table has dozens of columns, comparing each one individually is verbose and error-prone.
A single hash comparison replaces N column comparisons with one string comparison. The trade-off
is a negligible collision risk with MD5 (or use SHA-256 for stricter guarantees).

```python
# Bonus: Extract only the changed rows for downstream processing
changes_only = result_hash.filter(col("change_type") != "UNCHANGED")
changes_only.show()

# Bonus: Generate a delta table with before/after values for auditing
audit_log = joined_hash.filter(
    col("y.emp_id").isNotNull() & col("t.emp_id").isNotNull()
).select(
    col("y.emp_id").alias("emp_id"),
    col("y.salary").alias("old_salary"),
    col("t.salary").alias("new_salary"),
    (col("t.salary") - col("y.salary")).alias("salary_diff"),
).filter(col("salary_diff") != 0)

audit_log.show()
```

| emp_id | old_salary | new_salary | salary_diff |
|--------|------------|------------|-------------|
| 1      | 95000      | 98000      | 3000        |
| 3      | 88000      | 92000      | 4000        |

---

## Key Interview Talking Points
1. **Full outer join is the standard CDC pattern** -- it naturally surfaces all three change types in a single pass.
2. **Hash-based detection scales better** with wide tables (50+ columns) since you compare one hash instead of N columns.
3. **NULL handling is critical:** `!=` returns NULL when either side is NULL. Use `<=>` (null-safe equals) or explicit `isNull` checks to avoid silently dropping DELETEs/INSERTs.
4. **concat_ws with a delimiter** prevents hash collisions from value shifting (e.g., "AB" + "C" vs "A" + "BC" both produce "ABC" without a separator).
5. **Performance:** The full outer join causes a shuffle on the key column. For very large tables, consider broadcast join if one snapshot is small, or use Delta Lake's `MERGE` / `CHANGES` for built-in CDC.
6. **In production pipelines,** store the change_type alongside the data to feed SCD Type 2 dimensions or incremental fact loads.
7. **Testing edge cases:** Always verify behavior with NULL column values, duplicate keys, and schema evolution (new columns added between snapshots).
8. **Delta Lake alternative:** `delta.tables.DeltaTable.forPath(...).merge(...)` handles upserts natively and tracks changes via the transaction log.
