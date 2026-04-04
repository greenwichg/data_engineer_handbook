# PySpark Implementation: Tree Node Classification

## Problem Statement

Given a tree table with `id` and `p_id` (parent id), classify each node as **Root**, **Inner**, or **Leaf**. This is **LeetCode 608 — Tree Node**.

- **Root:** `p_id` is NULL (no parent).
- **Leaf:** Node is not a parent of any other node.
- **Inner:** Has a parent AND is a parent of at least one other node.

### Sample Data

```
id  p_id
1   null
2   1
3   1
4   2
5   2
```

### Expected Output

| id | type  |
|----|-------|
| 1  | Root  |
| 2  | Inner |
| 3  | Leaf  |
| 4  | Leaf  |
| 5  | Leaf  |

---

## Method 1: Using CASE WHEN with Subquery Logic (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, collect_set

spark = SparkSession.builder.appName("TreeNode").getOrCreate()

data = [
    (1, None),
    (2, 1),
    (3, 1),
    (4, 2),
    (5, 2)
]

columns = ["id", "p_id"]
df = spark.createDataFrame(data, columns)

# Collect all ids that are parents (appear in p_id column)
parent_ids = df.filter(col("p_id").isNotNull()) \
    .select(col("p_id").alias("pid")) \
    .distinct()

# Left join to check if each node is a parent
result = df.join(parent_ids, df["id"] == parent_ids["pid"], "left") \
    .withColumn(
        "type",
        when(col("p_id").isNull(), "Root")
        .when(col("pid").isNotNull(), "Inner")
        .otherwise("Leaf")
    ).select("id", "type").orderBy("id")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Find all parent ids
- **What happens:** Extract distinct values from `p_id` column (excluding nulls). These are nodes that have children.
- **Output (parent_ids):**

  | pid |
  |-----|
  | 1   |
  | 2   |

#### Step 2: Left join original table with parent_ids
- **What happens:** If a node's `id` appears in parent_ids, it has children.

  | id | p_id | pid  |
  |----|------|------|
  | 1  | null | 1    |
  | 2  | 1    | 2    |
  | 3  | 1    | null |
  | 4  | 2    | null |
  | 5  | 2    | null |

#### Step 3: Apply classification logic
- `p_id IS NULL` → Root
- `pid IS NOT NULL` (has children) → Inner
- Otherwise → Leaf

---

## Method 2: Using isin() Check

```python
from pyspark.sql.functions import col, when

# Collect parent ids as a Python list
parent_list = [row.p_id for row in df.filter(col("p_id").isNotNull()).select("p_id").distinct().collect()]

result = df.withColumn(
    "type",
    when(col("p_id").isNull(), "Root")
    .when(col("id").isin(parent_list), "Inner")
    .otherwise("Leaf")
).select("id", "type").orderBy("id")

result.show()
```

**Note:** This collects parent ids to the driver. Fine for small datasets but avoid for large-scale data.

---

## Method 3: Using Left Semi Join + Left Anti Join

```python
from pyspark.sql.functions import col, lit

children_ref = df.filter(col("p_id").isNotNull()).select(col("p_id").alias("child_pid")).distinct()

# Root: p_id is null
roots = df.filter(col("p_id").isNull()).withColumn("type", lit("Root"))

# Inner: has parent AND has children
inner = df.filter(col("p_id").isNotNull()) \
    .join(children_ref, col("id") == col("child_pid"), "left_semi") \
    .withColumn("type", lit("Inner"))

# Leaf: has parent AND no children
leaves = df.filter(col("p_id").isNotNull()) \
    .join(children_ref, col("id") == col("child_pid"), "left_anti") \
    .withColumn("type", lit("Leaf"))

result = roots.unionByName(inner).unionByName(leaves).select("id", "type").orderBy("id")
result.show()
```

---

## Method 4: Spark SQL

```python
df.createOrReplaceTempView("tree")

result = spark.sql("""
    SELECT id,
        CASE
            WHEN p_id IS NULL THEN 'Root'
            WHEN id IN (SELECT DISTINCT p_id FROM tree WHERE p_id IS NOT NULL) THEN 'Inner'
            ELSE 'Leaf'
        END AS type
    FROM tree
    ORDER BY id
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| Single node (root only) | Only one row with p_id = NULL | Returns "Root" |
| All nodes are leaves except root | Root -> children with no grandchildren | Two types: Root + Leaf |
| Deep chain (1→2→3→4) | Node 1 = Root, 2,3 = Inner, 4 = Leaf | Works with all methods |
| Multiple roots | Multiple rows with p_id = NULL | All classified as Root (forest) |

## Key Interview Talking Points

1. **Why not just check `p_id IS NULL` for all classifications?**
   - `p_id` only tells you if a node HAS a parent. To know if it's Inner vs. Leaf, you must also check if it IS a parent — requires looking at the `p_id` column of other rows.

2. **Join approach vs. isin() approach:**
   - `isin()` collects data to the driver — fails at scale.
   - Join approach keeps everything distributed.

3. **Follow-up: "What about a forest (multiple trees)?"**
   - Same logic works — multiple rows will have `p_id IS NULL` and all get classified as Root.

4. **Time complexity:**
   - Join approach: O(n) with hash join on distinct parent ids.
   - The `IN (subquery)` SQL approach uses a semi-join internally.
