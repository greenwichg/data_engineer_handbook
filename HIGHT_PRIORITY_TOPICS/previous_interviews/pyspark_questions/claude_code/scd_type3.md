# PySpark Implementation: Slowly Changing Dimension Type 3

## Problem Statement

Slowly Changing Dimension (SCD) Type 3 is a data warehousing technique where you track limited history by adding a new column to store the previous value of a changing attribute. Unlike SCD Type 2 (which adds new rows), Type 3 adds new columns — typically storing only the current and previous values. This is a common interview topic for data engineering roles because it tests your understanding of dimensional modeling trade-offs and your ability to implement column-level history tracking in PySpark.

Given a dimension table with current values and an incoming update feed, implement SCD Type 3 logic that:
- Adds a `previous_` column to hold the old value when an attribute changes
- Updates the current column to the new value
- Records the date of the last change
- Leaves unchanged records untouched

### Sample Data

**Existing Dimension Table:**

```
customer_id | customer_name | city         | previous_city | last_change_date
----------- | ------------- | ------------ | ------------- | ----------------
1           | Alice         | New York     | NULL          | 2024-01-01
2           | Bob           | San Francisco| NULL          | 2024-01-01
3           | Charlie       | Chicago      | NULL          | 2024-01-01
4           | Diana         | Boston       | NULL          | 2024-01-01
```

**Incoming Updates:**

```
customer_id | customer_name | city
----------- | ------------- | -----------
1           | Alice         | Los Angeles
3           | Charlie       | Denver
5           | Eve           | Seattle
```

### Expected Output

| customer_id | customer_name | city          | previous_city  | last_change_date |
|-------------|---------------|---------------|----------------|------------------|
| 1           | Alice         | Los Angeles   | New York       | 2024-06-15       |
| 2           | Bob           | San Francisco | NULL           | 2024-01-01       |
| 3           | Charlie       | Denver        | Chicago        | 2024-06-15       |
| 4           | Diana         | Boston        | NULL           | 2024-01-01       |
| 5           | Eve           | Seattle       | NULL           | 2024-06-15       |

---

## Method 1: Using Left Join and Coalesce

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, lit, coalesce, current_date

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("SCD Type 3 - Join Approach") \
    .master("local[*]") \
    .getOrCreate()

# Create existing dimension table
dim_data = [
    (1, "Alice",   "New York",      None, "2024-01-01"),
    (2, "Bob",     "San Francisco", None, "2024-01-01"),
    (3, "Charlie", "Chicago",       None, "2024-01-01"),
    (4, "Diana",   "Boston",        None, "2024-01-01"),
]

dim_columns = ["customer_id", "customer_name", "city", "previous_city", "last_change_date"]
dim_df = spark.createDataFrame(dim_data, dim_columns)

# Create incoming updates
update_data = [
    (1, "Alice",   "Los Angeles"),
    (3, "Charlie", "Denver"),
    (5, "Eve",     "Seattle"),
]

update_columns = ["customer_id", "customer_name", "city"]
updates_df = spark.createDataFrame(update_data, update_columns)

# Alias for clarity
dim = dim_df.alias("dim")
upd = updates_df.alias("upd")

# Left join: dimension left join updates to find changed records
joined = dim.join(upd, on="customer_id", how="full_outer")

# Apply SCD Type 3 logic
scd3_result = joined.select(
    coalesce(col("dim.customer_id"), col("upd.customer_id")).alias("customer_id"),
    coalesce(col("upd.customer_name"), col("dim.customer_name")).alias("customer_name"),
    # New city: take update value if present, otherwise keep existing
    coalesce(col("upd.city"), col("dim.city")).alias("city"),
    # Previous city: if city changed, store the old city; otherwise keep existing previous_city
    when(
        col("upd.city").isNotNull() & col("dim.city").isNotNull() & (col("upd.city") != col("dim.city")),
        col("dim.city")
    ).otherwise(col("dim.previous_city")).alias("previous_city"),
    # Last change date: update if changed
    when(
        col("upd.city").isNotNull() & (col("dim.city").isNull() | (col("upd.city") != col("dim.city"))),
        lit("2024-06-15")
    ).otherwise(col("dim.last_change_date")).alias("last_change_date")
)

print("=== SCD Type 3 Result (Method 1: Join Approach) ===")
scd3_result.orderBy("customer_id").show(truncate=False)
```

## Method 2: Using Separate Processing for Changed, Unchanged, and New Records

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, broadcast

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("SCD Type 3 - Segmented Approach") \
    .master("local[*]") \
    .getOrCreate()

# Create existing dimension table
dim_data = [
    (1, "Alice",   "New York",      None, "2024-01-01"),
    (2, "Bob",     "San Francisco", None, "2024-01-01"),
    (3, "Charlie", "Chicago",       None, "2024-01-01"),
    (4, "Diana",   "Boston",        None, "2024-01-01"),
]

dim_columns = ["customer_id", "customer_name", "city", "previous_city", "last_change_date"]
dim_df = spark.createDataFrame(dim_data, dim_columns)

update_data = [
    (1, "Alice",   "Los Angeles"),
    (3, "Charlie", "Denver"),
    (5, "Eve",     "Seattle"),
]

update_columns = ["customer_id", "customer_name", "city"]
updates_df = spark.createDataFrame(update_data, update_columns)

# Step 1: Identify which existing records have updates
matched = dim_df.join(broadcast(updates_df), on="customer_id", how="inner")

# Step 2: Build updated records — shift current city to previous_city
changed_records = matched.select(
    col("customer_id"),
    updates_df["customer_name"],
    updates_df["city"].alias("city"),
    dim_df["city"].alias("previous_city"),
    lit("2024-06-15").alias("last_change_date")
)

# Step 3: Unchanged records (in dimension but not in updates)
update_ids = updates_df.select("customer_id")
unchanged_records = dim_df.join(update_ids, on="customer_id", how="left_anti")

# Step 4: New records (in updates but not in dimension)
dim_ids = dim_df.select("customer_id")
new_records = updates_df.join(dim_ids, on="customer_id", how="left_anti") \
    .withColumn("previous_city", lit(None).cast("string")) \
    .withColumn("last_change_date", lit("2024-06-15"))

# Step 5: Combine all three segments
final_result = changed_records \
    .unionByName(unchanged_records) \
    .unionByName(new_records)

print("=== SCD Type 3 Result (Method 2: Segmented Approach) ===")
final_result.orderBy("customer_id").show(truncate=False)
```

## Method 3: Using SQL with MERGE-style Logic

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("SCD Type 3 - SQL Approach") \
    .master("local[*]") \
    .getOrCreate()

# Create dimension table
dim_data = [
    (1, "Alice",   "New York",      None, "2024-01-01"),
    (2, "Bob",     "San Francisco", None, "2024-01-01"),
    (3, "Charlie", "Chicago",       None, "2024-01-01"),
    (4, "Diana",   "Boston",        None, "2024-01-01"),
]
dim_df = spark.createDataFrame(dim_data,
    ["customer_id", "customer_name", "city", "previous_city", "last_change_date"])

update_data = [
    (1, "Alice",   "Los Angeles"),
    (3, "Charlie", "Denver"),
    (5, "Eve",     "Seattle"),
]
updates_df = spark.createDataFrame(update_data, ["customer_id", "customer_name", "city"])

# Register temp views
dim_df.createOrReplaceTempView("dimension")
updates_df.createOrReplaceTempView("updates")

# SQL-based SCD Type 3
scd3_sql = spark.sql("""
    -- Existing records with potential updates
    SELECT
        COALESCE(d.customer_id, u.customer_id) AS customer_id,
        COALESCE(u.customer_name, d.customer_name) AS customer_name,
        COALESCE(u.city, d.city) AS city,
        CASE
            WHEN u.city IS NOT NULL AND d.city IS NOT NULL AND u.city != d.city
                THEN d.city
            WHEN u.city IS NOT NULL AND d.city IS NULL
                THEN NULL
            ELSE d.previous_city
        END AS previous_city,
        CASE
            WHEN u.city IS NOT NULL AND (d.city IS NULL OR u.city != d.city)
                THEN '2024-06-15'
            ELSE d.last_change_date
        END AS last_change_date
    FROM dimension d
    FULL OUTER JOIN updates u ON d.customer_id = u.customer_id
    ORDER BY customer_id
""")

print("=== SCD Type 3 Result (Method 3: SQL Approach) ===")
scd3_sql.show(truncate=False)

spark.stop()
```

## Key Concepts

- **SCD Type 3 vs Type 2**: Type 3 adds columns (limited history, only previous value); Type 2 adds rows (full history). Type 3 is simpler but only tracks one level of change.
- **Trade-offs**: Type 3 requires schema changes when tracking new attributes but avoids row explosion. It is best suited when you only need to compare current vs. previous values.
- **FULL OUTER JOIN**: Essential for handling all three cases — updates to existing records, unchanged records, and brand new records.
- **NULL handling**: Use `coalesce` and `when` carefully since the `previous_city` column starts as NULL and must only be populated when an actual change occurs.
- **Production considerations**: In real pipelines, you might use Delta Lake MERGE statements for atomic SCD Type 3 updates instead of rewriting the entire table.

## Interview Tips

- Be prepared to compare SCD Types 1, 2, and 3 and explain when each is appropriate.
- Mention that Type 3 can track multiple attributes by adding `previous_` columns for each one.
- Discuss the limitation: Type 3 only remembers one historical value — if the city changes again, the first original city is lost.
- In Delta Lake, the MERGE statement with `UPDATE SET` and `INSERT` clauses maps naturally to SCD Type 3 logic.
