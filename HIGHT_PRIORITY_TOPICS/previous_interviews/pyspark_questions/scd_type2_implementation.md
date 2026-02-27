# PySpark Implementation: Slowly Changing Dimension Type 2 (SCD Type 2)

## Problem Statement

Implement an SCD Type 2 merge in PySpark. Given an **existing dimension table** (with history tracking columns) and an **incoming updates table**, update the dimension to:
1. **Close** the old record (set `end_date` and mark `is_current = false`) when a change is detected.
2. **Insert** the new record with updated values and mark it as the current version.
3. **Leave unchanged** records that have no updates.

This is a critical data warehousing concept and is frequently asked in senior data engineering interviews.

### Existing Dimension Table (dim_customer)

| customer_id | name       | city       | start_date | end_date   | is_current |
|-------------|------------|------------|------------|------------|------------|
| 101         | Alice      | New York   | 2024-01-01 | 9999-12-31 | true       |
| 102         | Bob        | Chicago    | 2024-01-01 | 9999-12-31 | true       |
| 103         | Charlie    | Boston     | 2024-01-01 | 9999-12-31 | true       |

### Incoming Updates (stg_customer)

| customer_id | name       | city       |
|-------------|------------|------------|
| 101         | Alice      | San Francisco |
| 104         | Diana      | Seattle       |

### Expected Output (dim_customer after SCD2 merge)

| customer_id | name    | city          | start_date | end_date   | is_current |
|-------------|---------|---------------|------------|------------|------------|
| 101         | Alice   | New York      | 2024-01-01 | 2025-01-20 | false      |
| 101         | Alice   | San Francisco | 2025-01-21 | 9999-12-31 | true       |
| 102         | Bob     | Chicago       | 2024-01-01 | 9999-12-31 | true       |
| 103         | Charlie | Boston        | 2024-01-01 | 9999-12-31 | true       |
| 104         | Diana   | Seattle       | 2025-01-21 | 9999-12-31 | true       |

---

## PySpark Implementation

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, current_date, date_sub, when, md5, concat_ws

# Initialize Spark session
spark = SparkSession.builder.appName("SCD_Type2").getOrCreate()

# Existing dimension table
dim_data = [
    (101, "Alice", "New York", "2024-01-01", "9999-12-31", True),
    (102, "Bob", "Chicago", "2024-01-01", "9999-12-31", True),
    (103, "Charlie", "Boston", "2024-01-01", "9999-12-31", True)
]
dim_columns = ["customer_id", "name", "city", "start_date", "end_date", "is_current"]
dim_df = spark.createDataFrame(dim_data, dim_columns)

# Incoming staging data (updates + new records)
stg_data = [
    (101, "Alice", "San Francisco"),
    (104, "Diana", "Seattle")
]
stg_columns = ["customer_id", "name", "city"]
stg_df = spark.createDataFrame(stg_data, stg_columns)

# Step 1: Join dimension with staging on customer_id to detect changes
joined = dim_df.filter(col("is_current") == True).join(
    stg_df,
    on="customer_id",
    how="full_outer"
)

# Step 2: Identify changed records using hash comparison on tracked columns
# Create hash of tracked attributes for comparison
dim_with_hash = dim_df.filter(col("is_current") == True) \
    .withColumn("dim_hash", md5(concat_ws("||", col("name"), col("city"))))

stg_with_hash = stg_df.withColumn("stg_hash", md5(concat_ws("||", col("name"), col("city"))))

comparison = dim_with_hash.join(
    stg_with_hash,
    on="customer_id",
    how="inner"
).filter(col("dim_hash") != col("stg_hash"))

# These are the customer_ids with changes
changed_ids = comparison.select("customer_id")

# Step 3: Close old records (set end_date and is_current = false)
closed_records = dim_df.join(changed_ids, on="customer_id", how="inner") \
    .filter(col("is_current") == True) \
    .withColumn("end_date", date_sub(current_date(), 1)) \
    .withColumn("is_current", lit(False))

# Step 4: Create new records for changed customers
new_records_changed = stg_df.join(changed_ids, on="customer_id", how="inner") \
    .withColumn("start_date", current_date()) \
    .withColumn("end_date", lit("9999-12-31")) \
    .withColumn("is_current", lit(True))

# Step 5: Create records for brand new customers (not in dimension)
existing_ids = dim_df.select("customer_id").distinct()
new_customers = stg_df.join(existing_ids, on="customer_id", how="left_anti") \
    .withColumn("start_date", current_date()) \
    .withColumn("end_date", lit("9999-12-31")) \
    .withColumn("is_current", lit(True))

# Step 6: Get unchanged records from dimension
unchanged_records = dim_df.join(changed_ids, on="customer_id", how="left_anti")

# Step 7: Union all parts together
final_dim = unchanged_records \
    .unionByName(closed_records) \
    .unionByName(new_records_changed) \
    .unionByName(new_customers)

final_dim.orderBy("customer_id", "start_date").show(truncate=False)
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Initial DataFrames

**dim_df (Dimension):**

| customer_id | name    | city     | start_date | end_date   | is_current |
|-------------|---------|----------|------------|------------|------------|
| 101         | Alice   | New York | 2024-01-01 | 9999-12-31 | true       |
| 102         | Bob     | Chicago  | 2024-01-01 | 9999-12-31 | true       |
| 103         | Charlie | Boston   | 2024-01-01 | 9999-12-31 | true       |

**stg_df (Staging):**

| customer_id | name  | city          |
|-------------|-------|---------------|
| 101         | Alice | San Francisco |
| 104         | Diana | Seattle       |

### Step 2: Identify Changed Records (Hash Comparison)
- **What happens:** Hashes the tracked columns (`name`, `city`) for both dimension and staging, then compares. Customer 101 has different city values ("New York" vs "San Francisco"), so the hashes differ.
- **changed_ids:**

  | customer_id |
  |-------------|
  | 101         |

### Step 3: Close Old Records
- **What happens:** For customer 101, the existing current record gets its `end_date` set to yesterday and `is_current` set to `false`.
- **closed_records:**

  | customer_id | name  | city     | start_date | end_date   | is_current |
  |-------------|-------|----------|------------|------------|------------|
  | 101         | Alice | New York | 2024-01-01 | 2025-01-20 | false      |

### Step 4: New Records for Changed Customers
- **What happens:** Creates a new current record for customer 101 with the updated city.
- **new_records_changed:**

  | customer_id | name  | city          | start_date | end_date   | is_current |
  |-------------|-------|---------------|------------|------------|------------|
  | 101         | Alice | San Francisco | 2025-01-21 | 9999-12-31 | true       |

### Step 5: Brand New Customers
- **What happens:** Customer 104 doesn't exist in the dimension — creates a new record.
- **new_customers:**

  | customer_id | name  | city    | start_date | end_date   | is_current |
  |-------------|-------|---------|------------|------------|------------|
  | 104         | Diana | Seattle | 2025-01-21 | 9999-12-31 | true       |

### Step 6: Unchanged Records
- **What happens:** Customers 102 and 103 have no updates — their records stay as-is.
- **unchanged_records:**

  | customer_id | name    | city    | start_date | end_date   | is_current |
  |-------------|---------|---------|------------|------------|------------|
  | 102         | Bob     | Chicago | 2024-01-01 | 9999-12-31 | true       |
  | 103         | Charlie | Boston  | 2024-01-01 | 9999-12-31 | true       |

### Step 7: Final Union
- **Output (final_dim):**

  | customer_id | name    | city          | start_date | end_date   | is_current |
  |-------------|---------|---------------|------------|------------|------------|
  | 101         | Alice   | New York      | 2024-01-01 | 2025-01-20 | false      |
  | 101         | Alice   | San Francisco | 2025-01-21 | 9999-12-31 | true       |
  | 102         | Bob     | Chicago       | 2024-01-01 | 9999-12-31 | true       |
  | 103         | Charlie | Boston        | 2024-01-01 | 9999-12-31 | true       |
  | 104         | Diana   | Seattle       | 2025-01-21 | 9999-12-31 | true       |

---

## Alternative: Using Delta Lake MERGE (Production Approach)

```python
# In production, Delta Lake's MERGE INTO simplifies SCD2 significantly
# This is pseudocode for a Delta Lake implementation

from delta.tables import DeltaTable

delta_dim = DeltaTable.forPath(spark, "/path/to/dim_customer")

delta_dim.alias("dim").merge(
    stg_df.alias("stg"),
    "dim.customer_id = stg.customer_id AND dim.is_current = true"
).whenMatchedUpdate(
    condition="dim.name != stg.name OR dim.city != stg.city",
    set={
        "end_date": "current_date() - 1",
        "is_current": "false"
    }
).whenNotMatchedInsert(
    values={
        "customer_id": "stg.customer_id",
        "name": "stg.name",
        "city": "stg.city",
        "start_date": "current_date()",
        "end_date": "lit('9999-12-31')",
        "is_current": "true"
    }
).execute()

# Note: Delta MERGE handles the matched-update in one pass,
# but inserting the new version of a changed row requires a second merge or insert step.
```

---

## Key Interview Talking Points

1. **SCD Types Overview:**
   - **Type 0:** No changes allowed (static dimension)
   - **Type 1:** Overwrite old value (no history)
   - **Type 2:** Add new row with versioning (full history preserved)
   - **Type 3:** Add new column for previous value (limited history)

2. **Why use hash comparison?** Using `md5(concat_ws(...))` on tracked columns is efficient — it avoids comparing each column individually and works well with many attributes.

3. **left_anti join:** This is the PySpark equivalent of `NOT IN` / `NOT EXISTS` in SQL. It returns rows from the left DataFrame that have no match in the right DataFrame.

4. **surrogate keys:** In production, SCD2 tables typically use a surrogate key (auto-increment or UUID) as the primary key instead of the business key.

5. **Performance:** For large dimensions, consider partitioning by `is_current` and using Delta Lake's Z-ordering on the business key.
