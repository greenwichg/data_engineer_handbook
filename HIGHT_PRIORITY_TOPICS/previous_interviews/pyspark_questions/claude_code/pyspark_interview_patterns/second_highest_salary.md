# PySpark Implementation: Second Highest Salary

## Problem Statement

Finding the Nth highest salary (most commonly the 2nd highest) is one of the most frequently asked interview questions. It tests your understanding of window functions, subqueries, and deduplication logic. You need to handle edge cases like tied salaries and NULL values. Interviewers often extend this to "per department" to test partitioning knowledge.

### Sample Data

```python
data = [
    (1, "Alice", "Engineering", 95000),
    (2, "Bob", "Engineering", 90000),
    (3, "Charlie", "Engineering", 95000),  # Tied with Alice
    (4, "Diana", "Marketing", 80000),
    (5, "Eve", "Marketing", 85000),
    (6, "Frank", "Marketing", 85000),      # Tied with Eve
    (7, "Grace", "Marketing", 70000),
    (8, "Heidi", "Sales", 60000),
    (9, "Ivan", "Sales", 60000),           # Only one distinct salary in Sales
]
columns = ["emp_id", "name", "department", "salary"]
```

### Expected Output

**Overall 2nd highest salary:** 90000

**Per-department 2nd highest salary:**
| department  | second_highest_salary |
|-------------|-----------------------|
| Engineering | 90000                 |
| Marketing   | 80000                 |
| Sales       | NULL (only one distinct salary) |

---

## Method 1: Window Function with dense_rank (Recommended)

This is the go-to approach in interviews. `dense_rank` handles ties correctly by not skipping ranks.

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("SecondHighestSalary").getOrCreate()

data = [
    (1, "Alice", "Engineering", 95000),
    (2, "Bob", "Engineering", 90000),
    (3, "Charlie", "Engineering", 95000),
    (4, "Diana", "Marketing", 80000),
    (5, "Eve", "Marketing", 85000),
    (6, "Frank", "Marketing", 85000),
    (7, "Grace", "Marketing", 70000),
    (8, "Heidi", "Sales", 60000),
    (9, "Ivan", "Sales", 60000),
]
columns = ["emp_id", "name", "department", "salary"]
df = spark.createDataFrame(data, columns)

# --- Overall 2nd highest salary ---
window_all = Window.orderBy(F.col("salary").desc())

result_overall = (
    df.withColumn("dense_rnk", F.dense_rank().over(window_all))
    .filter(F.col("dense_rnk") == 2)
    .select("salary")
    .distinct()
)
result_overall.show()

# --- Per-department 2nd highest salary ---
window_dept = Window.partitionBy("department").orderBy(F.col("salary").desc())

result_dept = (
    df.withColumn("dense_rnk", F.dense_rank().over(window_dept))
    .filter(F.col("dense_rnk") == 2)
    .select("department", F.col("salary").alias("second_highest_salary"))
    .distinct()
)
result_dept.show()
```

**Why dense_rank and not rank?** If two people share the highest salary, `rank()` would assign rank 1 to both but then skip to rank 3. The "2nd highest salary" would return nothing. `dense_rank()` assigns 1, 1, 2 so the next distinct salary correctly gets rank 2.

---

## Method 2: Subquery / Distinct + OrderBy + Limit + Offset

A simpler approach that avoids window functions entirely. Good for showing you know multiple ways.

```python
# --- Overall 2nd highest salary using distinct + orderBy ---
second_highest = (
    df.select("salary")
    .distinct()
    .orderBy(F.col("salary").desc())
    .limit(2)            # Take top 2 distinct salaries
    .orderBy("salary")   # Re-sort ascending so the smaller one is first
    .limit(1)            # Take the first (which is 2nd highest)
)
second_highest.show()

# Alternative: collect and index (small result sets only)
salaries = (
    df.select("salary")
    .distinct()
    .orderBy(F.col("salary").desc())
    .collect()
)
if len(salaries) >= 2:
    print(f"2nd highest salary: {salaries[1]['salary']}")
else:
    print("No 2nd highest salary exists")
```

---

## Method 3: Correlated Subquery Style (Using Joins)

This mirrors the classic SQL subquery: "find the max salary that is less than the max salary."

```python
# Overall: max salary less than the max
max_salary = df.agg(F.max("salary").alias("max_sal")).collect()[0]["max_sal"]

second_highest = (
    df.filter(F.col("salary") < max_salary)
    .agg(F.max("salary").alias("second_highest_salary"))
)
second_highest.show()

# Per-department: self-join approach
max_per_dept = (
    df.groupBy("department")
    .agg(F.max("salary").alias("max_salary"))
)

second_per_dept = (
    df.join(max_per_dept, on="department")
    .filter(F.col("salary") < F.col("max_salary"))
    .groupBy("department")
    .agg(F.max("salary").alias("second_highest_salary"))
)
second_per_dept.show()
```

**Caveat:** This approach returns nothing for departments where all employees have the same salary (e.g., Sales). The window function approach at least lets you detect that case.

---

## Method 4: Generic Nth Highest (Parameterized)

Show the interviewer you can generalize.

```python
def nth_highest_salary(df, n, partition_col=None):
    """Find the Nth highest salary, optionally per partition."""
    if partition_col:
        window = Window.partitionBy(partition_col).orderBy(F.col("salary").desc())
    else:
        window = Window.orderBy(F.col("salary").desc())

    result = (
        df.withColumn("dense_rnk", F.dense_rank().over(window))
        .filter(F.col("dense_rnk") == n)
        .drop("dense_rnk")
    )
    return result

# 2nd highest overall
nth_highest_salary(df, 2).show()

# 3rd highest per department
nth_highest_salary(df, 3, "department").show()
```

---

## Key Takeaways

- **Always use `dense_rank()`** for "Nth highest" problems. It does not skip ranks on ties, which is the correct behavior when looking for the Nth distinct value.
- **`rank()` skips ranks after ties** (1, 1, 3) while **`dense_rank()` does not** (1, 1, 2). This distinction is critical.
- **Handle edge cases**: What if there is no 2nd highest? What if all salaries are the same? Always mention these to the interviewer.
- **Per-department** just means adding `partitionBy("department")` to the window spec. This is a trivial extension but interviewers love asking it.
- The **distinct + orderBy + limit** approach is simple but hard to generalize to per-department without window functions.
- **Mention performance**: Window functions require a full shuffle. For very large datasets, the distinct+sort approach on a small column might be cheaper, but window functions are more flexible and idiomatic.

## Interview Tips

- Start by clarifying: "Should tied salaries count as the same rank?" This shows you understand the problem deeply.
- Write the `dense_rank` solution first -- it is the most robust and interviewers expect it.
- If asked for a follow-up, generalize to Nth highest or show the alternative approaches.
- Always test your logic mentally with the tied-salary edge case.
