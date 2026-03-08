# PySpark Implementation: Group Sold Products by Date

## Problem Statement

Given an `Activities` table with `sell_date` and `product`, find for each date the **number of distinct products** sold and their **names concatenated** in lexicographic order. This is **LeetCode 1484 — Group Sold Products By The Date**.

### Sample Data

```
sell_date    product
2025-01-01   Laptop
2025-01-01   Phone
2025-01-01   Laptop
2025-01-02   Phone
2025-01-02   Tablet
2025-01-02   Phone
2025-01-02   Laptop
```

### Expected Output

| sell_date  | num_sold | products             |
|------------|----------|----------------------|
| 2025-01-01 | 2        | Laptop,Phone         |
| 2025-01-02 | 3        | Laptop,Phone,Tablet  |

---

## Method 1: collect_set + sort_array + concat_ws (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, collect_set, sort_array, concat_ws,
    size, countDistinct
)

spark = SparkSession.builder.appName("GroupProducts").getOrCreate()

data = [
    ("2025-01-01", "Laptop"),
    ("2025-01-01", "Phone"),
    ("2025-01-01", "Laptop"),
    ("2025-01-02", "Phone"),
    ("2025-01-02", "Tablet"),
    ("2025-01-02", "Phone"),
    ("2025-01-02", "Laptop")
]

columns = ["sell_date", "product"]
df = spark.createDataFrame(data, columns)

result = df.groupBy("sell_date") \
    .agg(
        countDistinct("product").alias("num_sold"),
        concat_ws(",", sort_array(collect_set("product"))).alias("products")
    ).orderBy("sell_date")

result.show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Group by sell_date
- Groups all transactions for the same date together.

#### Step 2: collect_set("product")
- **What happens:** Collects unique products into an array (set = deduplicated).
- 2025-01-01 → ["Laptop", "Phone"]
- 2025-01-02 → ["Phone", "Tablet", "Laptop"]

#### Step 3: sort_array()
- **What happens:** Sorts the array lexicographically.
- 2025-01-02 → ["Laptop", "Phone", "Tablet"]

#### Step 4: concat_ws(",", ...)
- **What happens:** Joins array elements with comma separator.
- 2025-01-02 → "Laptop,Phone,Tablet"

#### Step 5: countDistinct for num_sold
- Alternative: `size(collect_set("product"))` gives the same result.

---

## Method 2: Using size() Instead of countDistinct

```python
from pyspark.sql.functions import collect_set, sort_array, concat_ws, size

result = df.groupBy("sell_date") \
    .agg(
        collect_set("product").alias("product_set")
    ).withColumn("num_sold", size("product_set")) \
    .withColumn("products", concat_ws(",", sort_array("product_set"))) \
    .drop("product_set") \
    .orderBy("sell_date")

result.show(truncate=False)
```

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("activities")

result = spark.sql("""
    SELECT
        sell_date,
        COUNT(DISTINCT product) AS num_sold,
        CONCAT_WS(',', SORT_ARRAY(COLLECT_SET(product))) AS products
    FROM activities
    GROUP BY sell_date
    ORDER BY sell_date
""")

result.show(truncate=False)
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| Single product per date | num_sold = 1, products = just that name | Works correctly |
| All same product on a date | collect_set deduplicates → size 1 | Correct behavior |
| NULL product | collect_set ignores NULLs | Correct behavior |
| Many distinct products | Large concatenated string | May need truncation for display |

## Key Interview Talking Points

1. **collect_set vs. collect_list:**
   - `collect_set` → deduplicated (like DISTINCT). Returns unique values.
   - `collect_list` → keeps all values including duplicates.

2. **sort_array for deterministic output:**
   - `collect_set` does NOT guarantee order. `sort_array` ensures lexicographic ordering.

3. **GROUP_CONCAT equivalent:**
   - MySQL: `GROUP_CONCAT(DISTINCT product ORDER BY product)`
   - PySpark: `concat_ws(",", sort_array(collect_set("product")))`
   - The PySpark version is more explicit but achieves the same result.

4. **Performance at scale:**
   - `collect_set` brings all distinct values to a single executor per group. If one group has millions of unique products, this can cause OOM.
   - For very large groups, consider approximate methods or limiting the set size.

5. **Follow-up: "What if you need top 5 products per date?"**
   - Use `slice(sort_array(collect_set("product")), 1, 5)` to limit the array.
