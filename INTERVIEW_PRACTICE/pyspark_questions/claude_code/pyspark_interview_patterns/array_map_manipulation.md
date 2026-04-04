# PySpark Implementation: Array and Map Manipulation

## Problem Statement
Given an orders dataset where each order contains an array of product IDs and a map of product-to-quantity,
perform the following:
1. Find orders containing specific products using `array_contains` and set operations.
2. Compute total quantity per order by reducing the quantity map.
3. Use `transform()` to apply discounts to quantities and `aggregate()` to sum them.
4. Compare product lists across orders using `array_intersect`, `array_union`, `array_except`.
5. Demonstrate `explode` vs `posexplode` on the product arrays.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

spark = SparkSession.builder.appName("ArrayMapManipulation").getOrCreate()

data = [
    (1, "Alice", ["P101", "P102", "P103"], {"P101": 2, "P102": 1, "P103": 5}),
    (2, "Bob",   ["P102", "P104"],         {"P102": 3, "P104": 2}),
    (3, "Carol", ["P101", "P105", "P106"], {"P101": 1, "P105": 4, "P106": 1}),
    (4, "Dave",  ["P103", "P104", "P105"], {"P103": 6, "P104": 1, "P105": 2}),
]

schema = StructType([
    StructField("order_id", IntegerType()),
    StructField("customer", StringType()),
    StructField("product_ids", ArrayType(StringType())),
    StructField("product_qty", MapType(StringType(), IntegerType())),
])

orders = spark.createDataFrame(data, schema)
orders.show(truncate=False)
```

### Expected Output
Orders containing P101 or P104:

| order_id | customer | contains_P101 | contains_P104 |
|----------|----------|---------------|---------------|
| 1        | Alice    | true          | false         |
| 2        | Bob      | false         | true          |
| 3        | Carol    | true          | false         |
| 4        | Dave     | false         | true          |

Total quantity per order:

| order_id | customer | total_qty |
|----------|----------|-----------|
| 1        | Alice    | 8         |
| 2        | Bob      | 5         |
| 3        | Carol    | 6         |
| 4        | Dave     | 9         |

---

## Method 1: Built-in Array and Map Functions (Recommended)
```python
# --- Part 1: array_contains to check membership ---
result1 = orders.select(
    "order_id", "customer",
    array_contains("product_ids", "P101").alias("contains_P101"),
    array_contains("product_ids", "P104").alias("contains_P104"),
)
result1.show()

# --- Part 2: Set operations across orders ---
# Compare order 1 and order 4 product lists
order1_products = orders.filter(col("order_id") == 1).select("product_ids").first()[0]
order4_products = orders.filter(col("order_id") == 4).select("product_ids").first()[0]

set_ops = orders.filter(col("order_id").isin(1, 4)).select(
    "order_id",
    "product_ids",
    array_intersect("product_ids", array(lit("P101"), lit("P103"))).alias("intersect_with_target"),
    array_union("product_ids", array(lit("P999"))).alias("union_with_new"),
    array_except("product_ids", array(lit("P101"), lit("P102"))).alias("except_common"),
)
set_ops.show(truncate=False)

# --- Part 3: Total quantity using map_values + aggregate ---
result3 = orders.select(
    "order_id", "customer",
    aggregate(
        map_values("product_qty"),
        lit(0),
        lambda acc, x: acc + x
    ).alias("total_qty")
)
result3.show()

# --- Part 4: transform() to apply 10% discount to each quantity ---
result4 = orders.select(
    "order_id",
    map_values("product_qty").alias("quantities"),
    transform(
        map_values("product_qty"),
        lambda x: (x * 0.9).cast("double")
    ).alias("discounted_quantities"),
)
result4.show(truncate=False)

# --- Part 5: map_keys, map_values, map_from_entries ---
result5 = orders.select(
    "order_id",
    map_keys("product_qty").alias("products"),
    map_values("product_qty").alias("quantities"),
)
result5.show(truncate=False)

# --- Part 6: explode vs posexplode ---
exploded = orders.select("order_id", explode("product_ids").alias("product"))
exploded.show()

pos_exploded = orders.select("order_id", posexplode("product_ids").alias("position", "product"))
pos_exploded.show()
```

### Step-by-Step Explanation

**Step 1 -- array_contains checks:** Each row is evaluated independently. `array_contains` returns a boolean
column by scanning the array for the literal value.

**Step 2 -- Set operations intermediate result:**

| order_id | product_ids          | intersect_with_target | union_with_new              | except_common     |
|----------|----------------------|-----------------------|-----------------------------|-------------------|
| 1        | [P101, P102, P103]   | [P101, P103]          | [P101, P102, P103, P999]    | [P103]            |
| 4        | [P103, P104, P105]   | [P103]                | [P103, P104, P105, P999]    | [P103, P104, P105]|

**Step 3 -- aggregate() reduces** `map_values` (an array of ints) to a single sum using a lambda accumulator.

**Step 6 -- explode vs posexplode:**
- `explode` produces one row per element with the element value.
- `posexplode` produces one row per element with both the positional index (0-based) and the element value.

| order_id | position | product |
|----------|----------|---------|
| 1        | 0        | P101    |
| 1        | 1        | P102    |
| 1        | 2        | P103    |
| 2        | 0        | P102    |
| ...      | ...      | ...     |

---

## Method 2: Explode and Re-aggregate Approach
```python
# Explode the map into rows, then aggregate with groupBy
exploded_map = orders.select(
    "order_id", "customer",
    explode("product_qty").alias("product", "quantity")
)

# Total quantity per order
total_qty = exploded_map.groupBy("order_id", "customer") \
    .agg(sum("quantity").alias("total_qty"))
total_qty.show()

# Check for specific products by filtering exploded rows
has_product = exploded_map.filter(col("product").isin("P101", "P104")) \
    .select("order_id", "product").distinct()
has_product.show()

# Reconstruct array after filtering using collect_list
filtered_back = exploded_map.filter(col("quantity") > 1) \
    .groupBy("order_id") \
    .agg(collect_list("product").alias("high_qty_products"))
filtered_back.show(truncate=False)
```

---

## Key Interview Talking Points
1. **`array_contains` is O(n)** per row -- for large arrays consider exploding once and joining instead.
2. **`transform` and `aggregate`** are Spark 2.4+ higher-order functions that avoid costly explode-reaggregate patterns.
3. **`explode` produces NULLs** for empty arrays unless you use `explode_outer`; same for maps.
4. **`posexplode`** is essential when element ordering matters (e.g., maintaining sequence in ML feature arrays).
5. **Map functions** like `map_from_entries(collect_list(struct(...)))` are the idiomatic way to build maps from grouped data.
6. **Performance:** Higher-order functions (`transform`, `aggregate`, `filter`) operate within the Catalyst optimizer and avoid the shuffle that explode + groupBy introduces.
7. **Null handling:** `array_contains` returns `null` if the array column itself is null, not `false` -- wrap with `coalesce(..., lit(false))` in production.
8. **`array_union` deduplicates** elements, behaving like a set union, while `concat` of arrays preserves duplicates.
