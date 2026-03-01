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
	19. Complete Array Functions Reference
	20. Complete Map Functions Reference
	21. Struct Manipulation (withField / dropFields)
	22. inline & inline_outer (Array of Structs → Columns)
	23. Re-Aggregation After Explode (collect_list / collect_set)
	24. arrays_zip & Parallel Array Combining
	25. JSON Read Options (Complete Reference)
	26. JSON Write Options (Complete Reference)
	27. JSON in CSV / Text Columns
	28. LATERAL VIEW EXPLODE (Spark SQL Syntax)
	29. str_to_map & Delimited String Parsing
	30. Schema Export, Import & Validation

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

---

### 19. Complete Array Functions Reference
#### Trigger Words
	- "array operations", "list functions", "array manipulation"
	- "array_sort", "array_distinct", "array_union", "slice"

**Complete Array Functions Matrix**

|Function                     |Purpose                                    |Example                                                  |
|-----------------------------|-------------------------------------------|---------------------------------------------------------|
|`explode(col)`               |One row per element                        |`[1,2,3]` → 3 rows                                      |
|`explode_outer(col)`         |Same, keeps NULL/empty                     |`NULL` → 1 row with NULL                                 |
|`posexplode(col)`            |Explode with index                         |`[a,b]` → `(0,a),(1,b)`                                 |
|`posexplode_outer(col)`      |Same, keeps NULL/empty                     |`NULL` → `(NULL, NULL)`                                  |
|`flatten(col)`               |Flatten nested arrays                      |`[[1,2],[3]]` → `[1,2,3]`                               |
|`inline(col)`                |Explode array of structs to columns        |`[{a:1,b:2}]` → columns a, b                            |
|`inline_outer(col)`          |Same, keeps NULL/empty                     |`NULL` → row with NULL columns                           |
|`size(col)`                  |Array length (-1 for NULL)                 |`[a,b,c]` → 3                                           |
|`array_contains(col, val)`   |Check if value exists                      |`[1,2,3]` contains 2 → true                             |
|`array_sort(col)`            |Sort elements ascending                    |`[3,1,2]` → `[1,2,3]`                                   |
|`array_distinct(col)`        |Remove duplicates                          |`[1,2,2,3]` → `[1,2,3]`                                 |
|`array_union(col1, col2)`    |Union with dedup                           |`[1,2]` + `[2,3]` → `[1,2,3]`                           |
|`array_intersect(col1, col2)`|Common elements                            |`[1,2,3]` & `[2,3,4]` → `[2,3]`                         |
|`array_except(col1, col2)`   |Elements in first not in second            |`[1,2,3]` - `[2,3]` → `[1]`                             |
|`array_join(col, delim)`     |Join elements into string                  |`["a","b","c"]` → `"a,b,c"`                              |
|`array_repeat(col, n)`       |Repeat value n times                       |`"x"` × 3 → `["x","x","x"]`                             |
|`arrays_zip(col1, col2)`     |Zip parallel arrays                        |`[1,2]` + `[a,b]` → `[{1,a},{2,b}]`                     |
|`arrays_overlap(col1, col2)` |Check common elements exist                |`[1,2]` & `[2,3]` → true                                |
|`concat(col1, col2)`         |Concatenate arrays                         |`[1,2]` + `[3,4]` → `[1,2,3,4]`                         |
|`reverse(col)`               |Reverse order                              |`[1,2,3]` → `[3,2,1]`                                   |
|`shuffle(col)`               |Random order                               |`[1,2,3]` → `[2,3,1]` (random)                          |
|`slice(col, start, len)`     |Extract subarray                           |`slice([1,2,3,4], 2, 2)` → `[2,3]`                      |
|`sequence(start, stop, step)`|Generate array of numbers                  |`sequence(1, 5, 2)` → `[1,3,5]`                         |
|`element_at(col, idx)`       |Get element (1-based)                      |`element_at([a,b,c], 2)` → `b`                          |
|`sort_array(col, asc)`       |Sort with direction                        |`sort_array([3,1,2], False)` → `[3,2,1]`                |
|`array_max(col)`             |Maximum element                            |`[3,1,5,2]` → 5                                         |
|`array_min(col)`             |Minimum element                            |`[3,1,5,2]` → 1                                         |
|`array_position(col, val)`   |Find index (1-based, 0 if not found)       |`array_position([a,b,c], "b")` → 2                      |
|`array_remove(col, val)`     |Remove all occurrences                     |`array_remove([1,2,1,3], 1)` → `[2,3]`                  |

### Higher-Order Array Functions (Spark 3.1+)

|Function                              |Purpose                                |Signature                                          |
|--------------------------------------|---------------------------------------|----------------------------------------------------|
|`transform(col, func)`               |Apply function to each element         |`transform("arr", lambda x: x * 2)`                |
|`filter(col, func)`                  |Keep matching elements                 |`filter("arr", lambda x: x > 0)`                   |
|`aggregate(col, init, merge, finish)` |Reduce to single value                 |`aggregate("arr", lit(0), lambda a,x: a+x)`        |
|`exists(col, func)`                  |Any element matches?                   |`exists("arr", lambda x: x > 100)`                 |
|`forall(col, func)`                  |All elements match?                    |`forall("arr", lambda x: x > 0)`                   |
|`zip_with(col1, col2, func)`         |Zip + transform                        |`zip_with("a","b", lambda x,y: x+y)`               |

### Examples
```python
from pyspark.sql.functions import (
    array_sort, array_distinct, array_union, array_intersect,
    array_except, array_join, slice, sequence, array_max, array_min,
    array_position, array_remove, forall, arrays_overlap, concat
)

# Set operations on arrays
df.select(
    array_union("tags_v1", "tags_v2").alias("all_tags"),
    array_intersect("tags_v1", "tags_v2").alias("common_tags"),
    array_except("tags_v1", "tags_v2").alias("removed_tags")
).show()

# Array to string
df.select(array_join("tags", ", ").alias("tag_string")).show()
# Result: "python, spark, sql"

# Subarray extraction
df.select(slice("items", 1, 3).alias("first_3_items")).show()

# Generate number sequence
df.select(sequence(lit(1), lit(10), lit(2)).alias("odds")).show()
# Result: [1, 3, 5, 7, 9]

# Check ALL elements positive
df.select(forall("scores", lambda x: x > 0).alias("all_positive")).show()

# Check overlap between arrays
df.select(arrays_overlap("user_tags", "promo_tags").alias("eligible")).show()
```

### Pitfalls
- `size()` returns **-1** for NULL arrays, not 0 — always null-check first
- `element_at()` is 1-based; `col("arr")[0]` is 0-based
- `array_sort()` puts NULLs at the end by default
- Higher-order functions require Spark 3.1+ — check your cluster version
- `forall()` returns TRUE for empty arrays (vacuous truth)

---

### 20. Complete Map Functions Reference
#### Trigger Words
	- "map operations", "dictionary", "key-value", "dynamic schema"
	- "map_filter", "map_from_entries", "str_to_map"

**Complete Map Functions Matrix**

|Function                           |Purpose                                    |Example                                           |
|-----------------------------------|-------------------------------------------|--------------------------------------------------|
|`create_map(k1,v1,k2,v2,...)`      |Build map from column pairs                |`create_map(lit("a"),col("x"))` → `{"a": x}`     |
|`map_from_arrays(keys, vals)`      |Build map from key & value arrays          |`[a,b]` + `[1,2]` → `{a:1, b:2}`                |
|`map_from_entries(col)`            |Array of structs(k,v) → map               |`[{a,1},{b,2}]` → `{a:1, b:2}`                   |
|`map_entries(col)`                 |Map → array of structs(key,value)          |`{a:1, b:2}` → `[{a,1},{b,2}]`                   |
|`map_keys(col)`                    |Get all keys as array                      |`{a:1, b:2}` → `[a, b]`                          |
|`map_values(col)`                  |Get all values as array                    |`{a:1, b:2}` → `[1, 2]`                          |
|`map_concat(col1, col2)`           |Merge two maps (right wins on conflict)    |`{a:1}` + `{b:2}` → `{a:1, b:2}`                |
|`map_filter(col, func)`            |Keep entries matching condition            |`map_filter(m, lambda k,v: v > 0)`               |
|`map_zip_with(col1, col2, func)`   |Combine maps with function                 |Merge values from matching keys                   |
|`element_at(col, key)`             |Get value by key (NULL if missing)         |`element_at(map, "key")` → value                 |
|`col("map")[key]`                  |Bracket access (NULL if missing)           |`col("props")["color"]` → `"red"`                |
|`explode(col)`                     |Map → key, value rows                      |`{a:1, b:2}` → `(a,1), (b,2)`                   |
|`str_to_map(col, pairDelim, kvDelim)`|Parse delimited string to map            |`"a:1,b:2"` → `{a:1, b:2}`                      |
|`size(col)`                        |Number of entries                          |`{a:1, b:2}` → 2                                 |

### Examples
```python
from pyspark.sql.functions import (
    map_from_arrays, map_from_entries, map_entries,
    map_filter, map_zip_with, str_to_map, element_at
)

# Build map from two arrays
df.select(map_from_arrays("key_array", "value_array").alias("props")).show()

# Filter map entries
df.select(
    map_filter("metrics", lambda k, v: v > 100).alias("high_metrics")
).show()

# Map entries to array of structs (useful for further processing)
df.select(map_entries("props").alias("entries")).show()
# [{key: "color", value: "red"}, {key: "size", value: "L"}]

# Parse delimited string into map
df.select(str_to_map("config_str", ",", ":").alias("config")).show()
# Input: "host:localhost,port:8080,db:mydb"
# Output: {host: localhost, port: 8080, db: mydb}

# Combine two maps with custom merge logic
df.select(
    map_zip_with("map1", "map2",
        lambda k, v1, v2: coalesce(v2, v1)  # Right wins
    ).alias("merged")
).show()
```

### Pitfalls
- Map keys must be non-null; values can be null
- `create_map` requires an even number of arguments (key-value pairs)
- `map_concat` — on duplicate keys, the **last map's value** wins
- `element_at` on map is key-based (not index-based like arrays)
- `str_to_map` with NULL input returns NULL, not empty map

---

### 21. Struct Manipulation (withField / dropFields)
#### Trigger Words
	- "modify struct field", "add field to struct", "remove struct field"
	- "withField", "dropFields", "update nested", "named_struct"

**Key Pattern**

```python
from pyspark.sql.functions import col, lit, struct

# Add or update a field in an existing struct (Spark 3.1+)
df = df.withColumn("address",
    col("address").withField("country", lit("US"))
)

# Drop a field from a struct (Spark 3.1+)
df = df.withColumn("address",
    col("address").dropFields("zipcode")
)

# Build struct from scratch (all Spark versions)
df = df.withColumn("address",
    struct(
        col("street"),
        col("city"),
        lit("US").alias("country")
    )
)

# named_struct in SQL
df = df.selectExpr("named_struct('name', name, 'age', age) as person")
```

### Function Choice Matrix

|Need                                |Use                                        |Spark Version|
|------------------------------------|-------------------------------------------|-------------|
|Add/update one field in struct      |`col("s").withField("f", expr)`            |3.1+         |
|Remove field from struct            |`col("s").dropFields("f1", "f2")`          |3.1+         |
|Build new struct from columns       |`struct(col1, col2, ...)`                  |All          |
|Build struct with explicit names    |`named_struct('k1',v1,'k2',v2)` (SQL)      |All          |
|Rename field in struct              |`withField` new name + `dropFields` old    |3.1+         |
|Update deeply nested struct field   |Chain: `col("a").withField("b", ...)`      |3.1+         |

### Examples
```python
from pyspark.sql.functions import col, lit, struct, upper

# Example 1: Add country field to address struct
df = df.withColumn("address",
    col("address").withField("country", lit("US"))
)
# address: {street, city, zip} → {street, city, zip, country}

# Example 2: Drop sensitive field from struct
df = df.withColumn("customer",
    col("customer").dropFields("ssn", "credit_card")
)

# Example 3: Update nested field (uppercase city)
df = df.withColumn("address",
    col("address").withField("city", upper(col("address.city")))
)

# Example 4: Rename struct field (Spark 3.1+)
df = df.withColumn("address",
    col("address")
        .withField("postal_code", col("address.zipcode"))
        .dropFields("zipcode")
)

# Example 5: Reconstruct struct (all Spark versions)
df = df.withColumn("address_v2",
    struct(
        col("address.street").alias("street"),
        col("address.city").alias("city"),
        col("address.zipcode").alias("postal_code"),
        lit("US").alias("country")
    )
)
```

### Pitfalls
- `withField` / `dropFields` require Spark 3.1+ — use `struct()` reconstruction for older versions
- `dropFields` returns NULL if the struct itself is NULL (not an empty struct)
- `withField` on a NULL struct returns NULL — guard with `when()`
- Cannot chain `withField` on deeply nested paths in one call — must rebuild outer layers

---

### 22. inline & inline_outer (Array of Structs → Columns)
#### Trigger Words
	- "array of structs to columns", "inline", "unnest structs"
	- "expand array of objects", "each struct field as column"

**Key Pattern**

```python
from pyspark.sql.functions import inline, inline_outer

# inline: Explode array of structs directly to columns
df.select("id", inline("items")).show()
# Equivalent to: explode("items") then select("item.*")

# inline_outer: Null-safe version
df.select("id", inline_outer("items")).show()
```

### Comparison: inline vs explode + select

```python
# These are equivalent:

# Approach 1: explode + select (two steps)
df.withColumn("item", explode("items")).select("id", "item.*")

# Approach 2: inline (one step, more concise)
df.select("id", inline("items"))

# Both produce:
# +---+--------+-----+
# | id| product|price|
# +---+--------+-----+
# |  1|  Laptop|  999|
# |  1|   Mouse|   25|
# +---+--------+-----+
```

### Function Choice Matrix

|Function          |NULL/Empty Array   |Use Case                              |
|------------------|-------------------|--------------------------------------|
|`inline()`        |Row **dropped**    |When NULLs are impossible             |
|`inline_outer()`  |Row kept as NULLs  |Production default                    |
|`explode()` + `.*`|Row **dropped**    |When you need intermediate processing |

### Pitfalls
- `inline` only works on `array<struct>` — not on plain arrays or maps
- Like `explode`, `inline` drops NULL/empty arrays — use `inline_outer` for safety
- Cannot alias individual output columns — they take struct field names

---

### 23. Re-Aggregation After Explode (collect_list / collect_set)
#### Trigger Words
	- "re-aggregate", "collect back", "group after explode"
	- "collect_list", "collect_set", "reconstruct array", "reverse explode"

**Key Pattern**

```python
from pyspark.sql.functions import collect_list, collect_set, struct

# After exploding and transforming, re-aggregate back into arrays

# collect_list: Preserves duplicates and order
df_reagg = df_flat.groupBy("customer_id").agg(
    collect_list("product").alias("products"),
    collect_list(struct("product", "price")).alias("items")
)

# collect_set: Deduplicated (unordered)
df_reagg = df_flat.groupBy("customer_id").agg(
    collect_set("category").alias("unique_categories")
)
```

### Function Choice Matrix

|Function           |Duplicates    |Order         |NULL Handling       |
|-------------------|--------------|--------------|--------------------|
|`collect_list()`   |Keeps all     |Preserves     |Includes NULLs      |
|`collect_set()`    |Removes dupes |Not guaranteed|Excludes NULLs      |

### Examples
```python
from pyspark.sql.functions import (
    collect_list, collect_set, struct, sort_array, array_distinct
)

# Example 1: Explode → Transform → Re-aggregate
# Start: customer with items array
# Goal: Get uppercase product names back as array
from pyspark.sql.functions import upper, explode

df_flat = df.withColumn("item", explode("items"))
df_transformed = df_flat.withColumn("product_upper", upper(col("item.product")))
df_result = df_transformed.groupBy("customer_id").agg(
    collect_list("product_upper").alias("products")
)

# Example 2: Sorted aggregation
df_result = df_flat.groupBy("customer_id").agg(
    sort_array(collect_list("product")).alias("products_sorted")
)

# Example 3: Collect structs (preserve structure)
df_result = df_flat.groupBy("customer_id").agg(
    collect_list(struct("product", "price", "quantity")).alias("items")
)

# Example 4: Collect with dedup
df_result = df_flat.groupBy("customer_id").agg(
    collect_set("category").alias("unique_categories"),
    collect_list("product").alias("all_products")
)
```

### Pitfalls
- `collect_list` can cause OOM if groups are very large — check with `size()` after
- `collect_set` does NOT preserve insertion order
- Both functions include NULL values differently — `collect_list` includes, `collect_set` excludes
- Consider `sort_array(collect_list(...))` for deterministic output

---

### 24. arrays_zip & Parallel Array Combining
#### Trigger Words
	- "combine arrays", "zip arrays", "parallel arrays", "element-wise"
	- "arrays_zip", "merge arrays", "pair up elements"

**Key Pattern**

```python
from pyspark.sql.functions import arrays_zip, col, explode

# Zip two parallel arrays into array of structs
df = df.withColumn("zipped",
    arrays_zip("names", "scores")
)
# names: ["Alice","Bob"], scores: [90,85]
# zipped: [{names:"Alice", scores:90}, {names:"Bob", scores:85}]

# Then explode to get paired rows
df_flat = df.select("id", explode("zipped").alias("pair"))
df_flat = df_flat.select("id",
    col("pair.names").alias("name"),
    col("pair.scores").alias("score")
)
```

### Function Choice Matrix

|Need                              |Use                                    |Result Type             |
|----------------------------------|---------------------------------------|------------------------|
|Pair elements by index            |`arrays_zip(a, b)`                     |`array<struct<a,b>>`    |
|Pair + transform                  |`zip_with(a, b, func)`                 |`array<T>`              |
|Concatenate arrays                |`concat(a, b)`                         |`array<T>`              |
|Interleave arrays                 |`zip_with` + `flatten`                 |`array<T>`              |
|Unequal length arrays             |`arrays_zip` pads shorter with NULL    |`array<struct>`         |

### Examples
```python
from pyspark.sql.functions import arrays_zip, zip_with, col, explode

# Example 1: Zip product names with prices
df.withColumn("items",
    arrays_zip("product_names", "prices", "quantities")
).show()
# [{product_names:"Laptop", prices:999, quantities:1}, ...]

# Example 2: Element-wise operations with zip_with
df.withColumn("totals",
    zip_with("prices", "quantities", lambda p, q: p * q)
).show()
# prices: [100, 50], quantities: [2, 3]
# totals: [200, 150]

# Example 3: Unequal length arrays
# names: ["A", "B", "C"], scores: [90, 85]
# arrays_zip result: [{A,90}, {B,85}, {C,NULL}]  — padded with NULL
```

### Pitfalls
- `arrays_zip` pads shorter arrays with NULL — does NOT truncate
- Output struct field names match input column names — rename with alias if needed
- `zip_with` requires Spark 3.1+ (higher-order function)
- For 3+ arrays, `arrays_zip` handles them: `arrays_zip("a", "b", "c")`

---

### 25. JSON Read Options (Complete Reference)
#### Trigger Words
	- "read options", "JSON parsing options", "multiLine"
	- "allowComments", "dateFormat", "encoding", "corrupt records"

**Complete JSON Read Options Matrix**

|Option                                |Default      |Purpose                                            |Example                           |
|--------------------------------------|-------------|---------------------------------------------------|----------------------------------|
|`multiLine`                           |`false`      |Parse multi-line JSON (not splittable)              |`True` for pretty-printed JSON    |
|`mode`                                |`PERMISSIVE` |Error handling: PERMISSIVE/DROPMALFORMED/FAILFAST   |`FAILFAST` for strict validation  |
|`columnNameOfCorruptRecord`           |`_corrupt_record`|Column name for corrupt lines                    |`"_bad_data"`                     |
|`primitivesAsString`                  |`false`      |Read all primitives as strings                      |`True` for schema-agnostic reads  |
|`prefersDecimal`                      |`false`      |Infer decimals instead of doubles                   |`True` for financial data         |
|`allowComments`                       |`false`      |Allow `//` and `/* */` comments in JSON             |`True` for config files           |
|`allowUnquotedFieldNames`             |`false`      |Allow `{name: "Alice"}` instead of `{"name":"Alice"}`|`True` for relaxed JSON          |
|`allowSingleQuotes`                   |`false`      |Allow `{'name':'Alice'}`                            |`True` for Python-style JSON      |
|`allowNumericLeadingZeros`            |`false`      |Allow `007` as valid number                         |`True` for legacy systems         |
|`allowBackslashEscapingAnyCharacter`  |`false`      |Allow `\q` (not just `\n`, `\t`)                    |`True` for non-standard JSON      |
|`allowNonNumericNumbers`              |`false`      |Allow `NaN`, `Infinity`, `-Infinity`                |`True` for scientific data        |
|`dateFormat`                          |`yyyy-MM-dd` |Custom date parsing format                          |`"MM/dd/yyyy"`                    |
|`timestampFormat`                     |ISO 8601     |Custom timestamp parsing format                     |`"yyyy-MM-dd HH:mm:ss"`          |
|`timestampNTZFormat`                  |ISO 8601     |Timestamp without timezone format                   |`"yyyy-MM-dd'T'HH:mm:ss"`        |
|`encoding` / `charset`               |`UTF-8`      |Character encoding of source file                   |`"UTF-16"`, `"ISO-8859-1"`       |
|`lineSep`                             |`\n`,`\r\n`,`\r`|Custom line separator                            |`"\u0001"` for SOH separator      |
|`samplingRatio`                       |`1.0`        |Fraction of data for schema inference               |`0.1` for 10% sampling           |
|`dropFieldIfAllNull`                  |`false`      |Remove field from schema if all values are null     |`True` for sparse data            |
|`locale`                              |`en-US`      |Locale for parsing                                  |`"de-DE"` for German dates        |

### Examples
```python
# Example 1: Relaxed JSON parsing (config files with comments)
df = spark.read \
    .option("multiLine", True) \
    .option("allowComments", True) \
    .option("allowSingleQuotes", True) \
    .option("allowUnquotedFieldNames", True) \
    .json("config.json")

# Example 2: Scientific data with NaN/Infinity
df = spark.read \
    .option("allowNonNumericNumbers", True) \
    .schema("sensor_id STRING, value DOUBLE") \
    .json("sensor_data.json")

# Example 3: Custom date/timestamp formats
df = spark.read \
    .option("dateFormat", "MM/dd/yyyy") \
    .option("timestampFormat", "yyyy-MM-dd'T'HH:mm:ss.SSSZ") \
    .schema("id STRING, event_date DATE, event_time TIMESTAMP") \
    .json("events.json")

# Example 4: Non-UTF8 encoding
df = spark.read \
    .option("charset", "ISO-8859-1") \
    .option("multiLine", True) \
    .json("legacy_data.json")

# Example 5: All primitives as strings (schema-agnostic)
df = spark.read \
    .option("primitivesAsString", True) \
    .json("unknown_schema.json")
# All fields become StringType — cast later as needed
```

### Pitfalls
- `multiLine=True` makes file non-splittable — entire file = one Spark task
- `samplingRatio < 1.0` can miss fields present in unsampled records
- `allowComments=True` is non-standard JSON — won't work with strict parsers downstream
- `primitivesAsString=True` reads 42 as `"42"` — must explicitly cast
- `dropFieldIfAllNull=True` makes schema non-deterministic across batches

---

### 26. JSON Write Options (Complete Reference)
#### Trigger Words
	- "write JSON", "output options", "compression", "formatting"
	- "ignoreNullFields", "dateFormat", "timestampFormat"

**Complete JSON Write Options Matrix**

|Option                  |Default      |Purpose                                    |Example                    |
|------------------------|-------------|-------------------------------------------|---------------------------|
|`compression`           |`none`       |Compression codec                          |`"gzip"`, `"snappy"`, `"bzip2"`, `"deflate"`, `"zstd"`|
|`dateFormat`            |`yyyy-MM-dd` |Custom date output format                  |`"MM/dd/yyyy"`             |
|`timestampFormat`       |ISO 8601     |Custom timestamp output format             |`"yyyy-MM-dd HH:mm:ss"`   |
|`ignoreNullFields`      |`true`       |Exclude null fields from output            |`"false"` to include nulls |
|`encoding`              |`UTF-8`      |Output character encoding                  |`"UTF-16"`                 |
|`lineSep`               |`\n`         |Line separator between records             |`"\r\n"` for Windows       |

### Examples
```python
# Example 1: Compressed JSON output
df.write \
    .option("compression", "gzip") \
    .mode("overwrite") \
    .json("output/compressed/")

# Example 2: Include null fields in output
df.write \
    .option("ignoreNullFields", "false") \
    .json("output/with_nulls/")
# Default: {"name":"Alice"} (age omitted if null)
# With false: {"name":"Alice","age":null}

# Example 3: Custom timestamp format
df.write \
    .option("timestampFormat", "yyyy-MM-dd HH:mm:ss") \
    .option("dateFormat", "MM/dd/yyyy") \
    .json("output/formatted/")

# Example 4: Write single JSON file (use coalesce)
df.coalesce(1).write.mode("overwrite").json("output/single_file/")
```

### Pitfalls
- `ignoreNullFields=true` (default) omits keys — downstream consumers may break if they expect all keys
- `coalesce(1)` for single file defeats parallelism — use only for small outputs
- Compression adds overhead — `snappy` is fastest, `gzip` has best ratio
- JSON output is always one JSON per line (JSONL) — not pretty-printed

---

### 27. JSON in CSV / Text Columns
#### Trigger Words
	- "JSON embedded in CSV", "JSON in text column", "parse column"
	- "CSV with JSON", "mixed format", "log parsing"

**Key Pattern**

```python
from pyspark.sql.functions import from_json, col
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

# Step 1: Read CSV normally
df = spark.read.option("header", True).csv("data_with_json.csv")
# Columns: id, name, metadata_json

# Step 2: Parse the JSON string column
schema = StructType([
    StructField("source", StringType(), True),
    StructField("version", IntegerType(), True),
    StructField("tags", ArrayType(StringType()), True)
])

df = df.withColumn("metadata", from_json("metadata_json", schema))

# Step 3: Expand into columns
df_flat = df.select("id", "name", "metadata.*")
```

### Examples
```python
# Example 1: CSV with JSON column
# CSV: id,name,payload
# 1,Alice,"{""event"":""login"",""ip"":""1.2.3.4""}"
df = spark.read.option("header", True).csv("logs.csv")
schema = "event STRING, ip STRING"
df = df.withColumn("parsed", from_json("payload", schema))
df.select("id", "name", "parsed.*").show()

# Example 2: Text file with JSON after delimiter
# Log: 2026-01-20 INFO {"user":"alice","action":"click"}
from pyspark.sql.functions import regexp_extract

df = spark.read.text("app.log")
df = df.withColumn("json_part",
    regexp_extract("value", r"(\{.*\})", 1)
)
schema = "user STRING, action STRING"
df = df.withColumn("parsed", from_json("json_part", schema))
df.select("parsed.*").show()

# Example 3: Multiple JSON columns in one CSV
df = spark.read.option("header", True).csv("multi_json.csv")
schema_user = "name STRING, email STRING"
schema_order = "order_id INT, total DOUBLE"

df = (df
    .withColumn("user", from_json("user_json", schema_user))
    .withColumn("order", from_json("order_json", schema_order))
    .select("id", "user.*", "order.*")
)
```

### Pitfalls
- CSV with embedded JSON often has escaped quotes: `""` instead of `\"` — Spark handles this
- Very long JSON strings in CSV can hit `maxColumnWidth` limits — increase if needed
- Some CSV files use single quotes around JSON — use `option("escape", "'")`
- Always verify with `df.select("json_col").show(truncate=False)` before parsing

---

### 28. LATERAL VIEW EXPLODE (Spark SQL Syntax)
#### Trigger Words
	- "SQL explode", "LATERAL VIEW", "SQL array flattening"
	- "Spark SQL JSON", "SQL syntax for arrays"

**Key Pattern**

```sql
-- LATERAL VIEW is the SQL equivalent of withColumn + explode
SELECT
    id,
    name,
    item.product,
    item.price
FROM customers
LATERAL VIEW explode(items) AS item

-- Null-safe version
SELECT id, tag
FROM customers
LATERAL VIEW OUTER explode(tags) AS tag
```

### SQL vs DataFrame API Equivalents

|SQL Syntax                                 |DataFrame API                                     |
|-------------------------------------------|--------------------------------------------------|
|`LATERAL VIEW explode(arr) t AS elem`      |`.withColumn("elem", explode("arr"))`             |
|`LATERAL VIEW OUTER explode(arr) t AS elem`|`.withColumn("elem", explode_outer("arr"))`       |
|`LATERAL VIEW posexplode(arr) t AS pos, elem`|`.select(posexplode("arr").alias("pos","elem"))` |
|`LATERAL VIEW inline(arr) t AS c1, c2`     |`.select(inline("arr"))`                          |
|`LATERAL VIEW json_tuple(j, 'a','b') t AS a, b`|`.select(json_tuple("j","a","b").alias("a","b"))`|

### Examples
```sql
-- Example 1: Explode + flatten in SQL
SELECT
    c.customer_id,
    c.name,
    o.order_id,
    i.product,
    i.price
FROM customers c
LATERAL VIEW explode(c.orders) orders_table AS o
LATERAL VIEW explode(o.items) items_table AS i

-- Example 2: Null-safe explode in SQL
SELECT c.id, t.tag
FROM customers c
LATERAL VIEW OUTER explode(c.tags) tags_table AS tag

-- Example 3: json_tuple in SQL
SELECT
    id,
    j.name,
    j.age
FROM events
LATERAL VIEW json_tuple(json_col, 'name', 'age') j AS name, age

-- Example 4: inline array of structs in SQL
SELECT c.id, i.product, i.price
FROM customers c
LATERAL VIEW inline(c.items) i AS product, price

-- Example 5: Multiple LATERAL VIEWs (chained explode)
SELECT c.id, o.order_id, i.product
FROM customers c
LATERAL VIEW explode(c.orders) AS o
LATERAL VIEW explode(o.items) AS i
```

### Pitfalls
- `LATERAL VIEW` requires a table alias even if not used: `AS t`
- `LATERAL VIEW OUTER` (with OUTER keyword) = `explode_outer` — easy to forget
- Chaining multiple `LATERAL VIEW` compounds row multiplication (same as DataFrame API)
- SQL syntax uses `AS alias` for the output column — must be provided

---

### 29. str_to_map & Delimited String Parsing
#### Trigger Words
	- "parse delimited string", "key-value string", "config string"
	- "str_to_map", "split to map", "query string parsing"

**Key Pattern**

```python
from pyspark.sql.functions import str_to_map

# Parse "key1:value1,key2:value2" into a map
df = df.withColumn("params",
    str_to_map("query_string", ",", ":")
)

# Then access individual keys
df = df.withColumn("host", col("params")["host"])
```

### Examples
```python
from pyspark.sql.functions import str_to_map, col, explode

# Example 1: Parse URL query string
# Input: "page=home&user=alice&lang=en"
df = df.withColumn("params", str_to_map("query_string", "&", "="))
df.select(
    col("params")["page"].alias("page"),
    col("params")["user"].alias("user")
).show()

# Example 2: Parse config strings
# Input: "host:localhost,port:8080,db:mydb"
df = df.withColumn("config", str_to_map("config_str", ",", ":"))
df.select(
    col("config")["host"].alias("host"),
    col("config")["port"].alias("port")
).show()

# Example 3: Parse HTTP headers
# Input: "Content-Type=application/json;Accept=text/html"
df = df.withColumn("headers", str_to_map("header_str", ";", "="))

# Example 4: Explode parsed map to rows
df.select("id", explode(str_to_map("tags_str", ",", ":")).alias("tag", "value")).show()
```

### Pitfalls
- Default delimiters: pair delimiter = `,`, key-value delimiter = `:`
- No automatic trimming — `" key "` is different from `"key"`
- NULL input returns NULL (not empty map)
- Duplicate keys: last value wins
- No support for escape characters — delimiters inside values will break parsing

---

### 30. Schema Export, Import & Validation
#### Trigger Words
	- "save schema", "export schema", "validate schema"
	- "schema registry", "schema JSON", "StructType from JSON"

**Key Pattern**

```python
# Export schema to JSON string
schema_json = df.schema.json()
# Save to file for reuse
with open("schema.json", "w") as f:
    f.write(schema_json)

# Import schema from JSON string
from pyspark.sql.types import StructType
import json

with open("schema.json", "r") as f:
    schema = StructType.fromJson(json.loads(f.read()))
df = spark.read.schema(schema).json("data.json")

# Export as DDL string
ddl = df.schema.simpleString()
# "struct<name:string,age:int,address:struct<city:string,zip:string>>"
```

### Function Choice Matrix

|Need                          |Use                                    |Output Format               |
|------------------------------|---------------------------------------|----------------------------|
|Export schema to JSON         |`df.schema.json()`                     |JSON string                 |
|Import schema from JSON       |`StructType.fromJson(json_dict)`       |StructType object           |
|Export schema as DDL          |`df.schema.simpleString()`             |DDL string                  |
|Import schema from DDL        |`spark.read.schema("DDL string")`      |Used directly               |
|Get schema as tree            |`df.printSchema()`                     |Human-readable tree         |
|Compare schemas               |`df1.schema == df2.schema`             |Boolean                     |
|Get field names               |`df.schema.fieldNames()`               |List of strings             |
|Check field exists            |`"field" in df.schema.fieldNames()`    |Boolean                     |

### Examples
```python
import json
from pyspark.sql.types import StructType

# Example 1: Round-trip schema persistence
# Save
with open("/tmp/my_schema.json", "w") as f:
    f.write(df.schema.json())

# Load
with open("/tmp/my_schema.json", "r") as f:
    saved_schema = StructType.fromJson(json.loads(f.read()))

df_new = spark.read.schema(saved_schema).json("new_data.json")

# Example 2: Schema validation
expected = StructType.fromJson(json.loads(open("expected_schema.json").read()))
actual = spark.read.json("data.json").schema

if expected == actual:
    print("Schema matches!")
else:
    # Find differences
    expected_fields = set(expected.fieldNames())
    actual_fields = set(actual.fieldNames())
    print(f"Missing: {expected_fields - actual_fields}")
    print(f"Extra: {actual_fields - expected_fields}")

# Example 3: Schema from DDL string (quick usage)
df = spark.read.schema(
    "id BIGINT, name STRING, scores ARRAY<INT>, address STRUCT<city: STRING, zip: STRING>"
).json("data.json")

# Example 4: Programmatic schema inspection
for field in df.schema.fields:
    print(f"{field.name}: {field.dataType} (nullable={field.nullable})")
```

### Pitfalls
- `schema.json()` includes full metadata — `simpleString()` is more compact but lossy
- `StructType.fromJson()` expects a dict — use `json.loads()` on the JSON string first
- Schema equality checks field names, types, AND nullability — all must match
- Schema JSON format changed between Spark 2.x and 3.x — verify compatibility
