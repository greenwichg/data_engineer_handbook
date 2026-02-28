# PySpark Implementation: Predicting Join Row Counts

## Problem Statement 

Given two tables with known values (including NULLs and duplicates), **predict the number of rows returned** by each join type: Inner, Left, Right, Full, and Cross. This is a common conceptual interview question that tests your deep understanding of how joins handle NULLs and Cartesian products.

---

## Table of Contents

1. [Scenario 1: Duplicates + NULLs (The Classic)](#scenario-1-duplicates--nulls-the-classic)
2. [Scenario 2: Unique Values with Partial Overlap](#scenario-2-unique-values-with-partial-overlap)
3. [Scenario 3: Completely Disjoint Tables (No Overlap)](#scenario-3-completely-disjoint-tables-no-overlap)
4. [Scenario 4: Identical Tables (Perfect Overlap)](#scenario-4-identical-tables-perfect-overlap)
5. [Scenario 5: One-to-Many (FK Relationship)](#scenario-5-one-to-many-fk-relationship)
6. [Scenario 6: Many-to-Many with Multiple Matching Values](#scenario-6-many-to-many-with-multiple-matching-values)
7. [Scenario 7: One Empty Table](#scenario-7-one-empty-table)
8. [Scenario 8: All NULLs in Both Tables](#scenario-8-all-nulls-in-both-tables)
9. [Scenario 9: Multi-Column Join](#scenario-9-multi-column-join)
10. [Scenario 10: Null-Safe Join (eqNullSafe)](#scenario-10-null-safe-join-eqnullsafe)
11. [Key Interview Talking Points](#key-interview-talking-points)
12. [Quick Reference: Join Count Formulas](#quick-reference-join-count-formulas)

---

## The Core Rules

Before diving into scenarios, memorize these rules:

1. **NULL != NULL** in join conditions. `NULL == NULL` evaluates to NULL (not TRUE), so NULLs never produce a match.
2. **Duplicates cause Cartesian products.** If value `X` appears M times in T1 and N times in T2, the inner join produces M × N rows for that value.
3. **Cross join = full Cartesian product** of both tables, ignoring all values. Result = `|T1| × |T2|` rows.
4. **Outer join formulas:**
   - Left = inner + unmatched_from_left
   - Right = inner + unmatched_from_right
   - Full = inner + unmatched_left + unmatched_right = left + right - inner

---

## Scenario 1: Duplicates + NULLs (The Classic)

### Sample Data

```
Table_1: [1, 1, 1, NULL, NULL]    (5 rows)
Table_2: [1, 1, NULL, NULL, NULL]  (5 rows)
```

### Expected Counts

| Join Type  | Row Count | Explanation |
|------------|-----------|-------------|
| Inner Join | 6         | 3 rows with 1 in T1 × 2 rows with 1 in T2 = 6 |
| Left Join  | 8         | 6 matched + 2 unmatched NULLs from T1 |
| Right Join | 9         | 6 matched + 3 unmatched NULLs from T2 |
| Full Join  | 11        | 6 matched + 2 from T1 + 3 from T2 |
| Cross Join | 25        | 5 × 5 = 25 |

### PySpark Code

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("JoinRowCounts").getOrCreate()

# Create the two tables
data1 = [(1,), (1,), (1,), (None,), (None,)]
data2 = [(1,), (1,), (None,), (None,), (None,)]

df1 = spark.createDataFrame(data1, ["val"])
df2 = spark.createDataFrame(data2, ["val"])

# Perform all five join types
inner = df1.join(df2, df1.val == df2.val, "inner")
left = df1.join(df2, df1.val == df2.val, "left")
right = df1.join(df2, df1.val == df2.val, "right")
full = df1.join(df2, df1.val == df2.val, "full")
cross = df1.crossJoin(df2)

print(f"Inner Join: {inner.count()} rows")  # 6
print(f"Left Join:  {left.count()} rows")   # 8
print(f"Right Join: {right.count()} rows")  # 9
print(f"Full Join:  {full.count()} rows")   # 11
print(f"Cross Join: {cross.count()} rows")  # 25
```

### Row-by-Row Results

**Inner Join → 6 Rows**

Only rows where `df1.val == df2.val` is TRUE. The 3 non-NULL rows in T1 (value=1) each match the 2 non-NULL rows in T2 (value=1): 3 × 2 = 6. NULL rows match nothing.

| df1.val | df2.val |
|---------|---------|
| 1       | 1       |
| 1       | 1       |
| 1       | 1       |
| 1       | 1       |
| 1       | 1       |
| 1       | 1       |

**Left Join → 8 Rows**

All rows from T1 are preserved. 6 matched + 2 NULLs from T1 that found no match.

| df1.val | df2.val    |
|---------|------------|
| 1       | 1          |
| 1       | 1          |
| 1       | 1          |
| 1       | 1          |
| 1       | 1          |
| 1       | 1          |
| NULL    | NULL *(no match)* |
| NULL    | NULL *(no match)* |

> Note: In the last 2 rows, df2.val is NULL because there was no match — not because it matched a NULL in T2.

**Right Join → 9 Rows**

All rows from T2 are preserved. 6 matched + 3 NULLs from T2 that found no match.

| df1.val    | df2.val |
|------------|---------|
| 1          | 1       |
| 1          | 1       |
| 1          | 1       |
| 1          | 1       |
| 1          | 1       |
| 1          | 1       |
| NULL *(no match)* | NULL    |
| NULL *(no match)* | NULL    |
| NULL *(no match)* | NULL    |

**Full Join → 11 Rows**

All rows from both sides preserved. 6 matched + 2 unmatched from T1 + 3 unmatched from T2. Formula: `left + right - inner = 8 + 9 - 6 = 11`.

| df1.val    | df2.val    |
|------------|------------|
| 1          | 1          |
| 1          | 1          |
| 1          | 1          |
| 1          | 1          |
| 1          | 1          |
| 1          | 1          |
| NULL       | NULL *(no match — from T1)* |
| NULL       | NULL *(no match — from T1)* |
| NULL *(no match — from T2)* | NULL       |
| NULL *(no match — from T2)* | NULL       |
| NULL *(no match — from T2)* | NULL       |

**Cross Join → 25 Rows**

Every row in T1 paired with every row in T2. No join condition — values are irrelevant. 5 × 5 = 25.

| df1.val | df2.val |
|---------|---------|
| 1       | 1       |
| 1       | 1       |
| 1       | NULL    |
| 1       | NULL    |
| 1       | NULL    |
| 1       | 1       |
| 1       | 1       |
| 1       | NULL    |
| 1       | NULL    |
| 1       | NULL    |
| 1       | 1       |
| 1       | 1       |
| 1       | NULL    |
| 1       | NULL    |
| 1       | NULL    |
| NULL    | 1       |
| NULL    | 1       |
| NULL    | NULL    |
| NULL    | NULL    |
| NULL    | NULL    |
| NULL    | 1       |
| NULL    | 1       |
| NULL    | NULL    |
| NULL    | NULL    |
| NULL    | NULL    |

---

## Scenario 2: Unique Values with Partial Overlap

### Sample Data

```
Table_A: [1, 2, 3, NULL, NULL]     (5 rows)
Table_B: [2, 1, NULL, NULL, NULL]  (5 rows)
```

Values 1 and 2 overlap. Value 3 is only in T_A. NULLs never match.

### Expected Counts

| Join Type  | Row Count | Explanation |
|------------|-----------|-------------|
| Inner Join | 2         | 1↔1 (1×1=1) + 2↔2 (1×1=1) = 2 |
| Left Join  | 5         | 2 matched + 3 unmatched (3, NULL, NULL) |
| Right Join | 5         | 2 matched + 3 unmatched (NULL, NULL, NULL) |
| Full Join  | 8         | 2 + 3 + 3 = 8 |
| Cross Join | 25        | 5 × 5 = 25 |

### PySpark Code

```python
data_a = [(1,), (2,), (3,), (None,), (None,)]
data_b = [(2,), (1,), (None,), (None,), (None,)]

df_a = spark.createDataFrame(data_a, ["val"])
df_b = spark.createDataFrame(data_b, ["val"])

inner_2 = df_a.join(df_b, df_a.val == df_b.val, "inner")
left_2 = df_a.join(df_b, df_a.val == df_b.val, "left")
right_2 = df_a.join(df_b, df_a.val == df_b.val, "right")
full_2 = df_a.join(df_b, df_a.val == df_b.val, "full")
cross_2 = df_a.crossJoin(df_b)

print(f"Inner Join: {inner_2.count()} rows")  # 2
print(f"Left Join:  {left_2.count()} rows")   # 5
print(f"Right Join: {right_2.count()} rows")  # 5
print(f"Full Join:  {full_2.count()} rows")   # 8
print(f"Cross Join: {cross_2.count()} rows")  # 25
```

### Row-by-Row Results

**Inner Join → 2 Rows**

With unique values, matches are 1-to-1 — no Cartesian explosion.

| df_a.val | df_b.val |
|----------|----------|
| 1        | 1        |
| 2        | 2        |

**Left Join → 5 Rows**

2 matched + 3 unmatched from T_A (value 3 has no partner, and 2 NULLs never match).

| df_a.val | df_b.val   |
|----------|------------|
| 1        | 1          |
| 2        | 2          |
| 3        | NULL *(no match)* |
| NULL     | NULL *(no match)* |
| NULL     | NULL *(no match)* |

**Right Join → 5 Rows**

2 matched + 3 NULLs from T_B that found no match.

| df_a.val   | df_b.val |
|------------|----------|
| 1          | 1        |
| 2          | 2        |
| NULL *(no match)* | NULL     |
| NULL *(no match)* | NULL     |
| NULL *(no match)* | NULL     |

**Full Join → 8 Rows**

2 matched + 3 unmatched from T_A + 3 unmatched from T_B.

| df_a.val   | df_b.val   |
|------------|------------|
| 1          | 1          |
| 2          | 2          |
| 3          | NULL *(no match)* |
| NULL       | NULL *(no match — from A)* |
| NULL       | NULL *(no match — from A)* |
| NULL *(no match — from B)* | NULL       |
| NULL *(no match — from B)* | NULL       |
| NULL *(no match — from B)* | NULL       |

**Cross Join → 25 Rows**

| df_a.val | df_b.val |
|----------|----------|
| 1        | 2        |
| 1        | 1        |
| 1        | NULL     |
| 1        | NULL     |
| 1        | NULL     |
| 2        | 2        |
| 2        | 1        |
| 2        | NULL     |
| 2        | NULL     |
| 2        | NULL     |
| 3        | 2        |
| 3        | 1        |
| 3        | NULL     |
| 3        | NULL     |
| 3        | NULL     |
| NULL     | 2        |
| NULL     | 1        |
| NULL     | NULL     |
| NULL     | NULL     |
| NULL     | NULL     |
| NULL     | 2        |
| NULL     | 1        |
| NULL     | NULL     |
| NULL     | NULL     |
| NULL     | NULL     |

---

## Scenario 3: Completely Disjoint Tables (No Overlap)

### Sample Data

```
Table_C: [1, 2, 3]    (3 rows)
Table_D: [4, 5, NULL]  (3 rows)
```

No values in common — zero matches.

### Expected Counts

| Join Type  | Row Count | Explanation |
|------------|-----------|-------------|
| Inner Join | 0         | No values match |
| Left Join  | 3         | 0 matched + 3 unmatched from T_C |
| Right Join | 3         | 0 matched + 3 unmatched from T_D |
| Full Join  | 6         | 0 + 3 + 3 = 6 |
| Cross Join | 9         | 3 × 3 = 9 |

### PySpark Code

```python
data_c = [(1,), (2,), (3,)]
data_d = [(4,), (5,), (None,)]

df_c = spark.createDataFrame(data_c, ["val"])
df_d = spark.createDataFrame(data_d, ["val"])

inner_3 = df_c.join(df_d, df_c.val == df_d.val, "inner")
left_3 = df_c.join(df_d, df_c.val == df_d.val, "left")
right_3 = df_c.join(df_d, df_c.val == df_d.val, "right")
full_3 = df_c.join(df_d, df_c.val == df_d.val, "full")
cross_3 = df_c.crossJoin(df_d)

print(f"Inner Join: {inner_3.count()} rows")  # 0
print(f"Left Join:  {left_3.count()} rows")   # 3
print(f"Right Join: {right_3.count()} rows")  # 3
print(f"Full Join:  {full_3.count()} rows")   # 6
print(f"Cross Join: {cross_3.count()} rows")  # 9
```

### Row-by-Row Results

**Inner Join → 0 Rows**

```
(empty result)
```

**Left Join → 3 Rows**

Every row from T_C is unmatched.

| df_c.val | df_d.val   |
|----------|------------|
| 1        | NULL *(no match)* |
| 2        | NULL *(no match)* |
| 3        | NULL *(no match)* |

**Right Join → 3 Rows**

Every row from T_D is unmatched.

| df_c.val   | df_d.val |
|------------|----------|
| NULL *(no match)* | 4        |
| NULL *(no match)* | 5        |
| NULL *(no match)* | NULL     |

**Full Join → 6 Rows**

All rows from both sides, none matched.

| df_c.val   | df_d.val   |
|------------|------------|
| 1          | NULL *(no match)* |
| 2          | NULL *(no match)* |
| 3          | NULL *(no match)* |
| NULL *(no match)* | 4          |
| NULL *(no match)* | 5          |
| NULL *(no match)* | NULL       |

**Cross Join → 9 Rows**

| df_c.val | df_d.val |
|----------|----------|
| 1        | 4        |
| 1        | 5        |
| 1        | NULL     |
| 2        | 4        |
| 2        | 5        |
| 2        | NULL     |
| 3        | 4        |
| 3        | 5        |
| 3        | NULL     |

---

## Scenario 4: Identical Tables (Perfect Overlap)

### Sample Data

```
Table_E: [1, 2, 3]  (3 rows)
Table_F: [1, 2, 3]  (3 rows)
```

Every value appears exactly once in both tables — perfect 1:1 match.

### Expected Counts

| Join Type  | Row Count | Explanation |
|------------|-----------|-------------|
| Inner Join | 3         | 1↔1, 2↔2, 3↔3 — each 1×1 = 3 |
| Left Join  | 3         | 3 matched + 0 unmatched = 3 |
| Right Join | 3         | 3 matched + 0 unmatched = 3 |
| Full Join  | 3         | 3 + 0 + 0 = 3 |
| Cross Join | 9         | 3 × 3 = 9 |

### PySpark Code

```python
data_e = [(1,), (2,), (3,)]
data_f = [(1,), (2,), (3,)]

df_e = spark.createDataFrame(data_e, ["val"])
df_f = spark.createDataFrame(data_f, ["val"])

inner_4 = df_e.join(df_f, df_e.val == df_f.val, "inner")
left_4 = df_e.join(df_f, df_e.val == df_f.val, "left")
right_4 = df_e.join(df_f, df_e.val == df_f.val, "right")
full_4 = df_e.join(df_f, df_e.val == df_f.val, "full")
cross_4 = df_e.crossJoin(df_f)

print(f"Inner Join: {inner_4.count()} rows")  # 3
print(f"Left Join:  {left_4.count()} rows")   # 3
print(f"Right Join: {right_4.count()} rows")  # 3
print(f"Full Join:  {full_4.count()} rows")   # 3
print(f"Cross Join: {cross_4.count()} rows")  # 9
```

### Row-by-Row Results

**Inner / Left / Right / Full Join → 3 Rows (all identical)**

When tables match perfectly, all join types return the same result.

| df_e.val | df_f.val |
|----------|----------|
| 1        | 1        |
| 2        | 2        |
| 3        | 3        |

**Cross Join → 9 Rows**

| df_e.val | df_f.val |
|----------|----------|
| 1        | 1        |
| 1        | 2        |
| 1        | 3        |
| 2        | 1        |
| 2        | 2        |
| 2        | 3        |
| 3        | 1        |
| 3        | 2        |
| 3        | 3        |

> Key takeaway: When there are no duplicates and no NULLs and all values overlap, inner = left = right = full.

---

## Scenario 5: One-to-Many (FK Relationship)

### Sample Data

This simulates a realistic foreign key scenario — departments to employees.

```
Departments: [10, 20, 30]                     (3 rows — parent)
Employees:   [10, 10, 10, 20, 20, NULL]       (6 rows — child)
```

Dept 10 has 3 employees, dept 20 has 2, dept 30 has 0, one employee has no dept.

### Expected Counts

| Join Type  | Row Count | Explanation |
|------------|-----------|-------------|
| Inner Join | 5         | 10→(1×3=3) + 20→(1×2=2) = 5 |
| Left Join  | 6         | 5 matched + 1 unmatched dept 30 |
| Right Join | 6         | 5 matched + 1 unmatched NULL employee |
| Full Join  | 7         | 5 + 1 + 1 = 7 |
| Cross Join | 18        | 3 × 6 = 18 |

### PySpark Code

```python
dept_data = [(10,), (20,), (30,)]
emp_data = [(10,), (10,), (10,), (20,), (20,), (None,)]

df_dept = spark.createDataFrame(dept_data, ["dept_id"])
df_emp = spark.createDataFrame(emp_data, ["dept_id"])

inner_5 = df_dept.join(df_emp, df_dept.dept_id == df_emp.dept_id, "inner")
left_5 = df_dept.join(df_emp, df_dept.dept_id == df_emp.dept_id, "left")
right_5 = df_dept.join(df_emp, df_dept.dept_id == df_emp.dept_id, "right")
full_5 = df_dept.join(df_emp, df_dept.dept_id == df_emp.dept_id, "full")
cross_5 = df_dept.crossJoin(df_emp)

print(f"Inner Join: {inner_5.count()} rows")  # 5
print(f"Left Join:  {left_5.count()} rows")   # 6
print(f"Right Join: {right_5.count()} rows")  # 6
print(f"Full Join:  {full_5.count()} rows")   # 7
print(f"Cross Join: {cross_5.count()} rows")  # 18
```

### Row-by-Row Results

**Inner Join → 5 Rows**

| df_dept.dept_id | df_emp.dept_id |
|-----------------|----------------|
| 10              | 10             |
| 10              | 10             |
| 10              | 10             |
| 20              | 20             |
| 20              | 20             |

**Left Join → 6 Rows**

Dept 30 has no employees — appears with NULL on the right side.

| df_dept.dept_id | df_emp.dept_id |
|-----------------|----------------|
| 10              | 10             |
| 10              | 10             |
| 10              | 10             |
| 20              | 20             |
| 20              | 20             |
| 30              | NULL *(no match)* |

**Right Join → 6 Rows**

The employee with NULL dept_id has no matching department.

| df_dept.dept_id | df_emp.dept_id |
|-----------------|----------------|
| 10              | 10             |
| 10              | 10             |
| 10              | 10             |
| 20              | 20             |
| 20              | 20             |
| NULL *(no match)* | NULL           |

**Full Join → 7 Rows**

Both unmatched sides are preserved.

| df_dept.dept_id | df_emp.dept_id |
|-----------------|----------------|
| 10              | 10             |
| 10              | 10             |
| 10              | 10             |
| 20              | 20             |
| 20              | 20             |
| 30              | NULL *(no match — dept with no employees)* |
| NULL *(no match — employee with no dept)* | NULL           |

**Cross Join → 18 Rows**

| df_dept.dept_id | df_emp.dept_id |
|-----------------|----------------|
| 10              | 10             |
| 10              | 10             |
| 10              | 10             |
| 10              | 20             |
| 10              | 20             |
| 10              | NULL           |
| 20              | 10             |
| 20              | 10             |
| 20              | 10             |
| 20              | 20             |
| 20              | 20             |
| 20              | NULL           |
| 30              | 10             |
| 30              | 10             |
| 30              | 10             |
| 30              | 20             |
| 30              | 20             |
| 30              | NULL           |

---

## Scenario 6: Many-to-Many with Multiple Matching Values

### Sample Data

```
Table_G: [1, 1, 2, 2, 2]     (5 rows)
Table_H: [1, 1, 1, 2, 2]     (5 rows)
```

No NULLs — pure duplicate explosion across multiple values.

### Expected Counts

| Join Type  | Row Count | Explanation |
|------------|-----------|-------------|
| Inner Join | 12        | 1→(2×3=6) + 2→(3×2=6) = 12 |
| Left Join  | 12        | 12 matched + 0 unmatched = 12 |
| Right Join | 12        | 12 matched + 0 unmatched = 12 |
| Full Join  | 12        | 12 + 0 + 0 = 12 |
| Cross Join | 25        | 5 × 5 = 25 |

### PySpark Code

```python
data_g = [(1,), (1,), (2,), (2,), (2,)]
data_h = [(1,), (1,), (1,), (2,), (2,)]

df_g = spark.createDataFrame(data_g, ["val"])
df_h = spark.createDataFrame(data_h, ["val"])

inner_6 = df_g.join(df_h, df_g.val == df_h.val, "inner")
left_6 = df_g.join(df_h, df_g.val == df_h.val, "left")
right_6 = df_g.join(df_h, df_g.val == df_h.val, "right")
full_6 = df_g.join(df_h, df_g.val == df_h.val, "full")
cross_6 = df_g.crossJoin(df_h)

print(f"Inner Join: {inner_6.count()} rows")  # 12
print(f"Left Join:  {left_6.count()} rows")   # 12
print(f"Right Join: {right_6.count()} rows")  # 12
print(f"Full Join:  {full_6.count()} rows")   # 12
print(f"Cross Join: {cross_6.count()} rows")  # 25
```

### Row-by-Row Results

**Inner / Left / Right / Full Join → 12 Rows (all identical)**

When all values have at least one match, every row is matched — outer joins add nothing.

| df_g.val | df_h.val |
|----------|----------|
| 1        | 1        |
| 1        | 1        |
| 1        | 1        |
| 1        | 1        |
| 1        | 1        |
| 1        | 1        |
| 2        | 2        |
| 2        | 2        |
| 2        | 2        |
| 2        | 2        |
| 2        | 2        |
| 2        | 2        |

> Key takeaway: With no NULLs and complete overlap, duplicates can make the result **larger** than either input table. Here 5-row tables produce 12-row joins. This is how "data explosion" happens in production.

**Cross Join → 25 Rows**

| df_g.val | df_h.val |
|----------|----------|
| 1        | 1        |
| 1        | 1        |
| 1        | 1        |
| 1        | 2        |
| 1        | 2        |
| 1        | 1        |
| 1        | 1        |
| 1        | 1        |
| 1        | 2        |
| 1        | 2        |
| 2        | 1        |
| 2        | 1        |
| 2        | 1        |
| 2        | 2        |
| 2        | 2        |
| 2        | 1        |
| 2        | 1        |
| 2        | 1        |
| 2        | 2        |
| 2        | 2        |
| 2        | 1        |
| 2        | 1        |
| 2        | 1        |
| 2        | 2        |
| 2        | 2        |

---

## Scenario 7: One Empty Table

### Sample Data

```
Table_I: [1, 2, 3]   (3 rows)
Table_J: []           (0 rows)
```

### Expected Counts

| Join Type  | Row Count | Explanation |
|------------|-----------|-------------|
| Inner Join | 0         | Nothing to match against |
| Left Join  | 3         | 0 matched + 3 unmatched from T_I |
| Right Join | 0         | 0 matched + 0 from empty T_J |
| Full Join  | 3         | 0 + 3 + 0 = 3 |
| Cross Join | 0         | 3 × 0 = 0 |

### PySpark Code

```python
from pyspark.sql.types import StructType, StructField, IntegerType

data_i = [(1,), (2,), (3,)]
schema = StructType([StructField("val", IntegerType(), True)])

df_i = spark.createDataFrame(data_i, ["val"])
df_j = spark.createDataFrame([], schema)  # empty DataFrame

inner_7 = df_i.join(df_j, df_i.val == df_j.val, "inner")
left_7 = df_i.join(df_j, df_i.val == df_j.val, "left")
right_7 = df_i.join(df_j, df_i.val == df_j.val, "right")
full_7 = df_i.join(df_j, df_i.val == df_j.val, "full")
cross_7 = df_i.crossJoin(df_j)

print(f"Inner Join: {inner_7.count()} rows")  # 0
print(f"Left Join:  {left_7.count()} rows")   # 3
print(f"Right Join: {right_7.count()} rows")  # 0
print(f"Full Join:  {full_7.count()} rows")   # 3
print(f"Cross Join: {cross_7.count()} rows")  # 0
```

### Row-by-Row Results

**Inner Join → 0 Rows**

```
(empty result)
```

**Left Join → 3 Rows**

| df_i.val | df_j.val   |
|----------|------------|
| 1        | NULL *(no match)* |
| 2        | NULL *(no match)* |
| 3        | NULL *(no match)* |

**Right Join → 0 Rows**

```
(empty result — T_J has no rows to preserve)
```

**Full Join → 3 Rows**

Same as left join here, since the right table contributes nothing.

| df_i.val | df_j.val   |
|----------|------------|
| 1        | NULL *(no match)* |
| 2        | NULL *(no match)* |
| 3        | NULL *(no match)* |

**Cross Join → 0 Rows**

```
(empty result — 3 × 0 = 0)
```

> Key takeaway: Cross join with an empty table gives 0 rows, while left/full join still preserves the non-empty side. An empty table is the one case where cross join returns fewer rows than a left join.

---

## Scenario 8: All NULLs in Both Tables

### Sample Data

```
Table_K: [NULL, NULL, NULL]   (3 rows)
Table_L: [NULL, NULL]         (2 rows)
```

### Expected Counts

| Join Type  | Row Count | Explanation |
|------------|-----------|-------------|
| Inner Join | 0         | NULL never matches NULL |
| Left Join  | 3         | 0 matched + 3 unmatched from T_K |
| Right Join | 2         | 0 matched + 2 unmatched from T_L |
| Full Join  | 5         | 0 + 3 + 2 = 5 |
| Cross Join | 6         | 3 × 2 = 6 |

### PySpark Code

```python
data_k = [(None,), (None,), (None,)]
data_l = [(None,), (None,)]

df_k = spark.createDataFrame(data_k, ["val"])
df_l = spark.createDataFrame(data_l, ["val"])

inner_8 = df_k.join(df_l, df_k.val == df_l.val, "inner")
left_8 = df_k.join(df_l, df_k.val == df_l.val, "left")
right_8 = df_k.join(df_l, df_k.val == df_l.val, "right")
full_8 = df_k.join(df_l, df_k.val == df_l.val, "full")
cross_8 = df_k.crossJoin(df_l)

print(f"Inner Join: {inner_8.count()} rows")  # 0
print(f"Left Join:  {left_8.count()} rows")   # 3
print(f"Right Join: {right_8.count()} rows")  # 2
print(f"Full Join:  {full_8.count()} rows")   # 5
print(f"Cross Join: {cross_8.count()} rows")  # 6
```

### Row-by-Row Results

**Inner Join → 0 Rows**

```
(empty result — NULL == NULL is never TRUE)
```

**Left Join → 3 Rows**

| df_k.val | df_l.val   |
|----------|------------|
| NULL     | NULL *(no match)* |
| NULL     | NULL *(no match)* |
| NULL     | NULL *(no match)* |

**Right Join → 2 Rows**

| df_k.val   | df_l.val |
|------------|----------|
| NULL *(no match)* | NULL     |
| NULL *(no match)* | NULL     |

**Full Join → 5 Rows**

| df_k.val   | df_l.val   |
|------------|------------|
| NULL       | NULL *(no match — from K)* |
| NULL       | NULL *(no match — from K)* |
| NULL       | NULL *(no match — from K)* |
| NULL *(no match — from L)* | NULL       |
| NULL *(no match — from L)* | NULL       |

> Tricky: The full join output looks like it could be a cross join, but it's not. Each row here is an unmatched row from one side, not a paired combination.

**Cross Join → 6 Rows**

| df_k.val | df_l.val |
|----------|----------|
| NULL     | NULL     |
| NULL     | NULL     |
| NULL     | NULL     |
| NULL     | NULL     |
| NULL     | NULL     |
| NULL     | NULL     |

> Key takeaway: All-NULL tables are a great trick question. The inner join returns 0 (not 6!), and the full join returns |T_K| + |T_L| = 5 (not |T_K| × |T_L| = 6). Only the cross join gives the Cartesian product.

---

## Scenario 9: Multi-Column Join

### Sample Data

```
Table_M:                          Table_N:
| id | dept |                     | id | dept |
|----|------|                     |----|------|
| 1  | HR   |                     | 1  | HR   |
| 1  | IT   |                     | 1  | IT   |
| 2  | HR   |                     | 2  | FIN  |
| NULL| HR   |                     | NULL| HR   |
```

Joining on BOTH columns: `id AND dept`.

### Expected Counts

| Join Type  | Row Count | Explanation |
|------------|-----------|-------------|
| Inner Join | 2         | (1,HR)↔(1,HR) + (1,IT)↔(1,IT) = 2. (2,HR)≠(2,FIN). NULLs don't match. |
| Left Join  | 4         | 2 matched + 2 unmatched ((2,HR) and (NULL,HR)) |
| Right Join | 4         | 2 matched + 2 unmatched ((2,FIN) and (NULL,HR)) |
| Full Join  | 6         | 2 + 2 + 2 = 6 |
| Cross Join | 16        | 4 × 4 = 16 |

### PySpark Code

```python
data_m = [(1, "HR"), (1, "IT"), (2, "HR"), (None, "HR")]
data_n = [(1, "HR"), (1, "IT"), (2, "FIN"), (None, "HR")]

df_m = spark.createDataFrame(data_m, ["id", "dept"])
df_n = spark.createDataFrame(data_n, ["id", "dept"])

# Multi-column join condition: BOTH columns must match
join_cond = (df_m.id == df_n.id) & (df_m.dept == df_n.dept)

inner_9 = df_m.join(df_n, join_cond, "inner")
left_9 = df_m.join(df_n, join_cond, "left")
right_9 = df_m.join(df_n, join_cond, "right")
full_9 = df_m.join(df_n, join_cond, "full")
cross_9 = df_m.crossJoin(df_n)

print(f"Inner Join: {inner_9.count()} rows")  # 2
print(f"Left Join:  {left_9.count()} rows")   # 4
print(f"Right Join: {right_9.count()} rows")  # 4
print(f"Full Join:  {full_9.count()} rows")   # 6
print(f"Cross Join: {cross_9.count()} rows")  # 16
```

### Row-by-Row Results

**Inner Join → 2 Rows**

Both `id` AND `dept` must match. Row (NULL, HR) doesn't match (NULL, HR) because NULL == NULL is not TRUE.

| df_m.id | df_m.dept | df_n.id | df_n.dept |
|---------|-----------|---------|-----------|
| 1       | HR        | 1       | HR        |
| 1       | IT        | 1       | IT        |

**Left Join → 4 Rows**

| df_m.id | df_m.dept | df_n.id    | df_n.dept  |
|---------|-----------|------------|------------|
| 1       | HR        | 1          | HR         |
| 1       | IT        | 1          | IT         |
| 2       | HR        | NULL *(no match)* | NULL *(no match)* |
| NULL    | HR        | NULL *(no match)* | NULL *(no match)* |

> (2, HR) from T_M doesn't match (2, FIN) from T_N because dept differs. (NULL, HR) doesn't match because id is NULL.

**Right Join → 4 Rows**

| df_m.id    | df_m.dept  | df_n.id | df_n.dept |
|------------|------------|---------|-----------|
| 1          | HR         | 1       | HR        |
| 1          | IT         | 1       | IT        |
| NULL *(no match)* | NULL *(no match)* | 2       | FIN       |
| NULL *(no match)* | NULL *(no match)* | NULL    | HR        |

**Full Join → 6 Rows**

| df_m.id    | df_m.dept  | df_n.id    | df_n.dept  |
|------------|------------|------------|------------|
| 1          | HR         | 1          | HR         |
| 1          | IT         | 1          | IT         |
| 2          | HR         | NULL *(no match)* | NULL *(no match)* |
| NULL       | HR         | NULL *(no match)* | NULL *(no match)* |
| NULL *(no match)* | NULL *(no match)* | 2          | FIN        |
| NULL *(no match)* | NULL *(no match)* | NULL       | HR         |

**Cross Join → 16 Rows**

| df_m.id | df_m.dept | df_n.id | df_n.dept |
|---------|-----------|---------|-----------|
| 1       | HR        | 1       | HR        |
| 1       | HR        | 1       | IT        |
| 1       | HR        | 2       | FIN       |
| 1       | HR        | NULL    | HR        |
| 1       | IT        | 1       | HR        |
| 1       | IT        | 1       | IT        |
| 1       | IT        | 2       | FIN       |
| 1       | IT        | NULL    | HR        |
| 2       | HR        | 1       | HR        |
| 2       | HR        | 1       | IT        |
| 2       | HR        | 2       | FIN       |
| 2       | HR        | NULL    | HR        |
| NULL    | HR        | 1       | HR        |
| NULL    | HR        | 1       | IT        |
| NULL    | HR        | 2       | FIN       |
| NULL    | HR        | NULL    | HR        |

> Key takeaway: With multi-column joins, ALL join columns must match. One NULL in any column makes the entire condition fail.

---

## Scenario 10: Null-Safe Join (eqNullSafe)

### Sample Data (Same as Scenario 1)

```
Table_1: [1, 1, 1, NULL, NULL]    (5 rows)
Table_2: [1, 1, NULL, NULL, NULL]  (5 rows)
```

Using `eqNullSafe` instead of `==` — NULLs now match NULLs.

### Expected Counts

| Join Type  | Row Count | Explanation |
|------------|-----------|-------------|
| Inner Join | 12        | 1→(3×2=6) + NULL→(2×3=6) = 12 |
| Left Join  | 12        | 12 matched + 0 unmatched = 12 |
| Right Join | 12        | 12 matched + 0 unmatched = 12 |
| Full Join  | 12        | 12 + 0 + 0 = 12 |
| Cross Join | 25        | 5 × 5 = 25 (cross join is unaffected) |

### PySpark Code

```python
data1 = [(1,), (1,), (1,), (None,), (None,)]
data2 = [(1,), (1,), (None,), (None,), (None,)]

df1 = spark.createDataFrame(data1, ["val"])
df2 = spark.createDataFrame(data2, ["val"])

# eqNullSafe: NULL == NULL evaluates to TRUE
inner_ns = df1.join(df2, df1.val.eqNullSafe(df2.val), "inner")
left_ns = df1.join(df2, df1.val.eqNullSafe(df2.val), "left")
right_ns = df1.join(df2, df1.val.eqNullSafe(df2.val), "right")
full_ns = df1.join(df2, df1.val.eqNullSafe(df2.val), "full")
cross_ns = df1.crossJoin(df2)  # cross join has no condition

print(f"Inner Join (null-safe): {inner_ns.count()} rows")  # 12
print(f"Left Join (null-safe):  {left_ns.count()} rows")   # 12
print(f"Right Join (null-safe): {right_ns.count()} rows")  # 12
print(f"Full Join (null-safe):  {full_ns.count()} rows")   # 12
print(f"Cross Join:             {cross_ns.count()} rows")  # 25
```

### Row-by-Row Results

**Inner Join (null-safe) → 12 Rows**

NULLs now match! 2 NULLs in T1 × 3 NULLs in T2 = 6 extra rows.

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
| NULL    | NULL    |

**Left / Right / Full Join (null-safe) → 12 Rows**

Same as inner — every row has a match, so outer joins add nothing.

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
| NULL    | NULL    |

### SQL Equivalent

```sql
-- PySpark eqNullSafe is equivalent to SQL's IS NOT DISTINCT FROM
SELECT *
FROM table_1 t1
JOIN table_2 t2
  ON t1.val IS NOT DISTINCT FROM t2.val;
```

> Key takeaway: Compare Scenario 1 (inner=6) vs Scenario 10 (inner=12). The only change is using `eqNullSafe` — the NULL×NULL Cartesian product (2×3=6) is now included. This doubles the result. Understanding `eqNullSafe` / `IS NOT DISTINCT FROM` is critical for interviews.

---

## Key Interview Talking Points

1. **The mental formula:**
   - Inner = sum of (M × N) for each matching value
   - Left = inner + unmatched_from_left
   - Right = inner + unmatched_from_right
   - Full = inner + unmatched_left + unmatched_right = left + right - inner
   - Cross = |T1| × |T2|

2. **Duplicates cause Cartesian products:** When a value appears M times in T1 and N times in T2, the inner join produces M × N rows for that value. This is why 3 ones × 2 ones = 6, not 2 or 3.

3. **NULL never equals NULL in joins:** This is the #1 gotcha. `NULL == NULL` evaluates to NULL (not TRUE), so NULLs never match in join conditions. They only appear in outer join results as unmatched rows. To match NULLs, use `df1.val.eqNullSafe(df2.val)` in PySpark or `IS NOT DISTINCT FROM` in SQL.

4. **Left Outer = Left, Right Outer = Right:** The word "OUTER" is optional in SQL/PySpark. `LEFT JOIN` and `LEFT OUTER JOIN` are identical. Interviewers sometimes use both forms to test if you know they're the same.

5. **Cross join ignores values entirely:** It's a pure Cartesian product based on row counts. NULLs, duplicates, and data don't matter — only `|T1| × |T2|`.

6. **Empty table edge case:** Inner and cross join with an empty table always return 0. Left/full join preserves the non-empty side. This is the one case where cross join can return fewer rows than an outer join.

7. **Multi-column joins:** All columns must match. A NULL in ANY join column makes the entire condition fail for that row pair.

8. **Data explosion in production:** In Scenario 6, two 5-row tables produce a 12-row inner join. In production with millions of rows, a many-to-many join on a column with duplicates can cause OOM errors. Always check for duplicates before joining.

---

## Quick Reference: Join Count Formulas

```
┌──────────────────────────────────────────────────────────────────┐
│                   JOIN ROW COUNT CHEAT SHEET                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  For each distinct non-NULL value v:                             │
│    matched_rows(v) = count_in_T1(v) × count_in_T2(v)            │
│                                                                  │
│  total_matched = Σ matched_rows(v) for all v                     │
│                                                                  │
│  unmatched_left  = rows in T1 with no match                      │
│                    (NULLs + values not in T2)                     │
│                                                                  │
│  unmatched_right = rows in T2 with no match                      │
│                    (NULLs + values not in T1)                     │
│                                                                  │
│  ┌────────────┬────────────────────────────────────────────────┐  │
│  │ Join Type  │ Formula                                        │  │
│  ├────────────┼────────────────────────────────────────────────┤  │
│  │ INNER      │ total_matched                                  │  │
│  │ LEFT       │ total_matched + unmatched_left                 │  │
│  │ RIGHT      │ total_matched + unmatched_right                │  │
│  │ FULL       │ total_matched + unmatched_left + unmatched_right│ │
│  │ CROSS      │ |T1| × |T2|                                   │  │
│  └────────────┴────────────────────────────────────────────────┘  │
│                                                                  │
│  Shortcut: FULL = LEFT + RIGHT − INNER                           │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### All Scenarios Summary Table

| Scenario | T1 | T2 | Inner | Left | Right | Full | Cross |
|----------|----|----|-------|------|-------|------|-------|
| 1. Duplicates + NULLs | `[1,1,1,NULL,NULL]` | `[1,1,NULL,NULL,NULL]` | 6 | 8 | 9 | 11 | 25 |
| 2. Unique + Partial Overlap | `[1,2,3,NULL,NULL]` | `[2,1,NULL,NULL,NULL]` | 2 | 5 | 5 | 8 | 25 |
| 3. Disjoint (No Overlap) | `[1,2,3]` | `[4,5,NULL]` | 0 | 3 | 3 | 6 | 9 |
| 4. Identical Tables | `[1,2,3]` | `[1,2,3]` | 3 | 3 | 3 | 3 | 9 |
| 5. One-to-Many (FK) | `[10,20,30]` | `[10,10,10,20,20,NULL]` | 5 | 6 | 6 | 7 | 18 |
| 6. Many-to-Many | `[1,1,2,2,2]` | `[1,1,1,2,2]` | 12 | 12 | 12 | 12 | 25 |
| 7. One Empty Table | `[1,2,3]` | `[]` | 0 | 3 | 0 | 3 | 0 |
| 8. All NULLs | `[NULL,NULL,NULL]` | `[NULL,NULL]` | 0 | 3 | 2 | 5 | 6 |
| 9. Multi-Column | 4 rows | 4 rows | 2 | 4 | 4 | 6 | 16 |
| 10. Null-Safe (eqNullSafe) | `[1,1,1,NULL,NULL]` | `[1,1,NULL,NULL,NULL]` | 12 | 12 | 12 | 12 | 25 |
