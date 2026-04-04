# PySpark Implementation: Network Graph Degree Analysis

## Problem Statement

Given network/graph data represented as edges (source_node, target_node), compute in-degree, out-degree, and total degree for each node. Identify hub nodes (highly connected) and authority nodes. This is a common interview question at companies dealing with social networks (LinkedIn, Meta), payment networks (PayPal, Stripe), and knowledge graphs. It tests your understanding of graph concepts and ability to implement them using relational operations.

### Sample Data

**Edges (directed graph):**

| source | target | weight |
|--------|--------|--------|
| Alice  | Bob    | 1      |
| Alice  | Carol  | 2      |
| Bob    | Carol  | 1      |
| Bob    | Dave   | 3      |
| Carol  | Alice  | 1      |
| Dave   | Alice  | 2      |
| Dave   | Bob    | 1      |
| Eve    | Alice  | 1      |
| Eve    | Bob    | 2      |
| Eve    | Carol  | 1      |

### Expected Output

| node  | in_degree | out_degree | total_degree | is_hub |
|-------|-----------|------------|--------------|--------|
| Alice | 3         | 2          | 5            | true   |
| Bob   | 3         | 2          | 5            | true   |
| Carol | 3         | 1          | 4            | false  |
| Dave  | 1         | 2          | 3            | false  |
| Eve   | 0         | 3          | 3            | false  |

---

## Method 1: DataFrame API

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Initialize Spark
spark = SparkSession.builder \
    .appName("Network Graph Degree Analysis") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
edges_data = [
    ("Alice", "Bob", 1),
    ("Alice", "Carol", 2),
    ("Bob", "Carol", 1),
    ("Bob", "Dave", 3),
    ("Carol", "Alice", 1),
    ("Dave", "Alice", 2),
    ("Dave", "Bob", 1),
    ("Eve", "Alice", 1),
    ("Eve", "Bob", 2),
    ("Eve", "Carol", 1),
]

edges_df = spark.createDataFrame(edges_data, ["source", "target", "weight"])

print("=== Edges ===")
edges_df.show()

# --- Compute Out-Degree (number of edges leaving each node) ---
out_degree = edges_df.groupBy("source").agg(
    F.count("*").alias("out_degree"),
    F.sum("weight").alias("out_weight")
).withColumnRenamed("source", "node")

# --- Compute In-Degree (number of edges arriving at each node) ---
in_degree = edges_df.groupBy("target").agg(
    F.count("*").alias("in_degree"),
    F.sum("weight").alias("in_weight")
).withColumnRenamed("target", "node")

# --- Get all unique nodes ---
all_nodes = edges_df.select(F.col("source").alias("node")) \
    .union(edges_df.select(F.col("target").alias("node"))) \
    .distinct()

# --- Join degrees with all nodes ---
node_degrees = all_nodes \
    .join(in_degree, "node", "left") \
    .join(out_degree, "node", "left") \
    .fillna(0) \
    .withColumn("total_degree", F.col("in_degree") + F.col("out_degree")) \
    .withColumn("total_weight", F.col("in_weight") + F.col("out_weight"))

# --- Identify hub nodes (top 40th percentile by total_degree) ---
degree_threshold = node_degrees.approxQuantile("total_degree", [0.6], 0.01)[0]

node_degrees = node_degrees.withColumn(
    "is_hub",
    F.when(F.col("total_degree") >= degree_threshold, True).otherwise(False)
)

print("=== Node Degree Analysis ===")
node_degrees.orderBy(F.desc("total_degree")).show()

# --- Identify mutual connections (bidirectional edges) ---
mutual = edges_df.alias("e1").join(
    edges_df.alias("e2"),
    (F.col("e1.source") == F.col("e2.target")) &
    (F.col("e1.target") == F.col("e2.source"))
).select(
    F.col("e1.source").alias("node_a"),
    F.col("e1.target").alias("node_b")
).filter(F.col("node_a") < F.col("node_b"))

print("=== Mutual Connections (Bidirectional Edges) ===")
mutual.show()

# --- Compute degree distribution ---
degree_dist = node_degrees.groupBy("total_degree").agg(
    F.count("*").alias("node_count")
).orderBy("total_degree")

print("=== Degree Distribution ===")
degree_dist.show()

spark.stop()
```

## Method 2: SQL-Based Approach

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Network Graph Degree - SQL") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
edges_data = [
    ("Alice", "Bob", 1), ("Alice", "Carol", 2),
    ("Bob", "Carol", 1), ("Bob", "Dave", 3),
    ("Carol", "Alice", 1), ("Dave", "Alice", 2),
    ("Dave", "Bob", 1), ("Eve", "Alice", 1),
    ("Eve", "Bob", 2), ("Eve", "Carol", 1),
]

edges_df = spark.createDataFrame(edges_data, ["source", "target", "weight"])
edges_df.createOrReplaceTempView("edges")

# --- All node degrees in a single query ---
node_degrees = spark.sql("""
    WITH all_nodes AS (
        SELECT source AS node FROM edges
        UNION
        SELECT target AS node FROM edges
    ),
    out_deg AS (
        SELECT source AS node, COUNT(*) AS out_degree
        FROM edges
        GROUP BY source
    ),
    in_deg AS (
        SELECT target AS node, COUNT(*) AS in_degree
        FROM edges
        GROUP BY target
    )
    SELECT
        n.node,
        COALESCE(i.in_degree, 0) AS in_degree,
        COALESCE(o.out_degree, 0) AS out_degree,
        COALESCE(i.in_degree, 0) + COALESCE(o.out_degree, 0) AS total_degree
    FROM all_nodes n
    LEFT JOIN in_deg i ON n.node = i.node
    LEFT JOIN out_deg o ON n.node = o.node
    ORDER BY total_degree DESC
""")

print("=== Node Degrees (SQL) ===")
node_degrees.show()

# --- Neighbors list per node ---
neighbors = spark.sql("""
    SELECT
        node,
        COLLECT_SET(neighbor) AS neighbors,
        SIZE(COLLECT_SET(neighbor)) AS unique_neighbors
    FROM (
        SELECT source AS node, target AS neighbor FROM edges
        UNION ALL
        SELECT target AS node, source AS neighbor FROM edges
    )
    GROUP BY node
    ORDER BY unique_neighbors DESC
""")

print("=== Neighbor Lists ===")
neighbors.show(truncate=False)

# --- Find triangles (common interview extension) ---
triangles = spark.sql("""
    SELECT DISTINCT
        LEAST(e1.source, e2.source, e3.source) AS node_a,
        -- middle value
        CASE
            WHEN e1.source != LEAST(e1.source, e2.source, e3.source)
                 AND e1.source != GREATEST(e1.source, e2.source, e3.source)
            THEN e1.source
            WHEN e2.source != LEAST(e1.source, e2.source, e3.source)
                 AND e2.source != GREATEST(e1.source, e2.source, e3.source)
            THEN e2.source
            ELSE e3.source
        END AS node_b,
        GREATEST(e1.source, e2.source, e3.source) AS node_c
    FROM edges e1
    JOIN edges e2 ON e1.target = e2.source
    JOIN edges e3 ON e2.target = e3.source AND e3.target = e1.source
    WHERE e1.source < e1.target
""")

print("=== Triangles in Graph ===")
triangles.show()

spark.stop()
```

## Key Concepts

- **In-Degree**: Number of edges pointing to a node. High in-degree nodes are "authorities" -- popular or referenced often.
- **Out-Degree**: Number of edges leaving a node. High out-degree nodes are "hubs" -- they connect to many others.
- **Total Degree**: Sum of in-degree and out-degree for directed graphs; simply the number of edges for undirected.
- **Weighted Degree**: Sum of edge weights rather than edge counts. Important for networks where connections have varying strength.
- **Hub Detection**: Typically nodes above a threshold (e.g., mean + 1 std dev, or top percentile) of total degree.
- **Triangles**: A cycle of length 3. The clustering coefficient of a node measures how many of its neighbor pairs are also connected.

## Interview Tips

- Clarify whether the graph is **directed or undirected** -- this changes how you count degrees.
- For very large graphs, mention **GraphFrames** library for PySpark, which provides optimized graph algorithms.
- The cross-join approach for finding triangles is O(E^2); mention that real-world implementations use more efficient algorithms.
- Degree distribution often follows a **power law** in real networks -- mentioning this shows domain knowledge.
- Common follow-ups: PageRank, connected components, shortest path -- know how these relate to degree analysis.
