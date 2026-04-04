# PySpark Implementation: Cross Join Combinations

## Problem Statement

Cross joins (Cartesian products) generate all possible combinations of rows from two DataFrames. While they should be used carefully due to their O(n*m) output size, they are essential for generating complete dimension combinations (e.g., all product-store pairs), filling date gaps, creating comparison matrices, and building lookup scaffolds. This is a common interview topic that tests your understanding of when cross joins are appropriate and how to use them efficiently.

Given dimension tables for products, stores, and dates, generate all combinations and identify missing sales records.

### Sample Data

**Products:**
```
+----------+-------------+
|product_id|product_name  |
+----------+-------------+
| P01      | Widget A     |
| P02      | Widget B     |
| P03      | Widget C     |
+----------+-------------+
```

**Stores:**
```
+--------+-----------+
|store_id|store_name  |
+--------+-----------+
| S1     | Downtown   |
| S2     | Mall       |
+--------+-----------+
```

**Actual Sales:**
```
+----------+--------+----------+--------+
|product_id|store_id| sale_date| revenue|
+----------+--------+----------+--------+
| P01      | S1     |2024-01-01| 100    |
| P02      | S1     |2024-01-01| 200    |
| P01      | S2     |2024-01-02| 150    |
+----------+--------+----------+--------+
```

### Expected Output

**Complete scaffold with missing combinations filled as zero:**

| product_id | store_id | sale_date  | revenue |
|------------|----------|------------|---------|
| P01        | S1       | 2024-01-01 | 100     |
| P02        | S1       | 2024-01-01 | 200     |
| P03        | S1       | 2024-01-01 | 0       |
| P01        | S2       | 2024-01-01 | 0       |
| P02        | S2       | 2024-01-01 | 0       |
| P03        | S2       | 2024-01-01 | 0       |
| ...        | ...      | ...        | ...     |

---

## Method 1: Generate All Product-Store-Date Combinations

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("CrossJoinCombinations") \
    .master("local[*]") \
    .getOrCreate()

# Dimension tables
products = spark.createDataFrame([
    ("P01", "Widget A"),
    ("P02", "Widget B"),
    ("P03", "Widget C"),
], ["product_id", "product_name"])

stores = spark.createDataFrame([
    ("S1", "Downtown"),
    ("S2", "Mall"),
], ["store_id", "store_name"])

# Generate date dimension
dates = spark.range(0, 3).select(
    F.date_add(F.lit("2024-01-01"), F.col("id").cast("int")).alias("sale_date")
)

# Actual sales data
sales_data = [
    ("P01", "S1", "2024-01-01", 100),
    ("P02", "S1", "2024-01-01", 200),
    ("P01", "S2", "2024-01-02", 150),
    ("P03", "S1", "2024-01-02",  75),
    ("P02", "S2", "2024-01-03", 180),
]
sales = spark.createDataFrame(sales_data,
    ["product_id", "store_id", "sale_date", "revenue"])
sales = sales.withColumn("sale_date", F.to_date("sale_date"))

# ============================================================
# Cross join to create the complete scaffold
# ============================================================

# All product-store-date combinations
scaffold = products.select("product_id") \
    .crossJoin(stores.select("store_id")) \
    .crossJoin(dates)

print(f"=== Scaffold: {scaffold.count()} rows " +
      f"({products.count()} products x {stores.count()} stores x {dates.count()} dates) ===")
scaffold.orderBy("product_id", "store_id", "sale_date").show()

# Left join actual sales onto scaffold
complete = scaffold.join(
    sales,
    ["product_id", "store_id", "sale_date"],
    "left"
).withColumn("revenue", F.coalesce("revenue", F.lit(0)))

print("=== Complete Sales Grid (with zeros for missing) ===")
complete.orderBy("sale_date", "store_id", "product_id").show(20)

# Identify missing combinations (no sales)
missing = complete.filter(F.col("revenue") == 0)
print(f"=== Missing Combinations: {missing.count()} rows ===")
missing.show()
```

## Method 2: Pairwise Comparisons Using Cross Join

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("PairwiseComparisons") \
    .master("local[*]") \
    .getOrCreate()

# Employee skills for skill gap analysis
employees = spark.createDataFrame([
    (1, "Alice",   ["Python", "SQL", "Spark"]),
    (2, "Bob",     ["Python", "Java"]),
    (3, "Carol",   ["SQL", "Spark", "Scala"]),
    (4, "Dave",    ["Python", "SQL"]),
], ["emp_id", "emp_name", "skills"])

# ============================================================
# Cross join to compare all pairs of employees
# ============================================================

# Self cross join (exclude self-pairs and duplicate pairs)
pairs = employees.alias("a").crossJoin(employees.alias("b")) \
    .filter(F.col("a.emp_id") < F.col("b.emp_id"))

# Compute skill overlap between each pair
pairs_with_overlap = pairs.select(
    F.col("a.emp_name").alias("employee_1"),
    F.col("b.emp_name").alias("employee_2"),
    F.col("a.skills").alias("skills_1"),
    F.col("b.skills").alias("skills_2"),
    F.array_intersect(F.col("a.skills"), F.col("b.skills")).alias("common_skills"),
    F.array_union(F.col("a.skills"), F.col("b.skills")).alias("combined_skills"),
    F.array_except(F.col("a.skills"), F.col("b.skills")).alias("unique_to_1"),
    F.array_except(F.col("b.skills"), F.col("a.skills")).alias("unique_to_2"),
)

pairs_with_overlap = pairs_with_overlap.withColumn("similarity",
    F.round(
        F.size("common_skills") / F.size("combined_skills"), 2
    )
)

print("=== Pairwise Skill Comparison ===")
pairs_with_overlap.select(
    "employee_1", "employee_2", "common_skills",
    "unique_to_1", "unique_to_2", "similarity"
).show(truncate=False)

# ============================================================
# Price comparison matrix using cross join
# ============================================================

products = spark.createDataFrame([
    ("Laptop",  999),
    ("Tablet",  499),
    ("Phone",   799),
    ("Watch",   299),
], ["product", "price"])

# All pairs for price difference matrix
price_matrix = products.alias("a").crossJoin(products.alias("b")) \
    .select(
        F.col("a.product").alias("product_a"),
        F.col("b.product").alias("product_b"),
        (F.col("a.price") - F.col("b.price")).alias("price_diff"),
        F.round(F.col("a.price") / F.col("b.price"), 2).alias("price_ratio"),
    )

print("=== Price Comparison Matrix ===")
price_matrix.show(16)

# Pivot to create a true matrix format
matrix = price_matrix.groupBy("product_a").pivot("product_b") \
    .agg(F.first("price_diff"))

print("=== Price Difference Matrix (pivoted) ===")
matrix.show()
```

## Method 3: Spark SQL Cross Joins

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("CrossJoinSQL") \
    .master("local[*]") \
    .getOrCreate()

# Create dimension tables
spark.createDataFrame([
    ("P01", "Widget A"), ("P02", "Widget B"), ("P03", "Widget C"),
], ["product_id", "product_name"]).createOrReplaceTempView("products")

spark.createDataFrame([
    ("S1", "Downtown"), ("S2", "Mall"),
], ["store_id", "store_name"]).createOrReplaceTempView("stores")

sales_data = [
    ("P01", "S1", "2024-01-01", 100),
    ("P02", "S1", "2024-01-01", 200),
    ("P01", "S2", "2024-01-02", 150),
]
spark.createDataFrame(sales_data,
    ["product_id", "store_id", "sale_date", "revenue"]) \
    .createOrReplaceTempView("sales")

# Cross join in SQL (explicit CROSS JOIN syntax)
spark.sql("""
    SELECT
        p.product_id,
        p.product_name,
        s.store_id,
        s.store_name,
        COALESCE(sl.revenue, 0) AS revenue,
        CASE WHEN sl.revenue IS NULL THEN 'missing' ELSE 'present' END AS status
    FROM products p
    CROSS JOIN stores s
    LEFT JOIN sales sl
        ON p.product_id = sl.product_id
        AND s.store_id = sl.store_id
        AND sl.sale_date = '2024-01-01'
    ORDER BY p.product_id, s.store_id
""").show()

# Generate all date-product combinations and find gaps
spark.sql("""
    WITH dates AS (
        SELECT date_add('2024-01-01', id) AS sale_date
        FROM range(3)
    ),
    scaffold AS (
        SELECT p.product_id, s.store_id, d.sale_date
        FROM products p
        CROSS JOIN stores s
        CROSS JOIN dates d
    ),
    filled AS (
        SELECT
            sc.*,
            COALESCE(sl.revenue, 0) AS revenue
        FROM scaffold sc
        LEFT JOIN sales sl
            ON sc.product_id = sl.product_id
            AND sc.store_id = sl.store_id
            AND sc.sale_date = sl.sale_date
    )
    SELECT
        sale_date,
        store_id,
        COUNT(*) AS total_products,
        SUM(CASE WHEN revenue > 0 THEN 1 ELSE 0 END) AS products_with_sales,
        SUM(CASE WHEN revenue = 0 THEN 1 ELSE 0 END) AS products_without_sales,
        SUM(revenue) AS total_revenue
    FROM filled
    GROUP BY sale_date, store_id
    ORDER BY sale_date, store_id
""").show()
```

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Cross join** | Cartesian product: every row in A paired with every row in B |
| **Output size** | n * m rows (can be very large; use with small dimensions) |
| **Scaffold pattern** | Cross join dimensions, then left join facts to fill gaps |
| **Self cross join** | Compare all pairs; use `a.id < b.id` to avoid duplicates |
| **Spark config** | `spark.sql.crossJoin.enabled` must be true (default in Spark 3.x) |
| **Broadcast hint** | Use `F.broadcast(small_df)` to optimize cross joins with small tables |

## Interview Tips

1. **When to use cross joins**: Only appropriate when both sides are small (dimension tables) or when you genuinely need all combinations. Never cross join two fact tables.

2. **The scaffold pattern**: Cross join dimensions to create a complete grid, then left join facts. This is the standard approach for identifying missing data, filling gaps, and creating dense reports.

3. **Performance safeguard**: In Spark 2.x, cross joins required explicit `spark.sql.crossJoin.enabled=true`. In Spark 3.x, they work by default but still generate a warning if unintentional (e.g., missing join condition).

4. **Broadcast optimization**: When one side is small (< 10MB), broadcast it to avoid shuffle: `small_df.crossJoin(F.broadcast(other_small_df))`.

5. **Avoid accidental cross joins**: A common bug is writing a join with no condition or a condition that is always true. This creates an unintended Cartesian product with potentially billions of rows. Spark will warn you.

6. **Self-join for pairs**: When computing pairwise metrics, always filter to `a.id < b.id` (or `!=` for directed comparisons) to avoid duplicate pairs and self-comparisons.
