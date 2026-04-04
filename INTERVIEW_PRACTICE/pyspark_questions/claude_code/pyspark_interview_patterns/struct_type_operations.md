# PySpark Implementation: StructType Operations

## Problem Statement

Structs are PySpark's way of representing nested/complex data within a single column. They are equivalent to a "row within a column" and are fundamental for working with JSON data, nested schemas, and complex transformations. Interviewers test your ability to create, access, manipulate, and flatten struct columns.

Key operations covered:
- Creating structs with `F.struct()`
- Accessing nested fields with dot notation and `getField()`
- Defining schemas manually with `StructType` and `StructField`
- Working with deeply nested structs
- Converting between struct columns and flat columns
- Schema evolution patterns

---

## Setup

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    DoubleType, ArrayType, MapType, BooleanType, TimestampType
)

spark = SparkSession.builder \
    .appName("StructType Operations") \
    .master("local[*]") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")
```

---

## Part 1: Creating Structs with F.struct()

### Sample Data

```python
data = [
    (1, "Alice",   "Smith",   "Engineering", 95000),
    (2, "Bob",     "Johnson", "Sales",       82000),
    (3, "Charlie", "Brown",   "Engineering", 105000),
    (4, "Diana",   "Prince",  "Marketing",   78000),
]

df = spark.createDataFrame(data, ["id", "first_name", "last_name", "dept", "salary"])
df.show(truncate=False)
```

```
+---+----------+---------+-----------+------+
|id |first_name|last_name|dept       |salary|
+---+----------+---------+-----------+------+
|1  |Alice     |Smith    |Engineering|95000 |
|2  |Bob       |Johnson  |Sales      |82000 |
|3  |Charlie   |Brown    |Engineering|105000|
|4  |Diana     |Prince   |Marketing  |78000 |
+---+----------+---------+-----------+------+
```

### Method 1: Create a struct column from existing columns

```python
df_with_struct = df.withColumn(
    "full_name",
    F.struct(
        F.col("first_name").alias("first"),
        F.col("last_name").alias("last"),
    )
).drop("first_name", "last_name")

df_with_struct.show(truncate=False)
df_with_struct.printSchema()
```

### Expected Output

```
+---+-----------+------+------------------+
|id |dept       |salary|full_name         |
+---+-----------+------+------------------+
|1  |Engineering|95000 |{Alice, Smith}    |
|2  |Sales      |82000 |{Bob, Johnson}    |
|3  |Engineering|105000|{Charlie, Brown}  |
|4  |Marketing  |78000 |{Diana, Prince}   |
+---+-----------+------+------------------+

root
 |-- id: long (nullable = true)
 |-- dept: string (nullable = true)
 |-- salary: long (nullable = true)
 |-- full_name: struct (nullable = false)
 |    |-- first: string (nullable = true)
 |    |-- last: string (nullable = true)
```

### Method 2: Create a struct without aliasing (uses original column names)

```python
df_struct_default = df.withColumn(
    "name_info",
    F.struct("first_name", "last_name")
)
df_struct_default.printSchema()
```

```
root
 |-- ...
 |-- name_info: struct (nullable = false)
 |    |-- first_name: string (nullable = true)
 |    |-- last_name: string (nullable = true)
```

### Method 3: Create nested structs

```python
df_nested = df.select(
    "id",
    F.struct(
        F.col("first_name").alias("first"),
        F.col("last_name").alias("last"),
    ).alias("name"),
    F.struct(
        F.col("dept").alias("department"),
        F.col("salary"),
        F.struct(
            (F.col("salary") / 12).cast("int").alias("monthly"),
            (F.col("salary") / 52).cast("int").alias("weekly"),
        ).alias("pay_breakdown"),
    ).alias("employment"),
)

df_nested.show(truncate=False)
df_nested.printSchema()
```

### Expected Output

```
root
 |-- id: long (nullable = true)
 |-- name: struct (nullable = false)
 |    |-- first: string (nullable = true)
 |    |-- last: string (nullable = true)
 |-- employment: struct (nullable = false)
 |    |-- department: string (nullable = true)
 |    |-- salary: long (nullable = true)
 |    |-- pay_breakdown: struct (nullable = false)
 |    |    |-- monthly: integer (nullable = true)
 |    |    |-- weekly: integer (nullable = true)
```

---

## Part 2: Accessing Nested Fields

### Sample Data (Using df_nested from above)

### Method 1: Dot notation (most common)

```python
df_nested.select(
    "id",
    "name.first",
    "name.last",
    "employment.department",
    "employment.salary",
    "employment.pay_breakdown.monthly",
).show(truncate=False)
```

### Expected Output

```
+---+-------+------+-----------+------+-------+
|id |first  |last  |department |salary|monthly|
+---+-------+------+-----------+------+-------+
|1  |Alice  |Smith |Engineering|95000 |7916   |
|2  |Bob    |Johnson|Sales     |82000 |6833   |
|3  |Charlie|Brown |Engineering|105000|8750   |
|4  |Diana  |Prince|Marketing  |78000 |6500   |
+---+-------+------+-----------+------+-------+
```

### Method 2: getField() -- useful for dynamic field access

```python
df_nested.select(
    "id",
    F.col("name").getField("first").alias("first_name"),
    F.col("employment").getField("pay_breakdown").getField("monthly").alias("monthly_pay"),
).show(truncate=False)
```

### Method 3: Using bracket notation with getItem (for maps) vs getField (for structs)

```python
# getField for structs
df_nested.select(
    F.col("name").getField("first"),
).show()

# Dot notation equivalent -- preferred for readability
df_nested.select(
    F.col("name.first"),
).show()
```

### Method 4: Wildcard star to expand all struct fields

```python
# Expand all fields of a struct into separate columns
df_nested.select("id", "name.*").show(truncate=False)
```

### Expected Output

```
+---+-------+-------+
|id |first  |last   |
+---+-------+-------+
|1  |Alice  |Smith  |
|2  |Bob    |Johnson|
|3  |Charlie|Brown  |
|4  |Diana  |Prince |
+---+-------+-------+
```

---

## Part 3: Defining Schemas Manually with StructType

### Method 1: Full manual schema definition

```python
manual_schema = StructType([
    StructField("user_id", IntegerType(), nullable=False),
    StructField("profile", StructType([
        StructField("name", StringType(), nullable=True),
        StructField("age", IntegerType(), nullable=True),
        StructField("active", BooleanType(), nullable=True),
    ]), nullable=True),
    StructField("scores", ArrayType(IntegerType()), nullable=True),
    StructField("metadata", MapType(StringType(), StringType()), nullable=True),
])

data_manual = [
    (1, ("Alice", 30, True),   [90, 85, 92], {"role": "admin"}),
    (2, ("Bob",   25, False),  [78, 82],     {"role": "user"}),
    (3, ("Charlie", 35, True), None,          None),
]

df_manual = spark.createDataFrame(data_manual, manual_schema)
df_manual.show(truncate=False)
df_manual.printSchema()
```

### Expected Output

```
+-------+-------------------+------------+-----------------+
|user_id|profile            |scores      |metadata         |
+-------+-------------------+------------+-----------------+
|1      |{Alice, 30, true}  |[90, 85, 92]|{role -> admin}  |
|2      |{Bob, 25, false}   |[78, 82]    |{role -> user}   |
|3      |{Charlie, 35, true}|null        |null             |
+-------+-------------------+------------+-----------------+
```

### Method 2: Schema from DDL string

```python
ddl_schema = "user_id INT, name STRING, score DOUBLE, tags ARRAY<STRING>"
df_ddl = spark.createDataFrame(
    [(1, "Alice", 95.5, ["python", "spark"])],
    schema=ddl_schema,
)
df_ddl.printSchema()
```

### Method 3: Schema from JSON (useful for schema registry integration)

```python
import json

# Extract schema as JSON
schema_json = df_manual.schema.json()
print(json.dumps(json.loads(schema_json), indent=2))

# Reconstruct schema from JSON
reconstructed_schema = StructType.fromJson(json.loads(schema_json))
print(reconstructed_schema)
```

---

## Part 4: Converting Between Structs and Flat Columns

### Flattening structs (struct -> individual columns)

```python
# Recursive flatten function -- common interview question
def flatten_struct(df, separator="_"):
    """Recursively flatten all struct columns in a DataFrame."""
    flat_cols = []
    for field in df.schema.fields:
        if isinstance(field.dataType, StructType):
            for sub_field in field.dataType.fields:
                flat_cols.append(
                    F.col(f"{field.name}.{sub_field.name}")
                    .alias(f"{field.name}{separator}{sub_field.name}")
                )
        else:
            flat_cols.append(F.col(field.name))
    
    df_flat = df.select(flat_cols)
    
    # Check if there are still structs to flatten
    has_structs = any(
        isinstance(f.dataType, StructType) for f in df_flat.schema.fields
    )
    if has_structs:
        return flatten_struct(df_flat, separator)
    return df_flat


df_flat = flatten_struct(df_nested)
df_flat.show(truncate=False)
df_flat.printSchema()
```

### Expected Output

```
+---+----------+---------+------------------------+-------------------+------------------------------+-----------------------------+
|id |name_first|name_last|employment_department   |employment_salary  |employment_pay_breakdown_monthly|employment_pay_breakdown_weekly|
+---+----------+---------+------------------------+-------------------+------------------------------+-----------------------------+
|1  |Alice     |Smith    |Engineering             |95000              |7916                          |1826                         |
|2  |Bob       |Johnson  |Sales                   |82000              |6833                          |1576                         |
|3  |Charlie   |Brown    |Engineering             |105000             |8750                          |2019                         |
|4  |Diana     |Prince   |Marketing               |78000              |6500                          |1500                         |
+---+----------+---------+------------------------+-------------------+------------------------------+-----------------------------+
```

### Re-nesting flat columns into structs

```python
# Go from flat back to nested
df_renested = df_flat.select(
    "id",
    F.struct(
        F.col("name_first").alias("first"),
        F.col("name_last").alias("last"),
    ).alias("name"),
    F.struct(
        F.col("employment_department").alias("department"),
        F.col("employment_salary").alias("salary"),
    ).alias("employment"),
)

df_renested.show(truncate=False)
```

---

## Part 5: Adding and Dropping Fields in Structs

### Method 1: withField() -- Add or replace a field inside a struct (Spark 3.1+)

```python
# Add a new field to the name struct
df_updated = df_nested.withColumn(
    "name",
    F.col("name").withField(
        "full",
        F.concat_ws(" ", F.col("name.first"), F.col("name.last"))
    )
)
df_updated.select("id", "name").show(truncate=False)
```

### Expected Output

```
+---+---------------------------+
|id |name                       |
+---+---------------------------+
|1  |{Alice, Smith, Alice Smith}|
|2  |{Bob, Johnson, Bob Johnson}|
|3  |{Charlie, Brown, Charlie Brown}|
|4  |{Diana, Prince, Diana Prince}|
+---+---------------------------+
```

### Method 2: dropFields() -- Remove a field from a struct (Spark 3.1+)

```python
df_dropped = df_nested.withColumn(
    "employment",
    F.col("employment").dropFields("pay_breakdown")
)
df_dropped.printSchema()
```

```
root
 |-- id: long (nullable = true)
 |-- name: struct (nullable = false)
 |    |-- first: string (nullable = true)
 |    |-- last: string (nullable = true)
 |-- employment: struct (nullable = false)
 |    |-- department: string (nullable = true)
 |    |-- salary: long (nullable = true)
```

### Method 3: Rebuild struct manually (works on all Spark versions)

```python
# Add a field by reconstructing the struct
df_rebuilt = df_nested.withColumn(
    "name",
    F.struct(
        F.col("name.first"),
        F.col("name.last"),
        F.concat_ws(" ", F.col("name.first"), F.col("name.last")).alias("full"),
    )
)
```

---

## Part 6: Working with Arrays of Structs

```python
orders_data = [
    (1, "Alice", [("laptop", 999.99, 1), ("mouse", 29.99, 2)]),
    (2, "Bob",   [("keyboard", 79.99, 1)]),
    (3, "Charlie", []),
]

orders_schema = StructType([
    StructField("id", IntegerType()),
    StructField("name", StringType()),
    StructField("items", ArrayType(StructType([
        StructField("product", StringType()),
        StructField("price", DoubleType()),
        StructField("qty", IntegerType()),
    ]))),
])

df_orders = spark.createDataFrame(orders_data, orders_schema)
df_orders.show(truncate=False)
```

### Accessing fields inside array of structs

```python
# Get all product names as an array
df_orders.select(
    "id", "name",
    F.col("items.product").alias("products"),     # extracts field from each struct
    F.col("items.price").alias("prices"),
).show(truncate=False)
```

### Expected Output

```
+---+-------+------------------+---------------+
|id |name   |products          |prices         |
+---+-------+------------------+---------------+
|1  |Alice  |[laptop, mouse]   |[999.99, 29.99]|
|2  |Bob    |[keyboard]        |[79.99]        |
|3  |Charlie|[]                |[]             |
+---+-------+------------------+---------------+
```

### Transform array of structs

```python
# Add a total_cost field to each item struct
df_orders.withColumn(
    "items_with_total",
    F.transform("items", lambda x: F.struct(
        x["product"].alias("product"),
        x["price"].alias("price"),
        x["qty"].alias("qty"),
        (x["price"] * x["qty"]).alias("total_cost"),
    ))
).show(truncate=False)
```

### Filter array of structs

```python
# Keep only items where price > 50
df_orders.withColumn(
    "expensive_items",
    F.filter("items", lambda x: x["price"] > 50)
).show(truncate=False)
```

### Aggregate within array of structs

```python
# Calculate total order value
df_orders.withColumn(
    "order_total",
    F.aggregate(
        "items",
        F.lit(0.0).cast("double"),
        lambda acc, x: acc + (x["price"] * x["qty"])
    )
).show(truncate=False)
```

### Expected Output

```
+---+-------+----------------------------------------------+-----------+
|id |name   |items                                         |order_total|
+---+-------+----------------------------------------------+-----------+
|1  |Alice  |[{laptop, 999.99, 1}, {mouse, 29.99, 2}]     |1059.97    |
|2  |Bob    |[{keyboard, 79.99, 1}]                        |79.99      |
|3  |Charlie|[]                                            |0.0        |
+---+-------+----------------------------------------------+-----------+
```

---

## Part 7: Schema Comparison and Merging

```python
# Common scenario: two DataFrames with slightly different struct schemas
df_v1 = spark.createDataFrame(
    [(1, ("Alice", 30))],
    StructType([
        StructField("id", IntegerType()),
        StructField("info", StructType([
            StructField("name", StringType()),
            StructField("age", IntegerType()),
        ])),
    ])
)

df_v2 = spark.createDataFrame(
    [(2, ("Bob", 25, "NYC"))],
    StructType([
        StructField("id", IntegerType()),
        StructField("info", StructType([
            StructField("name", StringType()),
            StructField("age", IntegerType()),
            StructField("city", StringType()),
        ])),
    ])
)

# Union requires matching schemas -- add missing field to v1
df_v1_updated = df_v1.withColumn(
    "info",
    F.col("info").withField("city", F.lit(None).cast("string"))
)

df_v1_updated.unionByName(df_v2).show(truncate=False)
```

### Expected Output

```
+---+----------------+
|id |info            |
+---+----------------+
|1  |{Alice, 30, null}|
|2  |{Bob, 25, NYC}  |
+---+----------------+
```

---

## Interview Tips

1. **Dot notation vs getField():** Both work for accessing struct fields. Dot notation (`col("struct.field")`) is more readable. `getField()` is useful when the field name is dynamic or stored in a variable.

2. **`select("struct.*")`** is the quickest way to expand a struct into top-level columns. This is a very common interview question.

3. **`withField()` and `dropFields()`** (Spark 3.1+) are the clean way to modify structs in-place. For older versions, you must reconstruct the entire struct.

4. **Recursive flattening** is a classic interview coding question. Know how to write it from scratch using `schema.fields` and `isinstance(field.dataType, StructType)`.

5. **Arrays of structs** are extremely common with JSON data. Know `F.transform()`, `F.filter()`, `F.aggregate()`, and the `.field_name` extraction pattern.

6. **Schema definition:** In production, always define schemas explicitly rather than relying on inference. Inference reads data twice and can guess wrong types (e.g., integer vs long).

7. **NULL structs vs structs with NULL fields:** A struct column can be NULL (the whole struct is missing), or individual fields within the struct can be NULL. These are different. `df.filter(F.col("struct_col").isNull())` checks the whole struct.
