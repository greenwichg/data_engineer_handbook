# PySpark Implementation: Simulating Recursive CTEs

## Problem Statement

Many SQL databases support recursive Common Table Expressions (CTEs) for traversing hierarchies, computing transitive closures, and generating series. PySpark does not support recursive CTEs natively, so data engineers must simulate them using iterative DataFrame operations. This is a frequently asked interview question because it tests both your understanding of recursive SQL patterns and your ability to translate them into PySpark's execution model.

Given an employee hierarchy and a graph of connections, demonstrate how to simulate recursive CTEs iteratively in PySpark.

### Sample Data

**Employee Hierarchy:**
```
+------+---------+-------+
|emp_id|emp_name |mgr_id |
+------+---------+-------+
| 1    | CEO     | NULL  |
| 2    | VP Sales| 1     |
| 3    | VP Eng  | 1     |
| 4    | Dir Mkt | 2     |
| 5    | Dir Dev | 3     |
| 6    | Eng 1   | 5     |
| 7    | Eng 2   | 5     |
| 8    | Sales 1 | 4     |
+------+---------+-------+
```

### Expected Output

**Full hierarchy path for each employee:**

| emp_id | emp_name | level | path              |
|--------|----------|-------|-------------------|
| 1      | CEO      | 0     | CEO               |
| 2      | VP Sales | 1     | CEO > VP Sales    |
| 3      | VP Eng   | 1     | CEO > VP Eng      |
| 5      | Dir Dev  | 2     | CEO > VP Eng > Dir Dev |
| 6      | Eng 1    | 3     | CEO > VP Eng > Dir Dev > Eng 1 |

---

## Method 1: Iterative DataFrame Loop for Hierarchy Traversal

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("RecursiveCTESimulation") \
    .master("local[*]") \
    .getOrCreate()

# Employee hierarchy data
data = [
    (1, "CEO",      None),
    (2, "VP Sales", 1),
    (3, "VP Eng",   1),
    (4, "Dir Mkt",  2),
    (5, "Dir Dev",  3),
    (6, "Eng 1",    5),
    (7, "Eng 2",    5),
    (8, "Sales 1",  4),
    (9, "Sales 2",  4),
    (10, "Eng 3",   6),
]

columns = ["emp_id", "emp_name", "mgr_id"]
employees = spark.createDataFrame(data, columns)

# ============================================================
# Recursive CTE equivalent in SQL would be:
#
# WITH RECURSIVE hierarchy AS (
#     -- Base case: root nodes (no manager)
#     SELECT emp_id, emp_name, mgr_id, 0 AS level,
#            CAST(emp_name AS VARCHAR) AS path
#     FROM employees WHERE mgr_id IS NULL
#
#     UNION ALL
#
#     -- Recursive step: join children to current level
#     SELECT e.emp_id, e.emp_name, e.mgr_id, h.level + 1,
#            h.path || ' > ' || e.emp_name
#     FROM employees e
#     JOIN hierarchy h ON e.mgr_id = h.emp_id
# )
# SELECT * FROM hierarchy;
# ============================================================

# PySpark simulation using iterative loop

# Base case: root nodes
current_level = employees.filter(F.col("mgr_id").isNull()) \
    .select(
        F.col("emp_id"),
        F.col("emp_name"),
        F.col("mgr_id"),
        F.lit(0).alias("level"),
        F.col("emp_name").alias("path"),
    )

# Accumulate all results
all_levels = current_level
level = 0
max_depth = 10  # Safety limit to prevent infinite loops

while True:
    level += 1
    if level > max_depth:
        print(f"Warning: Reached max depth {max_depth}")
        break

    # Join employees with current level to find children
    next_level = employees.alias("e").join(
        current_level.alias("c"),
        F.col("e.mgr_id") == F.col("c.emp_id"),
        "inner"
    ).select(
        F.col("e.emp_id"),
        F.col("e.emp_name"),
        F.col("e.mgr_id"),
        F.lit(level).alias("level"),
        F.concat(F.col("c.path"), F.lit(" > "), F.col("e.emp_name")).alias("path"),
    )

    # Check if we found any new rows
    count = next_level.count()
    if count == 0:
        break

    all_levels = all_levels.unionByName(next_level)
    current_level = next_level

print("=== Full Hierarchy (Recursive CTE Simulation) ===")
all_levels.orderBy("level", "emp_id").show(truncate=False)

# Compute additional hierarchy metrics
result = all_levels.alias("h").join(
    employees.alias("e"),
    F.col("h.emp_id") == F.col("e.emp_id")
).select(
    F.col("h.emp_id"),
    F.col("h.emp_name"),
    F.col("h.level"),
    F.col("h.path"),
    F.col("e.mgr_id"),
)

# Count subordinates per employee
subordinates = all_levels.alias("a").crossJoin(all_levels.alias("b")) \
    .filter(F.col("b.path").contains(F.col("a.emp_name"))) \
    .filter(F.col("a.emp_id") != F.col("b.emp_id")) \
    .groupBy(F.col("a.emp_id").alias("emp_id")) \
    .agg(F.count("*").alias("subordinate_count"))

final = all_levels.join(subordinates, "emp_id", "left") \
    .withColumn("subordinate_count", F.coalesce("subordinate_count", F.lit(0)))

print("=== Hierarchy with Subordinate Counts ===")
final.orderBy("level", "emp_id").show(truncate=False)
```

## Method 2: Graph Traversal / Shortest Path Simulation

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("GraphTraversalCTE") \
    .master("local[*]") \
    .getOrCreate()

# Graph edges (directed)
edges_data = [
    ("A", "B", 1),
    ("A", "C", 4),
    ("B", "C", 2),
    ("B", "D", 5),
    ("C", "D", 1),
    ("D", "E", 3),
    ("C", "E", 6),
]

edges = spark.createDataFrame(edges_data, ["src", "dst", "weight"])

# ============================================================
# Find all reachable nodes from a source (transitive closure)
# Equivalent to recursive CTE that follows edges
# ============================================================

source = "A"

# Base case: start node
reachable = spark.createDataFrame([(source, 0, source)],
    ["node", "distance", "path"])

visited_nodes = {source}
max_iterations = 10

for i in range(max_iterations):
    # Find new nodes reachable from current frontier
    new_nodes = reachable.join(edges,
        reachable.node == edges.src,
        "inner"
    ).select(
        edges.dst.alias("node"),
        (reachable.distance + edges.weight).alias("distance"),
        F.concat(reachable.path, F.lit(" -> "), edges.dst).alias("path"),
    )

    # Filter out already visited nodes
    new_nodes = new_nodes.filter(~F.col("node").isin(visited_nodes))

    if new_nodes.count() == 0:
        break

    # Keep shortest distance per node
    new_nodes = new_nodes.groupBy("node").agg(
        F.min("distance").alias("distance"),
        F.min("path").alias("path"),  # min path as tiebreaker
    )

    # Update visited set
    new_visited = [row["node"] for row in new_nodes.collect()]
    visited_nodes.update(new_visited)

    reachable = reachable.unionByName(new_nodes)

print(f"=== All Nodes Reachable from '{source}' ===")
reachable.orderBy("distance").show(truncate=False)
```

## Method 3: Generating Number Series (Recursive CTE Alternative)

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("SeriesGeneration") \
    .master("local[*]") \
    .getOrCreate()

# ============================================================
# SQL recursive CTE for generating a series:
#
# WITH RECURSIVE numbers AS (
#     SELECT 1 AS n
#     UNION ALL
#     SELECT n + 1 FROM numbers WHERE n < 100
# )
# SELECT * FROM numbers;
#
# PySpark equivalent: use spark.range()
# ============================================================

# Simple: use spark.range()
numbers = spark.range(1, 101).toDF("n")
print("=== Number Series (spark.range) ===")
numbers.show(5)

# ============================================================
# Date series generation (common recursive CTE use case)
# ============================================================

# Generate date range from 2024-01-01 to 2024-03-31
date_series = spark.range(0, 91).select(
    F.date_add(F.lit("2024-01-01"), F.col("id").cast("int")).alias("date")
)

print("=== Date Series ===")
date_series.show(5)

# ============================================================
# Fibonacci sequence (iterative simulation)
# ============================================================
# Recursive CTE:
# WITH RECURSIVE fib AS (
#     SELECT 1 AS n, 1 AS fib_n, 0 AS fib_prev
#     UNION ALL
#     SELECT n+1, fib_n + fib_prev, fib_n FROM fib WHERE n < 20
# )

n_terms = 15
fib_values = [(1, 1, 0)]

for i in range(2, n_terms + 1):
    prev_n, prev_fib, prev_prev = fib_values[-1]
    fib_values.append((i, prev_fib + prev_prev, prev_fib))

fib_df = spark.createDataFrame(fib_values, ["n", "fib_value", "prev_value"])

print("=== Fibonacci Sequence (Iterative) ===")
fib_df.select("n", "fib_value").show(n_terms)

# ============================================================
# Bill of Materials (BOM) explosion - classic recursive CTE
# ============================================================

bom_data = [
    ("Car",      "Engine",    1),
    ("Car",      "Chassis",   1),
    ("Car",      "Wheel",     4),
    ("Engine",   "Piston",    4),
    ("Engine",   "Crankshaft",1),
    ("Chassis",  "Frame",     1),
    ("Chassis",  "Axle",      2),
    ("Piston",   "Ring",      3),
]

bom = spark.createDataFrame(bom_data, ["parent", "child", "quantity"])

# Explode BOM starting from "Car"
root = "Car"
current = spark.createDataFrame(
    [(root, root, 1, 0, root)],
    ["root", "component", "total_qty", "level", "path"]
)

all_components = current
max_depth = 10

for depth in range(1, max_depth + 1):
    next_level = current.join(bom,
        current.component == bom.parent,
        "inner"
    ).select(
        current.root,
        bom.child.alias("component"),
        (current.total_qty * bom.quantity).alias("total_qty"),
        F.lit(depth).alias("level"),
        F.concat(current.path, F.lit(" > "), bom.child).alias("path"),
    )

    if next_level.count() == 0:
        break

    all_components = all_components.unionByName(next_level)
    current = next_level

print(f"=== Bill of Materials for '{root}' ===")
all_components.filter(F.col("level") > 0) \
    .orderBy("level", "component").show(truncate=False)
```

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Recursive CTE** | SQL construct with base case + recursive step; not natively supported in PySpark |
| **Iterative simulation** | While loop that joins current level with edges/relationships to find next level |
| **Termination** | Stop when no new rows are produced or max depth reached |
| **Accumulation** | Union each iteration's results into a growing result DataFrame |
| **Checkpoint** | Call `.checkpoint()` every few iterations to break lineage and prevent stack overflow |
| **spark.range()** | Direct replacement for simple number/date series recursive CTEs |

## Interview Tips

1. **Always mention the pattern**: Base case (seed query) -> iterative join -> union -> termination check. This is the universal pattern for simulating any recursive CTE.

2. **Lineage explosion**: Each iteration adds a join to the execution plan. For deep hierarchies (>10 levels), call `checkpoint()` or `cache()` every 3-5 iterations to break the lineage chain.

3. **Termination safety**: Always include a `max_iterations` guard. Cyclic data (e.g., A->B->C->A) will cause infinite loops without it.

4. **Performance**: Collect the frontier count to check for termination. This triggers a small action but prevents unnecessary iterations.

5. **GraphFrames**: For complex graph algorithms, mention Spark's GraphFrames library which provides built-in BFS, connected components, and PageRank. The iterative approach is for when you cannot use external libraries.

6. **Common use cases**: Org chart traversal, bill of materials explosion, network reachability, category/taxonomy trees, and friend-of-friend queries.
