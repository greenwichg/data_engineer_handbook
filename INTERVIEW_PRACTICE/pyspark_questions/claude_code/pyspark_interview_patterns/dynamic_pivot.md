# PySpark Implementation: Dynamic Pivot with Unknown Column Values

## Problem Statement
Pivot a sales table so that each distinct product becomes its own column and each region becomes a row, with aggregated sales amounts as cell values. The twist: the list of products is NOT known at compile time and must be discovered dynamically from the data. Handle the case where cardinality is large and pivoting becomes expensive.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as _sum, coalesce, lit

spark = SparkSession.builder.appName("DynamicPivot").getOrCreate()

data = [
    ("East",  "Widget",  100),
    ("East",  "Gadget",  200),
    ("East",  "Widget",  150),
    ("West",  "Gadget",  300),
    ("West",  "Doohickey", 50),
    ("North", "Widget",  400),
    ("North", "Gadget",  100),
    ("North", "Doohickey", 75),
    ("West",  "Widget",  250),
    ("East",  "Doohickey", 60),
]

df = spark.createDataFrame(data, ["region", "product", "amount"])
df.show()
```

| region | product   | amount |
|--------|-----------|--------|
| East   | Widget    | 100    |
| East   | Gadget    | 200    |
| East   | Widget    | 150    |
| West   | Gadget    | 300    |
| West   | Doohickey | 50     |
| North  | Widget    | 400    |
| North  | Gadget    | 100    |
| North  | Doohickey | 75     |
| West   | Widget    | 250    |
| East   | Doohickey | 60     |

### Expected Output

| region | Doohickey | Gadget | Widget |
|--------|-----------|--------|--------|
| East   | 60        | 200    | 250    |
| North  | 75        | 100    | 400    |
| West   | 50        | 300    | 250    |

---

## Method 1: Collect Distinct Values Then Pivot (Recommended)

```python
# Step 1: Collect distinct product values from the data
product_list = [row.product for row in df.select("product").distinct().collect()]
product_list.sort()  # optional: deterministic column order

# Step 2: Pivot using the explicit list to avoid full scan
pivoted = (
    df.groupBy("region")
      .pivot("product", product_list)
      .agg(_sum("amount"))
)

# Step 3: Replace nulls with 0 for clean output
pivoted = pivoted.fillna(0)
pivoted.orderBy("region").show()
```

### Step-by-Step Explanation

**After Step 1 -- Collect distinct products:**
```
product_list = ['Doohickey', 'Gadget', 'Widget']
```
This is a small collect() to the driver. It avoids Spark scanning the entire dataset twice (once to discover values, once to pivot).

**After Step 2 -- Pivot with explicit values:**

| region | Doohickey | Gadget | Widget |
|--------|-----------|--------|--------|
| East   | 60        | 200    | 250    |
| West   | 50        | 300    | 250    |
| North  | 75        | 100    | 400    |

When you pass the values list to `pivot()`, Spark generates a fixed execution plan rather than a two-phase plan that first discovers values. This is critical for performance.

**After Step 3 -- Fill nulls:**

Any region-product combination with no sales gets 0 instead of null.

---

## Method 2: Pivot Without Explicit Values (Simpler but Slower)

```python
# Let Spark discover pivot values automatically (triggers extra scan)
pivoted_auto = (
    df.groupBy("region")
      .pivot("product")
      .agg(_sum("amount"))
      .fillna(0)
)

pivoted_auto.orderBy("region").show()
```

This produces the same output but Spark internally runs an extra aggregation job to find the distinct product values. For small datasets this is acceptable; for large ones it doubles the work.

---

## Method 3: Manual Pivot Using Conditional Aggregation (High Cardinality Safe)

```python
from pyspark.sql.functions import when

# Collect distinct values
products = [row.product for row in df.select("product").distinct().collect()]
products.sort()

# Build aggregation expressions manually
agg_exprs = [
    _sum(when(col("product") == p, col("amount")).otherwise(0)).alias(p)
    for p in products
]

manual_pivot = df.groupBy("region").agg(*agg_exprs)
manual_pivot.orderBy("region").show()
```

This approach avoids the internal pivot mechanism entirely. For very high cardinality columns (thousands of distinct values), Spark's pivot can generate enormous physical plans. Conditional aggregation gives you full control and can be combined with column pruning if you only need a subset of products.

---

## Key Interview Talking Points

1. **Always pass explicit values to `pivot()`** -- without them Spark performs an additional aggregation job to discover distinct values, effectively doubling the cost.

2. **`collect()` on distinct values is safe** when cardinality is manageable (hundreds to low thousands). The small driver-side list is far cheaper than letting Spark resolve it internally across the full dataset.

3. **High cardinality pivots are dangerous** -- pivoting on a column with 10,000+ distinct values creates 10,000+ columns. Consider filtering to top-N values or using conditional aggregation with only the columns you need.

4. **Pivot generates wide DataFrames** -- downstream operations on very wide DataFrames (thousands of columns) cause large physical plans and can OOM the driver during plan compilation. Monitor `spark.sql.pivotMaxValues` (default 10,000) as a safety guard.

5. **`fillna(0)` vs `coalesce(col, lit(0))`** -- `fillna` is syntactic sugar applied to all columns. Use `coalesce` when you need column-specific defaults.

6. **Deterministic column order** -- sorting the product list before pivoting ensures consistent schema across runs, which matters for downstream consumers and schema evolution in production pipelines.

7. **Unpivot is the inverse** -- in Spark 3.4+ use `unpivot()` or `stack()` SQL function to reverse a pivot. Knowing both directions is a common follow-up question.
