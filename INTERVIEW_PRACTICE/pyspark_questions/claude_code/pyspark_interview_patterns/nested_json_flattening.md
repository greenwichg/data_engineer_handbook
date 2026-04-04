# PySpark Implementation: Deeply Nested JSON Flattening

## Problem Statement

Given a DataFrame with deeply nested JSON data (structs within structs, arrays of structs), **flatten it into a simple tabular format** suitable for analysis. This tests your understanding of PySpark's complex types (`StructType`, `ArrayType`, `MapType`) and the `explode` + dot-notation patterns needed to handle real-world nested data from APIs, NoSQL databases, and event streams.

### Sample Data (Nested JSON)

```json
{
    "order_id": "ORD001",
    "customer": {
        "id": "C001",
        "name": "Alice Smith",
        "address": {
            "city": "New York",
            "state": "NY",
            "zip": "10001"
        }
    },
    "items": [
        {"product": "Laptop", "qty": 1, "price": 1200.00},
        {"product": "Mouse", "qty": 2, "price": 25.00}
    ],
    "payment": {
        "method": "credit_card",
        "details": {
            "last_four": "4532",
            "exp_date": "12/26"
        }
    }
}
```

### Expected Output (Flattened)

| order_id | cust_id | cust_name   | city     | state | zip   | product | qty | price  | pay_method  | card_last_four |
|----------|---------|-------------|----------|-------|-------|---------|-----|--------|-------------|----------------|
| ORD001   | C001    | Alice Smith | New York | NY    | 10001 | Laptop  | 1   | 1200.0 | credit_card | 4532           |
| ORD001   | C001    | Alice Smith | New York | NY    | 10001 | Mouse   | 2   | 25.0   | credit_card | 4532           |

---

## Method 1: Manual Flattening with Dot Notation + Explode

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, explode
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, \
    DoubleType, ArrayType

# Initialize Spark session
spark = SparkSession.builder.appName("NestedJSON").getOrCreate()

# Define schema for the nested JSON
schema = StructType([
    StructField("order_id", StringType()),
    StructField("customer", StructType([
        StructField("id", StringType()),
        StructField("name", StringType()),
        StructField("address", StructType([
            StructField("city", StringType()),
            StructField("state", StringType()),
            StructField("zip", StringType())
        ]))
    ])),
    StructField("items", ArrayType(StructType([
        StructField("product", StringType()),
        StructField("qty", IntegerType()),
        StructField("price", DoubleType())
    ]))),
    StructField("payment", StructType([
        StructField("method", StringType()),
        StructField("details", StructType([
            StructField("last_four", StringType()),
            StructField("exp_date", StringType())
        ]))
    ]))
])

# Sample data as JSON string
json_data = [
    ('{"order_id":"ORD001","customer":{"id":"C001","name":"Alice Smith","address":{"city":"New York","state":"NY","zip":"10001"}},"items":[{"product":"Laptop","qty":1,"price":1200.0},{"product":"Mouse","qty":2,"price":25.0}],"payment":{"method":"credit_card","details":{"last_four":"4532","exp_date":"12/26"}}}',),
    ('{"order_id":"ORD002","customer":{"id":"C002","name":"Bob Jones","address":{"city":"Chicago","state":"IL","zip":"60601"}},"items":[{"product":"Monitor","qty":1,"price":450.0}],"payment":{"method":"debit_card","details":{"last_four":"7890","exp_date":"03/27"}}}',)
]

# Create DataFrame and parse JSON
from pyspark.sql.functions import from_json

raw_df = spark.createDataFrame(json_data, ["raw_json"])
parsed_df = raw_df.withColumn("data", from_json(col("raw_json"), schema))

# Step 1: Extract nested struct fields using dot notation
flat_structs = parsed_df.select(
    col("data.order_id").alias("order_id"),
    col("data.customer.id").alias("cust_id"),
    col("data.customer.name").alias("cust_name"),
    col("data.customer.address.city").alias("city"),
    col("data.customer.address.state").alias("state"),
    col("data.customer.address.zip").alias("zip"),
    col("data.items").alias("items"),
    col("data.payment.method").alias("pay_method"),
    col("data.payment.details.last_four").alias("card_last_four")
)

# Step 2: Explode the items array
flattened = flat_structs.withColumn("item", explode(col("items"))) \
    .select(
        "order_id", "cust_id", "cust_name", "city", "state", "zip",
        col("item.product").alias("product"),
        col("item.qty").alias("qty"),
        col("item.price").alias("price"),
        "pay_method", "card_last_four"
    )

flattened.show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Dot Notation for Nested Structs
```python
col("data.customer.address.city")
```
- Access nested fields by chaining dots: `parent.child.grandchild`
- Works for any depth of nesting
- Returns `null` if any intermediate level is null

#### Step 2: Explode for Arrays
```python
explode(col("items"))  # Array of structs → one row per struct
col("item.product")    # Access struct field within the exploded result
```

- **Before explode:** 1 row with `items = [{Laptop, 1, 1200}, {Mouse, 2, 25}]`
- **After explode:** 2 rows, one per item

- **Output:**

  | order_id | cust_id | cust_name   | city     | state | zip   | product | qty | price  | pay_method  | card_last_four |
  |----------|---------|-------------|----------|-------|-------|---------|-----|--------|-------------|----------------|
  | ORD001   | C001    | Alice Smith | New York | NY    | 10001 | Laptop  | 1   | 1200.0 | credit_card | 4532           |
  | ORD001   | C001    | Alice Smith | New York | NY    | 10001 | Mouse   | 2   | 25.0   | credit_card | 4532           |
  | ORD002   | C002    | Bob Jones   | Chicago  | IL    | 60601 | Monitor | 1   | 450.0  | debit_card  | 7890           |

---

## Method 2: Generic Recursive Flattening Function

```python
from pyspark.sql.types import StructType, ArrayType

def flatten_df(df, prefix=""):
    """Recursively flatten all nested structs in a DataFrame."""
    flat_cols = []
    for field in df.schema.fields:
        col_name = f"{prefix}{field.name}" if prefix else field.name
        full_path = f"{prefix}{field.name}" if prefix else field.name

        if isinstance(field.dataType, StructType):
            # Recursively flatten structs
            nested = df.select(f"{full_path}.*")
            for nested_field in field.dataType.fields:
                nested_name = f"{col_name}_{nested_field.name}"
                flat_cols.append(col(f"{full_path}.{nested_field.name}").alias(nested_name))
        elif isinstance(field.dataType, ArrayType):
            # Keep arrays as-is (handle separately with explode)
            flat_cols.append(col(full_path).alias(col_name))
        else:
            flat_cols.append(col(full_path).alias(col_name))

    return df.select(flat_cols)

# Apply to our parsed data
data_df = parsed_df.select("data.*")

# First pass: flatten top-level structs
flat_pass1 = flatten_df(data_df)
flat_pass1.printSchema()
flat_pass1.show(truncate=False)
```

### Deep Recursive Version

```python
def deep_flatten(df):
    """Fully flatten all nested structs regardless of depth."""
    complex_fields = True

    while complex_fields:
        complex_fields = False
        new_cols = []

        for field in df.schema.fields:
            if isinstance(field.dataType, StructType):
                complex_fields = True
                for nested in field.dataType.fields:
                    new_cols.append(
                        col(f"`{field.name}`.`{nested.name}`")
                        .alias(f"{field.name}_{nested.name}")
                    )
            else:
                new_cols.append(col(f"`{field.name}`"))

        df = df.select(new_cols)

    return df

# Usage
data_df = parsed_df.select("data.*")
fully_flat = deep_flatten(data_df)
fully_flat.printSchema()
```

- **Output schema:**
  ```
  root
   |-- order_id: string
   |-- customer_id: string
   |-- customer_name: string
   |-- customer_address_city: string
   |-- customer_address_state: string
   |-- customer_address_zip: string
   |-- items: array<struct>
   |-- payment_method: string
   |-- payment_details_last_four: string
   |-- payment_details_exp_date: string
  ```

Then explode `items` separately.

---

## Method 3: Handling Maps (Key-Value Pairs)

```python
from pyspark.sql.functions import explode, map_keys, map_values, create_map

# Data with map type
map_data = [
    ("U001", {"email": "alice@test.com", "phone": "555-0001"}),
    ("U002", {"email": "bob@test.com", "slack": "@bob"})
]
map_df = spark.createDataFrame(map_data, ["user_id", "contacts"])

# Option 1: Explode map to key-value rows
map_df.select("user_id", explode("contacts")).show(truncate=False)
```

- **Output:**

  | user_id | key   | value          |
  |---------|-------|----------------|
  | U001    | email | alice@test.com |
  | U001    | phone | 555-0001       |
  | U002    | email | bob@test.com   |
  | U002    | slack | @bob           |

```python
# Option 2: Access specific map keys
map_df.select(
    "user_id",
    col("contacts")["email"].alias("email"),
    col("contacts")["phone"].alias("phone")
).show(truncate=False)
```

- **Output:**

  | user_id | email          | phone    |
  |---------|----------------|----------|
  | U001    | alice@test.com | 555-0001 |
  | U002    | bob@test.com   | null     |

---

## Method 4: Arrays of Arrays (Double Explode)

```python
# Nested arrays: departments → teams → members
nested_data = [
    ("Company A", [
        {"dept": "Engineering", "members": ["Alice", "Bob"]},
        {"dept": "Sales", "members": ["Charlie"]}
    ])
]

nested_schema = StructType([
    StructField("company", StringType()),
    StructField("departments", ArrayType(StructType([
        StructField("dept", StringType()),
        StructField("members", ArrayType(StringType()))
    ])))
])

nested_df = spark.createDataFrame(nested_data, nested_schema)

# Double explode: first departments, then members
flat_members = nested_df \
    .withColumn("department", explode("departments")) \
    .withColumn("member", explode("department.members")) \
    .select("company", col("department.dept").alias("dept"), "member")

flat_members.show(truncate=False)
```

- **Output:**

  | company   | dept        | member  |
  |-----------|-------------|---------|
  | Company A | Engineering | Alice   |
  | Company A | Engineering | Bob     |
  | Company A | Sales       | Charlie |

---

## Method 5: Reading Nested JSON Files Directly

```python
# Read JSON files with auto-inferred schema
df_auto = spark.read.json("/path/to/nested_data.json")
df_auto.printSchema()  # See the inferred nested schema

# Read with explicit schema (recommended for production)
df_explicit = spark.read.schema(schema).json("/path/to/nested_data.json")

# Read multiline JSON (single object per file)
df_multiline = spark.read.option("multiline", "true").json("/path/to/data.json")
```

---

## Quick Reference: Complex Type Operations

| Operation | Syntax | Result |
|-----------|--------|--------|
| Access struct field | `col("struct.field")` | Single value |
| Access nested struct | `col("a.b.c")` | Deep nested value |
| Explode array | `explode(col("array"))` | One row per element |
| Explode array (keep nulls) | `explode_outer(col("array"))` | Keeps null rows |
| Access map value | `col("map")["key"]` | Value for key |
| Explode map | `explode(col("map"))` | key, value columns |
| Array element by index | `col("array")[0]` | First element |
| Array size | `size(col("array"))` | Element count |
| Flatten nested arrays | `flatten(col("array_of_arrays"))` | Single array |
| Struct to columns | `df.select("struct.*")` | Expands struct |

## Key Interview Talking Points

1. **Dot notation is your primary tool:** `col("parent.child.grandchild")` navigates any depth of struct nesting without UDFs or special functions.

2. **Explode for arrays, dot notation for structs:** These two patterns together handle 95% of nested data. Use `explode_outer` if you need to preserve rows with null/empty arrays.

3. **Schema-on-read:** Always define explicit schemas for JSON data in production. Auto-inference reads the entire file and may infer wrong types (e.g., integer vs long, nullable mismatches).

4. **Cartesian explosion warning:** Multiple `explode` calls create a Cartesian product. If you have 3 items and 2 payments per order, you get 6 rows. Use `posexplode` to track array indices and join back correctly.

5. **Common sources of nested data:**
   - REST API responses (JSON)
   - MongoDB/DynamoDB exports
   - Kafka event streams
   - Parquet files with nested schemas
   - Log data with embedded JSON fields

6. **Performance tip:** Flatten early in the pipeline. Operating on flat DataFrames is faster than repeated nested access because Spark's Catalyst optimizer works better with flat schemas.
