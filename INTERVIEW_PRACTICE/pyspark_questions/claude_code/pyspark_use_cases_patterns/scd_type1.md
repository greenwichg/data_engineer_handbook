# PySpark Implementation: Slowly Changing Dimension Type 1

## Problem Statement

SCD Type 1 is the simplest approach to handling dimension changes: when an attribute changes, you simply overwrite the old value with the new one, losing all history. This is appropriate for correcting errors or when historical values are not needed (e.g., fixing a typo in a customer's name). Given a current dimension table and a set of incoming updates, implement the SCD Type 1 merge logic. This is a foundational interview topic for data warehouse engineering roles.

### Sample Data

**Existing Dimension Table:**
```
customer_id | name          | email               | city         | last_updated
C001        | Alice Smith   | alice@old.com       | New York     | 2024-01-01
C002        | Bob Johnson   | bob@email.com       | Chicago      | 2024-01-15
C003        | Charlie Brown | charlie@email.com   | Los Angeles  | 2024-02-01
```

**Incoming Updates:**
```
customer_id | name          | email               | city
C001        | Alice Smith   | alice@new.com       | New York
C003        | Charles Brown | charlie@email.com   | San Francisco
C004        | Diana Prince  | diana@email.com     | Seattle
```

### Expected Output (After SCD Type 1 Merge)

| customer_id | name          | email             | city          | last_updated |
|-------------|---------------|-------------------|---------------|--------------|
| C001        | Alice Smith   | alice@new.com     | New York      | 2024-03-01   |
| C002        | Bob Johnson   | bob@email.com     | Chicago       | 2024-01-15   |
| C003        | Charles Brown | charlie@email.com | San Francisco | 2024-03-01   |
| C004        | Diana Prince  | diana@email.com   | Seattle       | 2024-03-01   |

---

## Method 1: Left Anti Join + Union Approach

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, current_date, coalesce, when

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("SCD_Type1_AntiJoin") \
    .master("local[*]") \
    .getOrCreate()

# Existing dimension table
existing_data = [
    ("C001", "Alice Smith",   "alice@old.com",     "New York",      "2024-01-01"),
    ("C002", "Bob Johnson",   "bob@email.com",     "Chicago",       "2024-01-15"),
    ("C003", "Charlie Brown", "charlie@email.com", "Los Angeles",   "2024-02-01"),
]

existing_dim = spark.createDataFrame(
    existing_data,
    ["customer_id", "name", "email", "city", "last_updated"]
)

# Incoming updates / new records
incoming_data = [
    ("C001", "Alice Smith",   "alice@new.com",   "New York"),
    ("C003", "Charles Brown", "charlie@email.com", "San Francisco"),
    ("C004", "Diana Prince",  "diana@email.com", "Seattle"),
]

incoming = spark.createDataFrame(
    incoming_data,
    ["customer_id", "name", "email", "city"]
)

# Step 1: Get existing records NOT in the incoming set (unchanged records)
unchanged = existing_dim.join(
    incoming,
    "customer_id",
    "left_anti"
)

# Step 2: Add timestamp to incoming records (these are new/updated)
updated_incoming = incoming.withColumn("last_updated", lit("2024-03-01"))

# Step 3: Union unchanged + updated/new
result = unchanged.unionByName(updated_incoming).orderBy("customer_id")

print("=== SCD Type 1 Result (Anti Join + Union) ===")
result.show(truncate=False)

spark.stop()
```

## Method 2: Full Outer Join with Coalesce

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, coalesce, when

spark = SparkSession.builder \
    .appName("SCD_Type1_FullOuterJoin") \
    .master("local[*]") \
    .getOrCreate()

existing_data = [
    ("C001", "Alice Smith",   "alice@old.com",     "New York",    "2024-01-01"),
    ("C002", "Bob Johnson",   "bob@email.com",     "Chicago",     "2024-01-15"),
    ("C003", "Charlie Brown", "charlie@email.com", "Los Angeles", "2024-02-01"),
]

existing_dim = spark.createDataFrame(
    existing_data,
    ["customer_id", "name", "email", "city", "last_updated"]
)

incoming_data = [
    ("C001", "Alice Smith",   "alice@new.com",     "New York"),
    ("C003", "Charles Brown", "charlie@email.com", "San Francisco"),
    ("C004", "Diana Prince",  "diana@email.com",   "Seattle"),
]

incoming = spark.createDataFrame(
    incoming_data,
    ["customer_id", "name", "email", "city"]
).withColumn("last_updated", lit("2024-03-01"))

# Full outer join: incoming takes precedence (overwrites existing)
result = existing_dim.alias("e").join(
    incoming.alias("i"),
    "customer_id",
    "full_outer"
).select(
    coalesce(col("i.customer_id"), col("e.customer_id")).alias("customer_id"),
    coalesce(col("i.name"), col("e.name")).alias("name"),
    coalesce(col("i.email"), col("e.email")).alias("email"),
    coalesce(col("i.city"), col("e.city")).alias("city"),
    coalesce(col("i.last_updated"), col("e.last_updated")).alias("last_updated")
).orderBy("customer_id")

print("=== SCD Type 1 Result (Full Outer Join) ===")
result.show(truncate=False)

spark.stop()
```

## Method 3: Using Delta Lake MERGE (Production Approach)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, current_timestamp

spark = SparkSession.builder \
    .appName("SCD_Type1_DeltaMerge") \
    .master("local[*]") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# NOTE: This method requires Delta Lake libraries. The code below
# demonstrates the pattern; in a non-Delta environment, use Method 1 or 2.

existing_data = [
    ("C001", "Alice Smith",   "alice@old.com",     "New York",    "2024-01-01"),
    ("C002", "Bob Johnson",   "bob@email.com",     "Chicago",     "2024-01-15"),
    ("C003", "Charlie Brown", "charlie@email.com", "Los Angeles", "2024-02-01"),
]

existing_dim = spark.createDataFrame(
    existing_data,
    ["customer_id", "name", "email", "city", "last_updated"]
)

incoming_data = [
    ("C001", "Alice Smith",   "alice@new.com",     "New York"),
    ("C003", "Charles Brown", "charlie@email.com", "San Francisco"),
    ("C004", "Diana Prince",  "diana@email.com",   "Seattle"),
]

incoming = spark.createDataFrame(
    incoming_data,
    ["customer_id", "name", "email", "city"]
)

# Write existing dim as Delta table
# existing_dim.write.format("delta").mode("overwrite").save("/tmp/dim_customer")

# In Databricks or with Delta Lake:
# from delta.tables import DeltaTable
#
# delta_table = DeltaTable.forPath(spark, "/tmp/dim_customer")
#
# delta_table.alias("target").merge(
#     incoming.alias("source"),
#     "target.customer_id = source.customer_id"
# ).whenMatchedUpdate(set={
#     "name": "source.name",
#     "email": "source.email",
#     "city": "source.city",
#     "last_updated": "current_date()"
# }).whenNotMatchedInsert(values={
#     "customer_id": "source.customer_id",
#     "name": "source.name",
#     "email": "source.email",
#     "city": "source.city",
#     "last_updated": "current_date()"
# }).execute()

# Simulating the same logic without Delta using DataFrame operations:
from pyspark.sql.functions import coalesce

result = existing_dim.alias("t").join(
    incoming.alias("s"),
    "customer_id",
    "full_outer"
).select(
    coalesce(col("s.customer_id"), col("t.customer_id")).alias("customer_id"),
    coalesce(col("s.name"), col("t.name")).alias("name"),
    coalesce(col("s.email"), col("t.email")).alias("email"),
    coalesce(col("s.city"), col("t.city")).alias("city"),
    when(col("s.customer_id").isNotNull(), lit("2024-03-01"))
        .otherwise(col("t.last_updated")).alias("last_updated")
).orderBy("customer_id")

print("=== SCD Type 1 Result (Delta MERGE pattern) ===")
result.show(truncate=False)

spark.stop()
```

## Method 4: Conditional Update (Only When Changed)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, when, coalesce, md5, concat_ws

spark = SparkSession.builder \
    .appName("SCD_Type1_ConditionalUpdate") \
    .master("local[*]") \
    .getOrCreate()

existing_data = [
    ("C001", "Alice Smith",   "alice@old.com",     "New York",    "2024-01-01"),
    ("C002", "Bob Johnson",   "bob@email.com",     "Chicago",     "2024-01-15"),
    ("C003", "Charlie Brown", "charlie@email.com", "Los Angeles", "2024-02-01"),
]

existing_dim = spark.createDataFrame(
    existing_data,
    ["customer_id", "name", "email", "city", "last_updated"]
)

incoming_data = [
    ("C001", "Alice Smith",   "alice@new.com",     "New York"),
    ("C002", "Bob Johnson",   "bob@email.com",     "Chicago"),      # No change
    ("C003", "Charles Brown", "charlie@email.com", "San Francisco"),
    ("C004", "Diana Prince",  "diana@email.com",   "Seattle"),
]

incoming = spark.createDataFrame(
    incoming_data,
    ["customer_id", "name", "email", "city"]
)

# Add hash of tracked columns to detect actual changes
tracked_cols = ["name", "email", "city"]

existing_hashed = existing_dim.withColumn(
    "row_hash", md5(concat_ws("||", *[col(c) for c in tracked_cols]))
)

incoming_hashed = incoming.withColumn(
    "row_hash", md5(concat_ws("||", *[col(c) for c in tracked_cols]))
)

# Join and determine action
joined = existing_hashed.alias("e").join(
    incoming_hashed.alias("i"),
    "customer_id",
    "full_outer"
)

result = joined.select(
    coalesce(col("i.customer_id"), col("e.customer_id")).alias("customer_id"),
    coalesce(col("i.name"), col("e.name")).alias("name"),
    coalesce(col("i.email"), col("e.email")).alias("email"),
    coalesce(col("i.city"), col("e.city")).alias("city"),
    when(col("e.customer_id").isNull(), lit("2024-03-01"))            # New insert
        .when(col("e.row_hash") != col("i.row_hash"), lit("2024-03-01"))  # Changed
        .otherwise(col("e.last_updated")).alias("last_updated"),
    when(col("e.customer_id").isNull(), lit("INSERT"))
        .when(col("i.customer_id").isNull(), lit("UNCHANGED"))
        .when(col("e.row_hash") != col("i.row_hash"), lit("UPDATE"))
        .otherwise(lit("UNCHANGED")).alias("action")
).orderBy("customer_id")

print("=== SCD Type 1 with Change Detection ===")
result.show(truncate=False)

# Final table without action column
final = result.drop("action")
print("=== Final Dimension Table ===")
final.show(truncate=False)

spark.stop()
```

## Interview Tips

- **SCD Type 1 vs Type 2**: Type 1 overwrites and loses history. Type 2 preserves history by adding new rows with effective date ranges. Know when to use each.
- **Change detection**: Use hashing (`md5`, `sha2`) on tracked columns to avoid unnecessary updates when data has not actually changed. This reduces write amplification.
- **Delta Lake MERGE**: In production Databricks/Delta environments, always mention the `MERGE INTO` statement as the preferred approach. It handles insert/update/delete atomically.
- **Idempotency**: SCD Type 1 merges are naturally idempotent since re-running with the same data produces the same result.
- **Performance considerations**: For large dimensions, consider partitioning the dimension table by a column that aligns with update patterns, and broadcast the incoming updates if they are small relative to the existing table.
