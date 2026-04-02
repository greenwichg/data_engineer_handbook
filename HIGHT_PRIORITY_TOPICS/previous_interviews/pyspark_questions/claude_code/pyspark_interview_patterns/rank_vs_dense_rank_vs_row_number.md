# PySpark Implementation: rank() vs dense_rank() vs row_number()

## Problem Statement

Understanding the differences between `rank()`, `dense_rank()`, and `row_number()` is fundamental for PySpark interviews. All three are window functions that assign sequential numbers to rows, but they handle **tied values** differently. Interviewers test whether you know which one to use in different scenarios and what happens when there are duplicates.

### Sample Data

```python
data = [
    (1, "Alice", "Engineering", 95000),
    (2, "Bob", "Engineering", 95000),   # Tie with Alice
    (3, "Charlie", "Engineering", 90000),
    (4, "Diana", "Engineering", 85000),
    (5, "Eve", "Marketing", 80000),
    (6, "Frank", "Marketing", 80000),   # Tie with Eve
    (7, "Grace", "Marketing", 80000),   # Three-way tie
    (8, "Heidi", "Marketing", 70000),
]
columns = ["emp_id", "name", "department", "salary"]
```

### Expected Output

**Side-by-side comparison (ordered by salary descending):**

| name    | salary | row_number | rank | dense_rank |
|---------|--------|------------|------|------------|
| Alice   | 95000  | 1          | 1    | 1          |
| Bob     | 95000  | 2          | 1    | 1          |
| Charlie | 90000  | 3          | 3    | 2          |
| Diana   | 85000  | 4          | 4    | 3          |
| Eve     | 80000  | 5          | 5    | 4          |
| Frank   | 80000  | 6          | 5    | 4          |
| Grace   | 80000  | 7          | 5    | 4          |
| Heidi   | 70000  | 8          | 8    | 5          |

Key observations:
- **row_number()**: Always unique (1, 2, 3, 4...). Ties get arbitrary ordering.
- **rank()**: Same value for ties, then **skips** (1, 1, 3). The next rank after a tie reflects the actual position.
- **dense_rank()**: Same value for ties, **no skip** (1, 1, 2). Consecutive integers always.

---

## Full Comparison Code

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("RankComparison").getOrCreate()

data = [
    (1, "Alice", "Engineering", 95000),
    (2, "Bob", "Engineering", 95000),
    (3, "Charlie", "Engineering", 90000),
    (4, "Diana", "Engineering", 85000),
    (5, "Eve", "Marketing", 80000),
    (6, "Frank", "Marketing", 80000),
    (7, "Grace", "Marketing", 80000),
    (8, "Heidi", "Marketing", 70000),
]
columns = ["emp_id", "name", "department", "salary"]
df = spark.createDataFrame(data, columns)

# Define window: overall ordering by salary descending
window_all = Window.orderBy(F.col("salary").desc())

comparison = df.select(
    "name",
    "department",
    "salary",
    F.row_number().over(window_all).alias("row_number"),
    F.rank().over(window_all).alias("rank"),
    F.dense_rank().over(window_all).alias("dense_rank"),
)

comparison.show(truncate=False)
```

---

## Partitioned Comparison (Per Department)

```python
# Window partitioned by department
window_dept = Window.partitionBy("department").orderBy(F.col("salary").desc())

comparison_dept = df.select(
    "name",
    "department",
    "salary",
    F.row_number().over(window_dept).alias("row_number"),
    F.rank().over(window_dept).alias("rank"),
    F.dense_rank().over(window_dept).alias("dense_rank"),
)

comparison_dept.orderBy("department", "salary").show(truncate=False)
```

**Output for Marketing department (3-way tie at 80000):**

| name  | department | salary | row_number | rank | dense_rank |
|-------|------------|--------|------------|------|------------|
| Eve   | Marketing  | 80000  | 1          | 1    | 1          |
| Frank | Marketing  | 80000  | 2          | 1    | 1          |
| Grace | Marketing  | 80000  | 3          | 1    | 1          |
| Heidi | Marketing  | 70000  | 4          | 4    | 2          |

Notice: After a 3-way tie, `rank()` jumps to 4, while `dense_rank()` goes to 2.

---

## When to Use Which

### Use row_number() when:

You need exactly one row per group, even if there are ties. Classic use case: deduplication.

```python
# Deduplicate: keep only the latest record per employee
dedup_data = [
    (1, "Alice", "2024-01-01", 90000),
    (1, "Alice", "2024-06-01", 95000),  # Latest for Alice
    (2, "Bob", "2024-03-01", 85000),    # Latest for Bob
    (2, "Bob", "2024-01-01", 80000),
]
dedup_df = spark.createDataFrame(dedup_data, ["emp_id", "name", "effective_date", "salary"])

window_dedup = Window.partitionBy("emp_id").orderBy(F.col("effective_date").desc())

deduped = (
    dedup_df.withColumn("rn", F.row_number().over(window_dedup))
    .filter(F.col("rn") == 1)
    .drop("rn")
)
deduped.show()
```

**Why not rank/dense_rank here?** If two records have the same effective_date, `rank()` would give both rank 1, and filtering for rank == 1 would keep both -- defeating the purpose of deduplication.

### Use dense_rank() when:

You need Nth highest/lowest values and ties should be treated as the same rank.

```python
# Find the 2nd highest salary per department
window_nth = Window.partitionBy("department").orderBy(F.col("salary").desc())

second_highest = (
    df.withColumn("dr", F.dense_rank().over(window_nth))
    .filter(F.col("dr") == 2)
)
second_highest.show()
```

### Use rank() when:

You need to know the actual position. Common in competition-style ranking (Olympic medals, leaderboards).

```python
# Competition ranking: if 2 people tie for 1st, next person is 3rd (no 2nd place)
competition_data = [
    ("Alice", 100), ("Bob", 100), ("Charlie", 95), ("Diana", 90),
]
comp_df = spark.createDataFrame(competition_data, ["athlete", "score"])

window_comp = Window.orderBy(F.col("score").desc())

ranked = comp_df.withColumn("position", F.rank().over(window_comp))
ranked.show()
# Alice: 1, Bob: 1, Charlie: 3, Diana: 4
# No 2nd place exists -- this is correct for competition ranking
```

---

## Behavior Summary Table

| Scenario         | row_number() | rank() | dense_rank() |
|------------------|--------------|--------|--------------|
| No ties          | 1, 2, 3, 4  | 1, 2, 3, 4 | 1, 2, 3, 4 |
| Two-way tie      | 1, 2, 3, 4  | 1, 1, 3, 4 | 1, 1, 2, 3 |
| Three-way tie    | 1, 2, 3, 4  | 1, 1, 1, 4 | 1, 1, 1, 2 |
| Guarantees unique? | Yes        | No     | No          |
| Skips numbers?   | No          | Yes    | No          |
| Max value = count? | Always    | Always | <= count    |
| Deterministic w/ ties? | No (arbitrary) | Yes | Yes |

---

## Common Pitfall: Non-Deterministic row_number()

```python
# DANGER: row_number with ties gives non-deterministic results
# The ordering among tied rows is arbitrary and may change between runs

# Fix: add a tiebreaker column to the orderBy
window_safe = Window.orderBy(F.col("salary").desc(), F.col("emp_id").asc())

# Now row_number is deterministic because emp_id breaks ties
df.withColumn("rn", F.row_number().over(window_safe)).show()
```

**Interview tip:** Always mention adding a tiebreaker to `row_number()` to make results deterministic. This shows awareness of production-quality code.

---

## ntile() Bonus -- The Fourth Ranking Function

```python
# ntile(n) divides rows into n roughly equal buckets
window_ntile = Window.orderBy(F.col("salary").desc())

df.select(
    "name", "salary",
    F.ntile(4).over(window_ntile).alias("quartile"),
).show()
# Divides 8 rows into 4 groups of 2
```

---

## Key Takeaways

- **row_number()** = always unique, non-deterministic on ties. Best for deduplication.
- **rank()** = ties get same rank, then skips. Best for competition/positional ranking.
- **dense_rank()** = ties get same rank, no skip. Best for "Nth highest/lowest" queries.
- Always add a **tiebreaker** column when using `row_number()` in production code.
- All three require a `Window.orderBy()` specification. Without `orderBy`, the results are meaningless.
- `partitionBy` is optional -- without it, the function operates over the entire dataset.
- These functions do NOT require a frame specification (`rowsBetween`/`rangeBetween`). Frame specs apply to aggregate window functions like `sum`, `avg`, etc.

## Interview Tips

- Draw the comparison table from memory. This is the fastest way to show mastery.
- Immediately mention the tie-handling difference -- that is the entire point of this question.
- If you mention `row_number()`, proactively bring up the non-determinism issue and the tiebreaker fix.
- Know that `dense_rank` max value equals the number of distinct values, while `rank` max value equals the total row count.
