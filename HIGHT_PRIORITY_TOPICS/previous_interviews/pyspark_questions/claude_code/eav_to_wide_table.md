# PySpark Implementation: EAV (Entity-Attribute-Value) to Wide Table

## Problem Statement
Given a key-value style properties table (Entity-Attribute-Value model) where each row stores one attribute for an entity, transform it into a wide table with one row per entity and each attribute as a separate column. This is a common interview pattern because many systems store flexible/schema-less data in EAV format (e.g., user preferences, product attributes, configuration settings).

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("EAVToWide").getOrCreate()

data = [
    (1, "name", "Alice"),
    (1, "age", "30"),
    (1, "city", "New York"),
    (1, "email", "alice@example.com"),
    (2, "name", "Bob"),
    (2, "age", "25"),
    (2, "city", "Chicago"),
    (3, "name", "Charlie"),
    (3, "age", "35"),
    (3, "city", "Boston"),
    (3, "email", "charlie@example.com"),
    (3, "phone", "555-1234"),
]

columns = ["entity_id", "attribute", "value"]
df = spark.createDataFrame(data, columns)
df.show(truncate=False)
```

```
+---------+---------+-------------------+
|entity_id|attribute|value              |
+---------+---------+-------------------+
|1        |name     |Alice              |
|1        |age      |30                 |
|1        |city     |New York           |
|1        |email    |alice@example.com  |
|2        |name     |Bob                |
|2        |age      |25                 |
|2        |city     |Chicago            |
|3        |name     |Charlie            |
|3        |age      |35                 |
|3        |city     |Boston             |
|3        |email    |charlie@example.com|
|3        |phone    |555-1234           |
+---------+---------+-------------------+
```

### Expected Output
```
+---------+-------+---+--------+-------------------+---------+
|entity_id|name   |age|city    |email              |phone    |
+---------+-------+---+--------+-------------------+---------+
|1        |Alice  |30 |New York|alice@example.com  |null     |
|2        |Bob    |25 |Chicago |null               |null     |
|3        |Charlie|35 |Boston  |charlie@example.com|555-1234 |
+---------+-------+---+--------+-------------------+---------+
```

---

## Method 1: groupBy + pivot (Recommended)

```python
result = (
    df.groupBy("entity_id")
    .pivot("attribute")
    .agg(F.first("value"))
)
result.show(truncate=False)
```

### Step-by-Step Explanation

#### How pivot works here:
1. **groupBy("entity_id"):** Groups all rows belonging to the same entity.
2. **pivot("attribute"):** Takes each unique value in the `attribute` column (name, age, city, email, phone) and creates a new column for it.
3. **agg(first("value")):** For each entity-attribute combination, takes the first value (since each entity should have at most one value per attribute).

- **Output:** One row per entity_id, with columns: entity_id, age, city, email, name, phone.

---

## Method 2: Conditional Aggregation with when()

```python
# Useful when you know the attributes upfront and want explicit control
result_manual = df.groupBy("entity_id").agg(
    F.max(F.when(F.col("attribute") == "name", F.col("value"))).alias("name"),
    F.max(F.when(F.col("attribute") == "age", F.col("value"))).alias("age"),
    F.max(F.when(F.col("attribute") == "city", F.col("value"))).alias("city"),
    F.max(F.when(F.col("attribute") == "email", F.col("value"))).alias("email"),
    F.max(F.when(F.col("attribute") == "phone", F.col("value"))).alias("phone"),
)
result_manual.show(truncate=False)
```

- **When to use:** When you want specific columns in a specific order, or when some attributes need special handling (e.g., casting age to integer).

---

## Method 3: Dynamic Pivot with Explicit Values

```python
# Step 1: Collect distinct attribute names (prevents Spark from scanning data twice)
attributes = [row.attribute for row in df.select("attribute").distinct().collect()]
# attributes = ['name', 'age', 'city', 'email', 'phone']

# Step 2: Pivot with explicit values for performance
result_dynamic = (
    df.groupBy("entity_id")
    .pivot("attribute", attributes)
    .agg(F.first("value"))
)
result_dynamic.show(truncate=False)
```

- **Why explicit values?** Without specifying values, Spark does an extra scan to discover all unique attributes. Passing them explicitly avoids this overhead.

---

## Method 4: Spark SQL

```python
df.createOrReplaceTempView("eav_table")

result_sql = spark.sql("""
    SELECT
        entity_id,
        MAX(CASE WHEN attribute = 'name' THEN value END) AS name,
        MAX(CASE WHEN attribute = 'age' THEN value END) AS age,
        MAX(CASE WHEN attribute = 'city' THEN value END) AS city,
        MAX(CASE WHEN attribute = 'email' THEN value END) AS email,
        MAX(CASE WHEN attribute = 'phone' THEN value END) AS phone
    FROM eav_table
    GROUP BY entity_id
    ORDER BY entity_id
""")
result_sql.show(truncate=False)
```

---

## Variation: Wide Table Back to EAV (Reverse)

```python
wide_df = result  # from Method 1

# Using stack() to unpivot back to EAV
eav_back = wide_df.select(
    "entity_id",
    F.expr("""
        stack(5,
            'age', age,
            'city', city,
            'email', email,
            'name', name,
            'phone', phone
        ) AS (attribute, value)
    """)
).filter(F.col("value").isNotNull())

eav_back.orderBy("entity_id", "attribute").show(truncate=False)
```

---

## Variation: EAV with Multiple Value Types

```python
# Sometimes EAV tables have typed value columns
typed_data = [
    (1, "name", "Alice", None, None),
    (1, "age", None, 30, None),
    (1, "active", None, None, True),
    (2, "name", "Bob", None, None),
    (2, "age", None, 25, None),
    (2, "active", None, None, False),
]

typed_df = spark.createDataFrame(
    typed_data, ["entity_id", "attribute", "str_value", "int_value", "bool_value"]
)

# Coalesce value columns into a single value, then pivot
typed_result = (
    typed_df.withColumn(
        "value",
        F.coalesce(
            F.col("str_value"),
            F.col("int_value").cast("string"),
            F.col("bool_value").cast("string"),
        ),
    )
    .groupBy("entity_id")
    .pivot("attribute")
    .agg(F.first("value"))
)
typed_result.show()
```

---

## Variation: Handle Duplicate Attributes per Entity

```python
# If an entity can have multiple values for the same attribute
multi_data = [
    (1, "hobby", "reading"),
    (1, "hobby", "cycling"),
    (1, "hobby", "cooking"),
    (1, "name", "Alice"),
]

multi_df = spark.createDataFrame(multi_data, ["entity_id", "attribute", "value"])

# Collect all values into an array instead of taking first
result_multi = (
    multi_df.groupBy("entity_id")
    .pivot("attribute")
    .agg(F.collect_list("value"))
)
result_multi.show(truncate=False)
```

**Output:**
```
+---------+----------------------------+-------+
|entity_id|hobby                       |name   |
+---------+----------------------------+-------+
|1        |[reading, cycling, cooking] |[Alice]|
+---------+----------------------------+-------+
```

---

## Comparison of Methods

| Method | Dynamic Attributes? | Performance | Control Over Output? |
|--------|---------------------|-------------|----------------------|
| pivot() | Yes — auto-discovers | Good (better with explicit values) | Column order may vary |
| when() conditional agg | No — hardcoded | Fast — no extra scan | Full control |
| Dynamic pivot (explicit) | Yes — one extra scan | Best — avoids double scan | Column order controlled |
| Spark SQL CASE WHEN | No — hardcoded | Same as when() | Full control |

## Key Interview Talking Points

1. **`pivot()` is the cleanest solution** for EAV-to-wide. It's a one-liner in PySpark.
2. **Performance tip:** Always pass explicit pivot values when possible. Without them, Spark scans the data twice — once to discover values, once to pivot.
3. **EAV trade-offs:** EAV is flexible (no schema changes for new attributes) but slow for analytics (requires pivot/conditional aggregation). Discuss when EAV is appropriate vs. a wide table.
4. **Null handling:** Entities missing certain attributes will naturally have nulls in the wide table — no special handling needed.
5. **`first()` vs `max()`:** Both work for single-valued attributes. `first()` is semantically clearer; `max()` also works since there's only one non-null value per group.
6. This pattern appears in: user profile settings, product catalogs with variable attributes, configuration management systems, healthcare (patient attributes), CRM systems.
