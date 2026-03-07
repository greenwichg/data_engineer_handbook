# PySpark Implementation: Matrix and Cross-Tabulation

## Problem Statement
Given a table of purchase transactions (user_id, product), build a **product co-occurrence
matrix** that shows how many distinct users purchased each pair of products together.
This is a foundational technique for collaborative-filtering recommendations and
market-basket analysis.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("MatrixCrossTab").getOrCreate()

purchases = spark.createDataFrame([
    (1, "Laptop"), (1, "Mouse"), (1, "Keyboard"),
    (2, "Laptop"), (2, "Mouse"),
    (3, "Mouse"), (3, "Keyboard"), (3, "Monitor"),
    (4, "Laptop"), (4, "Monitor"), (4, "Mouse"),
    (5, "Keyboard"), (5, "Monitor"),
], ["user_id", "product"])

purchases.show()
```

### Expected Output -- Co-occurrence Matrix
| product  | Keyboard | Laptop | Monitor | Mouse |
|----------|----------|--------|---------|-------|
| Keyboard | -        | 1      | 2       | 2     |
| Laptop   | 1        | -      | 1       | 3     |
| Monitor  | 2        | 1      | -       | 2     |
| Mouse    | 2        | 3      | 2       | -     |

Reading: "Laptop & Mouse were bought together by 3 users."

---

## Method 1: Self-Join with Pivot (Recommended)
```python
# Step 1 -- Self-join purchases on user_id to get all product pairs per user
pairs = purchases.alias("a").join(
    purchases.alias("b"),
    on=(F.col("a.user_id") == F.col("b.user_id"))
      & (F.col("a.product") < F.col("b.product")),  # avoid duplicates & self-pairs
    how="inner"
).select(
    F.col("a.user_id"),
    F.col("a.product").alias("product_a"),
    F.col("b.product").alias("product_b"),
)

# Step 2 -- Count distinct users for each product pair
pair_counts = pairs.groupBy("product_a", "product_b").agg(
    F.countDistinct("user_id").alias("co_occurrence")
)

# Step 3 -- Mirror the pairs so the matrix is symmetric
symmetric = pair_counts.unionByName(
    pair_counts.select(
        F.col("product_b").alias("product_a"),
        F.col("product_a").alias("product_b"),
        F.col("co_occurrence"),
    )
)

# Step 4 -- Pivot to create the matrix
matrix = symmetric.groupBy("product_a").pivot("product_b").agg(
    F.first("co_occurrence")
).na.fill(0).orderBy("product_a")

matrix = matrix.withColumnRenamed("product_a", "product")
matrix.show()
```

### Step-by-Step Explanation

**Step 1 -- Self-join produces all ordered product pairs per user:**
| user_id | product_a | product_b |
|---------|-----------|-----------|
| 1       | Keyboard  | Laptop    |
| 1       | Keyboard  | Mouse     |
| 1       | Laptop    | Mouse     |
| 2       | Laptop    | Mouse     |
| 3       | Keyboard  | Monitor   |
| 3       | Keyboard  | Mouse     |
| 3       | Monitor   | Mouse     |
| 4       | Laptop    | Monitor   |
| 4       | Laptop    | Mouse     |
| 4       | Monitor   | Mouse     |
| 5       | Keyboard  | Monitor   |

The condition `a.product < b.product` ensures each pair appears once (alphabetical order)
and excludes self-pairs like (Laptop, Laptop).

**Step 2 -- Aggregated pair counts:**
| product_a | product_b | co_occurrence |
|-----------|-----------|---------------|
| Keyboard  | Laptop    | 1             |
| Keyboard  | Monitor   | 2             |
| Keyboard  | Mouse     | 2             |
| Laptop    | Monitor   | 1             |
| Laptop    | Mouse     | 3             |
| Monitor   | Mouse     | 2             |

**Step 3 -- After mirroring (symmetric), each pair exists in both directions:**
| product_a | product_b | co_occurrence |
|-----------|-----------|---------------|
| Keyboard  | Laptop    | 1             |
| Laptop    | Keyboard  | 1             |
| ...       | ...       | ...           |

**Step 4 -- After pivot, the final matrix (see Expected Output above).**

---

## Method 2: Cross-Tabulation with Built-in crosstab
```python
# Spark's built-in crosstab counts row co-occurrences of two columns.
# For a simple frequency cross-tab (not co-occurrence), it works directly:

survey_data = spark.createDataFrame([
    ("Male", "Urban"), ("Female", "Rural"), ("Male", "Urban"),
    ("Female", "Urban"), ("Male", "Rural"), ("Male", "Suburban"),
    ("Female", "Suburban"), ("Female", "Urban"), ("Male", "Urban"),
    ("Female", "Rural"),
], ["gender", "location"])

# Built-in cross-tabulation
cross = survey_data.crosstab("gender", "location")
cross.show()
```

### crosstab Output
| gender_location | Rural | Suburban | Urban |
|-----------------|-------|----------|-------|
| Female          | 2     | 1        | 2     |
| Male            | 1     | 1        | 3     |

---

## Method 3: Correlation Matrix Between Numeric Columns
```python
from pyspark.ml.stat import Correlation
from pyspark.ml.feature import VectorAssembler

metrics = spark.createDataFrame([
    (100, 4.2, 12), (200, 3.8, 25), (150, 4.5, 18),
    (300, 3.2, 40), (250, 3.6, 35), (180, 4.0, 22),
], ["page_views", "avg_rating", "purchases"])

# Assemble numeric columns into a single vector column
assembler = VectorAssembler(
    inputCols=["page_views", "avg_rating", "purchases"],
    outputCol="features"
)
vec_df = assembler.transform(metrics).select("features")

# Compute Pearson correlation matrix
corr_matrix = Correlation.corr(vec_df, "features", method="pearson")
corr_array = corr_matrix.collect()[0][0].toArray()

col_names = ["page_views", "avg_rating", "purchases"]
rows = []
for i, name in enumerate(col_names):
    row = [name] + [round(float(corr_array[i][j]), 4) for j in range(len(col_names))]
    rows.append(tuple(row))

corr_df = spark.createDataFrame(rows, ["metric"] + col_names)
corr_df.show()
```

### Correlation Matrix Output
| metric     | page_views | avg_rating | purchases |
|------------|------------|------------|-----------|
| page_views | 1.0        | -0.8912    | 0.9934    |
| avg_rating | -0.8912    | 1.0        | -0.8736   |
| purchases  | 0.9934     | -0.8736    | 1.0       |

---

## Bonus: Sparse Representation for Large Matrices
```python
# For millions of products a dense pivot is impractical.
# Keep the data in sparse (long) format instead.

sparse_matrix = symmetric.select(
    F.col("product_a").alias("row_product"),
    F.col("product_b").alias("col_product"),
    F.col("co_occurrence").alias("value"),
).orderBy("row_product", "col_product")

sparse_matrix.show()
```
| row_product | col_product | value |
|-------------|-------------|-------|
| Keyboard    | Laptop      | 1     |
| Keyboard    | Monitor     | 2     |
| Keyboard    | Mouse       | 2     |
| Laptop      | Keyboard    | 1     |
| Laptop      | Monitor     | 1     |
| Laptop      | Mouse       | 3     |
| Monitor     | Keyboard    | 2     |
| Monitor     | Laptop      | 1     |
| Monitor     | Mouse       | 2     |
| Mouse       | Keyboard    | 2     |
| Mouse       | Laptop      | 3     |
| Mouse       | Monitor     | 2     |

---

## Key Interview Talking Points
1. **Self-join with inequality** -- Using `a.product < b.product` eliminates duplicate pairs and self-pairs in a single pass, halving the output before aggregation.
2. **Mirroring for symmetry** -- `unionByName` of the swapped pair DataFrame is the standard way to build a symmetric adjacency/co-occurrence matrix.
3. **pivot cost** -- `pivot` triggers a wide transformation. For high-cardinality columns, pass the explicit list of values to avoid an extra aggregation pass: `.pivot("col", ["val1", "val2", ...])`.
4. **Dense vs. sparse** -- A pivoted matrix is fine for tens to hundreds of products. Beyond that, store the sparse (row, col, value) representation and use it directly in downstream ML.
5. **crosstab** -- A convenience method equivalent to `groupBy + pivot + count`. Useful in EDA but limited to count aggregation.
6. **VectorAssembler + Correlation** -- The MLlib path for computing Pearson or Spearman correlation. The result is a local DenseMatrix, not a DataFrame.
7. **countDistinct vs. count** -- Use `countDistinct` when a user buying the same product multiple times should count as one co-occurrence. Use `count` if frequency matters.
