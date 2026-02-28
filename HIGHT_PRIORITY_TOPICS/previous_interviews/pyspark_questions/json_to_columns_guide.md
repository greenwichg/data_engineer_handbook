# PySpark Implementation: Convert JSON Column to Separate Columns

## Problem Statement

Given a DataFrame where one column contains **JSON strings**, parse and extract the JSON fields into separate, properly typed columns. This tests your understanding of `from_json()`, schema definition, and struct column access.

### Sample Data

```
customer_id  user_data
C001         {"name": "John", "age": 30, "city": "New York"}
C002         {"name": "Alice", "age": 25, "city": "London"}
C003         {"name": "Bob", "age": 35, "city": "Tokyo"}
```

### Expected Output

| customer_id | name  | age | city     |
|-------------|-------|-----|----------|
| C001        | John  | 30  | New York |
| C002        | Alice | 25  | London   |
| C003        | Bob   | 35  | Tokyo    |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

spark = SparkSession.builder.appName("JSONToColumns").getOrCreate()

data = [
    ("C001", '{"name": "John", "age": 30, "city": "New York"}'),
    ("C002", '{"name": "Alice", "age": 25, "city": "London"}'),
    ("C003", '{"name": "Bob", "age": 35, "city": "Tokyo"}')
]

df = spark.createDataFrame(data, ["customer_id", "user_data"])

# Step 1: Define the JSON schema
json_schema = StructType([
    StructField("name", StringType(), True),
    StructField("age", IntegerType(), True),
    StructField("city", StringType(), True)
])

# Step 2: Parse JSON string into a struct column
df_parsed = df.withColumn("parsed", from_json(col("user_data"), json_schema))

# Step 3: Extract struct fields into individual columns
df_result = df_parsed.select(
    "customer_id",
    col("parsed.name").alias("name"),
    col("parsed.age").alias("age"),
    col("parsed.city").alias("city")
)

df_result.show()
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Define JSON Schema

- **What happens:** Creates a `StructType` describing the expected JSON structure — field names, types, and nullability. This tells PySpark how to parse the JSON string.
- **Why explicit schema?** Avoids expensive schema inference, ensures correct types (`age` as integer, not string), and fails fast on malformed data.

### Step 2: Parse JSON into Struct Column

- **What happens:** `from_json(col("user_data"), json_schema)` parses each JSON string into a struct (nested object). The original column remains; a new `parsed` column is added.
- **Output (df_parsed):**

  | customer_id | user_data                                        | parsed                |
  |-------------|--------------------------------------------------|-----------------------|
  | C001        | {"name": "John", "age": 30, "city": "New York"} | {John, 30, New York}  |
  | C002        | {"name": "Alice", "age": 25, "city": "London"}  | {Alice, 25, London}   |
  | C003        | {"name": "Bob", "age": 35, "city": "Tokyo"}     | {Bob, 35, Tokyo}      |

  The `parsed` column is a single struct, not separate columns yet.

### Step 3: Extract Fields into Separate Columns

- **What happens:** Dot notation `col("parsed.name")` accesses individual struct fields. `.alias()` renames them for clean output. `select()` picks only the columns we want.
- **Output (df_result):**

  | customer_id | name  | age | city     |
  |-------------|-------|-----|----------|
  | C001        | John  | 30  | New York |
  | C002        | Alice | 25  | London   |
  | C003        | Bob   | 35  | Tokyo    |

---

## Handling Nested JSON and Arrays

### Nested JSON

```python
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

nested_schema = StructType([
    StructField("customer", StructType([
        StructField("name", StringType(), True),
        StructField("email", StringType(), True)
    ]), True),
    StructField("amount", IntegerType(), True)
])

# Access nested fields with chained dot notation
df_nested = df.withColumn("parsed", from_json(col("order_details"), nested_schema))
df_result = df_nested.select(
    "order_id",
    col("parsed.customer.name").alias("customer_name"),
    col("parsed.customer.email").alias("customer_email"),
    col("parsed.amount").alias("amount")
)
```

### JSON Arrays (with explode)

```python
from pyspark.sql.functions import explode
from pyspark.sql.types import ArrayType

array_schema = ArrayType(StructType([
    StructField("item", StringType(), True),
    StructField("price", IntegerType(), True)
]))

df_parsed = df.withColumn("orders_array", from_json(col("orders"), array_schema))
df_exploded = df_parsed.withColumn("order", explode(col("orders_array")))
df_result = df_exploded.select("customer_id", col("order.item"), col("order.price"))
```

---

## Alternative: Using Wildcard Expansion and Schema Inference

```python
from pyspark.sql.functions import schema_of_json

# Shortcut: expand all struct fields with wildcard
df_result = df_parsed.select("customer_id", "parsed.*")

# Or infer schema automatically from a sample JSON string
sample_json = '{"name": "John", "age": 30, "city": "New York"}'
inferred_schema = schema_of_json(sample_json)
df_auto = df.withColumn("parsed", from_json(col("user_data"), inferred_schema))
df_auto.select("customer_id", "parsed.*").show()
```

- `"parsed.*"` expands all struct fields automatically — no need to list each one
- `schema_of_json()` infers schema from a sample string — useful for prototyping but less efficient and may infer wrong types in production

---

## Key Interview Talking Points

1. **from_json() requires a schema:** Unlike `json.loads()` in Python, PySpark's `from_json()` needs an explicit schema (or inferred one via `schema_of_json()`). This is because Spark operates on distributed data and needs to know column types upfront for optimization.

2. **Struct vs separate columns:** `from_json()` produces a single struct column. You must explicitly extract fields using dot notation (`col("parsed.name")`) or wildcard (`"parsed.*"`). This two-step process (parse → extract) is the standard pattern.

3. **Malformed JSON handling:** Use the `mode` option: `PERMISSIVE` (default) sets malformed rows to null, `DROPMALFORMED` drops them, `FAILFAST` throws an exception. Example: `from_json(col, schema, {"mode": "PERMISSIVE"})`.

4. **Performance:** Always define schemas explicitly in production — schema inference via `schema_of_json()` requires scanning the data. For JSON arrays, `explode()` after parsing follows the same pattern as any array-to-rows transformation.
