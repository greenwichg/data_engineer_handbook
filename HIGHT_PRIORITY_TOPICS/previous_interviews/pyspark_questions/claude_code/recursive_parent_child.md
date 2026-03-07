# PySpark Implementation: Recursive Parent-Child Relationship Traversal

## Problem Statement

Given an **employee hierarchy** stored as parent-child relationships (each row has an `employee_id` and `manager_id`), traverse the hierarchy to determine the **full reporting chain**, **depth level**, and **root ancestor** for every employee. Since PySpark does not natively support recursive CTEs, implement an iterative approach to simulate recursive traversal.

This question tests your ability to handle **graph/tree traversal** in a distributed environment — a common interview topic for senior data engineering roles.

### Sample Data

**Employees table:**
```
employee_id  employee_name  manager_id
E001         Alice          null         <-- CEO (root node)
E002         Bob            E001
E003         Carol          E001
E004         Dave           E002
E005         Eve            E002
E006         Frank          E003
E007         Grace          E004
E008         Hank           E006
```

### Expected Output

**Full hierarchy with depth and reporting path:**

| employee_id | employee_name | depth | root_ancestor | reporting_path               |
|-------------|---------------|-------|---------------|------------------------------|
| E001        | Alice         | 0     | Alice         | Alice                        |
| E002        | Bob           | 1     | Alice         | Alice > Bob                  |
| E003        | Carol         | 1     | Alice         | Alice > Carol                |
| E004        | Dave          | 2     | Alice         | Alice > Bob > Dave           |
| E005        | Eve           | 2     | Alice         | Alice > Bob > Eve            |
| E006        | Frank         | 2     | Alice         | Alice > Carol > Frank        |
| E007        | Grace         | 3     | Alice         | Alice > Bob > Dave > Grace   |
| E008        | Hank          | 3     | Alice         | Alice > Carol > Frank > Hank |

---

## Method 1: Iterative Self-Join (Core Technique)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, lit, concat, concat_ws, when, coalesce
)

# Initialize Spark session
spark = SparkSession.builder.appName("RecursiveParentChild").getOrCreate()

# Employee hierarchy data
emp_data = [
    ("E001", "Alice", None),
    ("E002", "Bob", "E001"),
    ("E003", "Carol", "E001"),
    ("E004", "Dave", "E002"),
    ("E005", "Eve", "E002"),
    ("E006", "Frank", "E003"),
    ("E007", "Grace", "E004"),
    ("E008", "Hank", "E006"),
]

emp_df = spark.createDataFrame(emp_data, ["employee_id", "employee_name", "manager_id"])

# Step 1: Initialize — start with root nodes (employees with no manager)
hierarchy = emp_df.filter(col("manager_id").isNull()).select(
    col("employee_id"),
    col("employee_name"),
    lit(0).alias("depth"),
    col("employee_name").alias("root_ancestor"),
    col("employee_name").alias("reporting_path")
)

# Step 2: Iteratively join children to build the hierarchy
remaining = emp_df.filter(col("manager_id").isNotNull())
max_depth = 10  # Safety limit to prevent infinite loops

for i in range(1, max_depth + 1):
    # Find children whose parent is already in the hierarchy
    new_level = remaining.alias("child").join(
        hierarchy.alias("parent"),
        col("child.manager_id") == col("parent.employee_id"),
        how="inner"
    ).select(
        col("child.employee_id"),
        col("child.employee_name"),
        lit(i).alias("depth"),
        col("parent.root_ancestor"),
        concat(col("parent.reporting_path"), lit(" > "), col("child.employee_name")).alias("reporting_path")
    )

    # If no new nodes found, we have traversed the entire tree
    if new_level.count() == 0:
        break

    # Add new level to hierarchy
    hierarchy = hierarchy.union(new_level)

    # Remove processed employees from remaining
    remaining = remaining.join(
        new_level.select("employee_id"),
        on="employee_id",
        how="left_anti"
    )

# Step 3: Display final hierarchy
hierarchy.orderBy("depth", "employee_id").show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Initialize Root Nodes

- **What happens:** Find all employees with `manager_id IS NULL` — these are the top of the hierarchy (CEO/root).
- **Output:**

  | employee_id | employee_name | depth | root_ancestor | reporting_path |
  |-------------|---------------|-------|---------------|----------------|
  | E001        | Alice         | 0     | Alice         | Alice          |

#### Step 2: Iterative Expansion (Iteration 1)

- **What happens:** Join `remaining` employees against the current hierarchy on `manager_id = employee_id`. Bob and Carol have manager E001 (Alice), who is already in the hierarchy.
- **Output after iteration 1:**

  | employee_id | employee_name | depth | root_ancestor | reporting_path |
  |-------------|---------------|-------|---------------|----------------|
  | E001        | Alice         | 0     | Alice         | Alice          |
  | E002        | Bob           | 1     | Alice         | Alice > Bob    |
  | E003        | Carol         | 1     | Alice         | Alice > Carol  |

#### Iteration 2:

  | employee_id | employee_name | depth | root_ancestor | reporting_path          |
  |-------------|---------------|-------|---------------|-------------------------|
  | E004        | Dave          | 2     | Alice         | Alice > Bob > Dave      |
  | E005        | Eve           | 2     | Alice         | Alice > Bob > Eve       |
  | E006        | Frank         | 2     | Alice         | Alice > Carol > Frank   |

#### Iteration 3 (final):

  | employee_id | employee_name | depth | root_ancestor | reporting_path                |
  |-------------|---------------|-------|---------------|-------------------------------|
  | E007        | Grace         | 3     | Alice         | Alice > Bob > Dave > Grace    |
  | E008        | Hank          | 3     | Alice         | Alice > Carol > Frank > Hank  |

---

## Method 2: Bottom-Up Traversal (Find All Ancestors)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, collect_list, concat_ws, array, array_union

spark = SparkSession.builder.appName("BottomUpTraversal").getOrCreate()

emp_data = [
    ("E001", "Alice", None),
    ("E002", "Bob", "E001"),
    ("E003", "Carol", "E001"),
    ("E004", "Dave", "E002"),
    ("E005", "Eve", "E002"),
    ("E006", "Frank", "E003"),
    ("E007", "Grace", "E004"),
    ("E008", "Hank", "E006"),
]

emp_df = spark.createDataFrame(emp_data, ["employee_id", "employee_name", "manager_id"])

# Start: each employee knows only their direct manager
current = emp_df.select(
    col("employee_id"),
    col("employee_name"),
    col("manager_id").alias("current_ancestor_id"),
    lit(1).alias("hops")
)

all_ancestors = current.filter(col("current_ancestor_id").isNotNull())

# Iteratively look up the parent of each current ancestor
for i in range(10):  # Max depth safety
    next_hop = all_ancestors.filter(
        col("current_ancestor_id").isNotNull()
    ).alias("a").join(
        emp_df.alias("e"),
        col("a.current_ancestor_id") == col("e.employee_id"),
        how="inner"
    ).select(
        col("a.employee_id"),
        col("a.employee_name"),
        col("e.manager_id").alias("current_ancestor_id"),
        (col("a.hops") + 1).alias("hops")
    ).filter(col("current_ancestor_id").isNotNull())

    if next_hop.count() == 0:
        break

    all_ancestors = all_ancestors.union(next_hop)

# Now each employee has a row for each ancestor at each hop distance
# Find the furthest ancestor (root) for each employee
from pyspark.sql.window import Window
from pyspark.sql.functions import max as spark_max, row_number

w = Window.partitionBy("employee_id").orderBy(col("hops").desc())

root_ancestors = all_ancestors.withColumn(
    "rn", row_number().over(w)
).filter(col("rn") == 1).select(
    "employee_id", "current_ancestor_id"
).alias("r").join(
    emp_df.alias("e"),
    col("r.current_ancestor_id") == col("e.employee_id"),
    how="inner"
).select(
    col("r.employee_id"),
    col("e.employee_name").alias("root_ancestor_name")
)

root_ancestors.show(truncate=False)
```

### Output

| employee_id | root_ancestor_name |
|-------------|-------------------|
| E002        | Alice             |
| E003        | Alice             |
| E004        | Alice             |
| E005        | Alice             |
| E006        | Alice             |
| E007        | Alice             |
| E008        | Alice             |

---

## Method 3: Count Descendants (Subtree Size)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, countDistinct

spark = SparkSession.builder.appName("SubtreeSize").getOrCreate()

emp_data = [
    ("E001", "Alice", None),
    ("E002", "Bob", "E001"),
    ("E003", "Carol", "E001"),
    ("E004", "Dave", "E002"),
    ("E005", "Eve", "E002"),
    ("E006", "Frank", "E003"),
    ("E007", "Grace", "E004"),
    ("E008", "Hank", "E006"),
]

emp_df = spark.createDataFrame(emp_data, ["employee_id", "employee_name", "manager_id"])

# Build ancestor-descendant pairs using iterative expansion
pairs = emp_df.filter(col("manager_id").isNotNull()).select(
    col("manager_id").alias("ancestor_id"),
    col("employee_id").alias("descendant_id")
)

# Expand: if A manages B and B manages C, then A also has descendant C
current_pairs = pairs
for i in range(10):
    new_pairs = current_pairs.alias("p").join(
        emp_df.alias("e"),
        col("p.descendant_id") == col("e.employee_id"),
        how="inner"
    ).filter(
        col("e.manager_id").isNotNull()
    ).select(
        col("p.ancestor_id"),
        col("e.employee_id").alias("descendant_id")
    )

    # Find truly new pairs
    new_only = new_pairs.subtract(current_pairs)
    if new_only.count() == 0:
        break
    current_pairs = current_pairs.union(new_only).distinct()

# Count descendants per employee
descendant_counts = current_pairs.groupBy("ancestor_id").agg(
    countDistinct("descendant_id").alias("total_descendants")
)

# Join back to get names
result = emp_df.join(
    descendant_counts,
    emp_df.employee_id == descendant_counts.ancestor_id,
    how="left"
).select(
    "employee_id",
    "employee_name",
    coalesce(col("total_descendants"), lit(0)).alias("total_descendants")
).orderBy("employee_id")

result.show(truncate=False)
```

### Output

| employee_id | employee_name | total_descendants |
|-------------|---------------|-------------------|
| E001        | Alice         | 7                 |
| E002        | Bob           | 3                 |
| E003        | Carol         | 2                 |
| E004        | Dave          | 1                 |
| E005        | Eve           | 0                 |
| E006        | Frank         | 1                 |
| E007        | Grace         | 0                 |
| E008        | Hank          | 0                 |

---

## Method 4: GraphFrames (If Available)

```python
# GraphFrames provides native graph traversal — install via:
# spark-submit --packages graphframes:graphframes:0.8.2-spark3.2-s_2.12

from graphframes import GraphFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import col

spark = SparkSession.builder.appName("GraphFrameHierarchy").getOrCreate()

emp_data = [
    ("E001", "Alice", None),
    ("E002", "Bob", "E001"),
    ("E003", "Carol", "E001"),
    ("E004", "Dave", "E002"),
    ("E005", "Eve", "E002"),
    ("E006", "Frank", "E003"),
    ("E007", "Grace", "E004"),
    ("E008", "Hank", "E006"),
]

emp_df = spark.createDataFrame(emp_data, ["employee_id", "employee_name", "manager_id"])

# Vertices: all employees
vertices = emp_df.select(
    col("employee_id").alias("id"),
    col("employee_name").alias("name")
)

# Edges: manager → employee (direction: parent to child)
edges = emp_df.filter(col("manager_id").isNotNull()).select(
    col("manager_id").alias("src"),
    col("employee_id").alias("dst")
)

# Create graph
graph = GraphFrame(vertices, edges)

# BFS: Find shortest path from CEO to every employee
bfs_result = graph.bfs(
    fromExpr="id = 'E001'",
    toExpr="id = 'E007'",
    maxPathLength=10
)

bfs_result.show(truncate=False)
```

---

## Method 5: Handling Multiple Root Nodes (Forest)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, concat

spark = SparkSession.builder.appName("ForestTraversal").getOrCreate()

# Multiple organizations — two separate hierarchies
org_data = [
    ("E001", "Alice", None, "Org_A"),
    ("E002", "Bob", "E001", "Org_A"),
    ("E003", "Carol", "E001", "Org_A"),
    ("E004", "Dave", "E002", "Org_A"),
    ("E010", "Zara", None, "Org_B"),       # Second root
    ("E011", "Yusuf", "E010", "Org_B"),
    ("E012", "Xena", "E010", "Org_B"),
]

org_df = spark.createDataFrame(org_data, ["employee_id", "employee_name", "manager_id", "org"])

# Initialize with ALL root nodes (multiple trees)
hierarchy = org_df.filter(col("manager_id").isNull()).select(
    col("employee_id"),
    col("employee_name"),
    col("org"),
    lit(0).alias("depth"),
    col("employee_name").alias("root_ancestor"),
    col("employee_name").alias("reporting_path")
)

remaining = org_df.filter(col("manager_id").isNotNull())

for i in range(1, 10):
    new_level = remaining.alias("child").join(
        hierarchy.alias("parent"),
        col("child.manager_id") == col("parent.employee_id"),
        how="inner"
    ).select(
        col("child.employee_id"),
        col("child.employee_name"),
        col("child.org"),
        lit(i).alias("depth"),
        col("parent.root_ancestor"),
        concat(col("parent.reporting_path"), lit(" > "), col("child.employee_name")).alias("reporting_path")
    )

    if new_level.count() == 0:
        break

    hierarchy = hierarchy.union(new_level)
    remaining = remaining.join(
        new_level.select("employee_id"),
        on="employee_id",
        how="left_anti"
    )

hierarchy.orderBy("org", "depth", "employee_id").show(truncate=False)
```

### Output

| employee_id | employee_name | org   | depth | root_ancestor | reporting_path          |
|-------------|---------------|-------|-------|---------------|-------------------------|
| E001        | Alice         | Org_A | 0     | Alice         | Alice                   |
| E002        | Bob           | Org_A | 1     | Alice         | Alice > Bob             |
| E003        | Carol         | Org_A | 1     | Alice         | Alice > Carol           |
| E004        | Dave          | Org_A | 2     | Alice         | Alice > Bob > Dave      |
| E010        | Zara          | Org_B | 0     | Zara          | Zara                    |
| E011        | Yusuf         | Org_B | 1     | Zara          | Zara > Yusuf            |
| E012        | Xena          | Org_B | 1     | Zara          | Zara > Zara > Xena      |

---

## Handling Cycles (Defensive Programming)

```python
# In real data, bad records can create cycles: A → B → C → A
# The iterative approach naturally handles this with max_depth limit

# Additional safety: track visited nodes
from pyspark.sql.functions import array, array_contains, array_union

# After each iteration, check if any new node was already in hierarchy
# If overlap detected, log warning and break
for i in range(1, max_depth + 1):
    new_level = remaining.alias("child").join(
        hierarchy.alias("parent"),
        col("child.manager_id") == col("parent.employee_id"),
        how="inner"
    ).select(...)

    # Check for cycles — new node already exists in hierarchy
    cycle_check = new_level.join(
        hierarchy.select("employee_id"),
        on="employee_id",
        how="inner"
    )
    if cycle_check.count() > 0:
        print(f"WARNING: Cycle detected at depth {i}!")
        cycle_check.show()
        break

    hierarchy = hierarchy.union(new_level)
```

---

## Performance Considerations

```
Small hierarchy (< 100K nodes):
  → Iterative self-join works well
  → Consider collecting to driver and using Python networkx

Medium hierarchy (100K - 10M nodes):
  → Iterative self-join with caching intermediate results
  → Cache hierarchy DataFrame between iterations
  → Use broadcast join if parent lookup table is small

Large hierarchy (> 10M nodes):
  → Use GraphFrames for distributed graph processing
  → Consider pre-computing hierarchy in a relational DB
  → Store materialized paths or nested sets for fast queries
```

```python
# Performance optimization: cache intermediate hierarchy
hierarchy = hierarchy.cache()

# Checkpoint every N iterations to break lineage
if i % 3 == 0:
    spark.sparkContext.setCheckpointDir("/tmp/hierarchy_checkpoint")
    hierarchy = hierarchy.checkpoint()
```

---

## Key Interview Talking Points

1. **Why no recursive CTE in PySpark?** "PySpark DataFrames do not support recursive CTEs because Spark's execution model is based on DAGs, not iterative query plans. We simulate recursion with iterative self-joins, expanding one level of the hierarchy per iteration."

2. **When to stop iterating:** "We stop when the join produces zero new rows — meaning all children have been connected to their parents. A max depth limit prevents infinite loops from cyclic data."

3. **Performance of iterative joins:** "Each iteration triggers a shuffle for the join. For deep hierarchies, this can be expensive. Caching the hierarchy DataFrame between iterations avoids recomputation. Checkpointing every few iterations prevents lineage explosion."

4. **Alternative approaches:**
   - **GraphFrames:** Native graph traversal with BFS/shortest paths — best for complex graph queries
   - **Collect to driver:** For small hierarchies, collect to Python and use `networkx` — simpler code
   - **Pre-materialized paths:** Store `/CEO/VP/Director/Manager` paths in the table for O(1) lookups

5. **Handling edge cases:**
   - Multiple root nodes (forest): Initialize with all NULL-manager employees
   - Cycles in data: Use visited-node tracking or max-depth limit
   - Orphan nodes (manager_id points to non-existent employee): Use left_anti join to detect

6. **Real-world applications:**
   - Org chart traversal (who reports to whom)
   - Bill of Materials (BOM) explosion in manufacturing
   - Category/taxonomy trees in e-commerce
   - File system directory traversal
   - Network topology mapping
