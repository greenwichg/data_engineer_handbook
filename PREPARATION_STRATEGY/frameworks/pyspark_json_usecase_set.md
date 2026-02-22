# **PySpark Complex JSON Handling - Use Case Set & Deep Dive**

## **Table of Contents**

1. Flattening Nested JSON Structures (Structs + Arrays)
2. Parsing JSON String Columns (from_json)
3. Multi-Level Nested Flattening (3+ Levels)
4. Programmatic / Recursive Flattening
5. Handling Null & Missing Fields in JSON
6. JSON String Extraction Without Schema (get_json_object / json_tuple)
7. Building & Serializing JSON (to_json / struct)
8. Schema Strategies (Explicit vs Inferred vs DDL)
9. Map Type & Dynamic Keys
10. Higher-Order Functions on JSON Arrays
11. Real-World E-Commerce JSON Pipeline
12. Semi-Structured & Mixed-Type Data
13. Handling Malformed / Corrupt JSON Records
14. JSON Diffing & Change Detection (CDC)
15. JSON with Kafka Streaming
16. Performance Optimization Patterns
17. inline & inline_outer (Array of Structs to Columns)
18. Re-Aggregation After Explode (collect_list / collect_set)
19. arrays_zip & Parallel Array Combining
20. Struct Manipulation (withField / dropFields)
21. Complete Array Functions Deep Dive
22. Complete Map Functions Deep Dive
23. JSON in CSV / Text Columns
24. LATERAL VIEW EXPLODE (Spark SQL)
25. str_to_map & Delimited String Parsing
26. JSON Read & Write Options (Complete Reference)
27. Schema Export, Import & Validation
28. Common Interview Questions (Q&A) — Extended

---

## **PART 1: Flattening Nested JSON Structures (Structs + Arrays)**

### Problem Understanding

When working with JSON data, you often encounter **nested structures** that include:
- **Structs** (nested objects)
- **Arrays** (lists of items)
- **Combination of both** (arrays of structs, structs containing arrays)

**Challenge:** These nested structures make it difficult to perform analysis, aggregations, and queries. Flattening converts them into a tabular format.

### Solution Breakdown

The solution involves four main steps:

#### Step 1: Read the JSON Data
```python
df = spark.read.json("path/to/nested.json")
```
Loads the JSON file into a DataFrame with nested structures preserved.

#### Step 2: Explode Arrays
```python
from pyspark.sql.functions import explode

df = df.withColumn("exploded_column", explode("nested_array_column"))
```

**What `explode()` does:**
- Takes an array column
- Creates a new row for each element in the array
- Transforms one row with an array into multiple rows

#### Step 3: Select Nested Fields (Dot Notation)
```python
df = df.select(
    "top_level_field",
    "nested_struct_field.sub_field1",
    "nested_struct_field.sub_field2"
)
```
**Dot notation** accesses fields within nested structures.

#### Step 4: Flatten Structs Completely
```python
df = df.select(
    "top_level_field",
    col("sub_field1").alias("renamed_field1"),
    col("sub_field2").alias("renamed_field2"),
    col("nested_struct_field.sub_field3").alias("field3")
)
```
Repeat the selection process to bring all nested fields to the top level.

---

### Complete Example with Nested JSON

#### Sample Nested JSON Data
```json
{
  "customer_id": 101,
  "name": "Alice",
  "orders": [
    {
      "order_id": 1001,
      "items": [
        {"product": "Laptop", "price": 999},
        {"product": "Mouse", "price": 25}
      ]
    },
    {
      "order_id": 1002,
      "items": [
        {"product": "Keyboard", "price": 75}
      ]
    }
  ],
  "address": {
    "street": "123 Main St",
    "city": "New York",
    "zipcode": "10001"
  }
}
```

#### Step-by-Step Flattening

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import explode, col

spark = SparkSession.builder.appName("FlattenJSON").getOrCreate()

# ==========================================
# STEP 1: Read JSON Data
# ==========================================
df = spark.read.json("path/to/nested.json")
print("Original nested structure:")
df.printSchema()
df.show(truncate=False)
```

**Original Schema:**
```
root
 |-- customer_id: long
 |-- name: string
 |-- orders: array
 |    |-- element: struct
 |    |    |-- order_id: long
 |    |    |-- items: array
 |    |    |    |-- element: struct
 |    |    |    |    |-- product: string
 |    |    |    |    |-- price: long
 |-- address: struct
 |    |-- street: string
 |    |-- city: string
 |    |-- zipcode: string
```

**Original Data:**
```
+-----------+-----+------------------------------------------+------------------------------+
|customer_id|name |orders                                    |address                       |
+-----------+-----+------------------------------------------+------------------------------+
|101        |Alice|[{1001, [{Laptop, 999}, {Mouse, 25}]}, ...|{123 Main St, New York, 10001}|
+-----------+-----+------------------------------------------+------------------------------+
```

#### Step 2: Explode Orders Array
```python
# ==========================================
# STEP 2: Explode 'orders' array
# ==========================================
df_orders = df.withColumn("order", explode("orders"))

print("\nAfter exploding 'orders' array:")
df_orders.printSchema()
df_orders.show(truncate=False)
```

**After Exploding Orders:**
```
+-----------+-----+------------------------------------+------------------------------+
|customer_id|name |order                               |address                       |
+-----------+-----+------------------------------------+------------------------------+
|101        |Alice|{1001, [{Laptop, 999}, {Mouse, 25}]}|{123 Main St, New York, 10001}|
|101        |Alice|{1002, [{Keyboard, 75}]}            |{123 Main St, New York, 10001}|
+-----------+-----+------------------------------------+------------------------------+
```
Notice: One row per order now!

#### Step 3: Flatten Order Struct and Explode Items
```python
# ==========================================
# STEP 3: Select nested fields from 'order' struct
# ==========================================
df_order_flat = df_orders.select(
    "customer_id",
    "name",
    col("order.order_id").alias("order_id"),
    col("order.items").alias("items"),
    col("address.street").alias("street"),
    col("address.city").alias("city"),
    col("address.zipcode").alias("zipcode")
)

print("\nAfter flattening order struct:")
df_order_flat.show(truncate=False)

# ==========================================
# STEP 4: Explode 'items' array
# ==========================================
df_items = df_order_flat.withColumn("item", explode("items"))

print("\nAfter exploding 'items' array:")
df_items.show(truncate=False)
```

**After Exploding Items:**
```
+-----------+-----+--------+------------------+------------+--------+-------+
|customer_id|name |order_id|item              |street      |city    |zipcode|
+-----------+-----+--------+------------------+------------+--------+-------+
|101        |Alice|1001    |{Laptop, 999}     |123 Main St |New York|10001  |
|101        |Alice|1001    |{Mouse, 25}       |123 Main St |New York|10001  |
|101        |Alice|1002    |{Keyboard, 75}    |123 Main St |New York|10001  |
+-----------+-----+--------+------------------+------------+--------+-------+
```

#### Step 5: Final Flattening - Extract Item Fields
```python
# ==========================================
# STEP 5: Flatten 'item' struct completely
# ==========================================
df_final = df_items.select(
    "customer_id",
    "name",
    "order_id",
    col("item.product").alias("product"),
    col("item.price").alias("price"),
    "street",
    "city",
    "zipcode"
)

print("\nFinal flattened structure:")
df_final.printSchema()
df_final.show(truncate=False)
```

**Final Flattened Result:**
```
+-----------+-----+--------+--------+-----+------------+--------+-------+
|customer_id|name |order_id|product |price|street      |city    |zipcode|
+-----------+-----+--------+--------+-----+------------+--------+-------+
|101        |Alice|1001    |Laptop  |999  |123 Main St |New York|10001  |
|101        |Alice|1001    |Mouse   |25   |123 Main St |New York|10001  |
|101        |Alice|1002    |Keyboard|75   |123 Main St |New York|10001  |
+-----------+-----+--------+--------+-----+------------+--------+-------+
```

**Final Schema:**
```
root
 |-- customer_id: long
 |-- name: string
 |-- order_id: long
 |-- product: string
 |-- price: long
 |-- street: string
 |-- city: string
 |-- zipcode: string
```

---

### Compact One-Pass Version

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import explode, col

spark = SparkSession.builder.appName("FlattenNestedJSON").getOrCreate()

df = spark.read.json("path/to/nested.json")

# Flatten step by step in a single chain
df_flat = (df
    .withColumn("order", explode("orders"))
    .withColumn("item", explode("order.items"))
    .select(
        "customer_id",
        "name",
        col("order.order_id").alias("order_id"),
        col("item.product").alias("product"),
        col("item.price").alias("price"),
        col("address.street").alias("street"),
        col("address.city").alias("city"),
        col("address.zipcode").alias("zipcode")
    )
)

df_flat.show(truncate=False)

# Now you can easily analyze
df_flat.groupBy("customer_id", "name").agg({"price": "sum"}).show()
```

---

### Understanding `explode()` Visually

**Before Explode:**
```
Row 1: customer_id=101, orders=[{order_id: 1001}, {order_id: 1002}]
```

**After Explode:**
```
Row 1: customer_id=101, order={order_id: 1001}
Row 2: customer_id=101, order={order_id: 1002}
```

**Key Points:**
- One row becomes multiple rows
- Each array element gets its own row
- Other columns are duplicated across new rows

---

### Alternative Methods for Struct Flattening

#### Method 1: Using `select()` with Asterisk
```python
# Expand all struct fields automatically
df.select("customer_id", "name", "address.*")
```
**Result:**
```
+-----------+-----+------------+--------+-------+
|customer_id|name |street      |city    |zipcode|
+-----------+-----+------------+--------+-------+
|101        |Alice|123 Main St |New York|10001  |
+-----------+-----+------------+--------+-------+
```

#### Method 2: Using `selectExpr()`
```python
df.selectExpr(
    "customer_id",
    "name",
    "address.street as street",
    "address.city as city",
    "address.zipcode as zipcode"
)
```

---

### Comparison: Before vs After Flattening

**Before (Nested) — Complex queries:**
```python
df.filter(
    col("orders").getItem(0).getField("items").getItem(0).getField("price") > 100
)
```

**After (Flattened) — Simple queries:**
```python
df_flat.filter(col("price") > 100)
```

**Aggregations — Before (nested):** Very complex with nested structures

**Aggregations — After (flattened):**
```python
df_flat.groupBy("customer_id").agg({"price": "sum"})
```

---

## **PART 2: Parsing JSON String Columns (from_json)**

### The Problem

You have a DataFrame with JSON strings in one column, and you want to split them into separate columns.

**Starting DataFrame:**
```
| id | json_column                      |
|----|----------------------------------|
| 1  | {"name":"Alice","age":"25"}      |
| 2  | {"name":"Bob","age":"30"}        |
```

**Goal:**
```
| id | name  | age |
|----|-------|-----|
| 1  | Alice | 25  |
| 2  | Bob   | 30  |
```

### Step-by-Step Solution

#### Step 1: Tell Spark what's inside the JSON
```python
from pyspark.sql.types import StructType, StructField, StringType

schema = StructType([
    StructField("name", StringType(), True),
    StructField("age", StringType(), True)
])
```
This says: "The JSON has two things: `name` and `age`, both are text"

#### Step 2: Parse the JSON string
```python
from pyspark.sql.functions import from_json

df = df.withColumn("json_data", from_json("json_column", schema))
```

**What happens:**
```
| id | json_column                 | json_data              |
|----|-----------------------------|------------------------|
| 1  | {"name":"Alice","age":"25"} | {name: Alice, age: 25} |
| 2  | {"name":"Bob","age":"30"}   | {name: Bob, age: 30}   |
```
Now `json_data` is a **struct** (like a mini-table inside each row).

#### Step 3: Break the struct into columns
```python
df = df.select("id", "json_data.*")
```
The `.*` means "expand everything inside json_data into separate columns"

**Final result:**
```
| id | name  | age |
|----|-------|-----|
| 1  | Alice | 25  |
| 2  | Bob   | 30  |
```

### Complete Working Example

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json
from pyspark.sql.types import StructType, StructField, StringType

# Create sample data
data = [
    (1, '{"name":"Alice","age":"25"}'),
    (2, '{"name":"Bob","age":"30"}'),
    (3, '{"name":"Carol","age":"28"}')
]

spark = SparkSession.builder.getOrCreate()
df = spark.createDataFrame(data, ["id", "json_column"])

print("BEFORE:")
df.show()

# Define what's inside the JSON
schema = StructType([
    StructField("name", StringType(), True),
    StructField("age", StringType(), True)
])

# Parse JSON
df = df.withColumn("json_data", from_json("json_column", schema))

print("AFTER PARSING:")
df.show()

# Expand to columns
df = df.select("id", "json_data.*")

print("FINAL:")
df.show()
```

**Output:**
```
BEFORE:
+---+-----------------------------+
| id|json_column                  |
+---+-----------------------------+
|  1|{"name":"Alice","age":"25"}  |
|  2|{"name":"Bob","age":"30"}    |
|  3|{"name":"Carol","age":"28"}  |
+---+-----------------------------+

AFTER PARSING:
+---+-----------------------------+---------------+
| id|json_column                  |json_data      |
+---+-----------------------------+---------------+
|  1|{"name":"Alice","age":"25"}  |{Alice, 25}    |
|  2|{"name":"Bob","age":"30"}    |{Bob, 30}      |
|  3|{"name":"Carol","age":"28"}  |{Carol, 28}    |
+---+-----------------------------+---------------+

FINAL:
+---+-----+---+
| id| name|age|
+---+-----+---+
|  1|Alice| 25|
|  2|  Bob| 30|
|  3|Carol| 28|
+---+-----+---+
```

### Advanced: Nested JSON Strings

```python
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, ArrayType

# JSON string with nested objects and arrays
data = [
    (1, '{"user":{"name":"Alice","age":25},"tags":["premium","active"]}'),
]

schema = StructType([
    StructField("user", StructType([
        StructField("name", StringType(), True),
        StructField("age", IntegerType(), True)
    ]), True),
    StructField("tags", ArrayType(StringType()), True)
])

df = spark.createDataFrame(data, ["id", "json_col"])
df = df.withColumn("parsed", from_json("json_col", schema))

# Flatten: struct fields + explode array
from pyspark.sql.functions import explode

df_flat = (df
    .select(
        "id",
        col("parsed.user.name").alias("name"),
        col("parsed.user.age").alias("age"),
        explode("parsed.tags").alias("tag")
    )
)
df_flat.show()
# +---+-----+---+-------+
# | id| name|age|    tag|
# +---+-----+---+-------+
# |  1|Alice| 25|premium|
# |  1|Alice| 25| active|
# +---+-----+---+-------+
```

### Using DDL String Instead of StructType

```python
# Equivalent but more concise
df = df.withColumn("parsed",
    from_json("json_col", "user STRUCT<name: STRING, age: INT>, tags ARRAY<STRING>")
)
```

---

## **PART 3: Multi-Level Nested Flattening (3+ Levels)**

### Real-World Scenario: E-Commerce Transaction

```python
complex_json = """
{
  "transaction_id": "TXN001",
  "timestamp": "2026-01-20T10:00:00",
  "customer": {
    "id": 101,
    "name": "Alice",
    "email": "alice@example.com",
    "loyalty_tier": "gold"
  },
  "items": [
    {
      "sku": "LAPTOP-001",
      "name": "Gaming Laptop",
      "quantity": 1,
      "unit_price": 1299.99,
      "discounts": [
        {"type": "seasonal", "amount": 100},
        {"type": "loyalty", "amount": 50}
      ]
    },
    {
      "sku": "MOUSE-001",
      "name": "Wireless Mouse",
      "quantity": 2,
      "unit_price": 29.99,
      "discounts": [
        {"type": "bundle", "amount": 5}
      ]
    }
  ],
  "shipping": {
    "method": "express",
    "cost": 15.99,
    "address": {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "zip": "10001"
    }
  },
  "payment": {
    "method": "credit_card",
    "last_four": "4242",
    "amount": 1255.96
  }
}
"""
```

### Multi-Level Flattening

```python
from pyspark.sql.functions import explode, explode_outer, col

# Read data
df = spark.read.json(spark.sparkContext.parallelize([complex_json]))

print("=== ORIGINAL SCHEMA ===")
df.printSchema()

# Level 1: Explode items array
# Level 2: Explode discounts array (nested inside items)
# Level 3: Flatten all structs (customer, shipping.address, payment)

df_flat = (df
    .withColumn("item", explode("items"))
    .withColumn("discount", explode_outer("item.discounts"))
    .select(
        # Top-level fields
        "transaction_id",
        "timestamp",

        # Customer struct (Level 1 struct)
        col("customer.id").alias("customer_id"),
        col("customer.name").alias("customer_name"),
        col("customer.email").alias("customer_email"),
        col("customer.loyalty_tier").alias("loyalty_tier"),

        # Item fields (from exploded array)
        col("item.sku").alias("sku"),
        col("item.name").alias("product_name"),
        col("item.quantity").alias("quantity"),
        col("item.unit_price").alias("unit_price"),

        # Discount fields (from doubly-exploded array)
        col("discount.type").alias("discount_type"),
        col("discount.amount").alias("discount_amount"),

        # Shipping struct (Level 1 struct)
        col("shipping.method").alias("shipping_method"),
        col("shipping.cost").alias("shipping_cost"),

        # Shipping address (Level 2 struct — struct inside struct)
        col("shipping.address.street").alias("ship_street"),
        col("shipping.address.city").alias("ship_city"),
        col("shipping.address.state").alias("ship_state"),
        col("shipping.address.zip").alias("ship_zip"),

        # Payment struct
        col("payment.method").alias("payment_method"),
        col("payment.amount").alias("payment_amount")
    )
)

print("\n=== FLATTENED SCHEMA ===")
df_flat.printSchema()
df_flat.show(truncate=False)
```

**Result: Every nested level is now a flat column, ready for analysis.**

### Row Count Impact

```
Original:  1 row   (1 transaction)
After L1:  2 rows  (2 items per transaction)
After L2:  3 rows  (Laptop has 2 discounts, Mouse has 1)
```

**Important: Always track row multiplication when flattening multiple array levels.**

---

## **PART 4: Programmatic / Recursive Flattening**

### When to Use
- Schema is unknown or changes frequently
- JSON structures are very deep (4+ levels)
- Building a generic data ingestion framework

### The Recursive Flattener

```python
from pyspark.sql.types import StructType, ArrayType
from pyspark.sql.functions import col, explode_outer

def flatten_df(nested_df, prefix=""):
    """
    Recursively flatten all nested structs and arrays in a DataFrame.

    Args:
        nested_df: DataFrame with nested columns
        prefix: Column name prefix for nested fields (used in recursion)

    Returns:
        Fully flattened DataFrame
    """
    flat_cols = []
    nested_cols = []

    for field in nested_df.schema.fields:
        col_name = field.name
        full_name = f"{prefix}{col_name}"
        dtype = field.dataType

        if isinstance(dtype, StructType):
            # Struct: expand each sub-field with parent_child naming
            for sub_field in dtype.fields:
                flat_cols.append(
                    col(f"{col_name}.{sub_field.name}")
                        .alias(f"{full_name}_{sub_field.name}")
                )
        elif isinstance(dtype, ArrayType):
            # Array: mark for exploding
            nested_cols.append(col_name)
        else:
            # Primitive: keep as-is
            flat_cols.append(col(col_name).alias(full_name))

    # Select all flat columns
    if flat_cols:
        result = nested_df.select(flat_cols + [col(c) for c in nested_cols])
    else:
        result = nested_df

    # Explode each array column
    for arr_col in nested_cols:
        result = result.withColumn(arr_col, explode_outer(col(arr_col)))

    # Check if still nested and recurse
    has_complex = any(
        isinstance(f.dataType, (StructType, ArrayType))
        for f in result.schema.fields
    )
    if has_complex:
        result = flatten_df(result)

    return result


# Usage
df = spark.read.json("deeply_nested.json")
df_flat = flatten_df(df)
df_flat.printSchema()
df_flat.show()
```

### Version with Depth Limit

```python
def flatten_df_limited(nested_df, max_depth=5, current_depth=0):
    """Flatten with a maximum recursion depth to prevent infinite loops."""
    if current_depth >= max_depth:
        return nested_df

    flat_cols = []
    nested_cols = []

    for field in nested_df.schema.fields:
        name = field.name
        dtype = field.dataType

        if isinstance(dtype, StructType):
            for sub in dtype.fields:
                flat_cols.append(
                    col(f"{name}.{sub.name}").alias(f"{name}_{sub.name}")
                )
        elif isinstance(dtype, ArrayType):
            nested_cols.append(name)
        else:
            flat_cols.append(col(name))

    result = nested_df.select(flat_cols + [col(c) for c in nested_cols])

    for arr_col in nested_cols:
        result = result.withColumn(arr_col, explode_outer(col(arr_col)))

    has_complex = any(
        isinstance(f.dataType, (StructType, ArrayType))
        for f in result.schema.fields
    )
    if has_complex:
        result = flatten_df_limited(result, max_depth, current_depth + 1)

    return result
```

---

## **PART 5: Handling Null & Missing Fields in JSON**

### The Problem
Real-world JSON data frequently has:
- Missing fields in some records
- Null arrays or objects
- Empty arrays `[]` vs null arrays

### Null-Safe Patterns

```python
from pyspark.sql.functions import (
    explode, explode_outer, col, coalesce, lit, when, size, isnull
)

# ==========================================
# Pattern 1: explode_outer vs explode
# ==========================================

# DANGEROUS: explode() drops rows with null/empty arrays
df_bad = df.withColumn("item", explode("items"))
# If items is NULL or [], the entire row is silently DROPPED!

# SAFE: explode_outer() keeps those rows with NULL value
df_safe = df.withColumn("item", explode_outer("items"))
# Row is kept with item=NULL

# ==========================================
# Pattern 2: Default values for missing fields
# ==========================================
df = df.withColumn("city",
    coalesce(col("address.city"), lit("Unknown"))
)

# ==========================================
# Pattern 3: Conditional extraction
# ==========================================
df = df.withColumn("city",
    when(col("address").isNull(), lit("N/A"))
    .otherwise(coalesce(col("address.city"), lit("N/A")))
)

# ==========================================
# Pattern 4: Safe array size check
# ==========================================
# size() returns -1 for NULL arrays!
df = df.withColumn("item_count",
    when(col("items").isNull(), lit(0))
    .otherwise(size("items"))
)

# ==========================================
# Pattern 5: Filter before explode (performance + safety)
# ==========================================
df_valid = df.filter(col("items").isNotNull() & (size("items") > 0))
df_exploded = df_valid.withColumn("item", explode("items"))
```

### explode vs explode_outer Comparison

```
Input Data:
+----+-------------------+
| id | items             |
+----+-------------------+
| 1  | ["a", "b"]        |
| 2  | NULL              |
| 3  | []                |
| 4  | ["c"]             |
+----+-------------------+

After explode("items"):        After explode_outer("items"):
+----+------+                  +----+------+
| id | item |                  | id | item |
+----+------+                  +----+------+
| 1  | a    |                  | 1  | a    |
| 1  | b    |                  | 1  | b    |
| 4  | c    |                  | 2  | NULL |  <-- preserved!
+----+------+                  | 3  | NULL |  <-- preserved!
                               | 4  | c    |
Rows 2 & 3 LOST!              +----+------+
```

---

## **PART 6: JSON String Extraction Without Schema (get_json_object / json_tuple)**

### When to Use
- Quick extraction of 1-2 fields from a JSON string column
- Don't want to define a full schema
- Exploratory data analysis

### get_json_object — Single Field Extraction

```python
from pyspark.sql.functions import get_json_object

data = [
    (1, '{"name":"Alice","age":25,"address":{"city":"NYC","zip":"10001"},"tags":["a","b"]}'),
    (2, '{"name":"Bob","age":30,"address":{"city":"LA","zip":"90001"},"tags":["c"]}')
]
df = spark.createDataFrame(data, ["id", "data"])

# Top-level field
df.withColumn("name", get_json_object("data", "$.name")).show()

# Nested field
df.withColumn("city", get_json_object("data", "$.address.city")).show()

# Array element
df.withColumn("first_tag", get_json_object("data", "$.tags[0]")).show()

# IMPORTANT: Always returns STRING — must cast for numeric ops
df.withColumn("age_int",
    get_json_object("data", "$.age").cast("integer")
).show()
```

### json_tuple — Multiple Fields (More Efficient)

```python
from pyspark.sql.functions import json_tuple

# Extract multiple top-level fields in one pass
df.select(
    "id",
    json_tuple("data", "name", "age").alias("name", "age")
).show()

# +---+-----+---+
# | id| name|age|
# +---+-----+---+
# |  1|Alice| 25|
# |  2|  Bob| 30|
# +---+-----+---+
```

### When to Use Which

| Scenario | Use | Reason |
|---|---|---|
| 1-2 fields, possibly nested | `get_json_object` | Supports JSON path (`$.a.b`) |
| 3+ top-level fields | `json_tuple` | Single pass, better performance |
| Full struct needed for further ops | `from_json` | Typed struct column |
| Repeated access on same column | `from_json` | Parse once, access many times |

---

## **PART 7: Building & Serializing JSON (to_json / struct)**

### Converting Columns Back to JSON

```python
from pyspark.sql.functions import to_json, struct, col, create_map, lit

# ==========================================
# Scenario 1: Columns → JSON string
# ==========================================
df.withColumn("payload",
    to_json(struct("name", "age", "email"))
).show(truncate=False)
# +---+----------------------------------------------+
# | id|payload                                       |
# +---+----------------------------------------------+
# | 1 |{"name":"Alice","age":25,"email":"a@ex.com"}  |
# +---+----------------------------------------------+

# ==========================================
# Scenario 2: Nested JSON construction
# ==========================================
df.withColumn("payload",
    to_json(struct(
        col("name"),
        struct(col("street"), col("city"), col("zip")).alias("address")
    ))
).show(truncate=False)
# {"name":"Alice","address":{"street":"123 Main","city":"NYC","zip":"10001"}}

# ==========================================
# Scenario 3: Key-value map → JSON
# ==========================================
df.withColumn("config",
    to_json(create_map(
        lit("theme"), col("theme_pref"),
        lit("language"), col("lang_pref")
    ))
).show(truncate=False)

# ==========================================
# Scenario 4: Entire row → JSON (for Kafka, API, etc.)
# ==========================================
df.withColumn("full_json",
    to_json(struct(*df.columns))
).select("full_json").show(truncate=False)
```

### Round-Trip: JSON String → Struct → JSON String

```python
from pyspark.sql.functions import from_json, to_json
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

schema = StructType([
    StructField("name", StringType()),
    StructField("age", IntegerType())
])

# Parse
df = df.withColumn("parsed", from_json("json_col", schema))

# Modify
df = df.withColumn("parsed",
    struct(
        col("parsed.name").alias("name"),
        (col("parsed.age") + 1).alias("age")  # Increment age
    )
)

# Serialize back
df = df.withColumn("json_col", to_json("parsed"))
```

---

## **PART 8: Schema Strategies (Explicit vs Inferred vs DDL)**

### Method 1: Explicit StructType (Recommended for Production)

```python
from pyspark.sql.types import *

schema = StructType([
    StructField("transaction_id", StringType(), True),
    StructField("amount", DoubleType(), True),
    StructField("customer", StructType([
        StructField("id", LongType(), True),
        StructField("name", StringType(), True),
        StructField("email", StringType(), True)
    ]), True),
    StructField("items", ArrayType(StructType([
        StructField("sku", StringType(), True),
        StructField("price", DoubleType(), True),
        StructField("quantity", IntegerType(), True)
    ])), True),
    StructField("metadata", MapType(StringType(), StringType()), True)
])

df = spark.read.schema(schema).json("transactions/")
```

### Method 2: DDL String (Concise Alternative)

```python
ddl_schema = """
    transaction_id STRING,
    amount DOUBLE,
    customer STRUCT<id: BIGINT, name: STRING, email: STRING>,
    items ARRAY<STRUCT<sku: STRING, price: DOUBLE, quantity: INT>>,
    metadata MAP<STRING, STRING>
"""

df = spark.read.schema(ddl_schema).json("transactions/")
```

### Method 3: Schema Inference from Sample (Development Only)

```python
from pyspark.sql.functions import schema_of_json

sample = '{"name":"Alice","age":25,"scores":[90,85,92]}'
inferred = schema_of_json(sample)

df = df.withColumn("parsed", from_json("json_col", inferred))
```

### Method 4: Infer from Data (Slowest)

```python
# Reads entire file to determine schema — AVOID in production
df = spark.read.option("inferSchema", True).json("data.json")
```

### Comparison

| Approach | Read Speed | Reliability | Handles Evolution | Use When |
|---|---|---|---|---|
| Explicit StructType | Fastest | Highest | No (rigid) | Known, stable schema |
| DDL String | Fastest | High | No (rigid) | Quick scripting |
| `schema_of_json()` | Fast | Medium | Partial | Schema discovery |
| `inferSchema=True` | Slowest (2x reads) | Low | Yes | Ad-hoc exploration only |

---

## **PART 9: Map Type & Dynamic Keys**

### The Problem
Some JSON has keys that change per record:
```json
{"id": "u1", "properties": {"color": "red", "size": "L"}}
{"id": "u2", "properties": {"weight": "2kg", "material": "steel"}}
```
Here, `properties` has different keys in each row — `StructType` won't work.

### Solution: MapType

```python
from pyspark.sql.types import StructType, StructField, StringType, MapType

schema = StructType([
    StructField("id", StringType(), True),
    StructField("properties", MapType(StringType(), StringType()), True)
])

df = spark.read.schema(schema).json("data.json")

# Access specific key
df.select("id", col("properties")["color"].alias("color")).show()

# Get all keys
from pyspark.sql.functions import map_keys, map_values
df.select("id", map_keys("properties").alias("keys")).show()

# Explode to key-value rows
from pyspark.sql.functions import explode
df.select("id", explode("properties").alias("key", "value")).show()
# +---+--------+-----+
# | id|     key|value|
# +---+--------+-----+
# | u1|   color|  red|
# | u1|    size|    L|
# | u2|  weight|  2kg|
# | u2|material|steel|
# +---+--------+-----+

# Pivot known keys to columns
known_keys = ["color", "size", "weight", "material"]
for key in known_keys:
    df = df.withColumn(key, col("properties")[key])
df.show()
```

---

## **PART 10: Higher-Order Functions on JSON Arrays**

### When to Use
- Transform or filter array elements **without** exploding (preserve row count)
- Available in Spark 3.1+

### transform — Apply Function to Each Element

```python
from pyspark.sql.functions import transform, col

# Add tax to every item price
df = df.withColumn("items_with_tax",
    transform("items", lambda x: x.withField("price_with_tax", x["price"] * 1.1))
)

# Extract just product names from array of structs
df = df.withColumn("product_names",
    transform("items", lambda x: x["product"])
)
# Result: ["Laptop", "Mouse", "Keyboard"]
```

### filter — Keep Only Matching Elements

```python
from pyspark.sql.functions import filter as array_filter

# Keep only items with price > 50
df = df.withColumn("expensive_items",
    array_filter("items", lambda x: x["price"] > 50)
)

# Keep only non-null elements
df = df.withColumn("clean_tags",
    array_filter("tags", lambda x: x.isNotNull())
)
```

### aggregate — Reduce Array to Single Value

```python
from pyspark.sql.functions import aggregate

# Sum all prices in items array
df = df.withColumn("total_price",
    aggregate("items",
        lit(0).cast("double"),                       # initial value
        lambda acc, x: acc + x["price"],             # merge function
        lambda acc: acc                              # finish function
    )
)
```

### exists — Check if Any Element Matches

```python
from pyspark.sql.functions import exists

# Check if any item costs more than 1000
df = df.withColumn("has_expensive",
    exists("items", lambda x: x["price"] > 1000)
)
```

### Comparison: explode vs Higher-Order Functions

| Aspect | `explode()` | Higher-Order Functions |
|---|---|---|
| Row count | Increases | Same |
| Performance | Shuffle possible | No shuffle |
| Grouping needed after? | Yes (often) | No |
| Readability | Simple | Lambda syntax |
| Use case | Flatten for joins/aggs | In-place transforms |

---

## **PART 11: Real-World E-Commerce JSON Pipeline**

### End-to-End Production Pipeline

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    explode, explode_outer, col, coalesce, lit, when,
    size, sum as spark_sum, count, avg, current_timestamp
)
from pyspark.sql.types import *

spark = SparkSession.builder \
    .appName("EcommerceJSONPipeline") \
    .getOrCreate()

# ==========================================
# STAGE 1: DEFINE SCHEMA (never infer in production)
# ==========================================
schema = StructType([
    StructField("transaction_id", StringType(), True),
    StructField("timestamp", TimestampType(), True),
    StructField("customer", StructType([
        StructField("id", LongType(), True),
        StructField("name", StringType(), True),
        StructField("email", StringType(), True),
        StructField("loyalty_tier", StringType(), True)
    ]), True),
    StructField("items", ArrayType(StructType([
        StructField("sku", StringType(), True),
        StructField("name", StringType(), True),
        StructField("quantity", IntegerType(), True),
        StructField("unit_price", DoubleType(), True),
        StructField("discounts", ArrayType(StructType([
            StructField("type", StringType(), True),
            StructField("amount", DoubleType(), True)
        ])), True)
    ])), True),
    StructField("shipping", StructType([
        StructField("method", StringType(), True),
        StructField("cost", DoubleType(), True),
        StructField("address", StructType([
            StructField("street", StringType(), True),
            StructField("city", StringType(), True),
            StructField("state", StringType(), True),
            StructField("zip", StringType(), True)
        ]), True)
    ]), True),
    StructField("payment", StructType([
        StructField("method", StringType(), True),
        StructField("last_four", StringType(), True),
        StructField("amount", DoubleType(), True)
    ]), True)
])

# ==========================================
# STAGE 2: READ
# ==========================================
df_raw = spark.read.schema(schema).json("s3://bucket/transactions/")

# ==========================================
# STAGE 3: VALIDATE
# ==========================================
df_valid = df_raw.filter(
    col("transaction_id").isNotNull() &
    col("customer.id").isNotNull() &
    (size("items") > 0)
)

df_invalid = df_raw.subtract(df_valid)
df_invalid.write.mode("append").json("s3://bucket/quarantine/")

# ==========================================
# STAGE 4: FLATTEN
# ==========================================
df_flat = (df_valid
    .withColumn("item", explode("items"))
    .withColumn("discount", explode_outer("item.discounts"))
    .select(
        "transaction_id", "timestamp",
        col("customer.id").alias("customer_id"),
        col("customer.name").alias("customer_name"),
        col("customer.loyalty_tier").alias("loyalty_tier"),
        col("item.sku").alias("sku"),
        col("item.name").alias("product_name"),
        col("item.quantity").alias("quantity"),
        col("item.unit_price").alias("unit_price"),
        coalesce(col("discount.type"), lit("none")).alias("discount_type"),
        coalesce(col("discount.amount"), lit(0.0)).alias("discount_amount"),
        col("shipping.method").alias("ship_method"),
        col("shipping.cost").alias("ship_cost"),
        col("shipping.address.city").alias("ship_city"),
        col("shipping.address.state").alias("ship_state"),
        col("payment.method").alias("pay_method"),
        col("payment.amount").alias("pay_amount")
    )
)

# ==========================================
# STAGE 5: ENRICH
# ==========================================
df_enriched = (df_flat
    .withColumn("line_total",
        col("quantity") * col("unit_price") - col("discount_amount")
    )
    .withColumn("processed_at", current_timestamp())
)

# ==========================================
# STAGE 6: WRITE (Parquet for analytics)
# ==========================================
df_enriched.write \
    .mode("overwrite") \
    .partitionBy("ship_state") \
    .parquet("s3://bucket/processed/transactions/")

# ==========================================
# STAGE 7: AGGREGATE FOR REPORTING
# ==========================================
df_summary = (df_enriched
    .groupBy("customer_id", "customer_name", "loyalty_tier")
    .agg(
        spark_sum("line_total").alias("total_spend"),
        count("sku").alias("items_purchased"),
        avg("discount_amount").alias("avg_discount")
    )
    .orderBy(col("total_spend").desc())
)

df_summary.show()
```

---

## **PART 12: Semi-Structured & Mixed-Type Data**

### Handling Corrupt Records

```python
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

# Add _corrupt_record column to schema
schema = StructType([
    StructField("name", StringType(), True),
    StructField("age", IntegerType(), True),
    StructField("_corrupt_record", StringType(), True)
])

df = spark.read \
    .option("mode", "PERMISSIVE") \
    .option("columnNameOfCorruptRecord", "_corrupt_record") \
    .schema(schema) \
    .json("messy_data.json")

# Separate good and bad records
df_good = df.filter(col("_corrupt_record").isNull()).drop("_corrupt_record")
df_bad = df.filter(col("_corrupt_record").isNotNull())

print(f"Good records: {df_good.count()}")
print(f"Corrupt records: {df_bad.count()}")

# Quarantine bad records for investigation
df_bad.select("_corrupt_record").write.mode("append").text("quarantine/")
```

### Read Modes

| Mode | Behavior | When to Use |
|---|---|---|
| `PERMISSIVE` (default) | Puts NULLs for bad fields, stores raw line in `_corrupt_record` | Production — capture everything |
| `DROPMALFORMED` | Silently drops bad rows | When data loss is acceptable |
| `FAILFAST` | Throws exception on first bad row | Data quality enforcement / testing |

### Schema Evolution with unionByName

```python
# V1 data has fields: id, name, email
df_v1 = spark.read.json("data_v1/")

# V2 data has fields: id, name, email, phone (new field)
df_v2 = spark.read.json("data_v2/")

# Union with missing columns filled as NULL
df_all = df_v1.unionByName(df_v2, allowMissingColumns=True)
df_all.show()
# V1 rows will have phone=NULL
```

---

## **PART 13: Handling Malformed / Corrupt JSON Records**

### Common Corruptions

| Type | Example | Detection |
|---|---|---|
| Invalid syntax | `{"name": "Alice",}` (trailing comma) | `_corrupt_record` |
| Wrong type | `{"age": "twenty"}` for INT schema | Field becomes NULL |
| Missing field | `{"name": "Alice"}` (no age) | Field becomes NULL |
| Truncated | `{"name": "Ali` | `_corrupt_record` |
| Extra field | `{"name": "Alice", "extra": 1}` | Silently ignored |
| Encoding | Non-UTF8 characters | Garbled text |

### Robust Parsing Pattern

```python
from pyspark.sql.functions import col, when, length

# Read with corrupt record capture
schema = "name STRING, age INT, city STRING, _corrupt_record STRING"

df = spark.read \
    .option("mode", "PERMISSIVE") \
    .option("columnNameOfCorruptRecord", "_corrupt_record") \
    .schema(schema) \
    .json("input/")

# Classify records
df_classified = df.withColumn("quality",
    when(col("_corrupt_record").isNotNull(), "CORRUPT")
    .when(col("name").isNull(), "INCOMPLETE")
    .otherwise("GOOD")
)

# Route records
df_classified.filter(col("quality") == "GOOD") \
    .drop("_corrupt_record", "quality") \
    .write.parquet("output/good/")

df_classified.filter(col("quality") == "CORRUPT") \
    .select("_corrupt_record") \
    .write.text("output/corrupt/")

df_classified.filter(col("quality") == "INCOMPLETE") \
    .drop("_corrupt_record", "quality") \
    .write.parquet("output/incomplete/")
```

---

## **PART 14: JSON Diffing & Change Detection (CDC)**

### Detect Changes Between Two JSON Snapshots

```python
from pyspark.sql.functions import to_json, struct, sha2, col, lit

# Load two snapshots
df_old = spark.read.json("snapshot_day1/")
df_new = spark.read.json("snapshot_day2/")

# Compute row hash (excluding the primary key)
value_cols = [c for c in df_old.columns if c != "id"]

df_old = df_old.withColumn("row_hash",
    sha2(to_json(struct(*value_cols)), 256)
)
df_new = df_new.withColumn("row_hash",
    sha2(to_json(struct(*value_cols)), 256)
)

# ==========================================
# INSERTS: In new, not in old
# ==========================================
df_inserted = df_new.join(df_old, "id", "left_anti")
df_inserted = df_inserted.withColumn("change_type", lit("INSERT"))

# ==========================================
# DELETES: In old, not in new
# ==========================================
df_deleted = df_old.join(df_new, "id", "left_anti")
df_deleted = df_deleted.withColumn("change_type", lit("DELETE"))

# ==========================================
# UPDATES: Same id, different hash
# ==========================================
df_changed = (df_new.alias("new")
    .join(df_old.alias("old"), "id")
    .filter(col("new.row_hash") != col("old.row_hash"))
    .select("new.*")
    .withColumn("change_type", lit("UPDATE"))
)

# ==========================================
# UNCHANGED: Same id, same hash
# ==========================================
df_unchanged = (df_new.alias("new")
    .join(df_old.alias("old"), "id")
    .filter(col("new.row_hash") == col("old.row_hash"))
    .select("new.*")
    .withColumn("change_type", lit("UNCHANGED"))
)

# Combine all changes
df_cdc = df_inserted.unionByName(df_deleted, allowMissingColumns=True) \
    .unionByName(df_changed, allowMissingColumns=True)

df_cdc.groupBy("change_type").count().show()
```

---

## **PART 15: JSON with Kafka Streaming**

### Reading JSON from Kafka Topic

```python
from pyspark.sql.functions import from_json, col
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, TimestampType

# Define expected JSON schema
event_schema = StructType([
    StructField("event_type", StringType(), True),
    StructField("user_id", StringType(), True),
    StructField("amount", DoubleType(), True),
    StructField("timestamp", TimestampType(), True)
])

# Read from Kafka
df_kafka = (spark.readStream
    .format("kafka")
    .option("kafka.bootstrap.servers", "broker:9092")
    .option("subscribe", "events")
    .load()
)

# Kafka gives key/value as binary — cast value to string, then parse JSON
df_parsed = (df_kafka
    .selectExpr("CAST(value AS STRING) as json_str")
    .withColumn("data", from_json("json_str", event_schema))
    .select("data.*")
)

# Now you have typed, flat columns
df_parsed.printSchema()
# root
#  |-- event_type: string
#  |-- user_id: string
#  |-- amount: double
#  |-- timestamp: timestamp

# Write to sink
query = (df_parsed
    .writeStream
    .format("parquet")
    .option("path", "output/events/")
    .option("checkpointLocation", "checkpoints/events/")
    .trigger(processingTime="1 minute")
    .start()
)
```

### Writing JSON to Kafka

```python
from pyspark.sql.functions import to_json, struct

df_output = df.withColumn("value",
    to_json(struct(*df.columns))
)

(df_output
    .select("value")
    .writeStream
    .format("kafka")
    .option("kafka.bootstrap.servers", "broker:9092")
    .option("topic", "processed-events")
    .option("checkpointLocation", "checkpoints/output/")
    .start()
)
```

---

## **PART 16: Performance Optimization Patterns**

### 1. Always Use Explicit Schema
```python
# BAD: Reads entire file twice (once for schema, once for data)
df = spark.read.json("large_file.json")

# GOOD: Single pass
df = spark.read.schema(explicit_schema).json("large_file.json")
```

### 2. Filter Before Explode
```python
# BAD: Explode first, then filter (processes unnecessary rows)
df_flat = df.withColumn("item", explode("items"))
df_result = df_flat.filter(col("customer.tier") == "gold")

# GOOD: Filter first, then explode (fewer rows to process)
df_filtered = df.filter(col("customer.tier") == "gold")
df_result = df_filtered.withColumn("item", explode("items"))
```

### 3. Column Pruning Before Explode
```python
# BAD: Carry 50 columns through explode
df_flat = df.withColumn("item", explode("items"))  # All 50 columns duplicated

# GOOD: Select needed columns first
df_pruned = df.select("customer_id", "items")  # Only 2 columns
df_flat = df_pruned.withColumn("item", explode("items"))
```

### 4. Convert JSON to Parquet for Repeated Access
```python
# First time: Parse JSON and save as Parquet
df = spark.read.schema(schema).json("raw/events/")
df.write.mode("overwrite").parquet("processed/events/")

# All subsequent reads: 10-100x faster
df = spark.read.parquet("processed/events/")
```

### 5. Repartition After Skewed Explode
```python
# Large arrays in few rows cause data skew
df_flat = df.withColumn("item", explode("items"))
df_balanced = df_flat.repartition(200, "customer_id")
```

### 6. Use Higher-Order Functions When Possible
```python
# BAD: Explode → transform → groupBy to re-aggregate
df_exploded = df.withColumn("item", explode("items"))
df_result = df_exploded.groupBy("id").agg(spark_sum("item.price"))

# GOOD: aggregate() — no shuffle, no row multiplication
from pyspark.sql.functions import aggregate
df_result = df.withColumn("total",
    aggregate("items", lit(0.0), lambda acc, x: acc + x["price"])
)
```

### Performance Comparison Table

| Pattern | Speed Impact | When Critical |
|---|---|---|
| Explicit schema | 2x faster reads | Always |
| Filter before explode | 2-100x faster | Large datasets with selective filters |
| Column pruning | 2-5x faster | Wide DataFrames (20+ columns) |
| JSON → Parquet conversion | 10-100x faster | Repeated reads of same data |
| Repartition after explode | 2-10x faster | Skewed array sizes |
| Higher-order functions | 3-10x faster | When you don't need flat rows |

---

## **PART 17: Common Interview Questions (Q&A)**

---

### **Q1: What is the difference between `explode()` and `explode_outer()`?**

**Answer:**

| Aspect | `explode()` | `explode_outer()` |
|---|---|---|
| NULL array | Row **dropped** | Row kept, value = NULL |
| Empty array `[]` | Row **dropped** | Row kept, value = NULL |
| Non-empty array | One row per element | One row per element |
| Data loss risk | **Yes** — silent row loss | No |
| When to use | When NULLs are impossible | Production default |

**Key Interview Point:** Always use `explode_outer()` in production unless you explicitly want to drop NULL/empty records. `explode()` causes **silent data loss** — one of the most common bugs in PySpark pipelines.

---

### **Q2: How do you flatten deeply nested JSON (3+ levels)?**

**Answer:**

Strategy: **Work outside-in, one level at a time.**

```python
# Level 1: Explode outer array
df_l1 = df.withColumn("order", explode("orders"))

# Level 2: Explode nested array
df_l2 = df_l1.withColumn("item", explode("order.items"))

# Level 3: Explode deepest array
df_l3 = df_l2.withColumn("review", explode_outer("item.reviews"))

# Flatten all structs with aliases
df_final = df_l3.select(
    "customer_id",
    col("order.order_id").alias("order_id"),
    col("item.product").alias("product"),
    col("review.rating").alias("rating")
)
```

**Key Interview Point:** Track row multiplication at each level. If a customer has 5 orders with 3 items each with 2 reviews, one input row becomes 5 x 3 x 2 = 30 output rows.

---

### **Q3: What is the difference between `from_json()`, `get_json_object()`, and `json_tuple()`?**

**Answer:**

| Function | Input | Output | Schema Needed | Best For |
|---|---|---|---|---|
| `from_json()` | JSON string | StructType column | Yes | Full parsing, repeated access |
| `get_json_object()` | JSON string | String | No (JSON path) | 1-2 fields, nested access |
| `json_tuple()` | JSON string | Multiple Strings | No (key names) | 3+ top-level fields |

**Key Interview Point:** `from_json()` parses once into a struct that supports dot notation, making it the best choice for repeated access. `get_json_object()` re-parses the JSON string on every call, making it inefficient for multiple extractions from the same column.

---

### **Q4: How do you handle JSON data where different records have different fields (schema evolution)?**

**Answer:**

Three approaches:

1. **MapType** — for truly dynamic keys:
```python
schema = StructType([
    StructField("id", StringType()),
    StructField("properties", MapType(StringType(), StringType()))
])
```

2. **Permissive mode** — captures what it can, quarantines failures:
```python
df = spark.read.option("mode", "PERMISSIVE") \
    .option("columnNameOfCorruptRecord", "_corrupt") \
    .schema(schema).json("data/")
```

3. **unionByName** — merge different schema versions:
```python
df_all = df_v1.unionByName(df_v2, allowMissingColumns=True)
```

**Key Interview Point:** In production pipelines, combine explicit schemas with `PERMISSIVE` mode to handle the expected structure while capturing unexpected records for debugging.

---

### **Q5: Why should you avoid `inferSchema` in production JSON pipelines?**

**Answer:**

1. **Performance:** Spark reads the entire file twice — once to infer schema, once to read data
2. **Instability:** Schema changes if data changes (e.g., all-integer column becomes string if one record has a string)
3. **Type coercion:** Spark picks the broadest type — `42` and `"hello"` in the same field both become `StringType`
4. **Silent failures:** A missing field in all records means it won't appear in the schema at all

**Production pattern:** Always use explicit schemas (`StructType` or DDL string) and validate with `_corrupt_record`.

---

### **Q6: How do you optimize a PySpark pipeline that processes large nested JSON files?**

**Answer:**

Priority order of optimizations:

1. **Explicit schema** — eliminates double-read (2x improvement)
2. **Convert JSON → Parquet** first — columnar format enables predicate pushdown and column pruning (10-100x for subsequent reads)
3. **Filter before explode** — reduces row count before multiplication
4. **Column pruning before explode** — reduces data width before duplication
5. **Higher-order functions** instead of explode where possible — avoids row multiplication and shuffles
6. **Repartition after explode** — fixes data skew from uneven array sizes
7. **`multiLine=False`** (JSONL format) — enables parallel reading across partitions

**Key Interview Point:** JSON is not splittable when `multiLine=True`, meaning one file = one Spark task. For large files, convert to JSONL (one JSON per line) or Parquet.

---

### **Q7: What happens when `from_json()` encounters a schema mismatch?**

**Answer:**

The **entire row's parsed column becomes NULL** — no error, no exception.

```python
schema = "name STRING, age INT"
data = [(1, '{"name":"Alice","age":"not_a_number"}')]
df = spark.createDataFrame(data, ["id", "json"])

df.withColumn("parsed", from_json("json", schema)).show()
# +---+------------------------------------+------+
# | id|json                                |parsed|
# +---+------------------------------------+------+
# |  1|{"name":"Alice","age":"not_a_number"}| NULL |
# +---+------------------------------------+------+
```

**Key Interview Point:** This is a **silent failure**. Always validate parsed results: `df.filter(col("parsed").isNull()).count()` to detect how many rows failed parsing.

---

### **Q8: How do you process JSON data from Kafka in a streaming pipeline?**

**Answer:**

```python
# 1. Read from Kafka (value is binary)
df = spark.readStream.format("kafka") \
    .option("kafka.bootstrap.servers", "broker:9092") \
    .option("subscribe", "topic") \
    .load()

# 2. Cast binary to string, then parse JSON
df_parsed = df \
    .selectExpr("CAST(value AS STRING) as json_str") \
    .withColumn("data", from_json("json_str", schema)) \
    .select("data.*")

# 3. Process and write
df_parsed.writeStream \
    .format("delta") \
    .option("checkpointLocation", "checkpoints/") \
    .start("output/")
```

**Key Interview Points:**
- Kafka value is binary (`byte[]`) — must `CAST` to STRING before `from_json`
- Always use explicit schema — no `inferSchema` in streaming
- Checkpoint location is required for exactly-once semantics
- Use `to_json(struct(*cols))` to write back to Kafka

---

### **Q9: When should you use `transform()` / `filter()` higher-order functions vs `explode()`?**

**Answer:**

| Use Case | Approach | Reason |
|---|---|---|
| Need flat rows for joins/aggregations | `explode()` | Need separate rows |
| Transform array elements in place | `transform()` | No row multiplication |
| Filter array elements | `filter()` | Keep row structure |
| Sum/aggregate within array | `aggregate()` | No shuffle needed |
| Need element index | `posexplode()` | Gives position |

**Key Interview Point:** Higher-order functions avoid the "explode → process → re-aggregate" anti-pattern, which causes unnecessary shuffles and row multiplication. Always prefer them when you don't need flat rows as the final output.

---

### **Q10: How do you handle a JSON column where the schema is completely unknown?**

**Answer:**

```python
# Step 1: Read as text to examine raw data
df_raw = spark.read.text("unknown.json")
df_raw.show(5, truncate=False)

# Step 2: Parse with automatic inference on a sample
df_sample = spark.read.json("unknown.json")
df_sample.printSchema()  # Inspect auto-detected schema

# Step 3: Extract the schema as DDL for reuse
ddl = df_sample.schema.simpleString()
print(ddl)  # Use this to build explicit schema

# Step 4: Use the schema for production reads
# Copy the printed schema into StructType or DDL
production_schema = "..." # from step 3
df = spark.read.schema(production_schema).json("unknown.json")

# Alternative: Use recursive flatten for any depth
df_flat = flatten_df(df)
```

**Key Interview Point:** Schema discovery is a development task. In production, always use explicit schemas derived from the discovery phase. Never ship `inferSchema=True` to production.

---

### **Q11: What is the difference between `multiLine=True` and `multiLine=False` when reading JSON?**

**Answer:**

| Setting | File Format | Parallelism | Use Case |
|---|---|---|---|
| `multiLine=False` (default) | One JSON per line (JSONL) | Full — file is splittable | Logs, event streams, large files |
| `multiLine=True` | Pretty-printed or single JSON | **None** — one file = one task | API responses, config files |

```python
# JSONL (default, splittable)
# {"id":1}\n{"id":2}\n{"id":3}
df = spark.read.json("events.jsonl")

# Multi-line JSON (not splittable)
# {
#   "id": 1,
#   "name": "Alice"
# }
df = spark.read.option("multiLine", True).json("record.json")
```

**Key Interview Point:** For large-scale data, always prefer JSONL format. A 10GB multi-line JSON file will be processed by a **single Spark task**, while a 10GB JSONL file can be split across hundreds of tasks for parallel processing.

---

---

## **PART 17: inline & inline_outer (Array of Structs to Columns)**

### The Problem
When you have an `array<struct>`, the typical two-step approach is `explode()` followed by `select("col.*")`. The `inline` function combines both into one step.

### inline vs explode Comparison

```python
from pyspark.sql.functions import explode, inline, inline_outer

# Sample: customers with items array<struct<product, price>>
# ==========================================
# Approach 1: explode + select (two steps)
# ==========================================
df.withColumn("item", explode("items")).select("id", "item.*")

# ==========================================
# Approach 2: inline (one step, more concise)
# ==========================================
df.select("id", inline("items"))

# Both produce:
# +---+--------+-----+
# | id| product|price|
# +---+--------+-----+
# |  1|  Laptop|  999|
# |  1|   Mouse|   25|
# +---+--------+-----+
```

### Null Safety: inline_outer

```python
# inline() drops rows with NULL/empty arrays (same as explode)
# inline_outer() keeps those rows with NULL columns (same as explode_outer)

# Input:
# +---+--------------------+
# | id|               items|
# +---+--------------------+
# |  1| [{Laptop,999},...] |
# |  2|               NULL |
# |  3|                 [] |
# +---+--------------------+

# After inline("items"):
# +---+--------+-----+
# | id| product|price|
# +---+--------+-----+     <-- rows 2 & 3 DROPPED
# |  1|  Laptop|  999|
# |  1|   Mouse|   25|
# +---+--------+-----+

# After inline_outer("items"):
# +---+--------+-----+
# | id| product|price|
# +---+--------+-----+
# |  1|  Laptop|  999|
# |  1|   Mouse|   25|
# |  2|    NULL| NULL|     <-- preserved!
# |  3|    NULL| NULL|     <-- preserved!
# +---+--------+-----+
```

### SQL Syntax

```sql
-- inline in SQL
SELECT id, product, price
FROM customers
LATERAL VIEW inline(items) t AS product, price

-- inline_outer in SQL
SELECT id, product, price
FROM customers
LATERAL VIEW OUTER inline(items) t AS product, price
```

### When to Use Which

| Scenario | Use | Why |
|---|---|---|
| Quick flatten, no intermediate processing | `inline()` | Concise, one step |
| Need to reference exploded struct before flattening | `explode()` + `select` | Access via `col("item.field")` |
| NULL/empty arrays must be preserved | `inline_outer()` | Null-safe |
| Need position index | `posexplode()` | Gives pos column |

---

## **PART 18: Re-Aggregation After Explode (collect_list / collect_set)**

### The Problem
After exploding an array for transformation, you often need to **re-aggregate** the results back into an array. This is the "reverse explode" pattern.

### Pattern: Explode → Transform → Re-aggregate

```python
from pyspark.sql.functions import (
    explode, col, upper, collect_list, collect_set,
    struct, sort_array, size
)

# ==========================================
# Step 1: Explode the array
# ==========================================
df_flat = df.withColumn("item", explode("items"))
# customer_id=1, item={product:"laptop", price:999}
# customer_id=1, item={product:"mouse", price:25}

# ==========================================
# Step 2: Transform individual elements
# ==========================================
df_transformed = df_flat.withColumn("product_upper",
    upper(col("item.product"))
)

# ==========================================
# Step 3: Re-aggregate back into array
# ==========================================
df_result = df_transformed.groupBy("customer_id").agg(
    collect_list("product_upper").alias("products"),
    collect_list(
        struct(
            col("product_upper").alias("product"),
            col("item.price").alias("price")
        )
    ).alias("items_transformed")
)
```

### collect_list vs collect_set

```
Input rows (after explode):
customer_id=1, category="electronics"
customer_id=1, category="accessories"
customer_id=1, category="electronics"  <-- duplicate

collect_list("category"):
["electronics", "accessories", "electronics"]  <-- keeps duplicates, preserves order

collect_set("category"):
["electronics", "accessories"]  <-- removes duplicates, order NOT guaranteed
```

| Function | Duplicates | Order | NULLs | Use When |
|---|---|---|---|---|
| `collect_list()` | Keeps all | Preserves insertion | Includes | Need all values / order matters |
| `collect_set()` | Removes | Not guaranteed | Excludes | Need unique values only |

### Advanced Patterns

```python
# ==========================================
# Pattern 1: Sorted re-aggregation
# ==========================================
df_result = df_flat.groupBy("customer_id").agg(
    sort_array(collect_list("product")).alias("products_sorted")
)

# ==========================================
# Pattern 2: Conditional collection
# ==========================================
from pyspark.sql.functions import when

df_result = df_flat.groupBy("customer_id").agg(
    collect_list(
        when(col("item.price") > 100, col("item.product"))
    ).alias("expensive_products"),
    collect_set("item.category").alias("unique_categories")
)

# ==========================================
# Pattern 3: Collect structs (preserve full structure)
# ==========================================
df_result = df_flat.groupBy("customer_id").agg(
    collect_list(
        struct("item.product", "item.price", "item.quantity")
    ).alias("items_array")
)

# ==========================================
# Pattern 4: Size check after collection
# ==========================================
df_result = df_result.withColumn("item_count", size("items_array"))
```

### Performance Considerations
- `collect_list` / `collect_set` pull all data to a single executor per group
- Very large groups (1M+ elements) can cause OOM
- Consider `sort_array(collect_list(...))` for deterministic output
- `collect_set` is slightly more expensive than `collect_list` due to deduplication

---

## **PART 19: arrays_zip & Parallel Array Combining**

### The Problem
Sometimes data has **parallel arrays** — separate arrays that are positionally related:
```json
{"id": 1, "products": ["Laptop", "Mouse"], "prices": [999, 25], "quantities": [1, 2]}
```
The first element of each array belongs together, second elements belong together, etc.

### Solution: arrays_zip

```python
from pyspark.sql.functions import arrays_zip, col, explode

# ==========================================
# Step 1: Zip parallel arrays into array of structs
# ==========================================
df = df.withColumn("items",
    arrays_zip("products", "prices", "quantities")
)
# items: [{products:"Laptop", prices:999, quantities:1},
#          {products:"Mouse", prices:25, quantities:2}]

# ==========================================
# Step 2: Explode the zipped array
# ==========================================
df_flat = df.select("id", explode("items").alias("item"))

# ==========================================
# Step 3: Extract individual fields
# ==========================================
df_final = df_flat.select(
    "id",
    col("item.products").alias("product"),
    col("item.prices").alias("price"),
    col("item.quantities").alias("quantity")
)

# +---+--------+-----+--------+
# | id| product|price|quantity|
# +---+--------+-----+--------+
# |  1|  Laptop|  999|       1|
# |  1|   Mouse|   25|       2|
# +---+--------+-----+--------+
```

### Unequal Length Arrays

```python
# arrays_zip pads shorter arrays with NULL
# products: ["A", "B", "C"], prices: [10, 20]
# Result: [{A,10}, {B,20}, {C,NULL}]

# This is different from zip_with which truncates to shortest
```

### zip_with — Zip + Transform in One Step

```python
from pyspark.sql.functions import zip_with

# Element-wise multiplication
df = df.withColumn("line_totals",
    zip_with("prices", "quantities", lambda p, q: p * q)
)
# prices: [100, 50, 75], quantities: [2, 3, 1]
# line_totals: [200, 150, 75]

# Element-wise string concatenation
df = df.withColumn("labels",
    zip_with("products", "prices",
        lambda prod, price: concat(prod, lit(": $"), price.cast("string"))
    )
)
# labels: ["Laptop: $999", "Mouse: $25"]
```

### Comparison

| Function | What It Does | Output Type | Unequal Lengths |
|---|---|---|---|
| `arrays_zip(a, b, c)` | Zip by position | `array<struct<a,b,c>>` | Pads with NULL |
| `zip_with(a, b, func)` | Zip + apply function | `array<T>` | Truncates to shortest |
| `concat(a, b)` | Concatenate arrays | `array<T>` | N/A (appends) |

---

## **PART 20: Struct Manipulation (withField / dropFields)**

### The Problem
You need to add, modify, or remove fields from an existing struct column **without** reconstructing the entire struct.

### withField — Add or Update a Field (Spark 3.1+)

```python
from pyspark.sql.functions import col, lit, upper

# ==========================================
# Add a new field to an existing struct
# ==========================================
df = df.withColumn("address",
    col("address").withField("country", lit("US"))
)
# address: {street, city, zip} → {street, city, zip, country}

# ==========================================
# Update an existing field in a struct
# ==========================================
df = df.withColumn("address",
    col("address").withField("city", upper(col("address.city")))
)
# address.city: "new york" → "NEW YORK"

# ==========================================
# Add computed field
# ==========================================
df = df.withColumn("customer",
    col("customer").withField("display_name",
        concat(col("customer.first_name"), lit(" "), col("customer.last_name"))
    )
)
```

### dropFields — Remove Fields from a Struct (Spark 3.1+)

```python
from pyspark.sql.functions import col

# ==========================================
# Remove a single field
# ==========================================
df = df.withColumn("customer",
    col("customer").dropFields("ssn")
)
# customer: {name, email, ssn} → {name, email}

# ==========================================
# Remove multiple fields
# ==========================================
df = df.withColumn("customer",
    col("customer").dropFields("ssn", "credit_card", "phone")
)

# ==========================================
# Rename a field (add new + drop old)
# ==========================================
df = df.withColumn("address",
    col("address")
        .withField("postal_code", col("address.zipcode"))
        .dropFields("zipcode")
)
# address: {street, city, zipcode} → {street, city, postal_code}
```

### Pre-Spark 3.1 Alternative: Struct Reconstruction

```python
from pyspark.sql.functions import struct, col, lit

# For Spark versions before 3.1, reconstruct the entire struct
df = df.withColumn("address_v2",
    struct(
        col("address.street").alias("street"),
        col("address.city").alias("city"),
        col("address.zipcode").alias("postal_code"),  # Renamed
        lit("US").alias("country")                      # Added
        # ssn omitted = dropped
    )
).drop("address").withColumnRenamed("address_v2", "address")
```

### Deeply Nested Updates

```python
# Update a field inside a nested struct
# shipping.address.city → uppercase
df = df.withColumn("shipping",
    col("shipping").withField("address",
        col("shipping.address").withField("city",
            upper(col("shipping.address.city"))
        )
    )
)
```

---

## **PART 21: Complete Array Functions Deep Dive**

### Set Operations on Arrays

```python
from pyspark.sql.functions import (
    array_union, array_intersect, array_except, arrays_overlap
)

# ==========================================
# Union: All unique elements from both arrays
# ==========================================
df.select(array_union("tags_v1", "tags_v2").alias("all_tags")).show()
# tags_v1: ["a","b","c"], tags_v2: ["b","c","d"]
# all_tags: ["a","b","c","d"]

# ==========================================
# Intersection: Common elements
# ==========================================
df.select(array_intersect("tags_v1", "tags_v2").alias("common")).show()
# common: ["b","c"]

# ==========================================
# Except: Elements in first, not in second
# ==========================================
df.select(array_except("tags_v1", "tags_v2").alias("removed")).show()
# removed: ["a"]

# ==========================================
# Overlap check: Do arrays share any elements?
# ==========================================
df.select(arrays_overlap("user_tags", "promo_tags").alias("eligible")).show()
# true/false
```

### Array Manipulation Functions

```python
from pyspark.sql.functions import (
    array_sort, array_distinct, array_join, array_repeat,
    array_remove, array_position, array_max, array_min,
    concat, reverse, shuffle, slice, sequence, flatten
)

# ==========================================
# Sort, deduplicate, join
# ==========================================
df.select(
    array_sort("scores").alias("sorted"),           # [3,1,2] → [1,2,3]
    array_distinct("tags").alias("unique"),          # [a,b,a] → [a,b]
    array_join("tags", ", ").alias("tag_string")     # ["a","b"] → "a, b"
).show()

# ==========================================
# Subarray and generation
# ==========================================
df.select(
    slice("items", 1, 3).alias("first_3"),           # First 3 elements (1-based)
    reverse("items").alias("reversed"),              # Reverse order
    sequence(lit(1), lit(10), lit(2)).alias("odds")  # [1,3,5,7,9]
).show()

# ==========================================
# Search and remove
# ==========================================
df.select(
    array_position("tags", "premium").alias("pos"),  # 1-based index (0 = not found)
    array_remove("tags", "deprecated").alias("clean"),# Remove all occurrences
    array_max("scores").alias("max_score"),           # Maximum element
    array_min("scores").alias("min_score")            # Minimum element
).show()

# ==========================================
# Flatten nested arrays
# ==========================================
# [[1,2],[3,4],[5]] → [1,2,3,4,5]
df.select(flatten("nested_arrays").alias("flat")).show()

# Concatenate arrays
# [1,2] + [3,4] → [1,2,3,4]
df.select(concat("arr1", "arr2").alias("combined")).show()
```

### Higher-Order Functions (Spark 3.1+)

```python
from pyspark.sql.functions import (
    transform, filter as array_filter, aggregate, exists, forall
)

# ==========================================
# forall: Check ALL elements match condition
# ==========================================
df.select(
    forall("scores", lambda x: x > 0).alias("all_positive"),
    forall("items", lambda x: x["price"].isNotNull()).alias("all_priced")
).show()
# Note: forall returns TRUE for empty arrays (vacuous truth)

# ==========================================
# Complex transform: add computed fields to array of structs
# ==========================================
df = df.withColumn("items_enriched",
    transform("items", lambda x:
        struct(
            x["product"].alias("product"),
            x["price"].alias("price"),
            (x["price"] * 0.1).alias("tax"),
            (x["price"] * 1.1).alias("price_with_tax")
        )
    )
)

# ==========================================
# Chained higher-order: filter then transform
# ==========================================
from pyspark.sql.functions import filter as array_filter
df = df.withColumn("expensive_names",
    transform(
        array_filter("items", lambda x: x["price"] > 100),
        lambda x: x["product"]
    )
)
# Only product names where price > 100
```

---

## **PART 22: Complete Map Functions Deep Dive**

### Building Maps

```python
from pyspark.sql.functions import (
    create_map, map_from_arrays, map_from_entries,
    col, lit, struct, array
)

# ==========================================
# Method 1: create_map — from column pairs
# ==========================================
df = df.withColumn("metadata",
    create_map(
        lit("source"), col("source_system"),
        lit("timestamp"), col("event_time").cast("string"),
        lit("version"), lit("2.0")
    )
)

# ==========================================
# Method 2: map_from_arrays — from key & value arrays
# ==========================================
df = df.withColumn("props",
    map_from_arrays(col("property_names"), col("property_values"))
)
# property_names: ["color","size"], property_values: ["red","L"]
# props: {"color":"red", "size":"L"}

# ==========================================
# Method 3: map_from_entries — from array of key-value structs
# ==========================================
df = df.withColumn("config",
    map_from_entries(col("config_entries"))
)
# config_entries: [{key:"host",value:"localhost"}, {key:"port",value:"8080"}]
# config: {"host":"localhost", "port":"8080"}
```

### Querying Maps

```python
from pyspark.sql.functions import (
    map_keys, map_values, map_entries, element_at, col, size
)

# ==========================================
# Access, keys, values
# ==========================================
df.select(
    col("props")["color"].alias("color"),          # Bracket access
    element_at("props", "size").alias("size"),      # Function access
    map_keys("props").alias("all_keys"),            # ["color","size"]
    map_values("props").alias("all_values"),        # ["red","L"]
    map_entries("props").alias("entries"),           # [{color,red},{size,L}]
    size("props").alias("num_entries")              # 2
).show()
```

### Transforming Maps

```python
from pyspark.sql.functions import (
    map_filter, map_zip_with, map_concat, explode
)

# ==========================================
# Filter map entries
# ==========================================
df = df.withColumn("high_scores",
    map_filter("scores", lambda k, v: v > 80)
)
# scores: {"math":95, "english":70, "science":88}
# high_scores: {"math":95, "science":88}

# ==========================================
# Combine two maps with custom merge logic
# ==========================================
df = df.withColumn("merged",
    map_zip_with("defaults", "overrides",
        lambda k, v1, v2: coalesce(v2, v1)  # Override wins
    )
)

# ==========================================
# Concatenate maps (last wins on conflict)
# ==========================================
df = df.withColumn("all_props",
    map_concat("base_props", "extra_props")
)

# ==========================================
# Explode map to rows
# ==========================================
df.select("id", explode("props").alias("key", "value")).show()
# +---+------+-----+
# | id|   key|value|
# +---+------+-----+
# |  1| color|  red|
# |  1|  size|    L|
# +---+------+-----+
```

### str_to_map — Parse Delimited Strings

```python
from pyspark.sql.functions import str_to_map

# Parse URL query parameters
# Input: "page=home&user=alice&lang=en"
df = df.withColumn("params",
    str_to_map("query_string", "&", "=")
)
# params: {"page":"home", "user":"alice", "lang":"en"}

# Parse configuration strings
# Input: "host:localhost,port:8080,db:mydb"
df = df.withColumn("config",
    str_to_map("config_str", ",", ":")
)

# Access individual keys after parsing
df.select(
    col("params")["page"].alias("page"),
    col("config")["host"].alias("host")
).show()
```

---

## **PART 23: JSON in CSV / Text Columns**

### The Problem
JSON data is often embedded inside other formats:
- CSV files with a JSON column
- Log files with JSON payloads
- Text files with mixed structured/unstructured data

### Pattern 1: JSON Embedded in CSV

```python
from pyspark.sql.functions import from_json, col
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

# ==========================================
# CSV file: id,name,metadata
# 1,Alice,"{""source"":""web"",""version"":2}"
# ==========================================
df = spark.read.option("header", True).csv("data.csv")

# Parse JSON column
schema = StructType([
    StructField("source", StringType(), True),
    StructField("version", IntegerType(), True)
])
df = df.withColumn("meta", from_json("metadata", schema))
df_flat = df.select("id", "name", "meta.*")
# +---+-----+------+-------+
# | id| name|source|version|
# +---+-----+------+-------+
# |  1|Alice|   web|      2|
# +---+-----+------+-------+
```

### Pattern 2: JSON in Log Files

```python
from pyspark.sql.functions import regexp_extract, from_json

# ==========================================
# Log format: 2026-01-20 10:30:00 INFO {"user":"alice","action":"login","ip":"1.2.3.4"}
# ==========================================
df = spark.read.text("app.log")

# Extract timestamp, level, and JSON
df = df.select(
    regexp_extract("value", r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})", 1).alias("timestamp"),
    regexp_extract("value", r"(INFO|WARN|ERROR)", 1).alias("level"),
    regexp_extract("value", r"(\{.*\})", 1).alias("json_str")
)

# Parse extracted JSON
schema = "user STRING, action STRING, ip STRING"
df = df.withColumn("data", from_json("json_str", schema))
df_flat = df.select("timestamp", "level", "data.*")
```

### Pattern 3: Multiple JSON Columns in One File

```python
# CSV with separate JSON columns for user and order data
df = spark.read.option("header", True).csv("transactions.csv")

user_schema = "name STRING, email STRING, tier STRING"
order_schema = "order_id INT, total DOUBLE, items ARRAY<STRING>"

df_flat = (df
    .withColumn("user", from_json("user_json", user_schema))
    .withColumn("order", from_json("order_json", order_schema))
    .select(
        "transaction_id",
        "user.name", "user.email", "user.tier",
        "order.order_id", "order.total"
    )
)
```

### Pattern 4: JSON in Parquet String Column

```python
# Sometimes Parquet files store JSON as string (legacy pipelines)
df = spark.read.parquet("events.parquet")
# event_data column is StringType containing JSON

schema = StructType([
    StructField("event_type", StringType()),
    StructField("properties", MapType(StringType(), StringType()))
])
df = df.withColumn("parsed", from_json("event_data", schema))
df.select("event_id", "parsed.*").show()
```

---

## **PART 24: LATERAL VIEW EXPLODE (Spark SQL)**

### When to Use
- When writing Spark SQL queries (not DataFrame API)
- When using SQL notebooks or SQL-first teams
- When porting Hive queries to Spark

### Basic Syntax

```sql
-- ==========================================
-- LATERAL VIEW explode: One row per array element
-- ==========================================
SELECT
    c.customer_id,
    c.name,
    t.tag
FROM customers c
LATERAL VIEW explode(c.tags) tags_table AS tag

-- ==========================================
-- LATERAL VIEW OUTER explode: Null-safe (keeps rows with NULL/empty arrays)
-- ==========================================
SELECT
    c.customer_id,
    c.name,
    t.tag
FROM customers c
LATERAL VIEW OUTER explode(c.tags) tags_table AS tag
```

### Chained LATERAL VIEW (Multi-Level Flattening)

```sql
-- Flatten: customers → orders → items
SELECT
    c.customer_id,
    c.name,
    o.order_id,
    i.product,
    i.price
FROM customers c
LATERAL VIEW explode(c.orders) orders_table AS o
LATERAL VIEW explode(o.items) items_table AS i
```

### LATERAL VIEW with inline (Array of Structs)

```sql
-- inline: Explode array of structs directly to columns
SELECT
    c.id,
    i.product,
    i.price
FROM customers c
LATERAL VIEW inline(c.items) items_table AS product, price

-- Null-safe version
SELECT c.id, i.product, i.price
FROM customers c
LATERAL VIEW OUTER inline(c.items) items_table AS product, price
```

### LATERAL VIEW with json_tuple

```sql
-- Parse JSON string column in SQL
SELECT
    e.id,
    j.name,
    j.age,
    j.city
FROM events e
LATERAL VIEW json_tuple(e.json_col, 'name', 'age', 'city') j
    AS name, age, city
```

### LATERAL VIEW with posexplode

```sql
-- Explode with position index
SELECT
    c.id,
    t.pos,
    t.tag
FROM customers c
LATERAL VIEW posexplode(c.tags) t AS pos, tag
```

### SQL vs DataFrame API Reference

| SQL | DataFrame API |
|---|---|
| `LATERAL VIEW explode(arr) t AS elem` | `.withColumn("elem", explode("arr"))` |
| `LATERAL VIEW OUTER explode(arr) t AS elem` | `.withColumn("elem", explode_outer("arr"))` |
| `LATERAL VIEW posexplode(arr) t AS pos, elem` | `.select(posexplode("arr").alias("pos","elem"))` |
| `LATERAL VIEW inline(arr) t AS c1, c2` | `.select(inline("arr"))` |
| `LATERAL VIEW json_tuple(j, 'a','b') t AS a, b` | `.select(json_tuple("j","a","b").alias("a","b"))` |
| `get_json_object(col, '$.path')` | `get_json_object("col", "$.path")` |
| `from_json(col, 'schema DDL')` | `from_json("col", schema)` |

---

## **PART 25: str_to_map & Delimited String Parsing**

### The Problem
Data often arrives as delimited key-value strings:
- URL query parameters: `page=home&user=alice&lang=en`
- Configuration strings: `host:localhost,port:8080,db:mydb`
- HTTP headers: `Content-Type=application/json;Accept=text/html`

### str_to_map Function

```python
from pyspark.sql.functions import str_to_map, col, explode

# ==========================================
# Default delimiters: pair=",", kv=":"
# ==========================================
df = df.withColumn("config",
    str_to_map("config_str")
)
# Input: "host:localhost,port:8080,db:mydb"
# Output: {"host":"localhost", "port":"8080", "db":"mydb"}

# ==========================================
# Custom delimiters
# ==========================================
# URL query string: pair="&", kv="="
df = df.withColumn("params",
    str_to_map("query_string", "&", "=")
)
# Input: "page=home&user=alice&lang=en"
# Output: {"page":"home", "user":"alice", "lang":"en"}

# ==========================================
# Access individual keys
# ==========================================
df.select(
    col("params")["page"].alias("page"),
    col("params")["user"].alias("user"),
    col("config")["host"].alias("host")
).show()

# ==========================================
# Explode to rows for analysis
# ==========================================
df.select("id",
    explode(str_to_map("config_str")).alias("key", "value")
).show()
```

### Alternative: Manual Parsing with split + transform

```python
from pyspark.sql.functions import split, transform, element_at

# When str_to_map doesn't work (e.g., values contain delimiters)
# Parse "key1=val1|key2=val2" manually

# Split into pairs
df = df.withColumn("pairs", split("data_str", "\\|"))

# Transform each pair into key-value
df = df.withColumn("kv_pairs",
    transform("pairs", lambda x:
        struct(
            element_at(split(x, "="), 1).alias("key"),
            element_at(split(x, "="), 2).alias("value")
        )
    )
)

# Convert to map
from pyspark.sql.functions import map_from_entries
df = df.withColumn("params", map_from_entries("kv_pairs"))
```

---

## **PART 26: JSON Read & Write Options (Complete Reference)**

### All JSON Read Options

```python
# ==========================================
# STRICT PARSING (production data quality)
# ==========================================
df = spark.read \
    .option("mode", "FAILFAST") \
    .schema(explicit_schema) \
    .json("data.json")

# ==========================================
# RELAXED PARSING (config files, non-standard JSON)
# ==========================================
df = spark.read \
    .option("multiLine", True) \
    .option("allowComments", True) \
    .option("allowSingleQuotes", True) \
    .option("allowUnquotedFieldNames", True) \
    .option("allowNumericLeadingZeros", True) \
    .option("allowBackslashEscapingAnyCharacter", True) \
    .option("allowNonNumericNumbers", True) \
    .schema(schema) \
    .json("config.json")

# ==========================================
# SCIENTIFIC DATA (NaN, Infinity values)
# ==========================================
df = spark.read \
    .option("allowNonNumericNumbers", True) \
    .schema("sensor STRING, reading DOUBLE") \
    .json("sensors.json")
# Handles: {"sensor":"temp","reading":NaN}

# ==========================================
# CUSTOM DATE/TIMESTAMP FORMATS
# ==========================================
df = spark.read \
    .option("dateFormat", "MM/dd/yyyy") \
    .option("timestampFormat", "yyyy-MM-dd'T'HH:mm:ss.SSSZ") \
    .schema("id STRING, event_date DATE, event_time TIMESTAMP") \
    .json("events.json")

# ==========================================
# NON-UTF8 ENCODING
# ==========================================
df = spark.read \
    .option("encoding", "ISO-8859-1") \
    .option("multiLine", True) \
    .json("legacy.json")

# ==========================================
# SCHEMA-AGNOSTIC (read everything as strings)
# ==========================================
df = spark.read \
    .option("primitivesAsString", True) \
    .json("unknown.json")
# All numbers, booleans become strings — cast later

# ==========================================
# FINANCIAL DATA (prefer Decimal over Double)
# ==========================================
df = spark.read \
    .option("prefersDecimal", True) \
    .json("financial.json")
# 99.99 → Decimal instead of Double (no floating point issues)
```

### All JSON Write Options

```python
# ==========================================
# COMPRESSED OUTPUT
# ==========================================
df.write \
    .option("compression", "gzip") \
    .mode("overwrite") \
    .json("output/")
# Options: none, gzip, snappy, bzip2, deflate, zstd

# ==========================================
# INCLUDE NULL FIELDS
# ==========================================
df.write \
    .option("ignoreNullFields", "false") \
    .json("output/")
# Default: {"name":"Alice"} (null age omitted)
# With false: {"name":"Alice","age":null}

# ==========================================
# CUSTOM FORMATS FOR DATES
# ==========================================
df.write \
    .option("dateFormat", "MM/dd/yyyy") \
    .option("timestampFormat", "yyyy-MM-dd HH:mm:ss") \
    .json("output/")

# ==========================================
# SINGLE FILE OUTPUT (small data only)
# ==========================================
df.coalesce(1).write.mode("overwrite").json("output/single/")
```

### Read Options Reference Table

| Option | Default | Impact |
|---|---|---|
| `multiLine` | false | true = not splittable (1 file = 1 task) |
| `mode` | PERMISSIVE | Error handling strategy |
| `columnNameOfCorruptRecord` | _corrupt_record | Column for bad records |
| `primitivesAsString` | false | All primitives → String |
| `prefersDecimal` | false | Numbers → Decimal (not Double) |
| `allowComments` | false | Allow `//` and `/* */` |
| `allowUnquotedFieldNames` | false | Allow `{name: "val"}` |
| `allowSingleQuotes` | false | Allow `{'name':'val'}` |
| `allowNumericLeadingZeros` | false | Allow `007` |
| `allowNonNumericNumbers` | false | Allow NaN, Infinity |
| `dateFormat` | yyyy-MM-dd | Custom date parsing |
| `timestampFormat` | ISO 8601 | Custom timestamp parsing |
| `encoding` | UTF-8 | Source file encoding |
| `lineSep` | \n, \r\n, \r | Custom line separator |
| `samplingRatio` | 1.0 | Schema inference sampling |
| `dropFieldIfAllNull` | false | Remove all-null fields |

---

## **PART 27: Schema Export, Import & Validation**

### Saving and Loading Schemas

```python
import json
from pyspark.sql.types import StructType

# ==========================================
# EXPORT: Save schema to file
# ==========================================
schema_json = df.schema.json()
with open("schemas/customer_v1.json", "w") as f:
    f.write(schema_json)

# Also available as DDL string (more compact)
ddl_string = df.schema.simpleString()
# "struct<name:string,age:int,address:struct<city:string,zip:string>>"

# ==========================================
# IMPORT: Load schema from file
# ==========================================
with open("schemas/customer_v1.json", "r") as f:
    schema = StructType.fromJson(json.loads(f.read()))

df = spark.read.schema(schema).json("customers/")
```

### Schema Validation Pattern

```python
import json
from pyspark.sql.types import StructType

def validate_schema(df, expected_schema_path):
    """Validate DataFrame schema against expected schema file."""
    with open(expected_schema_path, "r") as f:
        expected = StructType.fromJson(json.loads(f.read()))

    actual = df.schema

    if expected == actual:
        print("Schema validation PASSED")
        return True

    # Find differences
    expected_fields = {f.name: f for f in expected.fields}
    actual_fields = {f.name: f for f in actual.fields}

    missing = set(expected_fields.keys()) - set(actual_fields.keys())
    extra = set(actual_fields.keys()) - set(expected_fields.keys())
    type_mismatches = []

    for name in set(expected_fields.keys()) & set(actual_fields.keys()):
        if expected_fields[name].dataType != actual_fields[name].dataType:
            type_mismatches.append({
                "field": name,
                "expected": str(expected_fields[name].dataType),
                "actual": str(actual_fields[name].dataType)
            })

    print(f"Schema validation FAILED:")
    if missing:
        print(f"  Missing fields: {missing}")
    if extra:
        print(f"  Extra fields: {extra}")
    for m in type_mismatches:
        print(f"  Type mismatch: {m['field']} — expected {m['expected']}, got {m['actual']}")

    return False

# Usage
validate_schema(df, "schemas/customer_v1.json")
```

### Schema Inspection Utilities

```python
from pyspark.sql.types import StructType, ArrayType, MapType

# ==========================================
# List all fields (including nested)
# ==========================================
def list_all_fields(schema, prefix=""):
    """Recursively list all fields with their types."""
    for field in schema.fields:
        full_name = f"{prefix}{field.name}"
        print(f"{full_name}: {field.dataType.simpleString()}")

        if isinstance(field.dataType, StructType):
            list_all_fields(field.dataType, f"{full_name}.")
        elif isinstance(field.dataType, ArrayType):
            if isinstance(field.dataType.elementType, StructType):
                list_all_fields(field.dataType.elementType, f"{full_name}[].")

list_all_fields(df.schema)
# Output:
# customer_id: bigint
# name: string
# orders: array<struct<order_id:bigint,items:array<struct<...>>>>
# orders[].order_id: bigint
# orders[].items: array<struct<product:string,price:double>>
# orders[].items[].product: string
# orders[].items[].price: double

# ==========================================
# Check if field exists at any level
# ==========================================
def field_exists(schema, field_name):
    """Check if a field exists anywhere in the schema."""
    for field in schema.fields:
        if field.name == field_name:
            return True
        if isinstance(field.dataType, StructType):
            if field_exists(field.dataType, field_name):
                return True
        elif isinstance(field.dataType, ArrayType):
            if isinstance(field.dataType.elementType, StructType):
                if field_exists(field.dataType.elementType, field_name):
                    return True
    return False

print(field_exists(df.schema, "price"))  # True
```

---

## **PART 28: Common Interview Questions (Q&A) — Extended**

---

### **Q12: What is `inline()` and how does it differ from `explode()`?**

**Answer:**

| Aspect | `explode()` | `inline()` |
|---|---|---|
| Input | Any array | `array<struct>` only |
| Output | Single column (the element) | Multiple columns (struct fields) |
| Steps to flat columns | 2 (explode + select.*) | 1 (inline directly) |
| NULL/empty arrays | Drops rows | Drops rows |
| Null-safe version | `explode_outer()` | `inline_outer()` |

```python
# These are equivalent:
df.withColumn("item", explode("items")).select("id", "item.*")
df.select("id", inline("items"))
```

**Key Interview Point:** `inline` is a shortcut for the common pattern of exploding an array of structs and then selecting all struct fields. Use `inline_outer` for null safety.

---

### **Q13: How do you re-aggregate data after an explode? What's the "explode → transform → collect" pattern?**

**Answer:**

```python
# Problem: You need to transform array elements but there's no
# higher-order function that does what you need

# Step 1: Explode
df_flat = df.withColumn("tag", explode("tags"))

# Step 2: Transform (e.g., lookup, join, complex logic)
df_enriched = df_flat.join(tag_metadata, "tag")

# Step 3: Re-aggregate with collect_list
df_result = df_enriched.groupBy("id").agg(
    collect_list(struct("tag", "category", "description")).alias("enriched_tags")
)
```

**Key Interview Points:**
- `collect_list` preserves duplicates and order; `collect_set` deduplicates
- Large groups can cause OOM — monitor with `size()` after collection
- Always prefer higher-order functions (`transform`, `filter`) when they can do the job — they avoid the shuffle cost of groupBy

---

### **Q14: How do you combine parallel arrays (e.g., separate names and scores arrays)?**

**Answer:**

```python
from pyspark.sql.functions import arrays_zip, explode, col

# Problem: names=["Alice","Bob"], scores=[90,85]
# Goal: Pair them by position

df = df.withColumn("pairs", arrays_zip("names", "scores"))
df_flat = df.select("id", explode("pairs").alias("pair"))
df_final = df_flat.select("id",
    col("pair.names").alias("name"),
    col("pair.scores").alias("score")
)
```

**Key Interview Points:**
- `arrays_zip` pads shorter arrays with NULL (doesn't truncate)
- `zip_with` combines zip + transform in one step: `zip_with("prices", "qty", lambda p,q: p*q)`
- For simple concatenation (not positional pairing), use `concat(arr1, arr2)`

---

### **Q15: What is `withField()` and `dropFields()` on structs?**

**Answer:**

```python
# withField: Add or update a field in an existing struct (Spark 3.1+)
df = df.withColumn("address",
    col("address").withField("country", lit("US"))
)

# dropFields: Remove a field from a struct
df = df.withColumn("customer",
    col("customer").dropFields("ssn", "credit_card")
)

# Rename: Add new name + drop old name
df = df.withColumn("address",
    col("address")
        .withField("postal_code", col("address.zipcode"))
        .dropFields("zipcode")
)
```

**Key Interview Points:**
- Requires Spark 3.1+ — for older versions, reconstruct with `struct()`
- `withField` on a NULL struct returns NULL — guard with `when()`
- These avoid full struct reconstruction, making code cleaner and more maintainable

---

### **Q16: What are all the JSON read options you should know?**

**Answer:**

| Category | Key Options |
|---|---|
| Error handling | `mode` (PERMISSIVE/DROPMALFORMED/FAILFAST), `columnNameOfCorruptRecord` |
| Format relaxation | `allowComments`, `allowSingleQuotes`, `allowUnquotedFieldNames`, `allowNonNumericNumbers` |
| Type control | `primitivesAsString`, `prefersDecimal` |
| Date/time | `dateFormat`, `timestampFormat` |
| Encoding | `encoding`/`charset` |
| Performance | `multiLine` (false=splittable), `samplingRatio` |
| Schema | `dropFieldIfAllNull` |

**Key Interview Point:** The most impactful options are `mode` (for error handling), `multiLine` (for parallelism), and `primitivesAsString` (for schema-agnostic reads). Always use explicit schemas with `mode=PERMISSIVE` and `columnNameOfCorruptRecord` in production.

---

### **Q17: How do you handle a map column with dynamic keys in PySpark?**

**Answer:**

Three strategies:

1. **Explode to rows** — for analysis:
```python
df.select("id", explode("props").alias("key", "value"))
```

2. **Pivot known keys to columns** — for structured output:
```python
for key in ["color", "size", "weight"]:
    df = df.withColumn(key, col("props")[key])
```

3. **map_filter** — for selective access:
```python
df.withColumn("filtered", map_filter("props", lambda k, v: k.startswith("config_")))
```

**Key Interview Points:**
- Use `MapType(StringType(), StringType())` when JSON keys vary per record
- `StructType` only works when all records have the same keys
- `str_to_map("k1:v1,k2:v2", ",", ":")` parses delimited strings directly to maps

---

### **Q18: What is the difference between `flatten()` and `explode()` for nested arrays?**

**Answer:**

| Function | Input | Output | Row Count |
|---|---|---|---|
| `flatten()` | `array<array<T>>` | `array<T>` | Same |
| `explode()` | `array<T>` | `T` (one per row) | Increases |

```python
# flatten: Merge nested arrays into single array
# [[1,2],[3,4]] → [1,2,3,4]  (still one row!)
df.select(flatten("nested_arr"))

# explode: One row per element
# [1,2,3,4] → 4 rows
df.select(explode("arr"))

# Combined: Flatten then explode
df.select(explode(flatten("nested_arr")))
# [[1,2],[3,4]] → 4 rows: 1, 2, 3, 4
```

**Key Interview Point:** `flatten` reduces nesting depth without changing row count. `explode` reduces array to individual elements, creating new rows. For `array<array<T>>`, use `flatten` first then `explode`.

---

### **Q19: How do you validate that `from_json()` parsed correctly?**

**Answer:**

```python
# from_json returns NULL for the entire struct on parse failure
# (no error, no exception — silent failure!)

df = df.withColumn("parsed", from_json("json_col", schema))

# Count parse failures
failed = df.filter(col("parsed").isNull() & col("json_col").isNotNull()).count()
total = df.count()
success_rate = (total - failed) / total * 100

print(f"Parse success rate: {success_rate:.1f}%")
print(f"Failed records: {failed}")

# Inspect failed records
df.filter(col("parsed").isNull() & col("json_col").isNotNull()) \
    .select("json_col") \
    .show(10, truncate=False)
```

**Key Interview Point:** Always validate after `from_json`. The function never throws errors — it silently returns NULL for the entire parsed column when any field doesn't match the schema. Check `parsed.isNull() AND json_col.isNotNull()` to find true parse failures (vs. rows that had NULL JSON input).

---

### Key Takeaways

**Flattening Process:**
1. Read JSON data: `spark.read.json()` or `from_json()`
2. Explode arrays: `withColumn("col", explode("array_col"))` or `inline("array_of_structs")`
3. Select nested fields: Use dot notation `"struct.field"`
4. Alias for clarity: `.alias("new_name")`
5. Repeat for multiple levels of nesting

**When to Flatten:**
- Doing analytics/aggregations
- Joining with other tables
- Nested structure is too complex for queries

**When NOT to Flatten:**
- Preserving JSON structure for output (Kafka, API responses)
- Arrays represent truly hierarchical relationships
- Working with document databases
- Using higher-order functions for in-place transformations

**Production Checklist:**
- Always use explicit schema (never `inferSchema`)
- Use `explode_outer()` / `inline_outer()` instead of `explode()` / `inline()`
- Filter and prune columns before exploding
- Convert JSON to Parquet for repeated reads
- Capture corrupt records with `PERMISSIVE` mode
- Track row counts at each flattening stage
- Prefer JSONL format over multi-line JSON for parallelism
- Validate `from_json` results — it fails silently
- Use `withField` / `dropFields` for struct manipulation (Spark 3.1+)
- Use higher-order functions (`transform`, `filter`, `aggregate`) before resorting to explode
