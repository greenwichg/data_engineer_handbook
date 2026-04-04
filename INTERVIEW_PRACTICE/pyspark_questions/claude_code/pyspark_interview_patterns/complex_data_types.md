# PySpark Implementation: Complex Data Type Operations

## Problem Statement

Modern data pipelines frequently deal with nested and complex data types such as structs, arrays, and maps, especially when ingesting JSON, Avro, or Parquet data from APIs and event streams. Understanding how to create, access, and transform these complex types is a key skill tested in data engineering interviews. Candidates are expected to demonstrate proficiency with StructType, ArrayType, and MapType operations.

Given a dataset representing e-commerce orders with nested product details, demonstrate how to work with structs, arrays, and maps for creating, reading, and transforming complex data.

### Sample Data

```
+--------+--------------------+---------------------------+
|order_id| customer           | items                     |
+--------+--------------------+---------------------------+
| 1001   | {name: "Alice",   | [{sku:"A1", qty:2, ...}, |
|        |  addr: {city:     |  {sku:"B2", qty:1, ...}]  |
|        |   "NYC", zip:"10" |                           |
|        |  }}                |                           |
+--------+--------------------+---------------------------+
```

### Expected Output

**Flattened order items:**

| order_id | cust_name | city | sku | qty | price | tags        |
|----------|-----------|------|-----|-----|-------|-------------|
| 1001     | Alice     | NYC  | A1  | 2   | 29.99 | [tech, new] |
| 1001     | Alice     | NYC  | B2  | 1   | 15.50 | [home]      |

---

## Method 1: Creating and Accessing Complex Types (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    DoubleType, ArrayType, MapType
)

spark = SparkSession.builder \
    .appName("ComplexDataTypeOperations") \
    .master("local[*]") \
    .getOrCreate()

# ============================================================
# 1. Creating data with StructType (nested schemas)
# ============================================================

schema = StructType([
    StructField("order_id", IntegerType()),
    StructField("customer", StructType([
        StructField("name", StringType()),
        StructField("address", StructType([
            StructField("city", StringType()),
            StructField("zip", StringType()),
        ])),
    ])),
    StructField("items", ArrayType(StructType([
        StructField("sku", StringType()),
        StructField("qty", IntegerType()),
        StructField("price", DoubleType()),
        StructField("tags", ArrayType(StringType())),
    ]))),
    StructField("metadata", MapType(StringType(), StringType())),
])

data = [
    (1001,
     ("Alice", ("NYC", "10001")),
     [("A1", 2, 29.99, ["tech", "new"]), ("B2", 1, 15.50, ["home"])],
     {"source": "web", "promo": "SUMMER10"}),
    (1002,
     ("Bob", ("LA", "90001")),
     [("C3", 3, 9.99, ["outdoor"]), ("A1", 1, 29.99, ["tech", "new"]), ("D4", 2, 45.00, ["premium"])],
     {"source": "app", "promo": "NONE"}),
    (1003,
     ("Carol", ("CHI", "60601")),
     [("B2", 5, 15.50, ["home", "sale"])],
     {"source": "web", "promo": "WINTER20"}),
]

df = spark.createDataFrame(data, schema)

print("=== Schema ===")
df.printSchema()

print("=== Raw Data ===")
df.show(truncate=False)

# ============================================================
# 2. Accessing nested struct fields using dot notation
# ============================================================

print("=== Accessing Struct Fields ===")
df.select(
    "order_id",
    "customer.name",
    "customer.address.city",
    "customer.address.zip",
).show()

# ============================================================
# 3. Accessing map values
# ============================================================

print("=== Accessing Map Values ===")
df.select(
    "order_id",
    F.col("metadata")["source"].alias("source"),
    F.col("metadata")["promo"].alias("promo"),
    F.map_keys("metadata").alias("all_keys"),
    F.map_values("metadata").alias("all_values"),
).show(truncate=False)

# ============================================================
# 4. Exploding arrays to flatten
# ============================================================

print("=== Exploded Items ===")
exploded = df.select(
    "order_id",
    F.col("customer.name").alias("cust_name"),
    F.col("customer.address.city").alias("city"),
    F.explode("items").alias("item"),
)

flattened = exploded.select(
    "order_id",
    "cust_name",
    "city",
    "item.sku",
    "item.qty",
    "item.price",
    "item.tags",
    (F.col("item.qty") * F.col("item.price")).alias("line_total"),
)

flattened.show(truncate=False)
```

## Method 2: Transforming Complex Types

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    DoubleType, ArrayType, MapType
)

spark = SparkSession.builder \
    .appName("TransformComplexTypes") \
    .master("local[*]") \
    .getOrCreate()

schema = StructType([
    StructField("order_id", IntegerType()),
    StructField("customer", StructType([
        StructField("name", StringType()),
        StructField("address", StructType([
            StructField("city", StringType()),
            StructField("zip", StringType()),
        ])),
    ])),
    StructField("items", ArrayType(StructType([
        StructField("sku", StringType()),
        StructField("qty", IntegerType()),
        StructField("price", DoubleType()),
        StructField("tags", ArrayType(StringType())),
    ]))),
    StructField("metadata", MapType(StringType(), StringType())),
])

data = [
    (1001,
     ("Alice", ("NYC", "10001")),
     [("A1", 2, 29.99, ["tech", "new"]), ("B2", 1, 15.50, ["home"])],
     {"source": "web", "promo": "SUMMER10"}),
    (1002,
     ("Bob", ("LA", "90001")),
     [("C3", 3, 9.99, ["outdoor"]), ("A1", 1, 29.99, ["tech", "new"]), ("D4", 2, 45.00, ["premium"])],
     {"source": "app", "promo": "NONE"}),
    (1003,
     ("Carol", ("CHI", "60601")),
     [("B2", 5, 15.50, ["home", "sale"])],
     {"source": "web", "promo": "WINTER20"}),
]

df = spark.createDataFrame(data, schema)

# ============================================================
# Array operations
# ============================================================

# Size of array
print("=== Array Size ===")
df.select("order_id", F.size("items").alias("num_items")).show()

# transform: apply a function to each element in an array
print("=== Transform Array Elements (add line_total field) ===")
df.select(
    "order_id",
    F.transform("items",
        lambda item: F.struct(
            item["sku"].alias("sku"),
            item["qty"].alias("qty"),
            item["price"].alias("price"),
            (item["qty"] * item["price"]).alias("line_total"),
        )
    ).alias("items_with_total"),
).show(truncate=False)

# filter: keep only items matching a condition
print("=== Filter Array: items with price > 20 ===")
df.select(
    "order_id",
    F.filter("items", lambda x: x["price"] > 20).alias("expensive_items"),
).show(truncate=False)

# aggregate (reduce): compute total across array
print("=== Aggregate Array: order total ===")
df.select(
    "order_id",
    F.aggregate(
        "items",
        F.lit(0.0).cast("double"),
        lambda acc, item: acc + (item["qty"] * item["price"])
    ).alias("order_total"),
).show()

# exists: check if any element matches
print("=== Exists: any item with tag 'premium'? ===")
df.select(
    "order_id",
    F.exists("items", lambda x: F.array_contains(x["tags"], "premium")).alias("has_premium"),
).show()

# ============================================================
# Collect all tags into a single flat array
# ============================================================

print("=== Flatten nested arrays (all tags per order) ===")
df.select(
    "order_id",
    F.flatten(F.transform("items", lambda x: x["tags"])).alias("all_tags"),
).show(truncate=False)

# ============================================================
# Map operations
# ============================================================

# Create a map from two arrays
print("=== Create Map from Arrays ===")
df.select(
    "order_id",
    F.map_from_arrays(
        F.transform("items", lambda x: x["sku"]),
        F.transform("items", lambda x: x["qty"])
    ).alias("sku_qty_map"),
).show(truncate=False)

# Add/update entries in an existing map
print("=== Map Concat: add new key-value pair ===")
df.select(
    "order_id",
    F.map_concat(
        "metadata",
        F.create_map(F.lit("processed"), F.lit("true"))
    ).alias("updated_metadata"),
).show(truncate=False)

# ============================================================
# Creating structs on the fly
# ============================================================

print("=== Create Struct Columns ===")
df.select(
    "order_id",
    F.struct(
        F.col("customer.name").alias("name"),
        F.col("customer.address.city").alias("city"),
        F.size("items").alias("item_count"),
    ).alias("order_summary"),
).show(truncate=False)
```

## Method 3: Schema Manipulation and Type Conversion

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    DoubleType, ArrayType, MapType
)

spark = SparkSession.builder \
    .appName("SchemaManipulation") \
    .master("local[*]") \
    .getOrCreate()

# Simple flat data to demonstrate converting to complex types
flat_data = [
    (1, "Alice", "NYC", "10001", "A1", 2, 29.99),
    (1, "Alice", "NYC", "10001", "B2", 1, 15.50),
    (2, "Bob",   "LA",  "90001", "C3", 3,  9.99),
    (2, "Bob",   "LA",  "90001", "A1", 1, 29.99),
]

flat_cols = ["order_id", "name", "city", "zip", "sku", "qty", "price"]
flat_df = spark.createDataFrame(flat_data, flat_cols)

# ============================================================
# Convert flat rows to nested structure
# ============================================================

nested = flat_df.groupBy("order_id").agg(
    # Create customer struct from first row
    F.first(F.struct(
        F.col("name"),
        F.struct(F.col("city"), F.col("zip")).alias("address")
    )).alias("customer"),

    # Collect items into an array of structs
    F.collect_list(
        F.struct("sku", "qty", "price")
    ).alias("items"),

    # Create a map: sku -> price
    F.map_from_entries(
        F.collect_list(F.struct("sku", "price"))
    ).alias("price_lookup"),
)

print("=== Flat to Nested Conversion ===")
nested.printSchema()
nested.show(truncate=False)

# ============================================================
# Convert from JSON string to struct
# ============================================================

json_data = [
    (1, '{"name": "Alice", "scores": [90, 85, 92]}'),
    (2, '{"name": "Bob", "scores": [78, 88, 95]}'),
]

json_df = spark.createDataFrame(json_data, ["id", "json_str"])

json_schema = StructType([
    StructField("name", StringType()),
    StructField("scores", ArrayType(IntegerType())),
])

parsed = json_df.withColumn("parsed", F.from_json("json_str", json_schema))
print("=== Parsed JSON ===")
parsed.select("id", "parsed.name", "parsed.scores").show(truncate=False)

# Convert struct to JSON string
print("=== Struct to JSON ===")
parsed.select("id", F.to_json("parsed").alias("back_to_json")).show(truncate=False)

# ============================================================
# Convert map to array of structs and vice versa
# ============================================================

map_df = spark.createDataFrame([
    (1, {"a": 10, "b": 20}),
    (2, {"x": 30, "y": 40, "z": 50}),
], ["id", "kv_map"])

print("=== Map to Array of Entries ===")
map_df.select("id", F.map_entries("kv_map").alias("entries")).show(truncate=False)

# Explode map into key-value rows
print("=== Explode Map ===")
map_df.select("id", F.explode("kv_map").alias("key", "value")).show()
```

## Key Concepts

| Operation | Function | Description |
|-----------|----------|-------------|
| **Access struct field** | `col("struct.field")` | Dot notation for nested access |
| **Access map value** | `col("map")["key"]` | Bracket notation for map lookup |
| **Explode array** | `F.explode("array")` | One row per array element |
| **Explode map** | `F.explode("map")` | One row per key-value pair |
| **Transform array** | `F.transform("arr", lambda)` | Apply function to each element |
| **Filter array** | `F.filter("arr", lambda)` | Keep elements matching condition |
| **Aggregate array** | `F.aggregate("arr", init, func)` | Reduce array to single value |
| **Flatten** | `F.flatten("nested_arr")` | Flatten array of arrays |
| **Create struct** | `F.struct(cols...)` | Build struct from columns |
| **Create map** | `F.create_map(k1,v1,k2,v2)` | Build map from key-value pairs |
| **map_from_arrays** | `F.map_from_arrays(keys, vals)` | Build map from two arrays |
| **from_json / to_json** | `F.from_json()` / `F.to_json()` | Parse/serialize JSON strings |

## Interview Tips

1. **Know the difference between explode and posexplode**: `posexplode` also returns the index position in the array, which is useful for maintaining order.

2. **explode vs explode_outer**: `explode` drops rows with null/empty arrays, while `explode_outer` keeps them with null values. This is a common gotcha.

3. **Higher-order functions**: `transform`, `filter`, `aggregate`, and `exists` operate on arrays without exploding, which is more efficient. These are available from Spark 2.4+.

4. **Schema evolution with structs**: When reading nested data (e.g., Parquet), new fields can be added to structs without breaking existing queries if `mergeSchema` is enabled.

5. **Performance**: Avoid unnecessary explode operations as they multiply row counts. Use higher-order functions when possible to process arrays in place.
