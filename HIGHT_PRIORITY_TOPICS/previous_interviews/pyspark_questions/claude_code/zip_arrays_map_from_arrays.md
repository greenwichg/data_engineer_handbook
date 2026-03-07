# PySpark Implementation: Zip Arrays and Map From Arrays

## Problem Statement

In many real-world data pipelines, you encounter datasets where related information is stored in parallel arrays (e.g., product IDs and their corresponding quantities in a single order row, or skill names and proficiency levels for an employee). A common interview question asks you to combine these parallel arrays into structured formats -- either an array of structs or a map (dictionary). This tests your knowledge of PySpark's `arrays_zip`, `map_from_arrays`, and related array functions.

**Scenario:** You have an e-commerce orders dataset where each row contains an order with parallel arrays for product names, quantities, and unit prices. You need to combine these into structured formats for downstream analytics.

### Sample Data

```
order_id | products                      | quantities | unit_prices
---------|-------------------------------|------------|------------------
1001     | [Laptop, Mouse, Keyboard]     | [1, 2, 1]  | [999.99, 29.99, 79.99]
1002     | [Monitor, Cable]              | [1, 3]     | [349.99, 12.99]
1003     | [Headset, Webcam, Mic, Stand] | [1, 1, 1, 2] | [89.99, 59.99, 149.99, 34.99]
1004     | [Tablet]                      | [2]        | [499.99]
```

### Expected Output

**After arrays_zip (array of structs):**

| order_id | line_items |
|----------|-----------|
| 1001 | [{Laptop, 1, 999.99}, {Mouse, 2, 29.99}, {Keyboard, 1, 79.99}] |
| 1002 | [{Monitor, 1, 349.99}, {Cable, 3, 12.99}] |
| 1003 | [{Headset, 1, 89.99}, {Webcam, 1, 59.99}, {Mic, 1, 149.99}, {Stand, 2, 34.99}] |
| 1004 | [{Tablet, 2, 499.99}] |

**After map_from_arrays (product -> price map):**

| order_id | product_price_map |
|----------|-------------------|
| 1001 | {Laptop: 999.99, Mouse: 29.99, Keyboard: 79.99} |
| 1002 | {Monitor: 349.99, Cable: 12.99} |
| 1003 | {Headset: 89.99, Webcam: 59.99, Mic: 149.99, Stand: 34.99} |
| 1004 | {Tablet: 499.99} |

---

## Method 1: Using arrays_zip to Combine Parallel Arrays into Structs

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    arrays_zip, col, explode, map_from_arrays,
    array, struct, transform, element_at, size
)
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    ArrayType, DoubleType
)

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("ZipArraysMapFromArrays") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    (1001, ["Laptop", "Mouse", "Keyboard"], [1, 2, 1], [999.99, 29.99, 79.99]),
    (1002, ["Monitor", "Cable"], [1, 3], [349.99, 12.99]),
    (1003, ["Headset", "Webcam", "Mic", "Stand"], [1, 1, 1, 2], [89.99, 59.99, 149.99, 34.99]),
    (1004, ["Tablet"], [2], [499.99]),
]

schema = StructType([
    StructField("order_id", IntegerType(), False),
    StructField("products", ArrayType(StringType()), False),
    StructField("quantities", ArrayType(IntegerType()), False),
    StructField("unit_prices", ArrayType(DoubleType()), False),
])

df = spark.createDataFrame(data, schema)

print("=== Original Data ===")
df.show(truncate=False)

# --- arrays_zip: combines parallel arrays element-wise into an array of structs ---
zipped_df = df.select(
    "order_id",
    arrays_zip("products", "quantities", "unit_prices").alias("line_items")
)

print("=== After arrays_zip ===")
zipped_df.show(truncate=False)
zipped_df.printSchema()

# Explode the zipped array to get individual line items
exploded_df = zipped_df.select(
    "order_id",
    explode("line_items").alias("item")
).select(
    "order_id",
    col("item.products").alias("product"),
    col("item.quantities").alias("quantity"),
    col("item.unit_prices").alias("unit_price")
)

print("=== Exploded Line Items ===")
exploded_df.show(truncate=False)

# Compute line totals
line_totals_df = exploded_df.withColumn(
    "line_total", col("quantity") * col("unit_price")
)

print("=== Line Totals ===")
line_totals_df.show(truncate=False)
```

## Method 2: Using map_from_arrays to Create Key-Value Maps

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    map_from_arrays, col, explode, map_keys, map_values,
    map_entries, element_at, transform, arrays_zip, aggregate
)
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    ArrayType, DoubleType
)

spark = SparkSession.builder \
    .appName("MapFromArrays") \
    .master("local[*]") \
    .getOrCreate()

data = [
    (1001, ["Laptop", "Mouse", "Keyboard"], [1, 2, 1], [999.99, 29.99, 79.99]),
    (1002, ["Monitor", "Cable"], [1, 3], [349.99, 12.99]),
    (1003, ["Headset", "Webcam", "Mic", "Stand"], [1, 1, 1, 2], [89.99, 59.99, 149.99, 34.99]),
    (1004, ["Tablet"], [2], [499.99]),
]

schema = StructType([
    StructField("order_id", IntegerType(), False),
    StructField("products", ArrayType(StringType()), False),
    StructField("quantities", ArrayType(IntegerType()), False),
    StructField("unit_prices", ArrayType(DoubleType()), False),
])

df = spark.createDataFrame(data, schema)

# --- map_from_arrays: creates a map from a key array and a value array ---
# Product -> Price map
product_price_map_df = df.select(
    "order_id",
    map_from_arrays("products", "unit_prices").alias("product_price_map")
)

print("=== Product -> Price Map ===")
product_price_map_df.show(truncate=False)

# Product -> Quantity map
product_qty_map_df = df.select(
    "order_id",
    map_from_arrays("products", "quantities").alias("product_qty_map")
)

print("=== Product -> Quantity Map ===")
product_qty_map_df.show(truncate=False)

# Access specific keys from the map
print("=== Lookup Specific Product Price ===")
product_price_map_df.select(
    "order_id",
    element_at("product_price_map", "Laptop").alias("laptop_price"),
    element_at("product_price_map", "Monitor").alias("monitor_price")
).show(truncate=False)

# Explode map into key-value rows
print("=== Exploded Map Entries ===")
product_price_map_df.select(
    "order_id",
    explode("product_price_map").alias("product", "price")
).show(truncate=False)

# Extract map keys and values back to arrays
print("=== Map Keys and Values ===")
product_price_map_df.select(
    "order_id",
    map_keys("product_price_map").alias("product_names"),
    map_values("product_price_map").alias("prices")
).show(truncate=False)
```

## Method 3: Using transform with arrays_zip for Computed Structs

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    arrays_zip, col, transform, struct, expr, aggregate,
    map_from_entries, array, size
)
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    ArrayType, DoubleType
)

spark = SparkSession.builder \
    .appName("TransformWithZip") \
    .master("local[*]") \
    .getOrCreate()

data = [
    (1001, ["Laptop", "Mouse", "Keyboard"], [1, 2, 1], [999.99, 29.99, 79.99]),
    (1002, ["Monitor", "Cable"], [1, 3], [349.99, 12.99]),
    (1003, ["Headset", "Webcam", "Mic", "Stand"], [1, 1, 1, 2], [89.99, 59.99, 149.99, 34.99]),
    (1004, ["Tablet"], [2], [499.99]),
]

schema = StructType([
    StructField("order_id", IntegerType(), False),
    StructField("products", ArrayType(StringType()), False),
    StructField("quantities", ArrayType(IntegerType()), False),
    StructField("unit_prices", ArrayType(DoubleType()), False),
])

df = spark.createDataFrame(data, schema)

# Step 1: Zip arrays and then transform to add computed fields
enriched_df = df.withColumn(
    "zipped", arrays_zip("products", "quantities", "unit_prices")
).withColumn(
    "line_items_with_totals",
    transform(
        "zipped",
        lambda x: struct(
            x["products"].alias("product"),
            x["quantities"].alias("qty"),
            x["unit_prices"].alias("price"),
            (x["quantities"] * x["unit_prices"]).alias("line_total")
        )
    )
).drop("zipped")

print("=== Enriched Line Items with Computed Totals ===")
enriched_df.select("order_id", "line_items_with_totals").show(truncate=False)

# Step 2: Use aggregate to compute order total from the array
order_totals_df = enriched_df.withColumn(
    "order_total",
    aggregate(
        "line_items_with_totals",
        expr("CAST(0.0 AS DOUBLE)"),
        lambda acc, x: acc + x["line_total"]
    )
)

print("=== Order Totals ===")
order_totals_df.select("order_id", "order_total").show(truncate=False)

# Step 3: Build a map from entries using map_from_entries
# Create array of (product, line_total) structs and convert to map
product_total_map_df = enriched_df.withColumn(
    "product_total_map",
    map_from_entries(
        transform(
            "line_items_with_totals",
            lambda x: struct(
                x["product"].alias("key"),
                x["line_total"].alias("value")
            )
        )
    )
)

print("=== Product -> Line Total Map ===")
product_total_map_df.select("order_id", "product_total_map").show(truncate=False)

# Step 4: Number of items per order using size
item_counts_df = df.select(
    "order_id",
    size("products").alias("num_distinct_products"),
    aggregate(
        "quantities",
        expr("CAST(0 AS INT)"),
        lambda acc, x: acc + x
    ).alias("total_quantity")
)

print("=== Item Counts Per Order ===")
item_counts_df.show(truncate=False)
```

## Key Concepts

| Function | Purpose | Input | Output |
|----------|---------|-------|--------|
| `arrays_zip(arr1, arr2, ...)` | Merges multiple arrays element-wise | N arrays of same length | Array of structs |
| `map_from_arrays(keys, values)` | Creates a map from key and value arrays | 2 arrays (keys must be unique) | MapType column |
| `map_from_entries(array_of_structs)` | Creates a map from array of (key, value) structs | Array of 2-field structs | MapType column |
| `transform(array, func)` | Applies a lambda to every element | Array + lambda | Transformed array |
| `aggregate(array, init, merge)` | Reduces array to single value | Array + initial + lambda | Scalar value |
| `element_at(map, key)` | Looks up a key in a map | Map + key | Value or null |
| `map_keys(map)` / `map_values(map)` | Extracts keys or values | MapType column | ArrayType column |
| `explode(array_or_map)` | Flattens array/map into rows | Array or Map | One row per element |

## Interview Tips

1. **arrays_zip requires same-length arrays** -- if lengths differ, shorter arrays are padded with nulls. Always validate array lengths match.
2. **map_from_arrays requires unique keys** -- duplicate keys will cause an error at runtime. Use `array_distinct` if needed.
3. **transform + arrays_zip** is a powerful pattern for computing derived fields without exploding and re-aggregating.
4. **aggregate** is PySpark's equivalent of a fold/reduce -- useful for summing or combining array elements.
5. **Performance**: Array operations are columnar and avoid the shuffle cost of explode + groupBy + collect_list. Prefer them when possible.
6. **map_from_entries vs map_from_arrays**: Use `map_from_entries` when you already have an array of structs; use `map_from_arrays` when you have separate key and value arrays.
