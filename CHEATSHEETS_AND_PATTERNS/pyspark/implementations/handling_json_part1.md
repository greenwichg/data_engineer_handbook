I'll explain how to flatten nested JSON structures in Spark for easier analysis.

## Problem Understanding

When working with JSON data, you often encounter **nested structures** that include:
- **Structs** (nested objects)
- **Arrays** (lists of items)
- **Combination of both** (arrays of structs, structs containing arrays)

**Challenge:** These nested structures make it difficult to perform analysis, aggregations, and queries. Flattening converts them into a tabular format.

## Solution Breakdown

The solution involves four main steps:

### 1. Read the JSON Data

```python
df = spark.read.json("path/to/nested.json")
```

Loads the JSON file into a DataFrame with nested structures preserved.

### 2. Explode Arrays

```python
from pyspark.sql.functions import explode

df = df.withColumn("exploded_column", explode("nested_array_column"))
```

**What `explode()` does:**
- Takes an array column
- Creates a new row for each element in the array
- Transforms one row with an array into multiple rows

### 3. Select Nested Fields (Dot Notation)

```python
df = df.select(
    "top_level_field",
    "nested_struct_field.sub_field1",
    "nested_struct_field.sub_field2"
)
```

**Dot notation** accesses fields within nested structures.

### 4. Flatten Structs Completely

```python
df = df.select(
    "top_level_field",
    "sub_field1",
    "sub_field2",
    "nested_struct_field.sub_field3"
)
```

Repeat the selection process to bring all nested fields to the top level.

## Complete Example with Nested JSON:

### Sample Nested JSON Data:

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

### Step-by-Step Flattening:

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

### Step 2: Explode Orders Array

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

### Step 3: Flatten Order Struct and Explode Items

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

### Step 5: Final Flattening - Extract Item Fields

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

Perfect! Now fully flattened and ready for analysis!

## Complete Code Example:

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import explode, col

# Initialize Spark
spark = SparkSession.builder \
    .appName("FlattenNestedJSON") \
    .getOrCreate()

# Sample nested JSON data
json_data = """
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
"""

# Write sample data to file
with open("/tmp/nested.json", "w") as f:
    f.write(json_data)

# Read JSON
df = spark.read.json("/tmp/nested.json")

print("=== ORIGINAL NESTED STRUCTURE ===")
df.printSchema()
df.show(truncate=False)

# Flatten step by step
df_flat = df \
    .withColumn("order", explode("orders")) \
    .withColumn("item", explode("order.items")) \
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

print("\n=== FLATTENED STRUCTURE ===")
df_flat.printSchema()
df_flat.show(truncate=False)

# Now you can easily analyze
print("\n=== ANALYSIS: Total spending per customer ===")
df_flat.groupBy("customer_id", "name") \
    .agg({"price": "sum"}) \
    .show()

spark.stop()
```

## Understanding `explode()` Function:

### Before Explode:
```
Row 1: customer_id=101, orders=[{order_id: 1001}, {order_id: 1002}]
```

### After Explode:
```
Row 1: customer_id=101, order={order_id: 1001}
Row 2: customer_id=101, order={order_id: 1002}
```

**Key Points:**
- One row becomes multiple rows
- Each array element gets its own row
- Other columns are duplicated

## Alternative Methods:

### Method 1: Using `select()` with Asterisk

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

### Method 2: Using `selectExpr()`

```python
df.selectExpr(
    "customer_id",
    "name",
    "address.street as street",
    "address.city as city",
    "address.zipcode as zipcode"
)
```

### Method 3: Programmatic Flattening Function

```python
from pyspark.sql.types import StructType, ArrayType

def flatten_df(nested_df):
    """
    Recursively flatten all nested structures
    """
    
    # Get all fields
    flat_cols = []
    nested_cols = []
    
    for field in nested_df.schema.fields:
        name = field.name
        dtype = field.dataType
        
        if isinstance(dtype, ArrayType):
            # It's an array - will need to explode
            nested_cols.append(name)
        elif isinstance(dtype, StructType):
            # It's a struct - expand with dot notation
            for subfield in dtype.fields:
                flat_cols.append(
                    col(f"{name}.{subfield.name}").alias(f"{name}_{subfield.name}")
                )
        else:
            # Regular field
            flat_cols.append(name)
    
    # Select flattened columns
    df_result = nested_df.select(*flat_cols)
    
    # Explode arrays
    for array_col in nested_cols:
        df_result = df_result.withColumn(array_col, explode(col(array_col)))
        # Recursively flatten if the exploded column is still nested
        if any(isinstance(f.dataType, (StructType, ArrayType)) 
               for f in df_result.schema.fields):
            df_result = flatten_df(df_result)
    
    return df_result

# Usage
df_flattened = flatten_df(df)
```

## Real-World Example: E-commerce Data

```python
# Complex nested structure
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

# Read and flatten
df = spark.read.json(spark.sparkContext.parallelize([complex_json]))

# Multi-level flattening
df_flat = df \
    .withColumn("item", explode("items")) \
    .withColumn("discount", explode("item.discounts")) \
    .select(
        "transaction_id",
        "timestamp",
        # Customer fields
        col("customer.id").alias("customer_id"),
        col("customer.name").alias("customer_name"),
        col("customer.email").alias("customer_email"),
        col("customer.loyalty_tier").alias("loyalty_tier"),
        # Item fields
        col("item.sku").alias("sku"),
        col("item.name").alias("product_name"),
        col("item.quantity").alias("quantity"),
        col("item.unit_price").alias("unit_price"),
        # Discount fields
        col("discount.type").alias("discount_type"),
        col("discount.amount").alias("discount_amount"),
        # Shipping fields
        col("shipping.method").alias("shipping_method"),
        col("shipping.cost").alias("shipping_cost"),
        col("shipping.address.street").alias("ship_street"),
        col("shipping.address.city").alias("ship_city"),
        col("shipping.address.state").alias("ship_state"),
        col("shipping.address.zip").alias("ship_zip"),
        # Payment fields
        col("payment.method").alias("payment_method"),
        col("payment.amount").alias("payment_amount")
    )

print("Flattened e-commerce data:")
df_flat.show(truncate=False)
```

## Handling Null Values in Nested Structures:

```python
from pyspark.sql.functions import when, col, size

# Check if array is empty before exploding
df_safe = df.withColumn(
    "item",
    when(size(col("items")) > 0, explode(col("items"))).otherwise(None)
)

# Or filter out empty arrays
df_filtered = df.filter(size(col("items")) > 0) \
    .withColumn("item", explode("items"))
```

## Performance Considerations:

### 1. Explode Can Create Many Rows:

```python
# Before: 1 row with 100 items
# After explode: 100 rows

# Be careful with large arrays!
```

### 2. Use `explode_outer()` for Null Safety:

```python
from pyspark.sql.functions import explode_outer

# explode_outer keeps rows even if array is null/empty
df = df.withColumn("item", explode_outer("items"))
```

### 3. Limit Data Early:

```python
# Filter before flattening to reduce data size
df_filtered = df.filter(col("customer.loyalty_tier") == "gold")
df_flat = df_filtered.withColumn("order", explode("orders"))
```

## Comparison: Before vs After Flattening

**Before (Nested):**
```python
# Complex query
df.filter(col("orders").getItem(0).getField("items").getItem(0).getField("price") > 100)
```

**After (Flattened):**
```python
# Simple query
df_flat.filter(col("price") > 100)
```

**Aggregations - Before:**
```python
# Very complex with nested structures
```

**Aggregations - After:**
```python
# Simple and straightforward
df_flat.groupBy("customer_id").agg({"price": "sum"})
```

## Key Takeaways:

**Flattening Process:**
1. ✅ Read JSON data: `spark.read.json()`
2. ✅ Explode arrays: `withColumn("col", explode("array_col"))`
3. ✅ Select nested fields: Use dot notation `"struct.field"`
4. ✅ Alias for clarity: `.alias("new_name")`
5. ✅ Repeat for multiple levels of nesting

**Benefits:**
- Simpler queries and filters
- Easier aggregations
- Better performance for analytics
- More intuitive data structure

**When to Flatten:**
- When doing analytics/aggregations
- When joining with other tables
- When nested structure is too complex

**When NOT to Flatten:**
- When preserving JSON structure for output
- When arrays represent truly hierarchical relationships
- When working with document databases

Does this comprehensive explanation clarify how to flatten nested JSON structures in Spark for analysis?