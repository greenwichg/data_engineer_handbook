# PySpark Implementation: Spark SQL vs DataFrame API

## Problem Statement

Given a dataset, solve the same problem using both the **Spark SQL** (string-based SQL queries) and **DataFrame API** (method chaining) approaches. Compare their trade-offs in terms of readability, performance, type safety, and testability. This is a common interview discussion topic.

### Sample Data

**employees:**
```
emp_id  name       department   salary   hire_date
1       Alice      Engineering  90000    2020-01-15
2       Bob        Marketing    65000    2019-03-22
3       Charlie    Engineering  85000    2021-06-01
4       Diana      Marketing    70000    2018-11-30
5       Eve        Engineering  95000    2022-02-14
6       Frank      Finance      80000    2020-07-08
7       Grace      Finance      75000    2021-09-15
```

### Task

Find the **top earner per department** with their rank among department peers and the department average salary.

---

## Setup

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, avg, rank, round as spark_round
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("SQLvsDataFrameAPI").getOrCreate()

data = [
    (1, "Alice", "Engineering", 90000, "2020-01-15"),
    (2, "Bob", "Marketing", 65000, "2019-03-22"),
    (3, "Charlie", "Engineering", 85000, "2021-06-01"),
    (4, "Diana", "Marketing", 70000, "2018-11-30"),
    (5, "Eve", "Engineering", 95000, "2022-02-14"),
    (6, "Frank", "Finance", 80000, "2020-07-08"),
    (7, "Grace", "Finance", 75000, "2021-09-15"),
]
df = spark.createDataFrame(data, ["emp_id", "name", "department", "salary", "hire_date"])

# Register as temp view for SQL
df.createOrReplaceTempView("employees")
```

---

## Approach 1: Spark SQL

```python
result_sql = spark.sql("""
    WITH ranked AS (
        SELECT
            emp_id,
            name,
            department,
            salary,
            RANK() OVER (PARTITION BY department ORDER BY salary DESC) as dept_rank,
            ROUND(AVG(salary) OVER (PARTITION BY department), 2) as dept_avg_salary
        FROM employees
    )
    SELECT
        emp_id, name, department, salary, dept_rank, dept_avg_salary
    FROM ranked
    WHERE dept_rank = 1
    ORDER BY salary DESC
""")

result_sql.show()
```

### Output

```
+------+-----+-----------+------+---------+--------------+
|emp_id| name| department|salary|dept_rank|dept_avg_salary|
+------+-----+-----------+------+---------+--------------+
|     5|  Eve|Engineering| 95000|        1|       90000.0|
|     6|Frank|    Finance| 80000|        1|       77500.0|
|     4|Diana|  Marketing| 70000|        1|       67500.0|
+------+-----+-----------+------+---------+--------------+
```

---

## Approach 2: DataFrame API

```python
# Define window spec
dept_window = Window.partitionBy("department").orderBy(col("salary").desc())
dept_agg_window = Window.partitionBy("department")

result_df = df \
    .withColumn("dept_rank", rank().over(dept_window)) \
    .withColumn("dept_avg_salary", spark_round(avg("salary").over(dept_agg_window), 2)) \
    .filter(col("dept_rank") == 1) \
    .select("emp_id", "name", "department", "salary", "dept_rank", "dept_avg_salary") \
    .orderBy(col("salary").desc())

result_df.show()
```

Same output as above.

---

## Approach 3: Hybrid (Mix SQL and DataFrame API)

```python
# Use SQL for complex logic, DataFrame API for simple transforms
ranked = spark.sql("""
    SELECT *,
           RANK() OVER (PARTITION BY department ORDER BY salary DESC) as dept_rank
    FROM employees
""")

# Continue with DataFrame API for filtering and enrichment
result_hybrid = ranked \
    .filter(col("dept_rank") == 1) \
    .join(
        df.groupBy("department").agg(
            spark_round(avg("salary"), 2).alias("dept_avg_salary")
        ),
        on="department"
    ) \
    .select("emp_id", "name", "department", "salary", "dept_rank", "dept_avg_salary") \
    .orderBy(col("salary").desc())

result_hybrid.show()
```

---

## Side-by-Side Comparison

### Simple Filter
```python
# SQL
spark.sql("SELECT * FROM employees WHERE salary > 80000")

# DataFrame API
df.filter(col("salary") > 80000)
```

### Aggregation with Group By
```python
# SQL
spark.sql("""
    SELECT department, COUNT(*) as cnt, AVG(salary) as avg_sal
    FROM employees
    GROUP BY department
    HAVING COUNT(*) > 1
""")

# DataFrame API
df.groupBy("department") \
    .agg(
        count("*").alias("cnt"),
        avg("salary").alias("avg_sal")
    ) \
    .filter(col("cnt") > 1)
```

### Multi-Table Join
```python
# SQL — often more readable for complex joins
spark.sql("""
    SELECT e.name, d.dept_name, m.name as manager_name
    FROM employees e
    JOIN departments d ON e.department = d.dept_id
    LEFT JOIN employees m ON e.manager_id = m.emp_id
""")

# DataFrame API — more verbose for multi-table
df.alias("e") \
    .join(dept_df.alias("d"), col("e.department") == col("d.dept_id")) \
    .join(df.alias("m"), col("e.manager_id") == col("m.emp_id"), "left") \
    .select("e.name", "d.dept_name", col("m.name").alias("manager_name"))
```

---

## Performance Comparison

```python
# Both produce the SAME physical plan
result_sql.explain(True)
result_df.explain(True)

# Catalyst optimizer handles both identically
# There is NO performance difference between SQL and DataFrame API
```

**Key insight:** Both SQL and DataFrame API go through Catalyst optimization and produce the same execution plan. The choice is purely about developer ergonomics.

---

## Comparison Table

| Aspect | Spark SQL | DataFrame API |
|--------|-----------|---------------|
| **Syntax** | String-based SQL | Method chaining |
| **Readability** | Familiar to SQL users | Familiar to Python devs |
| **Type safety** | No (errors at runtime) | Partial (column names still strings) |
| **IDE support** | No autocomplete | Autocomplete on methods |
| **Composability** | CTEs, subqueries | Chain transformations |
| **Testing** | Harder to unit test | Easier to compose and test |
| **Performance** | Same (Catalyst optimizer) | Same (Catalyst optimizer) |
| **Complex joins** | Often more readable | More verbose |
| **Dynamic logic** | String interpolation (risky) | Programmatic column building |
| **Debugging** | Full query only | Step-by-step inspection |

---

## Key Interview Talking Points

1. **Same performance:** Both Spark SQL and DataFrame API go through the Catalyst optimizer. The physical execution plan is identical. There is zero performance difference.

2. **When to use SQL:** Complex multi-table joins, CTEs, and when the team has strong SQL skills. Also useful for ad-hoc exploration in notebooks.

3. **When to use DataFrame API:** Production pipelines where you need composability, testability, and dynamic column logic. Easier to parameterize and reuse.

4. **Avoid string interpolation in SQL:** `spark.sql(f"SELECT * FROM t WHERE name = '{user_input}'")` is vulnerable to SQL injection. Use parameterized queries or DataFrame API for dynamic values.

5. **Hybrid is common:** Real-world code mixes both — SQL for complex analytical logic, DataFrame API for ETL transformations. This is perfectly fine and often the most readable approach.

6. **Temp views vs DataFrames:** `createOrReplaceTempView` makes a DataFrame accessible via SQL. The view is session-scoped and does not persist data. Use `createGlobalTempView` for cross-session access.
