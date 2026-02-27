# PySpark Implementation: ROLLUP, CUBE, and GROUPING SETS

## Problem Statement

Given a dataset of product sales across regions and categories, generate **multi-level aggregation summaries** using ROLLUP, CUBE, and GROUPING SETS. These are essential data warehousing operations for creating summary tables with subtotals and grand totals — frequently asked in data engineering interviews at companies with reporting and BI requirements.

### Sample Data

```
region    category     product    sales
East      Electronics  Laptop     5000
East      Electronics  Phone      3000
East      Clothing     Shirt      1500
East      Clothing     Pants      2000
West      Electronics  Laptop     4000
West      Electronics  Phone      3500
West      Clothing     Shirt      1800
West      Clothing     Pants      2200
```

---

## Method 1: ROLLUP — Hierarchical Subtotals

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, coalesce, lit, grouping, grouping_id

# Initialize Spark session
spark = SparkSession.builder.appName("RollupCubeGrouping").getOrCreate()

# Sample data
data = [
    ("East", "Electronics", "Laptop", 5000),
    ("East", "Electronics", "Phone", 3000),
    ("East", "Clothing", "Shirt", 1500),
    ("East", "Clothing", "Pants", 2000),
    ("West", "Electronics", "Laptop", 4000),
    ("West", "Electronics", "Phone", 3500),
    ("West", "Clothing", "Shirt", 1800),
    ("West", "Clothing", "Pants", 2200)
]

columns = ["region", "category", "product", "sales"]
df = spark.createDataFrame(data, columns)

# ROLLUP: Creates hierarchical subtotals (region → category → product)
rollup_df = df.rollup("region", "category", "product") \
    .agg(spark_sum("sales").alias("total_sales")) \
    .orderBy("region", "category", "product")

rollup_df.show(truncate=False)
```

### Step-by-Step Explanation

#### What ROLLUP Does
- `rollup("region", "category", "product")` generates aggregations at these levels:
  1. **(region, category, product)** — individual product totals
  2. **(region, category, null)** — category subtotals per region
  3. **(region, null, null)** — region subtotals
  4. **(null, null, null)** — grand total

- **Output (rollup_df):**

  | region | category    | product | total_sales |
  |--------|-------------|---------|-------------|
  | null   | null        | null    | 23000       |
  | East   | null        | null    | 11500       |
  | East   | Clothing    | null    | 3500        |
  | East   | Clothing    | Pants   | 2000        |
  | East   | Clothing    | Shirt   | 1500        |
  | East   | Electronics | null    | 8000        |
  | East   | Electronics | Laptop  | 5000        |
  | East   | Electronics | Phone   | 3000        |
  | West   | null        | null    | 11500       |
  | West   | Clothing    | null    | 4000        |
  | West   | Clothing    | Pants   | 2200        |
  | West   | Clothing    | Shirt   | 1800        |
  | West   | Electronics | null    | 7500        |
  | West   | Electronics | Laptop  | 4000        |
  | West   | Electronics | Phone   | 3500        |

  **Reading the output:**
  - `(null, null, null, 23000)` → Grand total of all sales
  - `(East, null, null, 11500)` → All sales in East region
  - `(East, Clothing, null, 3500)` → All Clothing sales in East
  - `(East, Clothing, Pants, 2000)` → Specific product-level detail

---

## Method 2: CUBE — All Possible Combinations

```python
# CUBE: Creates subtotals for ALL combinations of columns
cube_df = df.cube("region", "category") \
    .agg(spark_sum("sales").alias("total_sales")) \
    .orderBy("region", "category")

cube_df.show(truncate=False)
```

### What CUBE Does
- `cube("region", "category")` generates aggregations for **every combination**:
  1. **(region, category)** — each region-category pair
  2. **(region, null)** — each region total
  3. **(null, category)** — each category total (ROLLUP doesn't produce this!)
  4. **(null, null)** — grand total

- **Output (cube_df):**

  | region | category    | total_sales |
  |--------|-------------|-------------|
  | null   | null        | 23000       |
  | null   | Clothing    | 7500        |
  | null   | Electronics | 15500       |
  | East   | null        | 11500       |
  | East   | Clothing    | 3500        |
  | East   | Electronics | 8000        |
  | West   | null        | 11500       |
  | West   | Clothing    | 4000        |
  | West   | Electronics | 7500        |

### Key Difference: ROLLUP vs CUBE

| Feature | ROLLUP | CUBE |
|---------|--------|------|
| Subtotals for | Left-to-right hierarchy only | All possible combinations |
| For N columns | N+1 grouping levels | 2^N grouping levels |
| `(null, category)` | NOT included | Included |
| Use case | Hierarchical reports | Cross-tabulation reports |

For 3 columns (A, B, C):
- **ROLLUP** produces: (A,B,C), (A,B), (A), ()  → 4 levels
- **CUBE** produces: (A,B,C), (A,B), (A,C), (B,C), (A), (B), (C), () → 8 levels

---

## Method 3: GROUPING SETS — Custom Combinations

```python
# GROUPING SETS allows you to specify exactly which combinations you want
# PySpark doesn't have direct groupingSets API, use SQL instead

df.createOrReplaceTempView("sales")

grouping_sets_df = spark.sql("""
    SELECT region, category, SUM(sales) AS total_sales
    FROM sales
    GROUP BY GROUPING SETS (
        (region, category),
        (region),
        (category),
        ()
    )
    ORDER BY region, category
""")

grouping_sets_df.show(truncate=False)
```

- **Output:** Same as CUBE for 2 columns, but GROUPING SETS lets you pick exactly which combinations:

  | region | category    | total_sales |
  |--------|-------------|-------------|
  | null   | null        | 23000       |
  | null   | Clothing    | 7500        |
  | null   | Electronics | 15500       |
  | East   | null        | 11500       |
  | East   | Clothing    | 3500        |
  | East   | Electronics | 8000        |
  | West   | null        | 11500       |
  | West   | Clothing    | 4000        |
  | West   | Electronics | 7500        |

### Custom GROUPING SETS Example

```python
# Only want region totals and grand total (skip category-level)
custom_gs = spark.sql("""
    SELECT region, category, SUM(sales) AS total_sales
    FROM sales
    GROUP BY GROUPING SETS (
        (region, category),
        (region),
        ()
    )
    ORDER BY region, category
""")

custom_gs.show(truncate=False)
```

- This produces the same as ROLLUP(region, category) — ROLLUP is essentially a shorthand for a specific GROUPING SETS pattern.

---

## Method 4: Using grouping() and grouping_id() to Identify Subtotal Rows

```python
# grouping() returns 1 if the column is aggregated (null due to rollup), 0 otherwise
# This helps distinguish between "null = subtotal" and "null = actual null data"

rollup_labeled = df.rollup("region", "category") \
    .agg(
        spark_sum("sales").alias("total_sales"),
        grouping("region").alias("is_region_total"),
        grouping("category").alias("is_category_total"),
        grouping_id("region", "category").alias("gid")
    ) \
    .orderBy("region", "category")

rollup_labeled.show(truncate=False)
```

- **Output:**

  | region | category    | total_sales | is_region_total | is_category_total | gid |
  |--------|-------------|-------------|-----------------|-------------------|-----|
  | null   | null        | 23000       | 1               | 1                 | 3   |
  | East   | null        | 11500       | 0               | 1                 | 1   |
  | East   | Clothing    | 3500        | 0               | 0                 | 0   |
  | East   | Electronics | 8000        | 0               | 0                 | 0   |
  | West   | null        | 11500       | 0               | 1                 | 1   |
  | West   | Clothing    | 4000        | 0               | 0                 | 0   |
  | West   | Electronics | 7500        | 0               | 0                 | 0   |

### Understanding grouping_id

- `grouping_id` is a bitmask identifying which columns are aggregated:
  - `gid = 0` (binary 00): Both region and category are present → detail row
  - `gid = 1` (binary 01): category is aggregated → region subtotal
  - `gid = 3` (binary 11): Both aggregated → grand total

---

## Method 5: Adding Readable Labels for Subtotal Rows

```python
from pyspark.sql.functions import when

rollup_readable = df.rollup("region", "category") \
    .agg(spark_sum("sales").alias("total_sales")) \
    .withColumn("region", when(col("region").isNull(), lit("ALL REGIONS")).otherwise(col("region"))) \
    .withColumn("category", when(col("category").isNull(), lit("ALL CATEGORIES")).otherwise(col("category"))) \
    .orderBy("region", "category")

rollup_readable.show(truncate=False)
```

- **Output:**

  | region      | category        | total_sales |
  |-------------|-----------------|-------------|
  | ALL REGIONS | ALL CATEGORIES  | 23000       |
  | East        | ALL CATEGORIES  | 11500       |
  | East        | Clothing        | 3500        |
  | East        | Electronics     | 8000        |
  | West        | ALL CATEGORIES  | 11500       |
  | West        | Clothing        | 4000        |
  | West        | Electronics     | 7500        |

---

## Comparison Summary

| Feature | ROLLUP | CUBE | GROUPING SETS |
|---------|--------|------|---------------|
| Subtotal levels | Hierarchical (left-to-right) | All combinations | Custom selection |
| Groups for N cols | N + 1 | 2^N | User-defined |
| API | `df.rollup()` | `df.cube()` | SQL only in PySpark |
| Best for | Reports with hierarchy (country → state → city) | Cross-tabulation / pivot tables | Selective aggregation levels |

## Key Interview Talking Points

1. **When to use ROLLUP vs CUBE:**
   - ROLLUP for hierarchical data (geographic: country → state → city)
   - CUBE for cross-dimensional analysis (region x category x quarter)
   - GROUPING SETS for custom combinations when you don't need all levels

2. **Null ambiguity:** Subtotal rows have null values in aggregated columns. Use `grouping()` to distinguish subtotal nulls from actual null data.

3. **Performance:** ROLLUP generates fewer groupings than CUBE (N+1 vs 2^N). For 5 columns: ROLLUP = 6 groups, CUBE = 32 groups.

4. **Real-world use cases:**
   - Financial reporting (subtotals by department, division, company)
   - Retail analytics (sales by store, region, country)
   - BI dashboards with drill-down functionality
