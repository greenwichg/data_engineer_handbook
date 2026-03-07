# PySpark Implementation: Group Concatenation with collect_list and collect_set

## Problem Statement
Given a table of departments and employee names, produce one row per department with all employee names aggregated into a sorted, comma-separated string. This covers PySpark's equivalents of SQL's `GROUP_CONCAT` / `STRING_AGG` / `LISTAGG` functions.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("GroupConcat").getOrCreate()

data = [
    ("Engineering", "Alice",   "2022-03-15"),
    ("Engineering", "Bob",     "2021-07-01"),
    ("Engineering", "Charlie", "2023-01-10"),
    ("Marketing",   "Diana",   "2020-06-01"),
    ("Marketing",   "Eve",     "2022-11-20"),
    ("Marketing",   "Diana",   "2023-05-01"),  # Diana appears twice (e.g., re-hire)
    ("Sales",       "Frank",   "2021-01-15"),
    ("Sales",       "Grace",   "2021-09-01"),
    ("Sales",       "Hank",    "2022-04-10"),
    ("Sales",       "Grace",   "2023-02-01"),  # Grace appears twice
]

df = spark.createDataFrame(data, ["department", "employee_name", "join_date"])
df = df.withColumn("join_date", F.to_date("join_date"))
df.show()
```

```
+-----------+-------------+----------+
| department|employee_name| join_date|
+-----------+-------------+----------+
|Engineering|        Alice|2022-03-15|
|Engineering|          Bob|2021-07-01|
|Engineering|      Charlie|2023-01-10|
|  Marketing|        Diana|2020-06-01|
|  Marketing|          Eve|2022-11-20|
|  Marketing|        Diana|2023-05-01|
|      Sales|        Frank|2021-01-15|
|      Sales|        Grace|2021-09-01|
|      Sales|         Hank|2022-04-10|
|      Sales|        Grace|2023-02-01|
+-----------+-------------+----------+
```

### Expected Output (sorted, distinct names)
```
+-----------+-------------------+
| department|      employee_list|
+-----------+-------------------+
|Engineering|Alice, Bob, Charlie|
|  Marketing|         Diana, Eve|
|      Sales| Frank, Grace, Hank|
+-----------+-------------------+
```

---

## Method 1: collect_list + concat_ws (Recommended)
```python
# Basic aggregation with collect_list and concat_ws
result = (
    df.select("department", "employee_name")
    .distinct()  # Remove duplicates first
    .groupBy("department")
    .agg(
        F.concat_ws(", ", F.sort_array(F.collect_list("employee_name"))).alias(
            "employee_list"
        )
    )
    .orderBy("department")
)
result.show(truncate=False)
```

### Step-by-Step Explanation

**Step 1 -- Distinct to remove duplicate employee entries:**
```
+-----------+-------------+
| department|employee_name|
+-----------+-------------+
|Engineering|        Alice|
|Engineering|          Bob|
|Engineering|      Charlie|
|  Marketing|        Diana|
|  Marketing|          Eve|
|      Sales|        Frank|
|      Sales|        Grace|
|      Sales|         Hank|
+-----------+-------------+
```

**Step 2 -- `collect_list("employee_name")` gathers names into an array per department:**
```
+-----------+------------------------+
| department|collected               |
+-----------+------------------------+
|Engineering|[Bob, Alice, Charlie]   |
|  Marketing|[Diana, Eve]           |
|      Sales|[Grace, Hank, Frank]   |
+-----------+------------------------+
```
Note: The order within collect_list is non-deterministic without explicit sorting.

**Step 3 -- `sort_array(...)` sorts the array alphabetically:**
```
+-----------+------------------------+
| department|sorted                  |
+-----------+------------------------+
|Engineering|[Alice, Bob, Charlie]   |
|  Marketing|[Diana, Eve]           |
|      Sales|[Frank, Grace, Hank]   |
+-----------+------------------------+
```

**Step 4 -- `concat_ws(", ", ...)` joins array elements into a comma-separated string:**
```
+-----------+-------------------+
| department|      employee_list|
+-----------+-------------------+
|Engineering|Alice, Bob, Charlie|
|  Marketing|         Diana, Eve|
|      Sales| Frank, Grace, Hank|
+-----------+-------------------+
```

---

## Method 2: collect_set for Automatic Deduplication
```python
# collect_set automatically removes duplicates (but does NOT guarantee order)
result_set = (
    df.groupBy("department")
    .agg(
        F.concat_ws(", ", F.sort_array(F.collect_set("employee_name"))).alias(
            "employee_list"
        )
    )
    .orderBy("department")
)
result_set.show(truncate=False)
```

This avoids the need for a `.distinct()` step before grouping. `collect_set` removes duplicates at the aggregation level.

---

## Method 3: Ordered Collection by Join Date (Chronological Aggregation)
When you need names ordered by join date rather than alphabetically, you must pre-sort and use `collect_list` (which preserves insertion order when the input is sorted).

```python
# Use a window function to sort, then collect
window_spec = Window.partitionBy("department").orderBy("join_date")

result_chrono = (
    df.select("department", "employee_name", "join_date")
    .distinct()
    .withColumn("rn", F.row_number().over(window_spec))
    .groupBy("department")
    .agg(
        F.concat_ws(", ", F.collect_list("employee_name")).alias("employee_list_chrono")
    )
    .orderBy("department")
)
result_chrono.show(truncate=False)
```

**Alternative approach with struct sorting:**
```python
# Collect structs with the sort key, then extract names
result_struct = (
    df.select("department", "employee_name", "join_date")
    .distinct()
    .groupBy("department")
    .agg(
        F.collect_list(F.struct("join_date", "employee_name")).alias("collected")
    )
    .withColumn("sorted", F.sort_array("collected"))
    .withColumn(
        "employee_list",
        F.concat_ws(", ", F.transform("sorted", lambda x: x["employee_name"])),
    )
    .select("department", "employee_list")
    .orderBy("department")
)
result_struct.show(truncate=False)
```

**Output (ordered by join date):**
```
+-----------+-------------------+
| department|      employee_list|
+-----------+-------------------+
|Engineering|Bob, Alice, Charlie|
|  Marketing|         Diana, Eve|
|      Sales|Frank, Grace, Hank |
+-----------+-------------------+
```

---

## Method 4: Spark SQL Equivalent
```python
df.createOrReplaceTempView("employees")

result_sql = spark.sql("""
    SELECT
        department,
        CONCAT_WS(', ', SORT_ARRAY(COLLECT_SET(employee_name))) AS employee_list
    FROM employees
    GROUP BY department
    ORDER BY department
""")
result_sql.show(truncate=False)
```

---

## Collecting Multiple Columns
A common extension is collecting multiple fields per group:
```python
result_multi = (
    df.select("department", "employee_name", "join_date")
    .distinct()
    .groupBy("department")
    .agg(
        F.concat_ws(", ", F.sort_array(F.collect_set("employee_name"))).alias("employees"),
        F.count("employee_name").alias("headcount"),
        F.min("join_date").alias("earliest_hire"),
        F.max("join_date").alias("latest_hire"),
    )
    .orderBy("department")
)
result_multi.show(truncate=False)
```

```
+-----------+-------------------+---------+-------------+-----------+
| department|          employees|headcount|earliest_hire|latest_hire|
+-----------+-------------------+---------+-------------+-----------+
|Engineering|Alice, Bob, Charlie|        3|   2021-07-01| 2023-01-10|
|  Marketing|         Diana, Eve|        2|   2020-06-01| 2022-11-20|
|      Sales| Frank, Grace, Hank|        3|   2021-01-15| 2022-04-10|
+-----------+-------------------+---------+-------------+-----------+
```

---

## Key Interview Talking Points
1. **`collect_list`** keeps duplicates and preserves insertion order. **`collect_set`** removes duplicates but returns an unordered set.
2. `collect_list` order is non-deterministic unless the input partition is sorted. Use `sort_array()` after collection, or pre-sort with a window function.
3. **`concat_ws(separator, array)`** is the PySpark way to join array elements into a string. It gracefully handles NULLs by skipping them.
4. For ordered aggregation, the **struct + sort_array** trick is powerful: wrap the sort key and value in a struct, sort the array of structs, then extract the value field.
5. `collect_list` and `collect_set` collect all values into the driver for each group. For groups with millions of values, this can cause **OOM errors**. Mention this scalability concern.
6. In Spark 2.4+, `F.transform()` allows lambda-style processing on array columns, avoiding the need for UDFs.
7. There is no native `GROUP_CONCAT` function in Spark. The `collect_list` + `concat_ws` pattern is the standard equivalent.
8. When the interviewer asks about ordering guarantees, emphasize that `collect_list` output order depends on the physical plan. Always apply explicit sorting if order matters.
