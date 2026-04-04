# PySpark Implementation: Delete Duplicate Emails (In-Place)

## Problem Statement

Given a `Person` table with `id` and `email`, delete all duplicate emails keeping only the row with the **smallest id** for each email. This is **LeetCode 196 — Delete Duplicate Emails**. The key challenge is performing an in-place DELETE, not just a SELECT of unique rows.

### Sample Data

```
id  email
1   john@example.com
2   bob@example.com
3   john@example.com
```

### Expected Output (after deletion)

| id | email            |
|----|------------------|
| 1  | john@example.com |
| 2  | bob@example.com  |

---

## Method 1: Keep First Occurrence Using row_number() (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, row_number
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("DeleteDuplicates").getOrCreate()

data = [
    (1, "john@example.com"),
    (2, "bob@example.com"),
    (3, "john@example.com")
]

columns = ["id", "email"]
df = spark.createDataFrame(data, columns)

# Assign row number partitioned by email, ordered by id ascending
w = Window.partitionBy("email").orderBy("id")

result = df.withColumn("rn", row_number().over(w)) \
    .filter(col("rn") == 1) \
    .drop("rn")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Assign row_number within each email group
- **What happens:** Rows with the same email get sequential numbers, ordered by `id` ascending. The smallest `id` gets `rn = 1`.

  | id | email            | rn |
  |----|------------------|----|
  | 1  | john@example.com | 1  |
  | 3  | john@example.com | 2  |
  | 2  | bob@example.com  | 1  |

#### Step 2: Filter for rn == 1
- **What happens:** Only the first occurrence (smallest id) is kept.

  | id | email            |
  |----|------------------|
  | 1  | john@example.com |
  | 2  | bob@example.com  |

---

## Method 2: Using groupBy + min(id) with Join

```python
from pyspark.sql.functions import col, min as spark_min

# Get the minimum id for each email
min_ids = df.groupBy("email").agg(spark_min("id").alias("min_id"))

# Join back to get full rows
result = df.join(min_ids, (df["email"] == min_ids["email"]) & (df["id"] == min_ids["min_id"])) \
    .select(df["id"], df["email"])

result.show()
```

---

## Method 3: Using dropDuplicates (PySpark Native)

```python
# Sort by id first, then drop duplicates keeping first
result = df.orderBy("id").dropDuplicates(["email"])

result.show()
```

**Caveat:** `dropDuplicates` does NOT guarantee which row is kept in terms of ordering. In practice, combining with `orderBy` before `dropDuplicates` is not guaranteed to retain order. Use `row_number()` for deterministic results.

---

## Method 4: Self-Join DELETE Pattern (SQL Equivalent)

```python
df.createOrReplaceTempView("person")

# The classic SQL DELETE approach (LeetCode expected answer)
# In SQL databases: DELETE p1 FROM Person p1, Person p2
#                   WHERE p1.email = p2.email AND p1.id > p2.id

# PySpark equivalent: identify rows to DELETE via self-join
rows_to_delete = spark.sql("""
    SELECT p1.id
    FROM person p1
    JOIN person p2 ON p1.email = p2.email AND p1.id > p2.id
""")

# Keep rows NOT in the delete list
result = spark.sql("""
    SELECT * FROM person
    WHERE id NOT IN (
        SELECT p1.id
        FROM person p1
        JOIN person p2 ON p1.email = p2.email AND p1.id > p2.id
    )
    ORDER BY id
""")

result.show()
```

---

## Method 5: Delta Lake MERGE for True In-Place Delete

```python
# If using Delta Lake, you can perform actual in-place deletes
from delta.tables import DeltaTable

# Write to Delta
df.write.format("delta").mode("overwrite").save("/tmp/person_delta")
delta_table = DeltaTable.forPath(spark, "/tmp/person_delta")

# Find ids to keep
keep_ids = df.groupBy("email").agg(spark_min("id").alias("min_id"))

# Delete rows where id is not the minimum for its email group
delta_table.alias("t").merge(
    keep_ids.alias("k"),
    "t.email = k.email AND t.id != k.min_id"
).whenMatched().delete().execute()

# Verify
spark.read.format("delta").load("/tmp/person_delta").show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| No duplicates | All emails are unique | Returns original table unchanged |
| All rows same email | Only smallest id kept | Works correctly |
| NULL emails | NULL = NULL is false in joins | Handle separately or use null-safe equals |
| Case-sensitive emails | "John@..." vs "john@..." treated as different | Use `lower()` before grouping |

## Key Interview Talking Points

1. **SELECT dedup vs. DELETE dedup:**
   - In PySpark, DataFrames are immutable — you always produce a new DataFrame.
   - True in-place DELETE requires Delta Lake or a database.
   - The interview question tests your understanding of the DELETE self-join pattern.

2. **Why self-join for DELETE?**
   - Classic SQL: `DELETE p1 FROM Person p1, Person p2 WHERE p1.email = p2.email AND p1.id > p2.id`
   - This finds every duplicate row where a smaller-id row with the same email exists.

3. **dropDuplicates pitfall:**
   - `dropDuplicates` is non-deterministic about which row is kept.
   - Never rely on it when you need to keep a specific row (e.g., smallest id).

4. **Follow-up: "What if the table has billions of rows?"**
   - Use `row_number()` approach — distributed and efficient.
   - Avoid `collect()` or `isin()` with large sets.
