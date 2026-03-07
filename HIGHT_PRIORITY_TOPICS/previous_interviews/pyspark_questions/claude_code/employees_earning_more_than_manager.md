# PySpark Implementation: Employees Earning More Than Their Manager

## Problem Statement
Given an employees table with a self-referencing manager_id column, find all employees whose salary exceeds their direct manager's salary. This is a classic self-join interview question that tests understanding of hierarchical data and join mechanics.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("EmpVsManager").getOrCreate()

data = [
    (1, "Alice",   130000, None),  # CEO, no manager
    (2, "Bob",      95000, 1),     # reports to Alice
    (3, "Charlie", 140000, 1),     # reports to Alice, earns MORE
    (4, "Diana",    80000, 2),     # reports to Bob
    (5, "Eve",     100000, 2),     # reports to Bob, earns MORE
    (6, "Frank",    75000, 3),     # reports to Charlie
    (7, "Grace",    85000, 3),     # reports to Charlie
    (8, "Hank",     82000, 4),     # reports to Diana, earns MORE
]

df = spark.createDataFrame(data, ["id", "name", "salary", "manager_id"])
df.show()
```

```
+---+-------+------+----------+
| id|   name|salary|manager_id|
+---+-------+------+----------+
|  1|  Alice|130000|      NULL|
|  2|    Bob| 95000|         1|
|  3|Charlie|140000|         1|
|  4|  Diana| 80000|         2|
|  5|    Eve|100000|         2|
|  6|  Frank| 75000|         3|
|  7|  Grace| 85000|         3|
|  8|   Hank| 82000|         4|
+---+-------+------+----------+
```

### Expected Output
```
+---------+--------------+----------+--------------+
|emp_name |emp_salary    |mgr_name  |mgr_salary    |
+---------+--------------+----------+--------------+
|  Charlie|        140000|     Alice|        130000|
|      Eve|        100000|       Bob|         95000|
|     Hank|         82000|     Diana|         80000|
+---------+--------------+----------+--------------+
```

---

## Method 1: Self-Join with DataFrame API (Recommended)
```python
# Create two aliases of the same DataFrame
emp = df.alias("emp")
mgr = df.alias("mgr")

# Self-join: match each employee to their manager
result = (
    emp.join(
        mgr,
        F.col("emp.manager_id") == F.col("mgr.id"),
        how="inner",
    )
    .filter(F.col("emp.salary") > F.col("mgr.salary"))
    .select(
        F.col("emp.name").alias("emp_name"),
        F.col("emp.salary").alias("emp_salary"),
        F.col("mgr.name").alias("mgr_name"),
        F.col("mgr.salary").alias("mgr_salary"),
    )
)
result.show()
```

### Step-by-Step Explanation

**Step 1 -- Self-join on manager_id = id (inner join):**
Every employee row is matched with their manager's row. Employees without a manager (Alice, where manager_id is NULL) are excluded by the inner join.

```
+---+-------+------+----------+---+-------+------+----------+
|emp.id|emp.name|emp.salary|emp.manager_id|mgr.id|mgr.name|mgr.salary|mgr.manager_id|
+------+--------+----------+--------------+------+--------+----------+--------------+
|     2|     Bob|     95000|             1|     1|   Alice|    130000|          NULL|
|     3| Charlie|    140000|             1|     1|   Alice|    130000|          NULL|
|     4|   Diana|     80000|             2|     2|     Bob|     95000|             1|
|     5|     Eve|    100000|             2|     2|     Bob|     95000|             1|
|     6|   Frank|     75000|             3|     3| Charlie|    140000|             1|
|     7|   Grace|     85000|             3|     3| Charlie|    140000|             1|
|     8|    Hank|     82000|             4|     4|   Diana|     80000|             2|
+------+--------+----------+--------------+------+--------+----------+--------------+
```

**Step 2 -- Filter where employee salary > manager salary:**
Only three rows survive: Charlie earns more than Alice, Eve earns more than Bob, Hank earns more than Diana.

**Step 3 -- Select and rename columns for clean output.**

---

## Method 2: Spark SQL with Self-Join
```python
df.createOrReplaceTempView("employees")

result_sql = spark.sql("""
    SELECT
        e.name   AS emp_name,
        e.salary AS emp_salary,
        m.name   AS mgr_name,
        m.salary AS mgr_salary
    FROM employees e
    INNER JOIN employees m
        ON e.manager_id = m.id
    WHERE e.salary > m.salary
    ORDER BY e.salary DESC
""")
result_sql.show()
```

---

## Method 3: Window Function -- Employees Earning More Than Department Average
This is a common follow-up question that uses window functions instead of self-joins.

```python
dept_data = [
    (1, "Alice",   "Engineering", 130000),
    (2, "Bob",     "Engineering",  95000),
    (3, "Charlie", "Engineering", 140000),
    (4, "Diana",   "Marketing",   80000),
    (5, "Eve",     "Marketing",  100000),
    (6, "Frank",   "Marketing",   75000),
]

dept_df = spark.createDataFrame(dept_data, ["id", "name", "department", "salary"])

from pyspark.sql.window import Window

result_avg = (
    dept_df.withColumn(
        "dept_avg_salary",
        F.avg("salary").over(Window.partitionBy("department")),
    )
    .filter(F.col("salary") > F.col("dept_avg_salary"))
    .select("name", "department", "salary", F.round("dept_avg_salary", 2).alias("dept_avg_salary"))
)
result_avg.show()
```

**Output:**
```
+-------+-----------+------+---------------+
|   name| department|salary|dept_avg_salary|
+-------+-----------+------+---------------+
|  Alice|Engineering|130000|      121666.67|
|Charlie|Engineering|140000|      121666.67|
|    Eve|  Marketing|100000|       85000.00|
+-------+-----------+------+---------------+
```

---

## Method 4: Using a Map (Broadcast) Lookup
When the manager table is small, you can collect manager salaries into a map and broadcast it.

```python
mgr_map = {row["id"]: row["salary"] for row in df.select("id", "salary").collect()}

from pyspark.sql.types import IntegerType

@F.udf(IntegerType())
def get_mgr_salary(manager_id):
    if manager_id is None:
        return None
    return mgr_map.get(manager_id)

result_udf = (
    df.withColumn("mgr_salary", get_mgr_salary(F.col("manager_id")))
    .filter(F.col("salary") > F.col("mgr_salary"))
    .select("name", "salary", "mgr_salary")
)
result_udf.show()
```

> **Note:** This UDF approach is fine for small datasets but a self-join is preferred at scale since UDFs prevent Catalyst optimizations.

---

## Key Interview Talking Points
1. **Self-join** is the canonical technique for comparing rows within the same table across a hierarchical relationship.
2. Always use **aliases** (`alias("emp")`, `alias("mgr")`) to disambiguate columns when joining a table to itself.
3. The inner join naturally excludes the CEO (NULL manager_id), so no extra null-handling is needed.
4. For the "more than department average" variant, a **window function** with `avg().over(partitionBy)` is cleaner than a self-join with a subquery.
5. Be aware of **NULL handling**: `NULL > anything` evaluates to NULL (falsy) in Spark, so NULLs are safely excluded without explicit filtering.
6. If the hierarchy is deeper (e.g., "find employees earning more than any ancestor"), you would need **recursive joins or iterative traversal** -- Spark does not support recursive CTEs natively.
7. For very wide hierarchies, consider **broadcasting** the smaller manager DataFrame using `F.broadcast()` to avoid shuffle.
8. The UDF approach should be mentioned as an option but flagged as suboptimal because it breaks Spark's Catalyst optimizer pipeline.
