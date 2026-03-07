# PySpark Implementation: Finding Mutual Relationships

## Problem Statement
Given a directional "follows" table where each row represents `follower_id` following `followed_id`,
find all **mutual follow pairs** -- cases where user A follows user B AND user B follows user A.
Each mutual pair should appear only once in the output (avoid duplicates like showing both
(A, B) and (B, A)).

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, least, greatest

spark = SparkSession.builder.appName("MutualRelationships").getOrCreate()

# Directional follows table
data = [
    (1, 2),   # user 1 follows user 2
    (2, 1),   # user 2 follows user 1  -> MUTUAL with (1,2)
    (1, 3),   # user 1 follows user 3
    (3, 1),   # user 3 follows user 1  -> MUTUAL with (1,3)
    (1, 4),   # user 1 follows user 4  (user 4 does NOT follow back)
    (2, 3),   # user 2 follows user 3  (user 3 does NOT follow back)
    (5, 6),   # user 5 follows user 6
    (6, 5),   # user 6 follows user 5  -> MUTUAL with (5,6)
    (7, 8),   # user 7 follows user 8  (one-way)
    (2, 5),   # user 2 follows user 5
    (5, 2),   # user 5 follows user 2  -> MUTUAL with (2,5)
]

follows = spark.createDataFrame(data, ["follower_id", "followed_id"])
```

### Expected Output
| user_a | user_b |
|--------|--------|
| 1      | 2      |
| 1      | 3      |
| 2      | 5      |
| 5      | 6      |

Each mutual pair appears exactly once, with the smaller user ID in `user_a`.

---

## Method 1: Self-Join with ID Ordering Filter (Recommended)
```python
from pyspark.sql.functions import col

# Alias the follows table twice
f1 = follows.alias("f1")
f2 = follows.alias("f2")

# Self-join: find rows where A->B exists AND B->A exists
mutual = f1.join(
    f2,
    (col("f1.follower_id") == col("f2.followed_id")) &
    (col("f1.followed_id") == col("f2.follower_id")),
    "inner"
).select(
    col("f1.follower_id").alias("user_a"),
    col("f1.followed_id").alias("user_b")
)

# Deduplicate: keep only pairs where user_a < user_b
mutual_deduped = mutual.filter(col("user_a") < col("user_b"))

mutual_deduped.orderBy("user_a", "user_b").show()
```

### Step-by-Step Explanation

**Step 1 -- The raw follows table:**

| follower_id | followed_id |
|-------------|-------------|
| 1           | 2           |
| 2           | 1           |
| 1           | 3           |
| 3           | 1           |
| 1           | 4           |
| 2           | 3           |
| 5           | 6           |
| 6           | 5           |
| 7           | 8           |
| 2           | 5           |
| 5           | 2           |

**Step 2 -- After self-join (before dedup), matching A->B with B->A:**

The join condition `f1.follower_id = f2.followed_id AND f1.followed_id = f2.follower_id`
finds reverse-direction matches. This produces **two rows** per mutual pair:

| user_a | user_b |
|--------|--------|
| 1      | 2      |
| 2      | 1      |
| 1      | 3      |
| 3      | 1      |
| 5      | 6      |
| 6      | 5      |
| 2      | 5      |
| 5      | 2      |

**Step 3 -- After filter(user_a < user_b) to eliminate duplicates:**

| user_a | user_b |
|--------|--------|
| 1      | 2      |
| 1      | 3      |
| 2      | 5      |
| 5      | 6      |

The `<` filter guarantees exactly one row per mutual pair by always keeping the row
where the smaller ID comes first.

---

## Method 2: Canonical Pair with Group Count
```python
from pyspark.sql.functions import least, greatest, count

# Create a canonical pair column where the smaller ID is always first
canonical = follows.select(
    least("follower_id", "followed_id").alias("user_a"),
    greatest("follower_id", "followed_id").alias("user_b"),
)

# If a canonical pair appears twice, both directions exist -> mutual
mutual_pairs = (
    canonical
    .groupBy("user_a", "user_b")
    .agg(count("*").alias("direction_count"))
    .filter(col("direction_count") == 2)
    .select("user_a", "user_b")
)

mutual_pairs.orderBy("user_a", "user_b").show()
```

### How Method 2 Works

**Step 1 -- Apply least/greatest to normalize direction:**

| user_a | user_b |
|--------|--------|
| 1      | 2      |
| 1      | 2      |
| 1      | 3      |
| 1      | 3      |
| 1      | 4      |
| 2      | 3      |
| 5      | 6      |
| 5      | 6      |
| 7      | 8      |
| 2      | 5      |
| 2      | 5      |

**Step 2 -- Group and count, then filter for count == 2:**

| user_a | user_b | direction_count |
|--------|--------|-----------------|
| 1      | 2      | 2               |
| 1      | 3      | 2               |
| 1      | 4      | 1               |
| 2      | 3      | 1               |
| 2      | 5      | 2               |
| 5      | 6      | 2               |
| 7      | 8      | 1               |

Rows with `direction_count = 2` are mutual. Rows with 1 are one-way follows.

---

## Key Interview Talking Points

1. **Why self-join works**: A directional relationship is mutual when both (A, B) and (B, A)
   exist. The self-join explicitly matches each row with its reverse-direction counterpart.

2. **Deduplication strategy**: Without the `user_a < user_b` filter, every mutual pair
   appears twice. The inequality filter is an O(1) per-row operation -- much cheaper than
   `dropDuplicates()` which requires a shuffle.

3. **Method 1 vs Method 2 tradeoffs**:
   - Method 1 (self-join) is more intuitive and directly expresses the logic.
   - Method 2 (canonical pair + count) avoids a self-join and uses a single groupBy instead.
     On very large datasets, groupBy can be cheaper than a join.
   - Method 2 also naturally handles edge cases like duplicate rows in the input (a user
     following another user recorded twice would give count > 2; use `>= 2` to handle that).

4. **Broadcast optimization**: If one direction is much smaller (e.g., a "premium follows"
   subset), you can broadcast the smaller side of the join to avoid shuffle:
   ```python
   from pyspark.sql.functions import broadcast
   mutual = f1.join(broadcast(f2), ..., "inner")
   ```

5. **Handling at scale**: For social networks with billions of edges, consider:
   - Partitioning the follows table by `follower_id` to co-locate data
   - Using `salting` if certain users have extremely high follower counts (skew)
   - Pre-computing mutual relationships incrementally as new follows arrive

6. **Graph frame alternative**: For graph-heavy workloads, GraphFrames provides a `find()`
   method that can express mutual relationships as a motif pattern:
   ```python
   # g.find("(a)-[e1]->(b); (b)-[e2]->(a)")
   ```

7. **SQL equivalent of Method 1**:
   ```sql
   SELECT f1.follower_id AS user_a, f1.followed_id AS user_b
   FROM follows f1
   JOIN follows f2
     ON f1.follower_id = f2.followed_id
    AND f1.followed_id = f2.follower_id
   WHERE f1.follower_id < f1.followed_id
   ```
