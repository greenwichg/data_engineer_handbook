## PySpark Complex JSON Handling - Complete Cheat Sheet
### TABLE OF CONTENTS
	01. Flattening Nested Structs
	02. Exploding Arrays
	03. Parsing JSON Strings (from_json)
	04. Multi-Level Nested Flattening
	05. Handling Arrays of Structs
	06. Programmatic / Recursive Flattening
	07. Null-Safe JSON Handling
	08. JSON String Extraction (get_json_object / json_tuple)
	09. Building JSON (to_json / struct)
	10. Schema Inference vs Explicit Schema
	11. Map Type & Dynamic Keys
	12. Performance Optimization for JSON
	13. Semi-Structured Data (Mixed Types)
	14. Real-World E-Commerce JSON Pipeline
	15. Deeply Nested JSON (3+ Levels)
	16. JSON Arrays at Root Level
	17. Handling Malformed / Corrupt JSON
	18. JSON Diffing & Change Detection

---

### 1. Flattening Nested Structs
#### Trigger Words
	- "nested object", "struct fields", "dot notation", "expand struct"
	- "flatten object", "extract nested fields", "denormalize JSON"

**Key Pattern**

```python
from pyspark.sql.functions import col

# Method 1: Dot notation with alias
df_flat = df.select(
    "id",
    col("address.street").alias("street"),
    col("address.city").alias("city"),
    col("address.zipcode").alias("zipcode")
)

# Method 2: Star expansion (all struct fields)
df_flat = df.select("id", "name", "address.*")
```

### Function Choice Matrix

|Need                          |Use                          |Result                          |
|------------------------------|-----------------------------|--------------------------------|
|Extract one nested field      |`col("struct.field")`        |Single column                   |
|Extract all struct fields     |`select("struct.*")`         |All sub-fields as top columns   |
|Rename while extracting       |`col("s.f").alias("new")`    |Renamed column                  |
|SQL-style extraction          |`selectExpr("s.f as new")`   |Same as alias approach          |
|Nested struct (2+ levels)     |`col("a.b.c")`              |Drills through multiple levels  |

### Examples
```python
from pyspark.sql.functions import col

# Example 1: Simple struct flattening
df.select(
    "customer_id",
    col("address.street").alias("street"),
    col("address.city").alias("city")
).show()

# Example 2: Star expansion
df.select("customer_id", "name", "address.*").show()
# Result: customer_id | name | street | city | zipcode

# Example 3: Multi-level struct
df.select(
    "order_id",
    col("shipping.address.street").alias("ship_street"),
    col("shipping.address.city").alias("ship_city"),
    col("shipping.address.state").alias("ship_state")
).show()

# Example 4: selectExpr approach
df.selectExpr(
    "customer_id",
    "address.street as street",
    "address.city as city",
    "address.zipcode as zip"
).show()
```

### Pitfalls
- `select("struct.*")` fails if the column is not a StructType
- Dot notation returns NULL silently if the field doesn't exist — no error thrown
- Column name collisions when two structs have same sub-field names

---

### 2. Exploding Arrays
#### Trigger Words
	- "array column", "list of items", "one row per element"
	- "explode", "unnest", "expand array", "flatten array"

**Key Pattern**

```python
from pyspark.sql.functions import explode, explode_outer, posexplode

# Basic explode — drops rows with null/empty arrays
df_exploded = df.withColumn("item", explode("items"))

# Null-safe — keeps rows even if array is null/empty
df_exploded = df.withColumn("item", explode_outer("items"))

# With position index
df_exploded = df.select("id", posexplode("items").alias("pos", "item"))
```

### Function Choice Matrix

|Need                            |Use                |Null/Empty Array Behavior       |
|--------------------------------|-------------------|--------------------------------|
|One row per element             |`explode()`        |Row is DROPPED                  |
|Keep rows with null/empty arrays|`explode_outer()`  |Row kept, value = NULL          |
|Element + index position        |`posexplode()`     |Row is DROPPED                  |
|Element + index, null-safe      |`posexplode_outer()`|Row kept, pos & val = NULL     |

### Examples
```python
from pyspark.sql.functions import explode, explode_outer, posexplode

# Example 1: Basic explode
# Before: Row(id=1, tags=["python","spark","sql"])
df.withColumn("tag", explode("tags")).show()
# After: 3 rows — (1,"python"), (1,"spark"), (1,"sql")

# Example 2: Null-safe explode
# Before: Row(id=2, tags=None)
df.withColumn("tag", explode_outer("tags")).show()
# After: (2, NULL) — row preserved!

# Example 3: With position
df.select("id", posexplode("tags").alias("idx", "tag")).show()
# Result: (1,0,"python"), (1,1,"spark"), (1,2,"sql")

# Example 4: Chained explode (array inside array)
df_flat = (df
    .withColumn("order", explode("orders"))
    .withColumn("item", explode("order.items"))
)
```

### Pitfalls
- `explode()` silently drops rows with NULL or empty arrays — data loss risk
- Chained explodes cause row multiplication (cartesian-like growth)
- Always count rows before and after to verify: `df.count()` vs `df_exploded.count()`

---

### 3. Parsing JSON Strings (from_json)
#### Trigger Words
	- "JSON string column", "parse JSON", "string to struct"
	- "from_json", "JSON in column", "extract from JSON string"

**Key Pattern**

```python
from pyspark.sql.functions import from_json
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

# Step 1: Define schema
schema = StructType([
    StructField("name", StringType(), True),
    StructField("age", IntegerType(), True)
])

# Step 2: Parse JSON string → struct
df = df.withColumn("parsed", from_json("json_column", schema))

# Step 3: Expand struct to columns
df_flat = df.select("id", "parsed.*")
```

### Function Choice Matrix

|Need                          |Use                          |Returns                         |
|------------------------------|-----------------------------|--------------------------------|
|Parse JSON string → struct    |`from_json(col, schema)`     |StructType column               |
|Extract single JSON field     |`get_json_object(col, path)` |String value                    |
|Extract multiple JSON fields  |`json_tuple(col, keys...)`   |Multiple string columns         |
|Convert struct → JSON string  |`to_json(col)`               |JSON string                     |
|Infer schema from JSON column |`schema_of_json(sample)`     |DDL schema string               |

### Examples
```python
from pyspark.sql.functions import from_json, col
from pyspark.sql.types import StructType, StructField, StringType

# Example 1: Parse simple JSON string
schema = StructType([
    StructField("name", StringType(), True),
    StructField("age", StringType(), True)
])
df = df.withColumn("parsed", from_json("json_col", schema))
df.select("id", "parsed.*").show()

# Example 2: Using DDL string instead of StructType
df = df.withColumn("parsed", from_json("json_col", "name STRING, age INT"))
df.select("id", "parsed.*").show()

# Example 3: Schema inference from sample
from pyspark.sql.functions import schema_of_json
sample = '{"name":"Alice","age":25,"city":"NYC"}'
inferred_schema = schema_of_json(sample)
df = df.withColumn("parsed", from_json("json_col", inferred_schema))

# Example 4: JSON array string
from pyspark.sql.types import ArrayType
arr_schema = ArrayType(StructType([
    StructField("product", StringType(), True),
    StructField("price", IntegerType(), True)
]))
df = df.withColumn("items", from_json("items_json", arr_schema))
df = df.withColumn("item", explode("items"))
```

### Pitfalls
- Schema mismatch → entire column becomes NULL (no error, silent failure)
- `from_json` requires exact field names — case-sensitive
- Always validate with `.printSchema()` after parsing
- DDL strings use SQL types (`STRING`, `INT`), not Python types

---

### 4. Multi-Level Nested Flattening
#### Trigger Words
	- "deeply nested", "nested arrays", "arrays of structs"
	- "multi-level", "struct inside array", "step-by-step flattening"

**Key Pattern**

```python
from pyspark.sql.functions import explode, col

# Template: Flatten level by level
df_flat = (df
    .withColumn("level1", explode("array_col"))            # Explode L1
    .withColumn("level2", explode("level1.nested_array"))  # Explode L2
    .select(
        "top_field",
        col("level1.field_a").alias("field_a"),            # L1 struct
        col("level2.field_x").alias("field_x"),            # L2 struct
        col("level2.field_y").alias("field_y")             # L2 struct
    )
)
```

### Decision Matrix

|Nesting Pattern              |Strategy                                |
|-----------------------------|----------------------------------------|
|`struct`                     |Dot notation: `col("a.b")`             |
|`array<primitive>`           |`explode("col")`                        |
|`array<struct>`              |`explode()` then dot notation           |
|`array<array<T>>`            |`flatten()` then `explode()`            |
|`struct<struct<T>>`          |Chain dot notation: `col("a.b.c")`     |
|`array<struct<array<T>>>`   |`explode()` → dot → `explode()` again  |
|`map<K,V>`                   |`explode()` gives `key`, `value` cols   |

### Examples
```python
from pyspark.sql.functions import explode, col, flatten

# Example 1: Customer → Orders → Items (3-level)
df_flat = (df
    .withColumn("order", explode("orders"))
    .withColumn("item", explode("order.items"))
    .select(
        "customer_id", "name",
        col("order.order_id").alias("order_id"),
        col("item.product").alias("product"),
        col("item.price").alias("price"),
        col("address.street").alias("street"),
        col("address.city").alias("city")
    )
)

# Example 2: Array of arrays → flatten first
# Schema: tags: array<array<string>>
df_flat = df.withColumn("tags_flat", flatten("tags"))  # [[a,b],[c]] → [a,b,c]
df_flat = df_flat.withColumn("tag", explode("tags_flat"))

# Example 3: Selective explode (only one level)
df_orders = df.withColumn("order", explode("orders"))
# Keep items as array, don't explode further
df_orders.select(
    "customer_id",
    col("order.order_id").alias("order_id"),
    col("order.items").alias("items_array")  # Still nested
).show()
```

### Pitfalls
- Row multiplication compounds at each level: 10 orders × 5 items = 50 rows per customer
- Always `explode` from outermost array inward
- `flatten()` only works on `array<array<T>>`, not on structs

---

### 5. Handling Arrays of Structs
#### Trigger Words
	- "array of objects", "list of records", "struct array"
	- "access element in array", "filter array", "transform array"

**Key Pattern**

```python
from pyspark.sql.functions import explode, col, transform, filter, size, element_at

# Explode approach (creates rows)
df.withColumn("elem", explode("arr_col")).select("elem.*")

# Non-explode approach (keeps row count)
df.select(col("arr_col")[0].alias("first_elem"))         # Index access
df.select(element_at("arr_col", 1).alias("first_elem"))  # 1-based index
```

### Function Choice Matrix

|Need                               |Use                                     |Row Count Change|
|-----------------------------------|----------------------------------------|----------------|
|One row per array element          |`explode()`                             |Increases        |
|Access specific index              |`col("arr")[0]` or `element_at()`       |Same             |
|Transform each element             |`transform("arr", lambda x: ...)`       |Same             |
|Filter elements in array           |`filter("arr", lambda x: ...)`          |Same             |
|Check if array contains value      |`array_contains("arr", val)`            |Same             |
|Get array length                   |`size("arr")`                           |Same             |
|Sort array elements                |`sort_array("arr")`                     |Same             |
|Remove duplicates in array         |`array_distinct("arr")`                 |Same             |
|Combine two arrays                 |`array_union("a", "b")`                 |Same             |

### Examples
```python
from pyspark.sql.functions import (
    explode, col, transform, filter as array_filter,
    size, element_at, array_contains, sort_array
)

# Example 1: Transform array elements without exploding
# Add 10% tax to all prices in items array
df = df.withColumn("items_with_tax",
    transform("items", lambda x: x.withField("price_with_tax",
        x["price"] * 1.1))
)

# Example 2: Filter array elements
# Keep only items with price > 50
df = df.withColumn("expensive_items",
    array_filter("items", lambda x: x["price"] > 50)
)

# Example 3: Access specific element
df.select(
    col("items")[0]["product"].alias("first_product"),
    element_at("items", -1)["product"].alias("last_product"),
    size("items").alias("item_count")
).show()

# Example 4: Check array contents
df.filter(array_contains("tags", "premium")).show()
```

### Pitfalls
- `col("arr")[0]` is 0-based; `element_at("arr", 1)` is 1-based
- `transform()` and `filter()` require Spark 3.1+
- Higher-order functions return arrays, not individual values

---

### 6. Programmatic / Recursive Flattening
#### Trigger Words
	- "auto-flatten", "recursive flatten", "dynamic flattening"
	- "unknown schema", "generic flattener", "flatten any JSON"

**Key Pattern**

```python
from pyspark.sql.types import StructType, ArrayType
from pyspark.sql.functions import col, explode_outer

def flatten_df(nested_df):
    """Recursively flatten all nested structs and arrays."""
    flat_cols = []
    nested_cols = []

    for field in nested_df.schema.fields:
        name = field.name
        dtype = field.dataType

        if isinstance(dtype, ArrayType):
            nested_cols.append(name)
        elif isinstance(dtype, StructType):
            for sub in dtype.fields:
                flat_cols.append(
                    col(f"{name}.{sub.name}").alias(f"{name}_{sub.name}")
                )
        else:
            flat_cols.append(col(name))

    result = nested_df.select(flat_cols) if flat_cols else nested_df

    for arr_col in nested_cols:
        result = result.withColumn(arr_col, explode_outer(col(arr_col)))

    # Recurse if still nested
    has_complex = any(
        isinstance(f.dataType, (StructType, ArrayType))
        for f in result.schema.fields
    )
    if has_complex:
        result = flatten_df(result)

    return result

# Usage
df_flat = flatten_df(df)
```

### Decision Matrix

|Scenario                        |Approach                            |
|--------------------------------|------------------------------------|
|Known, stable schema            |Manual dot notation (fastest)       |
|Unknown/evolving schema         |Recursive `flatten_df()`            |
|Selective flattening            |Manual with specific columns        |
|Very deep nesting (5+ levels)   |Recursive with depth limit          |
|Mixed array + struct            |Recursive handles both              |

### Pitfalls
- Recursive flattening can cause column name collisions (`a_id`, `b_id` both become `id`)
- Row explosion from arrays is uncontrolled — monitor with `.count()`
- Performance degrades with very deep nesting — add a max-depth parameter
- Column naming convention: use `parent_child` pattern to avoid conflicts

---

### 7. Null-Safe JSON Handling
#### Trigger Words
	- "null values", "missing fields", "optional JSON fields"
	- "null-safe", "default values", "coalesce", "handle missing"

**Key Pattern**

```python
from pyspark.sql.functions import (
    explode_outer, col, coalesce, lit, when, size, isnull
)

# Null-safe explode
df = df.withColumn("item", explode_outer("items"))

# Default values for missing fields
df = df.withColumn("price",
    coalesce(col("item.price"), lit(0))
)

# Check before exploding
df = df.withColumn("has_items",
    when(col("items").isNull() | (size("items") == 0), False)
    .otherwise(True)
)
```

### Function Choice Matrix

|Scenario                        |Use                                       |
|--------------------------------|------------------------------------------|
|Array might be null/empty       |`explode_outer()` instead of `explode()`  |
|Field might not exist           |`coalesce(col("f"), lit(default))`        |
|Conditional extraction          |`when(condition, value).otherwise(default)`|
|Check null before access        |`col("f").isNull()` guard                 |
|Fill nulls in batch             |`df.fillna({"col": default})`             |
|Drop rows with null JSON        |`df.dropna(subset=["json_col"])`          |

### Examples
```python
from pyspark.sql.functions import (
    explode_outer, coalesce, lit, when, col, size
)

# Example 1: Safe explode with default
df_safe = (df
    .withColumn("item", explode_outer("items"))
    .withColumn("product", coalesce(col("item.product"), lit("UNKNOWN")))
    .withColumn("price", coalesce(col("item.price"), lit(0)))
)

# Example 2: Conditional processing
df = df.withColumn("item_count",
    when(col("items").isNull(), 0).otherwise(size("items"))
)

# Example 3: Filter before processing
df_valid = df.filter(
    col("items").isNotNull() & (size("items") > 0)
)
df_exploded = df_valid.withColumn("item", explode("items"))

# Example 4: Nested null handling
df = df.withColumn("city",
    when(col("address").isNull(), lit("N/A"))
    .otherwise(
        coalesce(col("address.city"), lit("N/A"))
    )
)
```

### Pitfalls
- `explode()` vs `explode_outer()` — the #1 source of silent data loss
- `size()` returns -1 for NULL arrays, not 0 — check explicitly
- Accessing a field on a NULL struct returns NULL, not an error

---

### 8. JSON String Extraction (get_json_object / json_tuple)
#### Trigger Words
	- "extract field from JSON string", "JSON path", "dollar sign path"
	- "get_json_object", "json_tuple", "quick extraction", "no schema needed"

**Key Pattern**

```python
from pyspark.sql.functions import get_json_object, json_tuple

# Single field extraction — returns String
df = df.withColumn("name",
    get_json_object("json_col", "$.name")
)

# Multiple fields — more efficient than multiple get_json_object
df = df.select("id",
    json_tuple("json_col", "name", "age", "city")
        .alias("name", "age", "city")
)
```

### Function Choice Matrix

|Need                          |Use                          |Returns        |Performance    |
|------------------------------|-----------------------------|---------------|---------------|
|One field from JSON string    |`get_json_object(col, path)` |String         |OK for 1-2     |
|Multiple fields               |`json_tuple(col, keys...)`   |Multiple Strings|Better for 3+  |
|Full struct parsing           |`from_json(col, schema)`     |StructType     |Best for complex|
|Nested field extraction       |`get_json_object(col, "$.a.b")`|String       |OK             |
|Array element in JSON string  |`get_json_object(col, "$.arr[0]")`|String    |OK             |

### Examples
```python
from pyspark.sql.functions import get_json_object, json_tuple

# Example 1: Single field
df.withColumn("name", get_json_object("data", "$.name")).show()

# Example 2: Nested access with JSON path
df.withColumn("city", get_json_object("data", "$.address.city")).show()

# Example 3: Array access
df.withColumn("first_tag", get_json_object("data", "$.tags[0]")).show()

# Example 4: Multiple fields with json_tuple
df.select("id",
    json_tuple("data", "name", "age", "email")
        .alias("name", "age", "email")
).show()

# Example 5: Cast after extraction (returns are always String)
from pyspark.sql.functions import col
df = df.withColumn("age_int",
    get_json_object("data", "$.age").cast("integer")
)
```

### Pitfalls
- `get_json_object` always returns String — must cast for numeric operations
- `json_tuple` can only extract top-level keys (no nested paths)
- JSON path uses `$` as root: `$.field`, `$.nested.field`, `$.arr[0]`
- Both are slower than `from_json` for repeated access on the same column

---

### 9. Building JSON (to_json / struct)
#### Trigger Words
	- "convert to JSON", "create JSON string", "struct to JSON"
	- "to_json", "build JSON", "serialize", "write JSON"

**Key Pattern**

```python
from pyspark.sql.functions import to_json, struct, col, create_map, lit

# Struct → JSON string
df = df.withColumn("json_str",
    to_json(struct("name", "age", "city"))
)

# Map → JSON string
df = df.withColumn("json_str",
    to_json(create_map(lit("key"), col("value")))
)
```

### Function Choice Matrix

|Need                          |Use                                      |
|------------------------------|-----------------------------------------|
|Columns → JSON string         |`to_json(struct(cols...))`               |
|Struct column → JSON string   |`to_json(col("struct_col"))`             |
|Key-value pairs → JSON        |`to_json(create_map(k1,v1,k2,v2))`      |
|Entire row → JSON             |`to_json(struct(*df.columns))`           |
|Nested struct → JSON          |`to_json(struct(struct(...), ...))`      |

### Examples
```python
from pyspark.sql.functions import to_json, struct, col, create_map, lit, array

# Example 1: Columns to JSON
df.withColumn("payload",
    to_json(struct("name", "age", "email"))
).show(truncate=False)
# Result: {"name":"Alice","age":25,"email":"alice@ex.com"}

# Example 2: Nested JSON construction
df.withColumn("payload",
    to_json(struct(
        col("name"),
        struct(col("street"), col("city"), col("zip")).alias("address")
    ))
).show(truncate=False)

# Example 3: Map to JSON
df.withColumn("config",
    to_json(create_map(
        lit("theme"), col("theme"),
        lit("lang"), col("language")
    ))
).show(truncate=False)

# Example 4: Write DataFrame as JSON
df.write.mode("overwrite").json("output/path")
```

### Pitfalls
- `to_json` output is a String column — not queryable without re-parsing
- Null values are excluded from JSON output by default
- Use `to_json` options: `to_json(col, {"ignoreNullFields": "false"})` to include nulls

---

### 10. Schema Inference vs Explicit Schema
#### Trigger Words
	- "schema definition", "infer schema", "define schema"
	- "StructType", "DDL string", "schema_of_json", "performance"

**Key Pattern**

```python
# Method 1: Explicit StructType (recommended for production)
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, ArrayType

schema = StructType([
    StructField("name", StringType(), True),
    StructField("age", IntegerType(), True),
    StructField("tags", ArrayType(StringType()), True)
])
df = spark.read.schema(schema).json("path")

# Method 2: DDL string (concise)
df = spark.read.schema("name STRING, age INT, tags ARRAY<STRING>").json("path")

# Method 3: Infer from sample (development only)
from pyspark.sql.functions import schema_of_json
inferred = schema_of_json('{"name":"Alice","age":25}')
```

### Comparison Matrix

|Approach               |Speed      |Safety     |Use Case                   |
|-----------------------|-----------|-----------|---------------------------|
|Explicit StructType    |Fastest    |Highest    |Production pipelines       |
|DDL string             |Fastest    |High       |Quick scripting            |
|`schema_of_json()`     |Fast       |Medium     |Schema discovery           |
|`inferSchema=True`     |Slowest    |Low        |Ad-hoc exploration only    |

### DDL Type Reference

|PySpark Type           |DDL String        |Example Value          |
|-----------------------|------------------|-----------------------|
|`StringType()`         |`STRING`          |`"hello"`              |
|`IntegerType()`        |`INT`             |`42`                   |
|`LongType()`           |`BIGINT`          |`9999999999`           |
|`DoubleType()`         |`DOUBLE`          |`3.14`                 |
|`BooleanType()`        |`BOOLEAN`         |`true`                 |
|`ArrayType(T)`         |`ARRAY<T>`        |`[1, 2, 3]`           |
|`StructType([...])`    |`STRUCT<a:T,...>` |`{"a": 1}`            |
|`MapType(K,V)`         |`MAP<K,V>`        |`{"key": "val"}`      |
|`TimestampType()`      |`TIMESTAMP`       |`"2026-01-20T10:00"`  |
|`DateType()`           |`DATE`            |`"2026-01-20"`        |
|`DecimalType(p,s)`     |`DECIMAL(p,s)`    |`99.99`               |

### Pitfalls
- `inferSchema` reads the entire file twice — never use in production
- Schema mismatch with `from_json` returns all NULLs (no error)
- Nullable fields: always set `True` in production to handle unexpected nulls
- `schema_of_json()` needs a literal string — cannot take a column

---

### 11. Map Type & Dynamic Keys
#### Trigger Words
	- "dynamic keys", "key-value pairs", "map type", "unknown field names"
	- "MapType", "explode map", "variable schema"

**Key Pattern**

```python
from pyspark.sql.functions import explode, col, create_map, map_keys, map_values
from pyspark.sql.types import MapType, StringType

# Read JSON with dynamic keys as MapType
schema = StructType([
    StructField("id", StringType(), True),
    StructField("properties", MapType(StringType(), StringType()), True)
])
df = spark.read.schema(schema).json("path")

# Explode map to key-value rows
df_kv = df.select("id", explode("properties").alias("key", "value"))
```

### Function Choice Matrix

|Need                          |Use                                |
|------------------------------|-----------------------------------|
|Explode map to rows           |`explode("map_col")` → key, value  |
|Get all keys                  |`map_keys("map_col")`              |
|Get all values                |`map_values("map_col")`            |
|Access specific key           |`col("map_col")["key_name"]`       |
|Build map from columns        |`create_map(k1,v1,k2,v2,...)`      |
|Merge two maps                |`map_concat("map1", "map2")`       |
|Check key exists              |`col("map_col")["key"].isNotNull()`|

### Examples
```python
from pyspark.sql.functions import explode, col, map_keys, map_values, create_map

# Example 1: Explode map to rows
# Input: {id: "u1", props: {"color": "red", "size": "L"}}
df.select("id", explode("props").alias("prop_name", "prop_value")).show()
# Output: (u1, color, red), (u1, size, L)

# Example 2: Access specific key
df.select("id", col("props")["color"].alias("color")).show()

# Example 3: Get all keys
df.select("id", map_keys("props").alias("all_keys")).show()

# Example 4: Pivot map to columns (when keys are known)
known_keys = ["color", "size", "weight"]
for key in known_keys:
    df = df.withColumn(key, col("props")[key])
df.select("id", *known_keys).show()
```

### Pitfalls
- Maps with mixed value types force everything to StringType
- Exploding large maps creates many rows — consider selective key access
- Map keys must be non-null; values can be null

---

### 12. Performance Optimization for JSON
#### Trigger Words
	- "slow JSON parsing", "optimize", "large JSON files"
	- "partitioning", "schema", "predicate pushdown"

**Key Pattern**

```python
# 1. Always provide explicit schema
df = spark.read.schema(explicit_schema).json("path")

# 2. Read multiline JSON
df = spark.read.option("multiLine", True).json("path")

# 3. Filter early, flatten late
df_filtered = df.filter(col("status") == "active")
df_flat = df_filtered.withColumn("item", explode("items"))

# 4. Select only needed columns before explode
df_pruned = df.select("id", "items")  # Drop unneeded columns
df_flat = df_pruned.withColumn("item", explode("items"))
```

### Optimization Matrix

|Technique                        |Impact    |When to Use                       |
|---------------------------------|----------|----------------------------------|
|Explicit schema                  |High      |Always in production              |
|Column pruning before explode    |High      |When source has many columns      |
|Filter before explode            |High      |When many rows will be dropped    |
|Repartition after explode        |Medium    |When explode causes skew          |
|Cache before multiple explodes   |Medium    |When same DF is exploded differently|
|Convert JSON → Parquet first     |Very High |Recurring reads of same JSON      |
|`multiLine=True` for pretty JSON |Required  |Multi-line formatted JSON files   |
|`samplingRatio` for inference    |Low       |Only if schema inference is needed|

### Examples
```python
# Example 1: Convert JSON to Parquet for repeated use
df = spark.read.schema(schema).json("raw/events.json")
df.write.mode("overwrite").parquet("processed/events.parquet")
# All subsequent reads use Parquet (10-100x faster)

# Example 2: Filter before expensive explode
df = spark.read.schema(schema).json("events.json")
df_active = df.filter(col("status") == "active")  # Filter first
df_flat = df_active.withColumn("event", explode("events"))  # Then explode

# Example 3: Column pruning
df_pruned = df.select("user_id", "orders")  # Only needed columns
df_flat = df_pruned.withColumn("order", explode("orders"))

# Example 4: Repartition after skewed explode
df_flat = df.withColumn("item", explode("items"))
df_balanced = df_flat.repartition(200, "customer_id")
```

### Pitfalls
- `inferSchema` scans the entire file — avoid in production
- JSON is not splittable when `multiLine=True` — one file = one task
- Large arrays in a few rows cause data skew after explode
- Predicate pushdown does NOT work on JSON files (works on Parquet)

---

### 13. Semi-Structured Data (Mixed Types)
#### Trigger Words
	- "mixed types", "inconsistent schema", "corrupt records"
	- "permissive mode", "columnNameOfCorruptRecord", "schema evolution"

**Key Pattern**

```python
# Permissive mode — stores corrupt records in separate column
df = spark.read \
    .option("mode", "PERMISSIVE") \
    .option("columnNameOfCorruptRecord", "_corrupt") \
    .schema(schema_with_corrupt_col) \
    .json("mixed_data.json")

# Check corrupt records
df.filter(col("_corrupt").isNotNull()).show()
```

### Read Mode Matrix

|Mode          |Behavior                              |Use Case                    |
|--------------|--------------------------------------|----------------------------|
|`PERMISSIVE`  |Nulls for bad fields, stores raw line |Default, production safe    |
|`DROPMALFORMED`|Silently drops bad rows              |When data loss is acceptable|
|`FAILFAST`    |Throws exception on first bad record  |Data quality enforcement    |

### Examples
```python
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

# Example 1: Capture corrupt records
schema = StructType([
    StructField("name", StringType(), True),
    StructField("age", IntegerType(), True),
    StructField("_corrupt_record", StringType(), True)
])

df = spark.read \
    .option("mode", "PERMISSIVE") \
    .option("columnNameOfCorruptRecord", "_corrupt_record") \
    .schema(schema) \
    .json("data.json")

# Separate good and bad records
df_good = df.filter(col("_corrupt_record").isNull())
df_bad = df.filter(col("_corrupt_record").isNotNull())

# Example 2: Force specific types
df = df.withColumn("age_safe",
    col("age").cast("integer")  # Returns NULL if not castable
)

# Example 3: Union schemas (schema evolution)
df1 = spark.read.json("v1_data.json")  # Has fields: a, b
df2 = spark.read.json("v2_data.json")  # Has fields: a, b, c
df_union = df1.unionByName(df2, allowMissingColumns=True)
```

### Pitfalls
- `PERMISSIVE` mode is the default — corrupt records become all-NULL rows
- `_corrupt_record` column must be in your schema to capture bad records
- `unionByName` with `allowMissingColumns=True` fills missing with NULL

---

### 14. Real-World E-Commerce JSON Pipeline
#### Trigger Words
	- "e-commerce", "transaction data", "real-world pipeline"
	- "end-to-end", "production pattern", "complex JSON"

**Key Pattern**

```python
# Full pipeline: Read → Validate → Flatten → Enrich → Write
df = spark.read.schema(schema).json("transactions/")

# Validate
df_valid = df.filter(col("transaction_id").isNotNull())

# Flatten
df_flat = (df_valid
    .withColumn("item", explode("items"))
    .withColumn("discount", explode_outer("item.discounts"))
    .select(
        "transaction_id", "timestamp",
        col("customer.id").alias("customer_id"),
        col("customer.name").alias("customer_name"),
        col("item.sku").alias("sku"),
        col("item.name").alias("product_name"),
        col("item.quantity").alias("quantity"),
        col("item.unit_price").alias("unit_price"),
        col("discount.type").alias("discount_type"),
        col("discount.amount").alias("discount_amount"),
        col("shipping.method").alias("ship_method"),
        col("shipping.address.city").alias("ship_city"),
        col("payment.method").alias("pay_method"),
        col("payment.amount").alias("pay_amount")
    )
)

# Enrich
df_enriched = df_flat.withColumn("line_total",
    col("quantity") * col("unit_price") - coalesce(col("discount_amount"), lit(0))
)

# Write
df_enriched.write.mode("overwrite").partitionBy("ship_city").parquet("output/")
```

### Pipeline Stage Matrix

|Stage     |Functions Used                        |Purpose                      |
|----------|--------------------------------------|-----------------------------|
|Read      |`spark.read.schema().json()`          |Load with explicit schema    |
|Validate  |`filter`, `isNotNull`                 |Remove bad records           |
|Flatten   |`explode`, `col("a.b").alias()`       |Denormalize structure        |
|Enrich    |`withColumn`, arithmetic ops          |Business logic               |
|Write     |`.write.partitionBy().parquet()`      |Optimized storage            |

---

### 15. Deeply Nested JSON (3+ Levels)
#### Trigger Words
	- "triple nested", "deep JSON", "3 levels deep"
	- "nested inside nested", "complex hierarchy"

**Key Pattern**

```python
# Strategy: Work outside-in, one level at a time
# Level 0: top fields
# Level 1: explode first array / flatten first struct
# Level 2: explode second array / flatten second struct
# Level 3: explode third array / flatten third struct

df_l1 = df.withColumn("order", explode("orders"))
df_l2 = df_l1.withColumn("item", explode("order.items"))
df_l3 = df_l2.withColumn("review", explode_outer("item.reviews"))

df_final = df_l3.select(
    "customer_id",
    col("order.order_id").alias("order_id"),
    col("item.product").alias("product"),
    col("item.price").alias("price"),
    col("review.rating").alias("rating"),
    col("review.comment").alias("comment")
)
```

### Depth Strategy Matrix

|Depth  |Strategy                            |Example                            |
|-------|------------------------------------|-----------------------------------|
|1      |Direct dot notation                 |`col("address.city")`              |
|2      |Explode + dot notation              |`explode("orders")` + `col("order.items")`|
|3      |Chained explode                     |Explode orders → explode items → explode reviews|
|4+     |Recursive `flatten_df()` function   |Auto-handles any depth             |
|Unknown|Recursive + schema inspection       |`df.schema.jsonString()`           |

---

### 16. JSON Arrays at Root Level
#### Trigger Words
	- "root array", "top-level array", "JSON starts with bracket"
	- "array of objects", "list of records at root"

**Key Pattern**

```python
# Spark handles root-level arrays natively with multiLine
# Input: [{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]
df = spark.read.option("multiLine", True).json("root_array.json")

# For JSON Lines (one object per line — no wrapping array):
# {"id":1,"name":"Alice"}
# {"id":2,"name":"Bob"}
df = spark.read.json("jsonl_file.jsonl")  # No multiLine needed
```

### Format Matrix

|Format                    |multiLine  |Example                                     |
|--------------------------|-----------|---------------------------------------------|
|JSON Lines (JSONL)        |`False`    |`{"a":1}\n{"a":2}`                           |
|Single JSON object        |`True`     |`{"a":1,"b":2}`                              |
|Root-level JSON array     |`True`     |`[{"a":1},{"a":2}]`                          |
|Pretty-printed JSON       |`True`     |Multi-line formatted single object           |
|NDJSON                    |`False`    |Same as JSONL                                |

---

### 17. Handling Malformed / Corrupt JSON
#### Trigger Words
	- "bad JSON", "malformed", "corrupt", "parse error"
	- "invalid JSON", "missing quotes", "truncated"

**Key Pattern**

```python
from pyspark.sql.types import StructType, StructField, StringType

# Add corrupt record column to schema
schema = StructType([
    StructField("id", StringType(), True),
    StructField("name", StringType(), True),
    StructField("_corrupt_record", StringType(), True)
])

df = spark.read \
    .option("mode", "PERMISSIVE") \
    .option("columnNameOfCorruptRecord", "_corrupt_record") \
    .schema(schema) \
    .json("messy_data.json")

# Split good and bad
df_good = df.filter(col("_corrupt_record").isNull()).drop("_corrupt_record")
df_bad = df.filter(col("_corrupt_record").isNotNull()).select("_corrupt_record")

# Log bad records for investigation
df_bad.write.mode("append").text("quarantine/bad_records/")
```

### Error Handling Matrix

|Error Type                |Detection                              |Recovery                    |
|--------------------------|---------------------------------------|----------------------------|
|Invalid JSON syntax       |`_corrupt_record` is not null          |Quarantine + manual fix     |
|Wrong data type           |Field becomes NULL                     |`coalesce` with default     |
|Missing required field    |Field is NULL                          |`filter` + `isNotNull`      |
|Extra unexpected field    |Ignored if not in schema               |No action needed            |
|Truncated JSON            |`_corrupt_record` captures partial     |Quarantine + retry source   |
|Encoding issues           |Garbled text in fields                 |`option("charset", "UTF-8")`|

---

### 18. JSON Diffing & Change Detection
#### Trigger Words
	- "compare JSON", "detect changes", "diff", "CDC"
	- "before and after", "what changed", "track changes"

**Key Pattern**

```python
from pyspark.sql.functions import to_json, struct, col, sha2, concat_ws

# Convert entire row to JSON for hashing
df = df.withColumn("row_hash",
    sha2(to_json(struct(*df.columns)), 256)
)

# Compare two snapshots
df_old = df_old.withColumn("hash", sha2(to_json(struct(*df_old.columns)), 256))
df_new = df_new.withColumn("hash", sha2(to_json(struct(*df_new.columns)), 256))

# New records
df_inserted = df_new.join(df_old, "id", "left_anti")

# Deleted records
df_deleted = df_old.join(df_new, "id", "left_anti")

# Changed records
df_changed = (df_new.alias("new")
    .join(df_old.alias("old"), "id")
    .filter(col("new.hash") != col("old.hash"))
)
```

### Change Detection Matrix

|Change Type    |Detection Method                       |Join Type       |
|---------------|---------------------------------------|----------------|
|New records    |In new, not in old                     |`left_anti`     |
|Deleted records|In old, not in new                     |`left_anti`     |
|Modified       |Same key, different hash               |`inner` + filter|
|Unchanged      |Same key, same hash                    |`inner` + filter|

### Pitfalls
- JSON key ordering can differ — `to_json` produces consistent ordering within Spark
- Floating-point precision can cause false positives in hash comparison
- NULL handling in `sha2` — NULL input returns NULL hash
- For large datasets, compare hashes first, then fetch full diff only for changed rows
