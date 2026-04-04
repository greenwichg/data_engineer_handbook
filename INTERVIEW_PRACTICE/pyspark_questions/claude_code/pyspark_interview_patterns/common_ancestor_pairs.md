# PySpark Implementation: Find Pairs Sharing a Common Ancestor

## Problem Statement
Given an employee hierarchy (parent-child relationship), find all pairs of employees who share a common manager within N levels. This tests the ability to traverse hierarchies and perform pair-wise comparisons — a common follow-up to basic hierarchy questions in interviews.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("CommonAncestorPairs").getOrCreate()

data = [
    (1, "CEO", None),
    (2, "VP_Eng", 1),
    (3, "VP_Sales", 1),
    (4, "Dir_Backend", 2),
    (5, "Dir_Frontend", 2),
    (6, "Dir_Enterprise", 3),
    (7, "Dir_SMB", 3),
    (8, "Alice", 4),
    (9, "Bob", 4),
    (10, "Charlie", 5),
    (11, "Diana", 6),
    (12, "Eve", 6),
]

columns = ["emp_id", "name", "manager_id"]
df = spark.createDataFrame(data, columns)
df.show()
```

```
+------+--------------+----------+
|emp_id|          name|manager_id|
+------+--------------+----------+
|     1|           CEO|      null|
|     2|        VP_Eng|         1|
|     3|      VP_Sales|         1|
|     4|   Dir_Backend|         2|
|     5|  Dir_Frontend|         2|
|     6|Dir_Enterprise|         3|
|     7|       Dir_SMB|         3|
|     8|         Alice|         4|
|     9|           Bob|         4|
|    10|       Charlie|         5|
|    11|         Diana|         6|
|    12|           Eve|         6|
+------+--------------+----------+
```

### Hierarchy Tree
```
CEO (1)
├── VP_Eng (2)
│   ├── Dir_Backend (4)
│   │   ├── Alice (8)
│   │   └── Bob (9)
│   └── Dir_Frontend (5)
│       └── Charlie (10)
└── VP_Sales (3)
    ├── Dir_Enterprise (6)
    │   ├── Diana (11)
    │   └── Eve (12)
    └── Dir_SMB (7)
```

### Expected Output: Pairs sharing a direct manager (common ancestor within 1 level)
```
+-------+-------+--------------+
|  emp_1|  emp_2|common_manager|
+-------+-------+--------------+
|  Alice|    Bob|   Dir_Backend|
|  Diana|    Eve|Dir_Enterprise|
|VP_Eng |VP_Sales|          CEO|
|Dir_Backend|Dir_Frontend|VP_Eng|
|Dir_Enterprise|Dir_SMB|VP_Sales|
+-------+-------+--------------+
```

---

## Method 1: Self-Join on Manager (Direct Reports — Level 1)

```python
# Find pairs of employees who share the same direct manager
# Self-join where both have the same manager_id and emp_1 < emp_2 to avoid duplicates
sibling_pairs = (
    df.alias("a")
    .join(
        df.alias("b"),
        (F.col("a.manager_id") == F.col("b.manager_id"))
        & (F.col("a.emp_id") < F.col("b.emp_id")),
    )
    .join(
        df.alias("mgr"),
        F.col("a.manager_id") == F.col("mgr.emp_id"),
    )
    .select(
        F.col("a.name").alias("emp_1"),
        F.col("b.name").alias("emp_2"),
        F.col("mgr.name").alias("common_manager"),
    )
)
sibling_pairs.show(truncate=False)
```

### Step-by-Step Explanation

1. **Self-join on manager_id:** Pairs every employee with every other employee who has the same manager.
2. **Filter `a.emp_id < b.emp_id`:** Avoids (Alice, Bob) and (Bob, Alice) duplicates, and avoids self-pairs.
3. **Join with manager table:** Resolves manager_id to manager name for readability.

---

## Method 2: Build Ancestor Chains, Then Find Common Ancestors (N Levels)

```python
# Step 1: Build ancestor chain for each employee up to N levels
max_levels = 3

# Start: each employee and their direct manager
ancestors = (
    df.filter(F.col("manager_id").isNotNull())
    .select(
        F.col("emp_id"),
        F.col("name").alias("emp_name"),
        F.col("manager_id").alias("ancestor_id"),
        F.lit(1).alias("distance"),
    )
)

all_ancestors = ancestors

# Iteratively add higher-level ancestors
current = ancestors
for level in range(2, max_levels + 1):
    current = (
        current.join(
            df.select(
                F.col("emp_id").alias("curr_id"),
                F.col("manager_id").alias("next_ancestor"),
            ),
            current.ancestor_id == F.col("curr_id"),
            how="inner",
        )
        .filter(F.col("next_ancestor").isNotNull())
        .select(
            current.emp_id,
            current.emp_name,
            F.col("next_ancestor").alias("ancestor_id"),
            F.lit(level).alias("distance"),
        )
    )
    all_ancestors = all_ancestors.union(current)

all_ancestors.orderBy("emp_id", "distance").show(truncate=False)
```

**Output (ancestor chains):**
```
+------+--------+-----------+--------+
|emp_id|emp_name|ancestor_id|distance|
+------+--------+-----------+--------+
|2     |VP_Eng  |1          |1       |
|3     |VP_Sales|1          |1       |
|4     |Dir_BE  |2          |1       |
|4     |Dir_BE  |1          |2       |
|5     |Dir_FE  |2          |1       |
|5     |Dir_FE  |1          |2       |
|8     |Alice   |4          |1       |
|8     |Alice   |2          |2       |
|8     |Alice   |1          |3       |
|9     |Bob     |4          |1       |
|9     |Bob     |2          |2       |
|9     |Bob     |1          |3       |
...
```

```python
# Step 2: Self-join to find pairs sharing a common ancestor
# Join on ancestor_id, filter emp_1 < emp_2
common_ancestor_pairs = (
    all_ancestors.alias("a")
    .join(
        all_ancestors.alias("b"),
        (F.col("a.ancestor_id") == F.col("b.ancestor_id"))
        & (F.col("a.emp_id") < F.col("b.emp_id")),
    )
    .join(
        df.select(F.col("emp_id").alias("anc_id"), F.col("name").alias("ancestor_name")),
        F.col("a.ancestor_id") == F.col("anc_id"),
    )
    .select(
        F.col("a.emp_name").alias("emp_1"),
        F.col("b.emp_name").alias("emp_2"),
        F.col("ancestor_name").alias("common_ancestor"),
        F.col("a.distance").alias("emp_1_distance"),
        F.col("b.distance").alias("emp_2_distance"),
    )
)

# Step 3: Keep only the LOWEST common ancestor (closest shared manager)
lca_window = Window.partitionBy("emp_1", "emp_2").orderBy(
    F.col("emp_1_distance") + F.col("emp_2_distance")
)

lowest_common_ancestor = (
    common_ancestor_pairs
    .withColumn("rn", F.row_number().over(lca_window))
    .filter(F.col("rn") == 1)
    .drop("rn")
)
lowest_common_ancestor.orderBy("emp_1", "emp_2").show(truncate=False)
```

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("employees")

result_sql = spark.sql("""
    -- Find pairs sharing the same direct manager
    SELECT
        a.name AS emp_1,
        b.name AS emp_2,
        mgr.name AS common_manager
    FROM employees a
    JOIN employees b
        ON a.manager_id = b.manager_id
        AND a.emp_id < b.emp_id
    JOIN employees mgr
        ON a.manager_id = mgr.emp_id
    ORDER BY common_manager, emp_1
""")
result_sql.show(truncate=False)
```

---

## Variation: Lowest Common Ancestor (LCA) with Recursive CTE (Spark 3.4+)

```python
result_lca = spark.sql("""
    WITH RECURSIVE ancestors AS (
        -- Base: each employee is their own ancestor at distance 0
        SELECT emp_id, name, emp_id AS ancestor_id, 0 AS distance
        FROM employees

        UNION ALL

        -- Recursive: go up one level
        SELECT a.emp_id, a.name, e.manager_id AS ancestor_id, a.distance + 1
        FROM ancestors a
        JOIN employees e ON a.ancestor_id = e.emp_id
        WHERE e.manager_id IS NOT NULL
    )
    SELECT
        a1.name AS emp_1,
        a2.name AS emp_2,
        mgr.name AS lca,
        a1.distance AS dist_1,
        a2.distance AS dist_2
    FROM ancestors a1
    JOIN ancestors a2
        ON a1.ancestor_id = a2.ancestor_id
        AND a1.emp_id < a2.emp_id
    JOIN employees mgr ON a1.ancestor_id = mgr.emp_id
    -- Keep only the lowest (closest) common ancestor per pair
    WHERE (a1.distance + a2.distance) = (
        SELECT MIN(x.distance + y.distance)
        FROM ancestors x
        JOIN ancestors y ON x.ancestor_id = y.ancestor_id
        WHERE x.emp_id = a1.emp_id AND y.emp_id = a2.emp_id
    )
    ORDER BY emp_1, emp_2
""")
result_lca.show(truncate=False)
```

---

## Comparison of Methods

| Method | Scope | Complexity | Best For |
|--------|-------|------------|----------|
| Direct manager self-join | 1 level only | Simple — one join | "Find siblings" questions |
| Iterative ancestor chains | N levels | Moderate — N iterations | General LCA with depth control |
| Recursive CTE | All levels | Clean SQL | Spark 3.4+ environments |

## Key Interview Talking Points

1. **Direct sibling pairs** (same manager) is the most common interview variant — a simple self-join solves it.
2. **Lowest Common Ancestor (LCA)** is the harder variant. The key insight is: build ancestor chains for all employees, then find the shared ancestor with the minimum total distance.
3. **`emp_id < emp_id`** in the join condition prevents duplicate and self-pairs — always mention this optimization.
4. **Performance:** Building ancestor chains is O(N × D) where D is tree depth. For very deep hierarchies (D > 20), consider GraphFrames' connected components.
5. **Real-world applications:** Org chart analysis ("who shares a skip-level manager?"), taxonomy/classification systems, social network analysis ("mutual connections within N hops").
6. This pattern combines **hierarchy traversal** (iterative self-join) with **pair-wise matching** (self-join on shared ancestor) — two fundamental patterns tested together.
