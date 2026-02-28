# PySpark Implementation: Predicting Join Row Counts

## Problem Statement

Given two tables with known values (including NULLs and duplicates), **predict the number of rows returned** by each join type: Inner, Left, Right, and Full. This is a common conceptual interview question that tests your deep understanding of how joins handle NULLs and Cartesian products.

### Sample Data

```
Table_1: [1, 1, 1, NULL, NULL]    (single column)
Table_2: [1, 1, NULL, NULL, NULL]  (single column)
```

### Expected Output

| Join Type  | Row Count | Explanation |
|------------|-----------|-------------|
| Inner Join | 6         | 3 rows with 1 in T1 x 2 rows with 1 in T2 = 6 |
| Left Join  | 8         | 6 matched + 2 unmatched NULLs from T1 |
| Right Join | 9         | 6 matched + 3 unmatched NULLs from T2 |
| Full Join  | 11        | 6 matched + 2 from T1 + 3 from T2 |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("JoinRowCounts").getOrCreate()

# Create the two tables
data1 = [(1,), (1,), (1,), (None,), (None,)]
data2 = [(1,), (1,), (None,), (None,), (None,)]

df1 = spark.createDataFrame(data1, ["val"])
df2 = spark.createDataFrame(data2, ["val"])

# Perform all four join types and count results
inner = df1.join(df2, df1.val == df2.val, "inner")
left = df1.join(df2, df1.val == df2.val, "left")
right = df1.join(df2, df1.val == df2.val, "right")
full = df1.join(df2, df1.val == df2.val, "full")

print(f"Inner Join: {inner.count()} rows")  # 6
print(f"Left Join:  {left.count()} rows")   # 8
print(f"Right Join: {right.count()} rows")  # 9
print(f"Full Join:  {full.count()} rows")   # 11
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### The Core Rule: NULL Never Matches Anything

The critical rule that drives all the counts: **NULL != NULL** in join conditions. NULL is "unknown," so comparing two unknowns never produces a match. This means NULL rows only appear in outer joins as unmatched rows.

### Inner Join → 6 Rows

- **What happens:** Only rows where `df1.val == df2.val` is TRUE are kept. The 3 non-NULL rows in T1 (value=1) each match the 2 non-NULL rows in T2 (value=1): 3 × 2 = 6. NULL rows match nothing.
- **Output:**

  | df1.val | df2.val |
  |---------|---------|
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |

### Left Join → 8 Rows

- **What happens:** All rows from T1 are preserved. The 3 non-NULL rows match T2's 2 non-NULL rows (6 matched). The 2 NULL rows from T1 don't match anything, so they appear with NULL for T2's column: 6 + 2 = 8.
- **Output:**

  | df1.val | df2.val |
  |---------|---------|
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | NULL    | NULL    |
  | NULL    | NULL    |

### Right Join → 9 Rows

- **What happens:** All rows from T2 are preserved. The 6 matches from the inner join, plus the 3 NULL rows from T2 that don't match anything: 6 + 3 = 9.
- **Output:**

  | df1.val | df2.val |
  |---------|---------|
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | NULL    | NULL    |
  | NULL    | NULL    |
  | NULL    | NULL    |

### Full Join → 11 Rows

- **What happens:** All rows from both sides are preserved. The 6 matched rows + 2 unmatched from T1 + 3 unmatched from T2: 6 + 2 + 3 = 11. Formula: `left_count + right_count - inner_count = 8 + 9 - 6 = 11`.
- **Output:**

  | df1.val | df2.val |
  |---------|---------|
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | 1       | 1       |
  | NULL    | NULL    |
  | NULL    | NULL    |
  | NULL    | NULL    |
  | NULL    | NULL    |
  | NULL    | NULL    |

---

## Alternative: Practice with Unique Values (No Duplicates)

```python
# Different scenario: unique values with partial overlap
data_a = [(1,), (2,), (3,), (None,), (None,)]
data_b = [(2,), (1,), (None,), (None,), (None,)]

df_a = spark.createDataFrame(data_a, ["val"])
df_b = spark.createDataFrame(data_b, ["val"])

# 1 matches 1 (1 row), 2 matches 2 (1 row) → no Cartesian product
inner_2 = df_a.join(df_b, df_a.val == df_b.val, "inner")   # 2 rows
left_2 = df_a.join(df_b, df_a.val == df_b.val, "left")     # 5 rows (2 + 3 unmatched from A)
right_2 = df_a.join(df_b, df_a.val == df_b.val, "right")   # 5 rows (2 + 3 unmatched from B)
full_2 = df_a.join(df_b, df_a.val == df_b.val, "full")     # 8 rows (2 + 3 + 3)
```

With unique non-NULL values, matches are 1-to-1 (no Cartesian expansion). The unmatched count includes both the non-overlapping value (3 in T_A has no match) and all NULLs.

---

## Key Interview Talking Points

1. **The mental formula:** Inner = matched_rows. Left = inner + unmatched_from_left. Right = inner + unmatched_from_right. Full = inner + unmatched_left + unmatched_right (equivalently: left + right - inner).

2. **Duplicates cause Cartesian products:** When a value appears M times in T1 and N times in T2, the inner join produces M × N rows for that value. This is why 3 ones × 2 ones = 6, not 2 or 3.

3. **NULL never equals NULL in joins:** This is the #1 gotcha. `NULL == NULL` evaluates to NULL (not TRUE), so NULLs never match in join conditions. They only appear in outer join results as unmatched rows. To match NULLs, use `df1.val.eqNullSafe(df2.val)` in PySpark or `IS NOT DISTINCT FROM` in SQL.

4. **Left Outer = Left, Right Outer = Right:** The word "OUTER" is optional in SQL/PySpark. `LEFT JOIN` and `LEFT OUTER JOIN` are identical. Interviewers sometimes use both forms to test if you know they're the same.
