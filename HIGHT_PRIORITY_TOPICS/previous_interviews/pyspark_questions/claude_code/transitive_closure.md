# PySpark Implementation: Transitive Closure of a Graph

## Problem Statement
Given a set of direct friendship edges `(person_a, person_b)`, compute the **transitive closure**:
find all pairs of people who are connected through any chain of friendships. If Alice knows Bob
and Bob knows Carol, then Alice and Carol are transitively connected.

This is a classic graph reachability problem. In PySpark (without GraphFrames), we solve it with
iterative self-joins until no new edges are discovered.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("TransitiveClosure").getOrCreate()

edges = [
    ("Alice", "Bob"),
    ("Bob",   "Carol"),
    ("Carol", "Dave"),
    ("Eve",   "Frank"),
    ("Grace", "Hank"),
    ("Hank",  "Ivy"),
]

df_edges = spark.createDataFrame(edges, ["person_a", "person_b"])
df_edges.show()
```

| person_a | person_b |
|----------|----------|
| Alice    | Bob      |
| Bob      | Carol    |
| Carol    | Dave     |
| Eve      | Frank    |
| Grace    | Hank     |
| Hank     | Ivy      |

**Connected components in this graph:**
- Component 1: {Alice, Bob, Carol, Dave}
- Component 2: {Eve, Frank}
- Component 3: {Grace, Hank, Ivy}

### Expected Output (Transitive Closure)
All reachable pairs (including the original direct edges):

| person_a | person_b |
|----------|----------|
| Alice    | Bob      |
| Alice    | Carol    |
| Alice    | Dave     |
| Bob      | Carol    |
| Bob      | Dave     |
| Carol    | Dave     |
| Eve      | Frank    |
| Grace    | Hank     |
| Grace    | Ivy      |
| Hank     | Ivy      |

---

## Method 1: Iterative Self-Join (Recommended)

```python
from pyspark.sql import functions as F

# Step 1 -- Make edges bidirectional so traversal works in both directions
df_sym = (
    df_edges
    .unionByName(
        df_edges.select(
            F.col("person_b").alias("person_a"),
            F.col("person_a").alias("person_b"),
        )
    )
    .distinct()
)

# Step 2 -- Iterative self-join to discover transitive edges
closure = df_sym
prev_count = 0
iteration = 0

while True:
    iteration += 1
    # Join: if (A->B) and (B->C) exist, add (A->C)
    new_edges = (
        closure.alias("left")
        .join(
            closure.alias("right"),
            F.col("left.person_b") == F.col("right.person_a"),
        )
        .select(
            F.col("left.person_a").alias("person_a"),
            F.col("right.person_b").alias("person_b"),
        )
        .filter(F.col("person_a") != F.col("person_b"))  # no self-loops
    )

    closure = closure.union(new_edges).distinct()
    closure.cache()

    current_count = closure.count()
    print(f"Iteration {iteration}: {current_count} edges")

    if current_count == prev_count:
        break
    prev_count = current_count

# Step 3 -- Optionally keep only one direction (person_a < person_b) for clean output
result = closure.filter(F.col("person_a") < F.col("person_b")).orderBy("person_a", "person_b")
result.show(truncate=False)
```

### Step-by-Step Explanation

**After Step 1** -- bidirectional edges (showing subset):

| person_a | person_b |
|----------|----------|
| Alice    | Bob      |
| Bob      | Alice    |
| Bob      | Carol    |
| Carol    | Bob      |
| Carol    | Dave     |
| Dave     | Carol    |

**Iteration 1** -- self-join discovers 2-hop connections:

The join `(Alice->Bob) + (Bob->Carol)` yields `(Alice->Carol)`.
The join `(Bob->Carol) + (Carol->Dave)` yields `(Bob->Dave)`.
The join `(Alice->Bob) + (Bob->Carol->Dave)` is not yet reachable; that needs iteration 2.

| New edges discovered | Via path              |
|----------------------|-----------------------|
| Alice -> Carol       | Alice -> Bob -> Carol |
| Bob -> Dave          | Bob -> Carol -> Dave  |
| Grace -> Ivy         | Grace -> Hank -> Ivy  |
| (+ reverse of each)  |                       |

**Iteration 2** -- discovers 3-hop connections:

| New edges discovered | Via path                      |
|----------------------|-------------------------------|
| Alice -> Dave        | Alice -> Bob -> Carol -> Dave |
| (+ reverse)          |                               |

**Iteration 3** -- no new edges found. Algorithm terminates.

**Final filtered output (person_a < person_b):**

| person_a | person_b |
|----------|----------|
| Alice    | Bob      |
| Alice    | Carol    |
| Alice    | Dave     |
| Bob      | Carol    |
| Bob      | Dave     |
| Carol    | Dave     |
| Eve      | Frank    |
| Grace    | Hank     |
| Grace    | Ivy      |
| Hank     | Ivy      |

---

## Method 2: Connected Components via Min-Label Propagation

Instead of computing all pairs, assign each node to a component ID (the alphabetically smallest
member). This is more efficient for large graphs where you only need component membership.

```python
from pyspark.sql import functions as F

# Build node list with initial component label = self
nodes = (
    df_edges.select(F.col("person_a").alias("node"))
    .union(df_edges.select(F.col("person_b").alias("node")))
    .distinct()
    .withColumn("component", F.col("node"))
)

# Bidirectional edges
edges_bi = df_edges.unionByName(
    df_edges.select(
        F.col("person_b").alias("person_a"),
        F.col("person_a").alias("person_b"),
    )
)

iteration = 0
while True:
    iteration += 1

    # For each node, find the minimum component label among its neighbors
    neighbor_labels = (
        edges_bi.alias("e")
        .join(nodes.alias("n"), F.col("e.person_b") == F.col("n.node"))
        .select(
            F.col("e.person_a").alias("node"),
            F.col("n.component").alias("neighbor_component"),
        )
    )

    updated_labels = (
        neighbor_labels
        .groupBy("node")
        .agg(F.min("neighbor_component").alias("new_component"))
    )

    new_nodes = (
        nodes.alias("old")
        .join(updated_labels.alias("upd"), "node", "left")
        .select(
            F.col("node"),
            F.least(F.col("old.component"), F.col("upd.new_component")).alias("component"),
        )
    )
    new_nodes.cache()

    # Check convergence
    changes = (
        nodes.alias("a")
        .join(new_nodes.alias("b"), "node")
        .filter(F.col("a.component") != F.col("b.component"))
        .count()
    )

    nodes = new_nodes
    print(f"Iteration {iteration}: {changes} label changes")

    if changes == 0:
        break

nodes.orderBy("node").show(truncate=False)
```

**Final component labels:**

| node  | component |
|-------|-----------|
| Alice | Alice     |
| Bob   | Alice     |
| Carol | Alice     |
| Dave  | Alice     |
| Eve   | Eve       |
| Frank | Eve       |
| Grace | Grace     |
| Hank  | Grace     |
| Ivy   | Grace     |

---

## Key Interview Talking Points

1. **Transitive closure is O(d) iterations where d is the graph diameter** -- each iteration
   discovers paths one hop longer. For a chain of length n, it takes n-1 iterations.

2. **Cache intermediate results** -- without `.cache()`, Spark recomputes the entire lineage on
   every `.count()` check, leading to exponential blowup. This is the most critical optimization.

3. **Convergence detection** -- compare edge counts (or label change counts) between iterations.
   When the count stops growing, all reachable pairs have been found.

4. **Bidirectionality** -- friendship is symmetric. Forgetting to add reverse edges is the most
   common bug and causes incomplete transitive closure.

5. **Self-loops** -- always filter out `person_a == person_b` edges created by the join; they
   waste space and can cause confusion.

6. **GraphFrames alternative** -- in production, `GraphFrames.connectedComponents()` uses a
   highly optimized algorithm. Mention it to show awareness, but be prepared to implement the
   iterative approach from scratch.

7. **Scalability concern** -- transitive closure can produce O(n^2) edges for a fully connected
   graph. For large graphs, connected components (Method 2) is far more practical since it
   produces only O(n) rows.

8. **Checkpoint vs cache** -- for many iterations, use `checkpoint()` instead of `cache()` to
   break the lineage DAG. Long lineages cause StackOverflow errors in the Spark driver.
