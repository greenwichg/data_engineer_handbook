# PySpark Implementation: Hierarchical Path Construction

## Problem Statement
Given an organizational chart stored as a self-referencing table (employee_id, name, manager_id), construct the full reporting chain path for each employee from the CEO down. For example, an employee at level 4 should show: `CEO > VP > Director > Employee`. This tests your ability to handle recursive/hierarchical data in Spark, which lacks native recursive CTEs.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("HierarchicalPath").getOrCreate()

data = [
    (1, "Alice",   None),   # CEO
    (2, "Bob",     1),      # VP, reports to Alice
    (3, "Charlie", 1),      # VP, reports to Alice
    (4, "Diana",   2),      # Director, reports to Bob
    (5, "Eve",     2),      # Director, reports to Bob
    (6, "Frank",   3),      # Director, reports to Charlie
    (7, "Grace",   4),      # Manager, reports to Diana
    (8, "Hank",    4),      # Manager, reports to Diana
    (9, "Ivy",     6),      # Manager, reports to Frank
    (10, "Jack",   7),      # IC, reports to Grace
]

df = spark.createDataFrame(data, ["employee_id", "name", "manager_id"])
df.show()
```

```
+-----------+-------+----------+
|employee_id|   name|manager_id|
+-----------+-------+----------+
|          1|  Alice|      NULL|
|          2|    Bob|         1|
|          3|Charlie|         1|
|          4|  Diana|         2|
|          5|    Eve|         2|
|          6|  Frank|         3|
|          7|  Grace|         4|
|          8|   Hank|         4|
|          9|    Ivy|         6|
|         10|   Jack|         7|
+-----------+-------+----------+
```

### Expected Output
```
+-----------+-------+-----+--------------------------------------+
|employee_id|   name|level|                           report_path|
+-----------+-------+-----+--------------------------------------+
|          1|  Alice|    1|                                 Alice|
|          2|    Bob|    2|                         Alice > Bob  |
|          3|Charlie|    2|                     Alice > Charlie  |
|          4|  Diana|    3|                 Alice > Bob > Diana  |
|          5|    Eve|    3|                   Alice > Bob > Eve  |
|          6|  Frank|    3|             Alice > Charlie > Frank  |
|          7|  Grace|    4|         Alice > Bob > Diana > Grace  |
|          8|   Hank|    4|          Alice > Bob > Diana > Hank  |
|          9|    Ivy|    4|         Alice > Charlie > Frank > Ivy|
|         10|   Jack|    5| Alice > Bob > Diana > Grace > Jack  |
+-----------+-------+-----+--------------------------------------+
```

---

## Method 1: Iterative Self-Join (Recommended)
Since PySpark does not support recursive CTEs, we traverse the hierarchy iteratively by joining each level to its parent until we reach the root.

```python
# Start with the root nodes (employees with no manager)
root = (
    df.filter(F.col("manager_id").isNull())
    .select(
        F.col("employee_id"),
        F.col("name"),
        F.lit(1).alias("level"),
        F.col("name").alias("report_path"),
    )
)

current_level = root
all_levels = root

# Iteratively join children to current level
max_depth = 10  # safety limit to prevent infinite loops
for i in range(2, max_depth + 1):
    # Join employees whose manager_id matches current level's employee_id
    next_level = (
        df.alias("child")
        .join(
            current_level.alias("parent"),
            F.col("child.manager_id") == F.col("parent.employee_id"),
            how="inner",
        )
        .select(
            F.col("child.employee_id"),
            F.col("child.name"),
            F.lit(i).alias("level"),
            F.concat_ws(" > ", F.col("parent.report_path"), F.col("child.name")).alias(
                "report_path"
            ),
        )
    )

    # If no more children found, stop
    if next_level.count() == 0:
        break

    all_levels = all_levels.union(next_level)
    current_level = next_level

result = all_levels.orderBy("level", "employee_id")
result.show(truncate=False)
```

### Step-by-Step Explanation

**Iteration 0 -- Root level (CEO):**
```
+-----------+-----+-----+-----------+
|employee_id| name|level|report_path|
+-----------+-----+-----+-----------+
|          1|Alice|    1|      Alice|
+-----------+-----+-----+-----------+
```

**Iteration 1 -- Level 2 (VPs who report to root):**
Join `df` to `current_level` (Alice) on `manager_id == employee_id`. Bob and Charlie match.
```
+-----------+-------+-----+----------------+
|employee_id|   name|level|     report_path|
+-----------+-------+-----+----------------+
|          2|    Bob|    2|   Alice > Bob   |
|          3|Charlie|    2|Alice > Charlie  |
+-----------+-------+-----+----------------+
```

**Iteration 2 -- Level 3 (Directors who report to VPs):**
Join `df` to `current_level` (Bob, Charlie). Diana, Eve report to Bob. Frank reports to Charlie.
```
+-----------+-----+-----+------------------------+
|employee_id| name|level|             report_path|
+-----------+-----+-----+------------------------+
|          4|Diana|    3|     Alice > Bob > Diana |
|          5|  Eve|    3|       Alice > Bob > Eve |
|          6|Frank|    3| Alice > Charlie > Frank |
+-----------+-----+-----+------------------------+
```

**Iteration 3 -- Level 4 (Managers):**
```
+-----------+-----+-----+--------------------------------+
|employee_id| name|level|                     report_path|
+-----------+-----+-----+--------------------------------+
|          7|Grace|    4|     Alice > Bob > Diana > Grace |
|          8| Hank|    4|      Alice > Bob > Diana > Hank |
|          9|  Ivy|    4| Alice > Charlie > Frank > Ivy   |
+-----------+-----+-----+--------------------------------+
```

**Iteration 4 -- Level 5 (ICs):**
```
+-----------+----+-----+--------------------------------------+
|employee_id|name|level|                           report_path|
+-----------+----+-----+--------------------------------------+
|         10|Jack|    5| Alice > Bob > Diana > Grace > Jack   |
+-----------+----+-----+--------------------------------------+
```

**Final -- Union all levels and sort.**

---

## Method 2: Spark SQL with Iterative CTE Simulation
```python
df.createOrReplaceTempView("org_chart")

# Build level by level using temp views
spark.sql("""
    CREATE OR REPLACE TEMP VIEW level_1 AS
    SELECT employee_id, name, 1 AS level, name AS report_path
    FROM org_chart
    WHERE manager_id IS NULL
""")

# In practice, you would loop in Python and execute SQL per level:
for lvl in range(2, 10):
    prev = f"level_{lvl - 1}"
    curr = f"level_{lvl}"
    count = spark.sql(f"""
        CREATE OR REPLACE TEMP VIEW {curr} AS
        SELECT c.employee_id, c.name, {lvl} AS level,
               CONCAT(p.report_path, ' > ', c.name) AS report_path
        FROM org_chart c
        INNER JOIN {prev} p ON c.manager_id = p.employee_id
    """)
    row_count = spark.sql(f"SELECT COUNT(*) AS cnt FROM {curr}").collect()[0]["cnt"]
    if row_count == 0:
        break

# Union all levels
view_names = [f"SELECT * FROM level_{i}" for i in range(1, lvl + 1)]
union_query = " UNION ALL ".join(view_names)
result_sql = spark.sql(f"{union_query} ORDER BY level, employee_id")
result_sql.show(truncate=False)
```

---

## Method 3: Collect-and-Traverse with UDF (Small Datasets)
For small org charts, collect the entire table to the driver and build paths in Python.

```python
from pyspark.sql.types import StringType, IntegerType, StructType, StructField

# Collect the full org chart into a Python dictionary
rows = df.collect()
manager_map = {row["employee_id"]: row["manager_id"] for row in rows}
name_map = {row["employee_id"]: row["name"] for row in rows}

def build_path(emp_id):
    """Walk up the hierarchy and build the path."""
    path_parts = []
    current = emp_id
    while current is not None:
        path_parts.append(name_map[current])
        current = manager_map.get(current)
    path_parts.reverse()
    return " > ".join(path_parts)

def get_level(emp_id):
    """Count depth from root."""
    level = 0
    current = emp_id
    while current is not None:
        level += 1
        current = manager_map.get(current)
    return level

# Build result using UDFs
build_path_udf = F.udf(build_path, StringType())
get_level_udf = F.udf(get_level, IntegerType())

result_udf = (
    df.withColumn("level", get_level_udf(F.col("employee_id")))
    .withColumn("report_path", build_path_udf(F.col("employee_id")))
    .select("employee_id", "name", "level", "report_path")
    .orderBy("level", "employee_id")
)
result_udf.show(truncate=False)
```

> **Warning:** This UDF approach only works when the entire org chart fits in driver memory. It does not scale to large hierarchies.

---

## Detecting Hierarchy Depth Automatically
A useful utility for determining the maximum depth before starting iterations:

```python
# Find max depth by iterative counting
depth = 0
remaining = df.filter(F.col("manager_id").isNull()).select("employee_id")

while remaining.count() > 0:
    depth += 1
    remaining = (
        df.join(remaining, df["manager_id"] == remaining["employee_id"], "inner")
        .select(df["employee_id"])
    )

print(f"Maximum hierarchy depth: {depth}")
```

---

## Key Interview Talking Points
1. **Spark does not support recursive CTEs** (unlike PostgreSQL or SQL Server). Hierarchical traversal must be done iteratively in a Python loop with repeated joins.
2. The iterative approach has **O(d) join operations** where d is the depth of the hierarchy. Each iteration processes one level.
3. Always set a **max_depth safety limit** to prevent infinite loops caused by circular references in the data.
4. Use `concat_ws(" > ", parent_path, child_name)` to build the path string incrementally at each level rather than reconstructing from scratch.
5. The **UDF approach** is acceptable for small datasets (under ~100K nodes) but should be avoided at scale because it serializes data to the driver and prevents Catalyst optimizations.
6. **Caching** the `current_level` DataFrame between iterations can improve performance by avoiding recomputation: `current_level = next_level.cache()`.
7. For very deep hierarchies, consider **GraphX** or **GraphFrames** in Spark, which provide built-in BFS/shortest-path algorithms.
8. A common follow-up question is handling **multiple roots** (e.g., a company with multiple CEOs or independent divisions). The iterative approach handles this naturally since the initial filter `manager_id IS NULL` captures all roots.
