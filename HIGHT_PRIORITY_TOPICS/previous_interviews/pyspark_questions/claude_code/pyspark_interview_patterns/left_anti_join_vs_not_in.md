# PySpark Implementation: Left Anti Join vs NOT IN vs NOT EXISTS vs Left Join + IS NULL

## Problem Statement

Finding records in one table that do NOT exist in another is a common interview question. There are four main approaches in PySpark, and each has different behavior -- especially when NULL values are present. The interviewer wants to see that you know the **NULL pitfall** of NOT IN and can explain why left anti join is usually the best choice in PySpark.

### Sample Data

```python
# All employees
employees_data = [
    (1, "Alice", "Engineering"),
    (2, "Bob", "Marketing"),
    (3, "Charlie", "Sales"),
    (4, "Diana", "Engineering"),
    (5, "Eve", "Marketing"),
    (6, "Frank", None),          # NULL department
]
emp_columns = ["emp_id", "name", "department"]

# Employees who received a bonus
bonus_data = [
    (1, 5000),
    (3, 3000),
    (None, 2000),   # NULL emp_id -- this causes problems with NOT IN
]
bonus_columns = ["emp_id", "bonus_amount"]
```

### Expected Output

**Employees who did NOT receive a bonus:** Bob (2), Diana (4), Eve (5), Frank (6)

---

## Method 1: Left Anti Join (Recommended)

The left anti join returns all rows from the left table that have NO match in the right table. It handles NULLs correctly and is the most efficient approach in PySpark.

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("AntiJoinComparison").getOrCreate()

employees_data = [
    (1, "Alice", "Engineering"),
    (2, "Bob", "Marketing"),
    (3, "Charlie", "Sales"),
    (4, "Diana", "Engineering"),
    (5, "Eve", "Marketing"),
    (6, "Frank", None),
]
emp_columns = ["emp_id", "name", "department"]
employees = spark.createDataFrame(employees_data, emp_columns)

bonus_data = [
    (1, 5000),
    (3, 3000),
    (None, 2000),
]
bonus_columns = ["emp_id", "bonus_amount"]
bonuses = spark.createDataFrame(bonus_data, bonus_columns)

# Left Anti Join
no_bonus = employees.join(bonuses, on="emp_id", how="left_anti")
no_bonus.show()
```

**Output:**
```
+------+-----+-----------+
|emp_id| name| department|
+------+-----+-----------+
|     2|  Bob|  Marketing|
|     4|Diana|Engineering|
|     5|  Eve|  Marketing|
|     6|Frank|       null|
+------+-----+-----------+
```

**Correct result.** The NULL emp_id in bonuses does not match any employee (NULL != NULL in joins), so it does not incorrectly exclude anyone.

---

## Method 2: NOT IN Using isin() -- The NULL Pitfall

```python
# Collect bonus emp_ids (includes None)
bonus_ids = [row["emp_id"] for row in bonuses.select("emp_id").collect()]
print(f"Bonus IDs: {bonus_ids}")  # [1, 3, None]

# NOT IN approach
no_bonus_not_in = employees.filter(~F.col("emp_id").isin(bonus_ids))
no_bonus_not_in.show()
```

**Output:**
```
+------+----+----------+
|emp_id|name|department|
+------+----+----------+
+------+----+----------+
```

**EMPTY RESULT!** This is the NULL pitfall. When the list contains NULL, `NOT IN` returns no rows because:
- `x NOT IN (1, 3, NULL)` evaluates to `x != 1 AND x != 3 AND x != NULL`
- `x != NULL` is always UNKNOWN (not TRUE or FALSE)
- `TRUE AND TRUE AND UNKNOWN = UNKNOWN`, which is treated as FALSE

**Fix: Filter out NULLs from the list first.**

```python
# Safe NOT IN: remove NULLs from the list
bonus_ids_clean = [x for x in bonus_ids if x is not None]
no_bonus_safe = employees.filter(~F.col("emp_id").isin(bonus_ids_clean))
no_bonus_safe.show()
```

**Now it returns the correct 4 rows.**

---

## Method 3: NOT EXISTS Using Left Semi Join Negation

SQL's `NOT EXISTS` does not have a direct PySpark equivalent, but you can simulate it with a left anti join (which IS the PySpark equivalent) or with a subtract pattern.

```python
# Approach 3a: Using subtract (set difference)
# Get emp_ids that have bonuses
emp_with_bonus = employees.join(bonuses, on="emp_id", how="left_semi")
# Subtract to get those without
no_bonus_subtract = employees.subtract(emp_with_bonus)
no_bonus_subtract.show()

# Approach 3b: SQL NOT EXISTS (register as temp views)
employees.createOrReplaceTempView("employees")
bonuses.createOrReplaceTempView("bonuses")

no_bonus_sql = spark.sql("""
    SELECT e.*
    FROM employees e
    WHERE NOT EXISTS (
        SELECT 1 FROM bonuses b WHERE b.emp_id = e.emp_id
    )
""")
no_bonus_sql.show()
```

**Both return the correct result.** `NOT EXISTS` handles NULLs correctly because it uses correlated subquery logic: `NULL = NULL` evaluates to UNKNOWN, so the EXISTS never finds a match for NULL rows, and they are correctly included.

---

## Method 4: Left Join + IS NULL

```python
# Left join and filter for non-matches
no_bonus_left = (
    employees.alias("e")
    .join(bonuses.alias("b"), on="emp_id", how="left")
    .filter(F.col("b.bonus_amount").isNull())
    .select("e.*")
)
no_bonus_left.show()
```

**Correct result.** After the left join, non-matching rows have NULLs in the right table columns. Filtering for `IS NULL` on a non-nullable right-table column gives us the unmatched rows.

**Caveat:** You must filter on a column that is NOT NULL in the original right table (like the bonus_amount, not emp_id which has a NULL). If the right table column you filter on can be NULL naturally, you might get false positives.

---

## Performance Comparison

```python
# Check execution plans to compare performance
print("=== Left Anti Join ===")
employees.join(bonuses, on="emp_id", how="left_anti").explain()

print("\n=== Left Join + IS NULL ===")
(
    employees.alias("e")
    .join(bonuses.alias("b"), on="emp_id", how="left")
    .filter(F.col("b.bonus_amount").isNull())
    .select("e.*")
).explain()

print("\n=== SQL NOT EXISTS ===")
spark.sql("""
    SELECT e.*
    FROM employees e
    WHERE NOT EXISTS (SELECT 1 FROM bonuses b WHERE b.emp_id = e.emp_id)
""").explain()
```

**Performance ranking (best to worst for large datasets):**

| Approach | Performance | NULL-safe? | Notes |
|----------|-------------|------------|-------|
| Left Anti Join | Best | Yes | Catalyst optimizes this natively. Single pass, no extra columns. |
| NOT EXISTS (SQL) | Best | Yes | Catalyst converts this to a left anti join internally. |
| Left Join + IS NULL | Good | Mostly* | Requires joining all columns then filtering. More data shuffled. |
| NOT IN (isin) | Worst | NO | Collects to driver, broadcasts list. Fails with NULLs. |

*Left Join + IS NULL can give wrong results if you pick a nullable column to check.

---

## Left Semi Join (Bonus -- The Opposite)

While we are discussing anti joins, know the semi join too. It finds rows that DO have a match.

```python
# Employees who DID receive a bonus
with_bonus = employees.join(bonuses, on="emp_id", how="left_semi")
with_bonus.show()
# Returns Alice (1) and Charlie (3)
# Note: does NOT return bonus_amount -- semi join only returns left table columns
```

**Key difference from inner join:** Semi join returns each left row at most once, even if there are multiple matches in the right table. Inner join would duplicate left rows.

---

## Multi-Column Anti Join

```python
# Find department-role combinations in table A that don't exist in table B
table_a = spark.createDataFrame([
    ("Engineering", "Senior"), ("Engineering", "Junior"),
    ("Marketing", "Senior"), ("Sales", "Junior"),
], ["dept", "role"])

table_b = spark.createDataFrame([
    ("Engineering", "Senior"), ("Marketing", "Senior"),
], ["dept", "role"])

# Anti join on multiple columns
missing = table_a.join(table_b, on=["dept", "role"], how="left_anti")
missing.show()
# Returns: (Engineering, Junior), (Sales, Junior)
```

---

## The NULL Pitfall -- Deep Dive

This is worth drilling because interviewers love it.

```python
# Demonstration of the three-valued logic problem
test_df = spark.createDataFrame([(1,), (2,), (3,)], ["id"])

# With NULL in the list
print("NOT IN with NULL in list:")
test_df.filter(~F.col("id").isin(1, None)).show()  # Returns NOTHING

# Without NULL in the list
print("NOT IN without NULL:")
test_df.filter(~F.col("id").isin(1)).show()  # Returns 2, 3

# Why? Three-valued logic:
# id=2: NOT (2 IN (1, NULL))
#      = NOT (2=1 OR 2=NULL)
#      = NOT (FALSE OR UNKNOWN)
#      = NOT (UNKNOWN)
#      = UNKNOWN  --> filtered out!
```

---

## Key Takeaways

- **Always prefer `left_anti` join in PySpark.** It is NULL-safe, performant, and semantically clear.
- **NEVER use `NOT IN` / `isin()` with a list that might contain NULLs.** The result will be empty due to three-valued logic.
- `NOT EXISTS` in SQL is equivalent to `left_anti` in PySpark. Catalyst optimizes them to the same plan.
- `Left Join + IS NULL` works but shuffles more data and you must filter on a guaranteed non-null column.
- **Left semi join** is the positive counterpart -- use it when you want rows that DO match (like `IN` or `EXISTS`).

## Interview Tips

- If asked "How do you find rows not in another table?", immediately say "left anti join" and explain why it is better than NOT IN.
- Proactively mention the NULL pitfall of NOT IN. This is the trap the interviewer is setting.
- Know that Catalyst optimizes NOT EXISTS to a left anti join. This shows you understand the query engine.
- If the interviewer insists on NOT IN, show that you filter NULLs first: `bonus_ids_clean = [x for x in bonus_ids if x is not None]`.
- Mention that `isin()` collects data to the driver node. For large lists, this can cause OOM errors. Anti join keeps everything distributed.
