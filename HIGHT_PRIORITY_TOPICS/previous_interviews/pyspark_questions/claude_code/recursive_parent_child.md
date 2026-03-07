# PySpark Implementation: Recursive Parent-Child Relationship Traversal

## Problem Statement

Given a table with parent-child relationships (e.g., employee-manager, category-subcategory, folder structure), **traverse the hierarchy recursively** to find the full path from leaf to root, calculate depth levels, and identify all descendants of a given node. PySpark does not support recursive CTEs natively, so iterative approaches are required.

### Sample Data

```
node_id   name        parent_id
1         CEO         null
2         VP_Eng      1
3         VP_Sales    1
4         Dir_Backend 2
5         Dir_Frontend 2
6         Dir_East    3
7         Sr_Eng_1    4
8         Sr_Eng_2    4
9         Jr_Eng      7
10        Sales_Rep   6
```

### Expected Output (Full Hierarchy Path)

| node_id | name        | depth | path                              |
|---------|-------------|-------|-----------------------------------|
| 1       | CEO         | 0     | CEO                               |
| 2       | VP_Eng      | 1     | CEO > VP_Eng                      |
| 3       | VP_Sales    | 1     | CEO > VP_Sales                    |
| 4       | Dir_Backend | 2     | CEO > VP_Eng > Dir_Backend        |
| 5       | Dir_Frontend| 2     | CEO > VP_Eng > Dir_Frontend       |
| 6       | Dir_East    | 2     | CEO > VP_Sales > Dir_East         |
| 7       | Sr_Eng_1    | 3     | CEO > VP_Eng > Dir_Backend > Sr_Eng_1 |
| 8       | Sr_Eng_2    | 3     | CEO > VP_Eng > Dir_Backend > Sr_Eng_2 |
| 9       | Jr_Eng      | 4     | CEO > VP_Eng > Dir_Backend > Sr_Eng_1 > Jr_Eng |
| 10      | Sales_Rep   | 3     | CEO > VP_Sales > Dir_East > Sales_Rep |

---

## Method 1: Iterative Self-Join (Bottom-Up Path Building)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, concat, when, coalesce

spark = SparkSession.builder.appName("RecursiveParentChild").getOrCreate()

data = [
    (1, "CEO", None), (2, "VP_Eng", 1), (3, "VP_Sales", 1),
    (4, "Dir_Backend", 2), (5, "Dir_Frontend", 2), (6, "Dir_East", 3),
    (7, "Sr_Eng_1", 4), (8, "Sr_Eng_2", 4), (9, "Jr_Eng", 7),
    (10, "Sales_Rep", 6),
]
df = spark.createDataFrame(data, ["node_id", "name", "parent_id"])

# Step 1: Start with root nodes (parent_id is null)
roots = df.filter(col("parent_id").isNull()) \
    .select(
        col("node_id"),
        col("name"),
        col("parent_id"),
        lit(0).alias("depth"),
        col("name").alias("path")
    )

# Step 2: Iteratively join children
current_level = roots
result = roots
max_depth = 10  # Safety limit

for i in range(1, max_depth + 1):
    # Find children of current level
    next_level = df.alias("child").join(
        current_level.alias("parent"),
        col("child.parent_id") == col("parent.node_id"),
        "inner"
    ).select(
        col("child.node_id"),
        col("child.name"),
        col("child.parent_id"),
        lit(i).alias("depth"),
        concat(col("parent.path"), lit(" > "), col("child.name")).alias("path")
    )

    # Check if there are more children
    if next_level.count() == 0:
        break

    result = result.union(next_level)
    current_level = next_level

result.orderBy("depth", "node_id").show(truncate=False)
```

### Output

```
+-------+------------+---------+-----+---------------------------------------------------+
|node_id|name        |parent_id|depth|path                                               |
+-------+------------+---------+-----+---------------------------------------------------+
|1      |CEO         |null     |0    |CEO                                                |
|2      |VP_Eng      |1        |1    |CEO > VP_Eng                                       |
|3      |VP_Sales    |1        |1    |CEO > VP_Sales                                     |
|4      |Dir_Backend |2        |2    |CEO > VP_Eng > Dir_Backend                         |
|5      |Dir_Frontend|2        |2    |CEO > VP_Eng > Dir_Frontend                        |
|6      |Dir_East    |3        |2    |CEO > VP_Sales > Dir_East                          |
|7      |Sr_Eng_1    |4        |3    |CEO > VP_Eng > Dir_Backend > Sr_Eng_1              |
|8      |Sr_Eng_2    |4        |3    |CEO > VP_Eng > Dir_Backend > Sr_Eng_2              |
|9      |Jr_Eng      |7        |4    |CEO > VP_Eng > Dir_Backend > Sr_Eng_1 > Jr_Eng     |
|10     |Sales_Rep   |6        |3    |CEO > VP_Sales > Dir_East > Sales_Rep              |
+-------+------------+---------+-----+---------------------------------------------------+
```

---

## Method 2: Find All Descendants of a Node

```python
def get_all_descendants(df, root_node_id):
    """Find all nodes under a given root (inclusive)."""
    root = df.filter(col("node_id") == root_node_id) \
        .select("node_id", "name", "parent_id")

    descendants = root
    current = root

    for _ in range(10):
        children = df.join(
            current.select(col("node_id").alias("pid")),
            col("parent_id") == col("pid"),
            "inner"
        ).select("node_id", "name", "parent_id")

        if children.count() == 0:
            break

        descendants = descendants.union(children)
        current = children

    return descendants

# Find all descendants of VP_Eng (node 2)
vp_eng_tree = get_all_descendants(df, 2)
vp_eng_tree.show()
```

**Output:**
```
+-------+------------+---------+
|node_id|        name|parent_id|
+-------+------------+---------+
|      2|      VP_Eng|        1|
|      4| Dir_Backend|        2|
|      5|Dir_Frontend|        2|
|      7|    Sr_Eng_1|        4|
|      8|    Sr_Eng_2|        4|
|      9|      Jr_Eng|        7|
+-------+------------+---------+
```

---

## Method 3: GraphFrames (If Available)

```python
# GraphFrames provides native BFS and shortest path algorithms
# Install: spark-submit --packages graphframes:graphframes:0.8.2-spark3.2-s_2.12

# from graphframes import GraphFrame
#
# vertices = df.select(col("node_id").alias("id"), "name")
# edges = df.filter(col("parent_id").isNotNull()) \
#     .select(col("parent_id").alias("src"), col("node_id").alias("dst"))
#
# g = GraphFrame(vertices, edges)
#
# # BFS from CEO to Jr_Eng
# paths = g.bfs(
#     fromExpr="id = 1",
#     toExpr="id = 9"
# )
# paths.show()
```

---

## Method 4: Bottom-Up (Leaf to Root) Traversal

```python
from pyspark.sql.functions import collect_list, array, struct

def trace_to_root(df, leaf_node_id):
    """Trace path from a leaf node up to the root."""
    current = df.filter(col("node_id") == leaf_node_id)
    path_parts = []

    for _ in range(10):
        row = current.collect()
        if not row:
            break

        node = row[0]
        path_parts.append(node["name"])

        if node["parent_id"] is None:
            break

        current = df.filter(col("node_id") == node["parent_id"])

    path_parts.reverse()
    return " > ".join(path_parts)

# Trace Jr_Eng (node 9) to root
print(trace_to_root(df, 9))
# Output: CEO > VP_Eng > Dir_Backend > Sr_Eng_1 > Jr_Eng
```

**Note:** This approach uses `collect()` and is NOT scalable for large datasets. Use Method 1 for production.

---

## Method 5: Counting Subtree Sizes

```python
# Count how many total reports (direct + indirect) each node has
from pyspark.sql.functions import count

# Start from leaf nodes (no children)
all_parents = df.select("parent_id").distinct().filter(col("parent_id").isNotNull())
leaves = df.join(
    all_parents,
    df.node_id == all_parents.parent_id,
    "left_anti"
)

print("Leaf nodes:")
leaves.show()

# Use the hierarchy result from Method 1 to count descendants
descendant_counts = result.groupBy("node_id") \
    .agg(count("*").alias("dummy")) \
    .drop("dummy")

# Join with full hierarchy to get subtree sizes
# Each node's descendants = all nodes whose path contains this node's name
```

---

## Key Interview Talking Points

1. **No recursive CTE in PySpark:** Unlike SQL databases (PostgreSQL, SQL Server), Spark does not support `WITH RECURSIVE`. You must use iterative self-joins or GraphFrames.

2. **Iterative approach pattern:** Start with root/leaf nodes, join to find the next level, union results, repeat until no more rows are found. Always set a max iteration limit to prevent infinite loops from cycles.

3. **Performance considerations:** Each iteration triggers a new join + shuffle. For deep hierarchies (>10 levels), consider using GraphFrames or converting to RDD and using `flatMap` with accumulators.

4. **Cycle detection:** Add a check to detect if any `node_id` appears twice in the path — this indicates a cycle in the data. Without cycle detection, the loop runs until `max_depth`.

5. **Broadcast optimization:** If the hierarchy table is small (< 10MB), broadcast it during the self-join to avoid shuffles: `df.join(broadcast(current_level), ...)`.

6. **Real-world applications:** Organizational charts, product category trees, bill of materials (BOM), file system traversal, and social network graph traversal.
