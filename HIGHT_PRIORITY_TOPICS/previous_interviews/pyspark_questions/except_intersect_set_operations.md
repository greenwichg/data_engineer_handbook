# PySpark Implementation: EXCEPT, INTERSECT, and Set Operations

## Problem Statement

Given two datasets — a **current month's active users** list and a **previous month's active users** list — find:
1. **New users** (in current but not in previous) → EXCEPT
2. **Retained users** (in both months) → INTERSECT
3. **Churned users** (in previous but not in current) → EXCEPT (reversed)
4. **All unique users** (combined) → UNION

These set operations are fundamental for user cohort analysis, data reconciliation, and comparison queries — commonly asked in analytics-focused interviews.

### Sample Data

**Current Month (January 2025):**
```
user_id  user_name
U001     Alice
U002     Bob
U003     Charlie
U005     Eve
U007     Grace
```

**Previous Month (December 2024):**
```
user_id  user_name
U001     Alice
U003     Charlie
U004     Diana
U006     Frank
U007     Grace
```

### Expected Results

| Operation | Users | Description |
|-----------|-------|-------------|
| New (EXCEPT) | U002 Bob, U005 Eve | In Jan but not Dec |
| Retained (INTERSECT) | U001 Alice, U003 Charlie, U007 Grace | In both months |
| Churned (EXCEPT reversed) | U004 Diana, U006 Frank | In Dec but not Jan |

---

## Method 1: EXCEPT (Difference)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit

# Initialize Spark session
spark = SparkSession.builder.appName("SetOperations").getOrCreate()

# Current month users
current_data = [
    ("U001", "Alice"), ("U002", "Bob"), ("U003", "Charlie"),
    ("U005", "Eve"), ("U007", "Grace")
]
current_df = spark.createDataFrame(current_data, ["user_id", "user_name"])

# Previous month users
previous_data = [
    ("U001", "Alice"), ("U003", "Charlie"), ("U004", "Diana"),
    ("U006", "Frank"), ("U007", "Grace")
]
previous_df = spark.createDataFrame(previous_data, ["user_id", "user_name"])

# NEW USERS: In current but NOT in previous
new_users = current_df.exceptAll(previous_df)
print("New Users (Current EXCEPT Previous):")
new_users.show()

# CHURNED USERS: In previous but NOT in current
churned_users = previous_df.exceptAll(current_df)
print("Churned Users (Previous EXCEPT Current):")
churned_users.show()
```

### Output

**New Users:**

| user_id | user_name |
|---------|-----------|
| U002    | Bob       |
| U005    | Eve       |

**Churned Users:**

| user_id | user_name |
|---------|-----------|
| U004    | Diana     |
| U006    | Frank     |

---

## Method 2: INTERSECT (Common Records)

```python
# RETAINED USERS: In both current AND previous
retained_users = current_df.intersectAll(previous_df)
print("Retained Users (INTERSECT):")
retained_users.show()
```

- **Output:**

  | user_id | user_name |
  |---------|-----------|
  | U001    | Alice     |
  | U003    | Charlie   |
  | U007    | Grace     |

---

## Method 3: UNION and UNION ALL

```python
# UNION ALL: Combines all rows (including duplicates)
all_users_with_dupes = current_df.unionAll(previous_df)
print(f"Union All count: {all_users_with_dupes.count()}")  # 10

# UNION (distinct): Combines and removes duplicates
all_unique_users = current_df.union(previous_df).distinct()
print(f"Union Distinct count: {all_unique_users.count()}")  # 7
all_unique_users.orderBy("user_id").show()
```

- **Output (all unique users):**

  | user_id | user_name |
  |---------|-----------|
  | U001    | Alice     |
  | U002    | Bob       |
  | U003    | Charlie   |
  | U004    | Diana     |
  | U005    | Eve       |
  | U006    | Frank     |
  | U007    | Grace     |

---

## except vs exceptAll vs subtract

```python
# Handling duplicates in set operations

# Data with duplicates
df_a = spark.createDataFrame([(1, "A"), (1, "A"), (2, "B")], ["id", "val"])
df_b = spark.createDataFrame([(1, "A")], ["id", "val"])

# except: Removes all matching rows + deduplicates result
result_except = df_a.exceptAll(df_b)  # Wrong — this is exceptAll
result_except_dedup = df_a.subtract(df_b)  # or df_a.except(df_b) — both deduplicate

# exceptAll: Removes only as many rows as exist in the right DataFrame
result_exceptAll = df_a.exceptAll(df_b)

print("subtract (deduplicates):")
df_a.subtract(df_b).show()
# Output: (2, "B") — only one row, duplicates of (1, "A") removed entirely

print("exceptAll (preserves count):")
df_a.exceptAll(df_b).show()
# Output: (1, "A"), (2, "B") — removes ONE copy of (1, "A"), keeps the other
```

### Comparison Table

| Operation | Duplicates in A | Matching in B | Result |
|-----------|----------------|---------------|--------|
| `subtract` / `except` | 2 copies of X | 1 copy of X | 0 copies (deduplicates all) |
| `exceptAll` | 2 copies of X | 1 copy of X | 1 copy of X (removes only 1) |
| `intersect` | 2 copies of X | 1 copy of X | 1 copy (deduplicated) |
| `intersectAll` | 2 copies of X | 1 copy of X | 1 copy (min of counts) |

---

## Method 4: Using Joins as Alternatives

```python
# LEFT ANTI JOIN = EXCEPT (more flexible, allows different schemas)
new_users_join = current_df.join(previous_df, on="user_id", how="left_anti")
print("New Users (left_anti join):")
new_users_join.show()

# INNER JOIN = INTERSECT (can select columns from both)
retained_join = current_df.join(previous_df, on="user_id", how="inner") \
    .select(current_df.user_id, current_df.user_name)
print("Retained Users (inner join):")
retained_join.show()

# LEFT SEMI JOIN = INTERSECT (returns only left columns, like exists)
retained_semi = current_df.join(previous_df, on="user_id", how="left_semi")
print("Retained Users (left_semi join):")
retained_semi.show()
```

### When to Use Joins vs Set Operations

| Scenario | Use Set Operation | Use Join |
|----------|-------------------|----------|
| Same schema, exact match on all columns | `except`, `intersect` | Overkill |
| Match on subset of columns | Can't do directly | `left_anti`, `left_semi` |
| Need columns from both DataFrames | Can't do | `inner`, `left` |
| Different column names | Can't do | Join with renamed columns |
| Handling duplicates precisely | `exceptAll`, `intersectAll` | More complex |

---

## Method 5: Complete Cohort Analysis

```python
from pyspark.sql.functions import when, count

# Tag each user with their cohort status
tagged = current_df.withColumn("in_current", lit(True)) \
    .join(
        previous_df.withColumn("in_previous", lit(True)),
        on="user_id",
        how="full_outer"
    ) \
    .withColumn(
        "cohort",
        when(col("in_current") & col("in_previous"), "Retained")
        .when(col("in_current") & col("in_previous").isNull(), "New")
        .when(col("in_current").isNull() & col("in_previous"), "Churned")
    ) \
    .select(
        "user_id",
        current_df.user_name,
        "cohort"
    )

tagged.orderBy("user_id").show()

# Cohort summary
tagged.groupBy("cohort").agg(count("*").alias("user_count")).show()
```

- **Output:**

  | user_id | user_name | cohort   |
  |---------|-----------|----------|
  | U001    | Alice     | Retained |
  | U002    | Bob       | New      |
  | U003    | Charlie   | Retained |
  | U004    | Diana     | Churned  |
  | U005    | Eve       | New      |
  | U006    | Frank     | Churned  |
  | U007    | Grace     | Retained |

  | cohort   | user_count |
  |----------|------------|
  | Retained | 3          |
  | New      | 2          |
  | Churned  | 2          |

---

## Method 6: Using SQL

```python
current_df.createOrReplaceTempView("current_users")
previous_df.createOrReplaceTempView("previous_users")

# EXCEPT
spark.sql("""
    SELECT * FROM current_users
    EXCEPT
    SELECT * FROM previous_users
""").show()

# INTERSECT
spark.sql("""
    SELECT * FROM current_users
    INTERSECT
    SELECT * FROM previous_users
""").show()

# UNION
spark.sql("""
    SELECT * FROM current_users
    UNION
    SELECT * FROM previous_users
""").show()

# EXCEPT ALL (preserves duplicates)
spark.sql("""
    SELECT * FROM current_users
    EXCEPT ALL
    SELECT * FROM previous_users
""").show()
```

---

## Requirements for Set Operations

| Requirement | Details |
|-------------|---------|
| Same number of columns | Both DataFrames must have identical column count |
| Compatible data types | Corresponding columns must have compatible types |
| Column names | Taken from the left DataFrame |
| No join condition needed | Operates on all columns by default |

## Key Interview Talking Points

1. **except vs subtract:** In PySpark, `except()` is an alias for `subtract()`. Both deduplicate. Use `exceptAll()` to preserve duplicate counts.

2. **left_anti vs except:** `left_anti` join is more flexible — it matches on specific columns, while `except` matches on ALL columns. Use `left_anti` when schemas differ or you only want to match on a key.

3. **left_semi vs intersect:** `left_semi` is like `INTERSECT` but only returns columns from the left table and matches on specific columns. `intersect` matches all columns.

4. **Performance:** Set operations require a shuffle (like a distinct + anti-join). For large datasets, consider using joins with explicit keys instead — they're easier to optimize.

5. **Real-world use cases:**
   - User retention/churn analysis (as demonstrated)
   - Data reconciliation between sources
   - Finding missing records between tables
   - Incremental data loading (new records only)
   - A/B test user overlap detection
