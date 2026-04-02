# PySpark Implementation: Graph Shortest Path via Iterative Joins

## Problem Statement
Given a table of flight routes (origin city, destination city, distance), find the
**shortest route** between two cities using an iterative breadth-first search (BFS)
approach built entirely with PySpark join operations. Also find **all cities reachable
within N hops** from a starting city.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("GraphShortestPath").getOrCreate()

flights = spark.createDataFrame([
    ("Seattle", "Chicago", 1740),
    ("Seattle", "Denver", 1320),
    ("Denver", "Chicago", 920),
    ("Denver", "Dallas", 660),
    ("Chicago", "New York", 790),
    ("Chicago", "Miami", 1380),
    ("Dallas", "Miami", 1310),
    ("Dallas", "New York", 1550),
    ("Miami", "New York", 1280),
    ("New York", "Boston", 215),
], ["origin", "destination", "distance"])

# Make edges bidirectional
edges = flights.unionByName(
    flights.select(
        F.col("destination").alias("origin"),
        F.col("origin").alias("destination"),
        F.col("distance"),
    )
)

edges.orderBy("origin").show()
```

### Expected Output -- Shortest Path from Seattle to Miami
| path                            | total_distance | hops |
|---------------------------------|----------------|------|
| Seattle -> Denver -> Dallas -> Miami | 3290       | 3    |

### Expected Output -- All Cities Reachable Within 2 Hops from Seattle
| city     | min_distance | hops |
|----------|--------------|------|
| Chicago  | 1740         | 1    |
| Denver   | 1320         | 1    |
| Dallas   | 1980         | 2    |
| Miami    | 3120         | 2    |
| New York | 2530         | 2    |

---

## Method 1: Iterative BFS with Join (Recommended)
```python
def shortest_path_bfs(edges_df, start, end, max_hops=6):
    """
    Find the shortest path between start and end using iterative joins.
    Each iteration extends known paths by one hop.
    """

    # Initialize the frontier: paths of length 0 starting at the source
    frontier = spark.createDataFrame(
        [(start, start, 0, [start])],
        ["current_node", "origin", "total_distance", "path"]
    )

    # Track all visited nodes to avoid cycles
    visited = spark.createDataFrame([(start,)], ["node"])

    best_result = None

    for hop in range(1, max_hops + 1):
        # Extend the frontier by one hop: join current endpoints with edges
        extended = frontier.join(
            edges_df,
            frontier["current_node"] == edges_df["origin"],
            "inner"
        ).select(
            edges_df["destination"].alias("current_node"),
            frontier["origin"],
            (frontier["total_distance"] + edges_df["distance"]).alias("total_distance"),
            F.concat(frontier["path"], F.array(edges_df["destination"])).alias("path"),
        )

        # Remove nodes already visited (cycle prevention)
        extended = extended.join(visited, extended["current_node"] == visited["node"], "left_anti")

        # Cache because we read this DataFrame multiple times
        extended = extended.cache()

        if extended.count() == 0:
            break

        # Check if we reached the destination
        arrived = extended.filter(F.col("current_node") == end)
        if arrived.count() > 0:
            # Keep the path with the minimum total distance
            best_in_hop = arrived.orderBy("total_distance").limit(1)
            if best_result is None:
                best_result = best_in_hop
            else:
                combined = best_result.unionByName(best_in_hop)
                best_result = combined.orderBy("total_distance").limit(1)

        # Add newly reached nodes to visited set
        new_nodes = extended.select(F.col("current_node").alias("node")).distinct()
        visited = visited.union(new_nodes).distinct()

        # The frontier for the next iteration is the extended set (minus destination hits)
        frontier = extended

    if best_result is not None:
        result = best_result.withColumn(
            "path_str", F.concat_ws(" -> ", "path")
        ).withColumn("hops", F.size("path") - 1)
        result.select("path_str", "total_distance", "hops").show(truncate=False)
        return result
    else:
        print(f"No path found from {start} to {end} within {max_hops} hops.")
        return None

result = shortest_path_bfs(edges, "Seattle", "Miami")
```

### Step-by-Step Explanation

**Iteration 1 (hop = 1) -- Extend from Seattle:**

Frontier before:
| current_node | total_distance | path       |
|--------------|----------------|------------|
| Seattle      | 0              | [Seattle]  |

After join with edges and filtering visited:
| current_node | total_distance | path               |
|--------------|----------------|---------------------|
| Chicago      | 1740           | [Seattle, Chicago]  |
| Denver       | 1320           | [Seattle, Denver]   |

Destination "Miami" not reached. Add Chicago, Denver to visited.

**Iteration 2 (hop = 2) -- Extend from Chicago and Denver:**
| current_node | total_distance | path                        |
|--------------|----------------|-----------------------------|
| New York     | 2530           | [Seattle, Chicago, New York]|
| Miami        | 3120           | [Seattle, Chicago, Miami]   |
| Dallas       | 1980           | [Seattle, Denver, Dallas]   |

Miami reached at distance 3120. Record as best_result so far.

**Iteration 3 (hop = 3) -- Extend from New York, Miami, Dallas:**
| current_node | total_distance | path                                  |
|--------------|----------------|---------------------------------------|
| Miami        | 3290           | [Seattle, Denver, Dallas, Miami]      |
| Boston       | 2745           | [Seattle, Chicago, New York, Boston]  |

Miami reached again at 3290 -- but 3120 < 3290, so the hop-2 path remains best.

**Final result:**
| path_str                  | total_distance | hops |
|---------------------------|----------------|------|
| Seattle -> Chicago -> Miami | 3120         | 2    |

---

## Method 2: Find All Nodes Reachable Within N Hops
```python
def reachable_within_n_hops(edges_df, start, n_hops):
    """
    Return all nodes reachable from start within n_hops, with minimum distance.
    """
    frontier = spark.createDataFrame(
        [(start, 0, 0)],
        ["current_node", "total_distance", "hops"]
    )
    all_reached = spark.createDataFrame([], frontier.schema)
    visited = spark.createDataFrame([(start,)], ["node"])

    for hop in range(1, n_hops + 1):
        extended = frontier.join(
            edges_df,
            frontier["current_node"] == edges_df["origin"],
            "inner"
        ).select(
            edges_df["destination"].alias("current_node"),
            (frontier["total_distance"] + edges_df["distance"]).alias("total_distance"),
            F.lit(hop).alias("hops"),
        )
        extended = extended.join(visited, extended["current_node"] == visited["node"], "left_anti")

        # Keep minimum distance per node at this hop
        w = Window.partitionBy("current_node").orderBy("total_distance")
        extended = extended.withColumn("rn", F.row_number().over(w)) \
                           .filter(F.col("rn") == 1).drop("rn")

        extended = extended.cache()
        if extended.count() == 0:
            break

        all_reached = all_reached.unionByName(extended)
        new_nodes = extended.select(F.col("current_node").alias("node")).distinct()
        visited = visited.union(new_nodes).distinct()
        frontier = extended

    # Keep minimum distance across all hops for each node
    w2 = Window.partitionBy("current_node").orderBy("total_distance")
    result = all_reached.withColumn("rn", F.row_number().over(w2)) \
                        .filter(F.col("rn") == 1).drop("rn") \
                        .withColumnRenamed("current_node", "city") \
                        .orderBy("hops", "total_distance")
    result.show()
    return result

reachable = reachable_within_n_hops(edges, "Seattle", 2)
```

### Output
| city     | total_distance | hops |
|----------|----------------|------|
| Denver   | 1320           | 1    |
| Chicago  | 1740           | 1    |
| Dallas   | 1980           | 2    |
| New York | 2530           | 2    |
| Miami    | 3120           | 2    |

---

## Key Interview Talking Points
1. **Why iterative joins** -- PySpark does not natively support recursive CTEs (unlike SQL in some engines). The standard workaround is a Python loop that extends the frontier by one hop per iteration via joins.
2. **Cycle prevention** -- Maintaining a `visited` set and using `left_anti` join ensures each node is processed only once, preventing infinite loops in cyclic graphs.
3. **BFS vs. Dijkstra** -- This approach is BFS-like (explores hop by hop). It finds shortest-hop paths naturally. For shortest-distance paths in weighted graphs, you must continue exploring even after reaching the destination.
4. **Caching intermediate results** -- `cache()` on the extended DataFrame is critical because it is read twice (once for count/filter, once as the next frontier).
5. **Scalability** -- This works for graphs that fit in a moderate number of hops. For very large graphs (billions of edges), consider GraphX or GraphFrames which provide optimized Pregel-style message passing.
6. **Bidirectional edges** -- The `unionByName` at the start doubles the edge set to make the graph undirected. Omit this for directed graphs.
7. **left_anti join** -- The idiomatic PySpark way to express "NOT IN" or "NOT EXISTS" subqueries from SQL, more efficient than a left join followed by a null filter.
