# PySpark Implementation: union() vs unionAll() vs unionByName()

## Problem Statement

One of the most common PySpark gotchas: unlike SQL where `UNION` removes duplicates and `UNION ALL` keeps them, **PySpark's `union()` behaves like SQL's `UNION ALL`** -- it does NOT remove duplicates. This trips up many candidates who come from a SQL background. Interviewers also test `unionByName()` behavior when DataFrames have different column orders or different schemas.

### Sample Data

```python
# Two DataFrames with overlapping records
df1_data = [
    (1, "Alice", "Engineering"),
    (2, "Bob", "Marketing"),
    (3, "Charlie", "Sales"),
]

df2_data = [
    (3, "Charlie", "Sales"),       # Duplicate of row in df1
    (4, "Diana", "Engineering"),
    (5, "Eve", "Marketing"),
]

# DataFrames with DIFFERENT column orders
df3_data = [
    ("Engineering", "Frank", 6),   # Columns: department, name, emp_id
]

# DataFrame with EXTRA columns
df4_data = [
    (7, "Grace", "Sales", 75000),  # Has salary column that df1 doesn't
]

columns_1 = ["emp_id", "name", "department"]
columns_2 = ["emp_id", "name", "department"]
columns_3 = ["department", "name", "emp_id"]   # Different order!
columns_4 = ["emp_id", "name", "department", "salary"]  # Extra column!
```

### Expected Output

**union() (keeps duplicates):** 6 rows (Charlie appears twice)
**True SQL UNION (no duplicates):** 5 rows (Charlie appears once)

---

## Setup

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("UnionComparison").getOrCreate()

df1 = spark.createDataFrame(
    [(1, "Alice", "Engineering"), (2, "Bob", "Marketing"), (3, "Charlie", "Sales")],
    ["emp_id", "name", "department"]
)

df2 = spark.createDataFrame(
    [(3, "Charlie", "Sales"), (4, "Diana", "Engineering"), (5, "Eve", "Marketing")],
    ["emp_id", "name", "department"]
)

# Different column order
df3 = spark.createDataFrame(
    [("Engineering", "Frank", 6)],
    ["department", "name", "emp_id"]
)

# Extra column
df4 = spark.createDataFrame(
    [(7, "Grace", "Sales", 75000)],
    ["emp_id", "name", "department", "salary"]
)
```

---

## union() -- PySpark's UNION ALL

```python
# union() keeps ALL rows including duplicates
result_union = df1.union(df2)
print(f"df1 count: {df1.count()}")         # 3
print(f"df2 count: {df2.count()}")         # 3
print(f"union count: {result_union.count()}")  # 6 (Charlie appears twice!)
result_union.show()
```

**Output:**
```
+------+-------+-----------+
|emp_id|   name| department|
+------+-------+-----------+
|     1|  Alice|Engineering|
|     2|    Bob|  Marketing|
|     3|Charlie|      Sales|   <-- first occurrence
|     3|Charlie|      Sales|   <-- duplicate kept!
|     4|  Diana|Engineering|
|     5|    Eve|  Marketing|
+------+-------+-----------+
```

**Key point:** `union()` is equivalent to SQL's `UNION ALL`. PySpark also has `unionAll()` which does the exact same thing -- it is just an alias.

```python
# unionAll() is identical to union() -- both keep duplicates
result_unionall = df1.unionAll(df2)
print(f"unionAll count: {result_unionall.count()}")  # Also 6
```

---

## Getting True SQL UNION (Remove Duplicates)

```python
# To get SQL UNION behavior (deduplication), chain .distinct()
result_true_union = df1.union(df2).distinct()
print(f"union + distinct count: {result_true_union.count()}")  # 5
result_true_union.show()
```

**Output:**
```
+------+-------+-----------+
|emp_id|   name| department|
+------+-------+-----------+
|     1|  Alice|Engineering|
|     2|    Bob|  Marketing|
|     3|Charlie|      Sales|   <-- only once now
|     4|  Diana|Engineering|
|     5|    Eve|  Marketing|
+------+-------+-----------+
```

**Performance note:** `distinct()` triggers a shuffle. If you know there are no duplicates, skip it. If deduplication is needed, `dropDuplicates()` is equivalent to `distinct()` but lets you specify a subset of columns.

---

## union() with Different Column Orders -- DANGER

```python
# df1 columns: emp_id, name, department
# df3 columns: department, name, emp_id (DIFFERENT ORDER)

# union() resolves by POSITION, not by name!
bad_union = df1.union(df3)
bad_union.show()
```

**Output:**
```
+------+-----------+-----------+
|emp_id|       name| department|
+------+-----------+-----------+
|     1|      Alice|Engineering|
|     2|        Bob|  Marketing|
|     3|    Charlie|      Sales|
|Engineering|  Frank|          6|   <-- WRONG! department went into emp_id column
+------+-----------+-----------+
```

**The data is silently corrupted.** `union()` matches columns by position (1st with 1st, 2nd with 2nd), not by name. This is one of the most dangerous PySpark behaviors.

---

## unionByName() -- The Safe Alternative

```python
# unionByName() resolves by COLUMN NAME, not position
correct_union = df1.unionByName(df3)
correct_union.show()
```

**Output:**
```
+------+-------+-----------+
|emp_id|   name| department|
+------+-------+-----------+
|     1|  Alice|Engineering|
|     2|    Bob|  Marketing|
|     3|Charlie|      Sales|
|     6|  Frank|Engineering|   <-- Correct! Columns matched by name
+------+-------+-----------+
```

---

## unionByName() with Different Schemas

```python
# df1 has: emp_id, name, department
# df4 has: emp_id, name, department, salary (extra column)

# unionByName without allowMissingColumns -- FAILS
try:
    df1.unionByName(df4).show()
except Exception as e:
    print(f"Error: {e}")
    # AnalysisException: cannot resolve 'salary' -- schemas must match

# unionByName WITH allowMissingColumns -- fills missing with NULL
flexible_union = df1.unionByName(df4, allowMissingColumns=True)
flexible_union.show()
```

**Output:**
```
+------+-------+-----------+------+
|emp_id|   name| department|salary|
+------+-------+-----------+------+
|     1|  Alice|Engineering|  null|   <-- salary filled with NULL
|     2|    Bob|  Marketing|  null|
|     3|Charlie|      Sales|  null|
|     7|  Grace|      Sales| 75000|
+------+-------+-----------+------+
```

---

## Combining Multiple DataFrames

```python
from functools import reduce

# Union multiple DataFrames at once
dfs = [df1, df2]  # List of DataFrames with same schema

combined = reduce(lambda a, b: a.unionByName(b), dfs)
combined.show()

# With allowMissingColumns for heterogeneous schemas
dfs_mixed = [df1, df2, df4]
combined_mixed = reduce(
    lambda a, b: a.unionByName(b, allowMissingColumns=True),
    dfs_mixed
)
combined_mixed.show()
```

---

## union() vs unionByName() Comparison Table

| Feature | union() | unionByName() |
|---------|---------|---------------|
| Column matching | By position | By name |
| Different column order | Silent data corruption | Handles correctly |
| Different number of columns | Error | Error (unless allowMissingColumns=True) |
| Removes duplicates | No | No |
| Performance | Slightly faster | Slightly slower (name resolution) |
| Safe for schema evolution | No | Yes |
| Available since | PySpark 1.0 | PySpark 2.3 |
| allowMissingColumns | Not available | Available (PySpark 3.1+) |

---

## SQL Equivalents via Spark SQL

```python
df1.createOrReplaceTempView("table1")
df2.createOrReplaceTempView("table2")

# SQL UNION ALL (same as PySpark union)
spark.sql("SELECT * FROM table1 UNION ALL SELECT * FROM table2").show()

# SQL UNION (removes duplicates -- no direct PySpark equivalent without .distinct())
spark.sql("SELECT * FROM table1 UNION SELECT * FROM table2").show()

# SQL UNION behaves correctly -- removes Charlie duplicate
# This is different from PySpark's union() which keeps it
```

---

## Common Interview Follow-Up: Union vs Join

```python
# Union stacks rows vertically (same columns, more rows)
# Join combines columns horizontally (same rows, more columns)

# Union: 3 + 3 = 6 rows, same 3 columns
df1.union(df2).show()

# Join: up to 3 rows (matching), potentially 6 columns
df1.join(df2, on="emp_id", how="inner").show()
```

---

## Key Takeaways

- **PySpark `union()` = SQL `UNION ALL`.** It does NOT remove duplicates. This is the number one gotcha.
- **`unionAll()` is just an alias for `union()`.** They are identical. `unionAll` exists for backward compatibility.
- **To get SQL `UNION` behavior:** use `union().distinct()`.
- **`union()` matches by POSITION.** If column orders differ, data gets silently corrupted. This is extremely dangerous.
- **Always use `unionByName()`** in production code. It matches by column name and is safe against column reordering.
- **`allowMissingColumns=True`** fills missing columns with NULL. Essential for schema evolution scenarios.
- Both `union()` and `unionByName()` require the same data types for matched columns. Mismatched types will throw an error.

## Interview Tips

- The moment you hear "union" in an interview, say: "In PySpark, `union()` is actually `UNION ALL` -- it keeps duplicates." This is the key insight they are testing.
- Always recommend `unionByName()` over `union()` and explain why (position vs name matching).
- Know the `allowMissingColumns` parameter. It comes up in schema evolution and data lake merge scenarios.
- If asked to union many DataFrames, show the `reduce` pattern with `functools.reduce`.
- Mention that both operations are narrow transformations (no shuffle) unless followed by `distinct()`.
