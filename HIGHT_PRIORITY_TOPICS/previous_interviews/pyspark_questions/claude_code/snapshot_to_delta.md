# PySpark Implementation: Snapshot-to-Delta Change Data Capture

## Problem Statement
You receive **daily full snapshots** of a customer table. Given two consecutive snapshots
(day 1 and day 2), produce a **CDC (Change Data Capture) delta** that contains only the
rows that changed between the two days. Each output row should be tagged with an operation
type: `INSERT`, `UPDATE`, or `DELETE`.

This is a common pattern in data lakes where upstream systems dump full extracts instead
of providing incremental change feeds.

### Sample Data

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, lit, when, coalesce, md5, concat_ws, struct
)
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

spark = SparkSession.builder.appName("SnapshotToDelta").getOrCreate()

# Day 1 snapshot
day1_data = [
    (1, "Alice",   "alice@email.com",   "NY"),
    (2, "Bob",     "bob@email.com",     "CA"),
    (3, "Charlie", "charlie@email.com", "TX"),
    (4, "Diana",   "diana@email.com",   "FL"),
    (5, "Eve",     "eve@email.com",     "WA"),
]

# Day 2 snapshot
day2_data = [
    (1, "Alice",   "alice@email.com",   "NY"),   # unchanged
    (2, "Bob",     "bob_new@email.com", "CA"),   # UPDATE: email changed
    (3, "Charlie", "charlie@email.com", "IL"),   # UPDATE: state changed
    # (4, Diana) is missing => DELETE
    (5, "Eve",     "eve@email.com",     "WA"),   # unchanged
    (6, "Frank",   "frank@email.com",   "OR"),   # INSERT: new customer
    (7, "Grace",   "grace@email.com",   "NV"),   # INSERT: new customer
]

schema = StructType([
    StructField("customer_id", IntegerType()),
    StructField("name", StringType()),
    StructField("email", StringType()),
    StructField("state", StringType()),
])

day1 = spark.createDataFrame(day1_data, schema)
day2 = spark.createDataFrame(day2_data, schema)

day1.show()
day2.show()
```

**Day 1 Snapshot:**

| customer_id | name    | email             | state |
|-------------|---------|-------------------|-------|
| 1           | Alice   | alice@email.com   | NY    |
| 2           | Bob     | bob@email.com     | CA    |
| 3           | Charlie | charlie@email.com | TX    |
| 4           | Diana   | diana@email.com   | FL    |
| 5           | Eve     | eve@email.com     | WA    |

**Day 2 Snapshot:**

| customer_id | name    | email              | state |
|-------------|---------|---------------------|-------|
| 1           | Alice   | alice@email.com     | NY    |
| 2           | Bob     | bob_new@email.com   | CA    |
| 3           | Charlie | charlie@email.com   | IL    |
| 5           | Eve     | eve@email.com       | WA    |
| 6           | Frank   | frank@email.com     | OR    |
| 7           | Grace   | grace@email.com     | NV    |

### Expected Output

| customer_id | operation | old_name | old_email          | old_state | new_name | new_email          | new_state |
|-------------|-----------|----------|--------------------|-----------|----------|--------------------|-----------|
| 2           | UPDATE    | Bob      | bob@email.com      | CA        | Bob      | bob_new@email.com  | CA        |
| 3           | UPDATE    | Charlie  | charlie@email.com  | TX        | Charlie  | charlie@email.com  | IL        |
| 4           | DELETE    | Diana    | diana@email.com    | FL        | NULL     | NULL               | NULL      |
| 6           | INSERT    | NULL     | NULL               | NULL      | Frank    | frank@email.com    | OR        |
| 7           | INSERT    | NULL     | NULL               | NULL      | Grace    | grace@email.com    | NV        |

---

## Method 1: Full Outer Join with Hash Comparison (Recommended)

```python
from pyspark.sql.functions import col, when, md5, concat_ws, lit

# Non-key columns used for change detection
value_cols = ["name", "email", "state"]

# Add a hash of all non-key columns for efficient comparison
day1_h = day1.withColumn(
    "row_hash", md5(concat_ws("||", *[col(c) for c in value_cols]))
)
day2_h = day2.withColumn(
    "row_hash", md5(concat_ws("||", *[col(c) for c in value_cols]))
)

# Alias for clarity in the join
d1 = day1_h.alias("d1")
d2 = day2_h.alias("d2")

# Full outer join on the business key
joined = d1.join(d2, col("d1.customer_id") == col("d2.customer_id"), "full_outer")

# Classify each row
cdc = (
    joined
    .withColumn(
        "operation",
        when(col("d1.customer_id").isNull(), lit("INSERT"))
        .when(col("d2.customer_id").isNull(), lit("DELETE"))
        .when(col("d1.row_hash") != col("d2.row_hash"), lit("UPDATE"))
    )
    .filter(col("operation").isNotNull())  # drop unchanged rows
    .select(
        coalesce(col("d1.customer_id"), col("d2.customer_id")).alias("customer_id"),
        col("operation"),
        col("d1.name").alias("old_name"),
        col("d1.email").alias("old_email"),
        col("d1.state").alias("old_state"),
        col("d2.name").alias("new_name"),
        col("d2.email").alias("new_email"),
        col("d2.state").alias("new_state"),
    )
    .orderBy("customer_id")
)

cdc.show(truncate=False)
```

### Step-by-Step Explanation

**Step 1 -- Compute row hashes on both snapshots:**

For day1 (showing customer_id 2 as example):
`md5("Bob||bob@email.com||CA")` = `a1b2c3...`

For day2 (same customer):
`md5("Bob||bob_new@email.com||CA")` = `x7y8z9...`  (different hash)

**Step 2 -- Full outer join on customer_id:**

| d1.customer_id | d1.row_hash | d2.customer_id | d2.row_hash |
|----------------|-------------|----------------|-------------|
| 1              | abc123      | 1              | abc123      |
| 2              | a1b2c3      | 2              | x7y8z9      |
| 3              | def456      | 3              | m4n5o6      |
| 4              | ghi789      | NULL           | NULL        |
| 5              | jkl012      | 5              | jkl012      |
| NULL           | NULL        | 6              | p1q2r3      |
| NULL           | NULL        | 7              | s4t5u6      |

**Step 3 -- Classify operations:**

- `d1.customer_id IS NULL` => the key only exists in day2 => **INSERT**
- `d2.customer_id IS NULL` => the key only exists in day1 => **DELETE**
- Both exist but hashes differ => **UPDATE**
- Both exist and hashes match => unchanged (filtered out)

**Step 4 -- Filter and select final columns, dropping unchanged rows (ids 1 and 5).**

---

## Method 2: exceptAll + Subtract Approach (No Join)

```python
from pyspark.sql.functions import col, lit

# Rows in day2 but not in day1 => potential inserts or the "new" side of updates
new_or_updated = day2.exceptAll(day1)

# Rows in day1 but not in day2 => potential deletes or the "old" side of updates
old_or_deleted = day1.exceptAll(day2)

# Keys that appear in both sets are updates; keys in only one set are inserts/deletes
new_keys = new_or_updated.select("customer_id").alias("nk")
old_keys = old_or_deleted.select("customer_id").alias("ok")

# INSERTS: keys in new_or_updated but not in old_or_deleted
inserts = (
    new_or_updated
    .join(old_keys, new_or_updated.customer_id == col("ok.customer_id"), "left_anti")
    .select(
        "customer_id",
        lit("INSERT").alias("operation"),
        lit(None).alias("old_name"), lit(None).alias("old_email"), lit(None).alias("old_state"),
        col("name").alias("new_name"), col("email").alias("new_email"), col("state").alias("new_state"),
    )
)

# DELETES: keys in old_or_deleted but not in new_or_updated
deletes = (
    old_or_deleted
    .join(new_keys, old_or_deleted.customer_id == col("nk.customer_id"), "left_anti")
    .select(
        "customer_id",
        lit("DELETE").alias("operation"),
        col("name").alias("old_name"), col("email").alias("old_email"), col("state").alias("old_state"),
        lit(None).alias("new_name"), lit(None).alias("new_email"), lit(None).alias("new_state"),
    )
)

# UPDATES: keys present in both sets
updates = (
    old_or_deleted.alias("o")
    .join(new_or_updated.alias("n"), "customer_id", "inner")
    .select(
        col("customer_id"),
        lit("UPDATE").alias("operation"),
        col("o.name").alias("old_name"), col("o.email").alias("old_email"), col("o.state").alias("old_state"),
        col("n.name").alias("new_name"), col("n.email").alias("new_email"), col("n.state").alias("new_state"),
    )
)

cdc = inserts.unionByName(updates).unionByName(deletes).orderBy("customer_id")
cdc.show(truncate=False)
```

---

## Key Interview Talking Points

1. **Hash comparison avoids comparing every column**: Using `md5(concat_ws(...))` turns
   an N-column equality check into a single string comparison. This is cleaner and scales
   better when tables have dozens of columns.

2. **Hash collision risk**: MD5 collisions are theoretically possible but practically
   negligible for change detection. If paranoid, use SHA-256 or follow up with a
   column-by-column check on hash-matched rows.

3. **concat_ws delimiter choice**: Use a delimiter that cannot appear in the data (e.g., `||`
   or a null byte). Otherwise `"A||B"` and `"A|" + "|B"` produce the same hash.

4. **NULL handling**: `concat_ws` skips NULLs, so `NULL` and empty string may hash the same.
   Wrap columns in `coalesce(col, lit("__NULL__"))` if your data has meaningful NULLs.

5. **exceptAll vs except**: `exceptAll` preserves duplicate rows; `except` deduplicates.
   For snapshot comparison where duplicates should not exist, either works, but `exceptAll`
   is safer and avoids an unnecessary distinct.

6. **Performance trade-off**: Method 1 (full outer join) requires one shuffle. Method 2
   (`exceptAll`) internally performs two sorts/shuffles plus additional joins. The join
   approach is generally more efficient for this use case.

7. **Real-world scale**: For very large snapshots where only a small fraction changes,
   consider bloom-filter pre-filtering or partitioning the comparison by a date or
   region column to reduce shuffle size.

8. **Delta Lake native support**: In production, Delta Lake's `MERGE INTO` or the
   `delta.tables.DeltaTable.merge()` API handles this pattern natively, including
   automatic CDC output via `delta.enableChangeDataFeed`.
