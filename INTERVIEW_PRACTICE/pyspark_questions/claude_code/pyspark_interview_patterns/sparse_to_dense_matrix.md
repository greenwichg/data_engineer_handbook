# PySpark Implementation: Sparse to Dense Matrix Conversion

## Problem Statement

In many real-world datasets (recommendation systems, NLP term-document matrices, IoT sensor grids), data is stored in a sparse format (row_id, column_id, value) where only non-zero entries are recorded. Converting this sparse representation to a dense matrix format -- where every row-column combination is filled (with zeros or nulls for missing entries) -- is a common interview question for data engineering roles. This tests your ability to work with pivoting, cross joins, and efficient handling of missing data.

### Sample Data

**Sparse Representation (user-item ratings):**

| user_id | item_id | rating |
|---------|---------|--------|
| u1      | i1      | 5      |
| u1      | i3      | 3      |
| u2      | i2      | 4      |
| u2      | i4      | 2      |
| u3      | i1      | 1      |
| u3      | i2      | 5      |
| u3      | i3      | 4      |

### Expected Output

**Dense Matrix:**

| user_id | i1   | i2   | i3   | i4   |
|---------|------|------|------|------|
| u1      | 5    | 0    | 3    | 0    |
| u2      | 0    | 4    | 0    | 2    |
| u3      | 1    | 5    | 4    | 0    |

---

## Method 1: Using Pivot

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# Initialize Spark
spark = SparkSession.builder \
    .appName("Sparse to Dense Matrix - Pivot") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
sparse_data = [
    ("u1", "i1", 5),
    ("u1", "i3", 3),
    ("u2", "i2", 4),
    ("u2", "i4", 2),
    ("u3", "i1", 1),
    ("u3", "i2", 5),
    ("u3", "i3", 4),
]

sparse_df = spark.createDataFrame(sparse_data, ["user_id", "item_id", "rating"])

print("=== Sparse Representation ===")
sparse_df.show()

# Get all distinct items for consistent column ordering
all_items = sorted([row["item_id"] for row in sparse_df.select("item_id").distinct().collect()])

# Pivot to create dense matrix, fill missing with 0
dense_df = sparse_df.groupBy("user_id") \
    .pivot("item_id", all_items) \
    .agg(F.first("rating")) \
    .fillna(0)

print("=== Dense Matrix (Pivot Method) ===")
dense_df.orderBy("user_id").show()

# --- Convert back from dense to sparse ---
# Stack/unpivot the columns back
item_cols = [c for c in dense_df.columns if c != "user_id"]

# Build the stack expression
stack_expr = ", ".join([f"'{col}', `{col}`" for col in item_cols])
n_cols = len(item_cols)

sparse_again = dense_df.select(
    "user_id",
    F.expr(f"stack({n_cols}, {stack_expr}) as (item_id, rating)")
).filter(F.col("rating") != 0)

print("=== Converted Back to Sparse ===")
sparse_again.orderBy("user_id", "item_id").show()

spark.stop()
```

## Method 2: Cross Join + Left Join (Explicit Dense Construction)

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Sparse to Dense - Cross Join") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
sparse_data = [
    ("u1", "i1", 5),
    ("u1", "i3", 3),
    ("u2", "i2", 4),
    ("u2", "i4", 2),
    ("u3", "i1", 1),
    ("u3", "i2", 5),
    ("u3", "i3", 4),
]

sparse_df = spark.createDataFrame(sparse_data, ["user_id", "item_id", "rating"])

# Step 1: Get all unique row and column identifiers
all_users = sparse_df.select("user_id").distinct()
all_items = sparse_df.select("item_id").distinct()

# Step 2: Cross join to get every user-item combination
full_grid = all_users.crossJoin(all_items)

print(f"Full grid size: {full_grid.count()} (users x items)")

# Step 3: Left join with original data to fill in values
dense_long = full_grid.join(
    sparse_df,
    on=["user_id", "item_id"],
    how="left"
).fillna(0, subset=["rating"])

print("=== Dense (Long Format) ===")
dense_long.orderBy("user_id", "item_id").show()

# Step 4: Pivot to wide format
all_item_list = sorted([r["item_id"] for r in all_items.collect()])

dense_wide = dense_long.groupBy("user_id") \
    .pivot("item_id", all_item_list) \
    .agg(F.first("rating"))

print("=== Dense (Wide/Matrix Format) ===")
dense_wide.orderBy("user_id").show()

spark.stop()
```

## Method 3: Using collect_list and MapType for Large Sparse Matrices

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import MapType, StringType, IntegerType

spark = SparkSession.builder \
    .appName("Sparse to Dense - Map Approach") \
    .master("local[*]") \
    .getOrCreate()

# --- Larger sample for demonstration ---
sparse_data = [
    ("u1", "i1", 5), ("u1", "i3", 3), ("u1", "i7", 2),
    ("u2", "i2", 4), ("u2", "i4", 2), ("u2", "i6", 1),
    ("u3", "i1", 1), ("u3", "i2", 5), ("u3", "i3", 4),
    ("u4", "i5", 3), ("u4", "i7", 5),
    ("u5", "i1", 2), ("u5", "i4", 4), ("u5", "i6", 3),
]

sparse_df = spark.createDataFrame(sparse_data, ["user_id", "item_id", "rating"])

# Create a map column per user: {item_id -> rating}
user_maps = sparse_df.groupBy("user_id").agg(
    F.map_from_entries(
        F.collect_list(F.struct("item_id", "rating"))
    ).alias("ratings_map")
)

print("=== User Rating Maps ===")
user_maps.show(truncate=False)

# Get all items
all_items = sorted([r["item_id"] for r in sparse_df.select("item_id").distinct().collect()])

# Expand map to columns -- useful for very wide sparse matrices where
# you only need to materialize a subset of columns
for item in all_items:
    user_maps = user_maps.withColumn(
        item,
        F.coalesce(F.col("ratings_map").getItem(item), F.lit(0))
    )

dense_result = user_maps.drop("ratings_map")

print("=== Dense Matrix from Map ===")
dense_result.orderBy("user_id").show()

# --- Compute sparsity metric ---
total_cells = sparse_df.select("user_id").distinct().count() * len(all_items)
filled_cells = sparse_df.count()
sparsity = 1 - (filled_cells / total_cells)

print(f"Matrix dimensions: {sparse_df.select('user_id').distinct().count()} x {len(all_items)}")
print(f"Non-zero entries: {filled_cells}")
print(f"Sparsity: {sparsity:.2%}")

spark.stop()
```

## Key Concepts

- **Sparse Representation**: Only stores non-zero/non-null entries, saving storage. Common in recommendation systems (user-item matrices), NLP (term-document), and graph adjacency matrices.
- **Dense Representation**: Every row-column combination is explicitly stored, including zeros. Needed for matrix operations, ML model inputs, or reporting.
- **Pivot**: The most natural PySpark approach for sparse-to-dense. Use the `pivot()` method with `fillna(0)` for missing entries.
- **Cross Join Approach**: More explicit -- create the full grid of all row-column combinations, then left-join the values. Better when you need to control the grid dimensions explicitly.
- **Map Approach**: For extremely wide matrices, storing as a MapType column avoids materializing thousands of columns. Extract only needed columns on demand.
- **Performance**: Pivot can be expensive with many distinct column values. Use `pivot("col", values_list)` with a pre-computed list to avoid an extra aggregation pass.

## Interview Tips

- Mention **sparsity** as a key metric -- if the matrix is 99% sparse, keeping it dense wastes memory.
- Discuss **trade-offs**: dense format is easier to query but uses more storage; sparse format is compact but harder to compute with.
- For very large matrices, consider storing as **SparseVector** in MLlib rather than converting to wide format.
- The reverse operation (dense to sparse) is also commonly asked -- filter out zero values after unpivoting.
