# PySpark Implementation: Finding Duplicate Records

## Problem Statement

Finding duplicates is one of the most practical interview questions because it directly maps to real data engineering work: data quality checks, deduplication pipelines, and SCD (slowly changing dimension) logic. Interviewers want to see that you can find exact duplicates, partial duplicates (same on some columns but different on others), count them, and remove them efficiently.

### Sample Data

```python
data = [
    (1, "Alice", "Engineering", 95000),
    (2, "Bob", "Marketing", 85000),
    (3, "Alice", "Engineering", 95000),   # Exact duplicate of row 1 (different ID)
    (4, "Charlie", "Sales", 70000),
    (5, "Bob", "Marketing", 90000),       # Same name+dept as row 2, different salary
    (6, "Alice", "Engineering", 88000),   # Same name+dept as row 1, different salary
    (7, "Diana", "Sales", 70000),         # Same dept+salary as row 4, different name
    (8, "Bob", "Marketing", 85000),       # Exact duplicate of row 2
    (9, "Eve", "Engineering", 95000),     # Unique
]
columns = ["emp_id", "name", "department", "salary"]
```

### Expected Output

**Exact duplicates (same name, department, salary):**
- Alice, Engineering, 95000 (rows 1 and 3)
- Bob, Marketing, 85000 (rows 2 and 8)

**Partial duplicates (same name and department, different salary):**
- Alice in Engineering: IDs 1, 3, 6
- Bob in Marketing: IDs 2, 5, 8

---

## Method 1: groupBy + count (Finding Duplicate Groups)

The simplest and most common approach. Groups by the columns that define "duplicate" and counts occurrences.

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("FindDuplicates").getOrCreate()

data = [
    (1, "Alice", "Engineering", 95000),
    (2, "Bob", "Marketing", 85000),
    (3, "Alice", "Engineering", 95000),
    (4, "Charlie", "Sales", 70000),
    (5, "Bob", "Marketing", 90000),
    (6, "Alice", "Engineering", 88000),
    (7, "Diana", "Sales", 70000),
    (8, "Bob", "Marketing", 85000),
    (9, "Eve", "Engineering", 95000),
]
columns = ["emp_id", "name", "department", "salary"]
df = spark.createDataFrame(data, columns)

# --- Exact duplicates: same name, department, salary ---
exact_dupes = (
    df.groupBy("name", "department", "salary")
    .agg(
        F.count("*").alias("count"),
        F.collect_list("emp_id").alias("emp_ids"),
    )
    .filter(F.col("count") > 1)
)
exact_dupes.show(truncate=False)

# --- Partial duplicates: same name and department ---
partial_dupes = (
    df.groupBy("name", "department")
    .agg(
        F.count("*").alias("count"),
        F.collect_list("emp_id").alias("emp_ids"),
        F.collect_list("salary").alias("salaries"),
    )
    .filter(F.col("count") > 1)
)
partial_dupes.show(truncate=False)
```

**Output (exact duplicates):**
```
+-----+-----------+------+-----+--------+
|name |department |salary|count|emp_ids |
+-----+-----------+------+-----+--------+
|Alice|Engineering|95000 |2    |[1, 3]  |
|Bob  |Marketing  |85000 |2    |[2, 8]  |
+-----+-----------+------+-----+--------+
```

---

## Method 2: Window Function with row_number (Marking Duplicates)

This approach marks each duplicate and lets you keep the first (or last) occurrence. Best for deduplication pipelines.

```python
# Mark duplicates using row_number within each group
window_exact = (
    Window.partitionBy("name", "department", "salary")
    .orderBy("emp_id")  # Keep the row with the smallest emp_id
)

df_marked = df.withColumn("row_num", F.row_number().over(window_exact))

# Show all duplicates (row_num > 1)
duplicates_only = df_marked.filter(F.col("row_num") > 1)
print("Duplicate rows (to be removed):")
duplicates_only.show()

# Keep only first occurrence (deduplicated result)
deduped = df_marked.filter(F.col("row_num") == 1).drop("row_num")
print("Deduplicated result:")
deduped.show()
```

**Output (duplicates to remove):**
```
+------+-----+-----------+------+-------+
|emp_id| name| department|salary|row_num|
+------+-----+-----------+------+-------+
|     3|Alice|Engineering| 95000|      2|
|     8|  Bob|  Marketing| 85000|      2|
+------+-----+-----------+------+-------+
```

---

## Method 3: Self-Join (Finding Duplicate Pairs)

When you need to see which specific rows are duplicates of each other.

```python
# Self-join to find pairs of duplicates
# Join on the columns that define "duplicate"
duplicate_pairs = (
    df.alias("a")
    .join(
        df.alias("b"),
        (F.col("a.name") == F.col("b.name")) &
        (F.col("a.department") == F.col("b.department")) &
        (F.col("a.salary") == F.col("b.salary")) &
        (F.col("a.emp_id") < F.col("b.emp_id")),  # Avoid self-match and reverse pairs
    )
    .select(
        F.col("a.emp_id").alias("emp_id_1"),
        F.col("b.emp_id").alias("emp_id_2"),
        F.col("a.name"),
        F.col("a.department"),
        F.col("a.salary"),
    )
)
duplicate_pairs.show()
```

**Output:**
```
+--------+--------+-----+-----------+------+
|emp_id_1|emp_id_2| name| department|salary|
+--------+--------+-----+-----------+------+
|       1|       3|Alice|Engineering| 95000|
|       2|       8|  Bob|  Marketing| 85000|
+--------+--------+-----+-----------+------+
```

**Note:** `a.emp_id < b.emp_id` ensures we only get each pair once and exclude self-matches.

---

## Method 4: Using count() Window Function (Tag Without Grouping)

Keep all original rows but tag which ones are duplicates.

```python
# Add a duplicate count to each row without collapsing groups
window_count = Window.partitionBy("name", "department", "salary")

df_tagged = (
    df.withColumn("dupe_count", F.count("*").over(window_count))
    .withColumn("is_duplicate", F.when(F.col("dupe_count") > 1, True).otherwise(False))
)
df_tagged.orderBy("name", "emp_id").show()
```

**Output:**
```
+------+-------+-----------+------+----------+------------+
|emp_id|   name| department|salary|dupe_count|is_duplicate|
+------+-------+-----------+------+----------+------------+
|     1|  Alice|Engineering| 95000|         2|        true|
|     3|  Alice|Engineering| 95000|         2|        true|
|     6|  Alice|Engineering| 88000|         1|       false|
|     2|    Bob|  Marketing| 85000|         2|        true|
|     5|    Bob|  Marketing| 90000|         1|       false|
|     8|    Bob|  Marketing| 85000|         2|        true|
|     4|Charlie|      Sales| 70000|         1|       false|
|     7|  Diana|      Sales| 70000|         1|       false|
|     9|    Eve|Engineering| 95000|         1|       false|
+------+-------+-----------+------+----------+------------+
```

---

## Method 5: dropDuplicates (Quick Deduplication)

PySpark's built-in method for removing exact duplicates.

```python
# Remove exact duplicates across ALL columns
df_no_id = df.drop("emp_id")  # Remove ID since it makes every row unique
deduped_all = df_no_id.dropDuplicates()
print(f"Before: {df_no_id.count()} rows, After: {deduped_all.count()} rows")

# Remove duplicates based on specific columns (keeps first encountered row)
deduped_subset = df.dropDuplicates(["name", "department"])
print("Deduplicated by name + department:")
deduped_subset.show()
```

**Important:** `dropDuplicates()` keeps an arbitrary row from each duplicate group. You CANNOT control which row is kept (e.g., the one with the highest salary). For that, use the window function approach with `row_number()`.

---

## Method 6: Counting Duplicates Per Group (Reporting)

For data quality reports: how many duplicate groups exist and how severe is the duplication.

```python
# Summary statistics about duplication
dupe_summary = (
    df.groupBy("name", "department", "salary")
    .agg(F.count("*").alias("occurrences"))
    .withColumn("dupe_status",
        F.when(F.col("occurrences") == 1, "unique")
        .when(F.col("occurrences") == 2, "duplicate_pair")
        .otherwise("multiple_duplicates")
    )
)

# Overall duplication stats
print("=== Duplication Summary ===")
dupe_summary.groupBy("dupe_status").agg(
    F.count("*").alias("num_groups"),
    F.sum("occurrences").alias("total_rows"),
).show()

# Duplication rate
total_rows = df.count()
unique_rows = df.dropDuplicates(["name", "department", "salary"]).count()
dupe_rate = (total_rows - unique_rows) / total_rows * 100
print(f"Duplication rate: {dupe_rate:.1f}%")
```

---

## Method 7: Finding Duplicates with NULL Handling

NULLs require special attention because `NULL != NULL` in standard comparisons.

```python
data_with_nulls = [
    (1, "Alice", None, 95000),
    (2, "Alice", None, 95000),   # Should be a duplicate of row 1
    (3, "Bob", "Marketing", None),
    (4, "Bob", "Marketing", None),  # Should be a duplicate of row 3
]
df_nulls = spark.createDataFrame(data_with_nulls, ["emp_id", "name", "department", "salary"])

# groupBy treats NULLs as equal (correct behavior for finding duplicates)
df_nulls.groupBy("name", "department", "salary").count().show()
# This works correctly -- NULLs are grouped together

# dropDuplicates also treats NULLs as equal
df_nulls.dropDuplicates(["name", "department", "salary"]).show()

# But self-join does NOT (NULL != NULL in join conditions)
# You need eqNullSafe for NULL-safe comparison
duplicate_pairs_null_safe = (
    df_nulls.alias("a")
    .join(
        df_nulls.alias("b"),
        (F.col("a.name").eqNullSafe(F.col("b.name"))) &
        (F.col("a.department").eqNullSafe(F.col("b.department"))) &
        (F.col("a.salary").eqNullSafe(F.col("b.salary"))) &
        (F.col("a.emp_id") < F.col("b.emp_id")),
    )
    .select(F.col("a.emp_id").alias("id_1"), F.col("b.emp_id").alias("id_2"))
)
duplicate_pairs_null_safe.show()
```

---

## Key Takeaways

- **groupBy + count** is the fastest way to identify duplicate groups. Use `filter(count > 1)`.
- **row_number() window function** is best for deduplication because you can control which row to keep (e.g., most recent, highest salary).
- **Self-join** is useful when you need to see specific duplicate pairs but is O(n^2) and expensive.
- **dropDuplicates()** is the simplest but gives you no control over which row is retained.
- **NULLs** are grouped together by `groupBy` and `dropDuplicates`, but NOT by join conditions (use `eqNullSafe`).
- Always clarify with the interviewer: "Are we looking for exact duplicates across all columns, or duplicates on specific columns?"

## Interview Tips

- Start by asking what defines a "duplicate" -- all columns or a subset? This is a critical clarification.
- Show the groupBy approach first (simple and efficient), then the window function approach (more powerful).
- If asked to "remove duplicates and keep the most recent," use `row_number()` with `orderBy(col("date").desc())`.
- Mention `collect_list()` as a way to see which specific IDs are duplicated -- interviewers love this for data quality reporting.
- Know that `dropDuplicates` is non-deterministic about which row is kept. In production, always use window functions when the choice matters.
- Mention that `distinct()` operates on ALL columns (including ID), so it rarely removes anything unless rows are truly identical.
