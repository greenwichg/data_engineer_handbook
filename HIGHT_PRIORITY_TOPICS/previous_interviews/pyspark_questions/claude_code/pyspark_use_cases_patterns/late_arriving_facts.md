# PySpark Implementation: Late-Arriving Facts

## Problem Statement

In data warehousing, fact records sometimes arrive after the dimension data they reference has already been updated. For example, a sales transaction from last week may arrive today, but the product's price or category has since changed. You need to associate the late-arriving fact with the correct dimension snapshot that was active at the time the event occurred. This is a common interview topic for data engineering roles at companies building enterprise data warehouses.

### Sample Data

**Fact Table (new arrivals including late facts):**
```
transaction_id | product_id | transaction_date | quantity | amount
101            | P001       | 2024-01-15       | 2        | 50.00
102            | P002       | 2024-02-20       | 1        | 30.00
103            | P001       | 2024-01-05       | 3        | 60.00   <-- late arriving
104            | P003       | 2023-12-25       | 1        | 100.00  <-- late arriving
```

**Dimension Table (SCD Type 2 with history):**
```
surrogate_key | product_id | product_name | category    | effective_start | effective_end | is_current
1             | P001       | Widget A     | Electronics | 2023-01-01      | 2024-01-10    | false
2             | P001       | Widget A+    | Electronics | 2024-01-10      | 9999-12-31    | true
3             | P002       | Gadget B     | Home        | 2023-06-01      | 9999-12-31    | true
4             | P003       | Tool C       | Hardware    | 2023-01-01      | 2024-01-01    | false
5             | P003       | Tool C Pro   | Tools       | 2024-01-01      | 9999-12-31    | true
```

### Expected Output

| transaction_id | product_id | transaction_date | surrogate_key | product_name | category    |
|----------------|------------|------------------|---------------|--------------|-------------|
| 101            | P001       | 2024-01-15       | 2             | Widget A+    | Electronics |
| 102            | P002       | 2024-02-20       | 3             | Gadget B     | Home        |
| 103            | P001       | 2024-01-05       | 1             | Widget A     | Electronics |
| 104            | P003       | 2023-12-25       | 4             | Tool C       | Hardware    |

---

## Method 1: Temporal Join with SCD Type 2 Dimension

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, lit, when

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("LateArrivingFacts") \
    .master("local[*]") \
    .getOrCreate()

# Create fact data (includes late-arriving records)
fact_data = [
    (101, "P001", "2024-01-15", 2, 50.00),
    (102, "P002", "2024-02-20", 1, 30.00),
    (103, "P001", "2024-01-05", 3, 60.00),   # Late arriving
    (104, "P003", "2023-12-25", 1, 100.00),  # Late arriving
]

facts = spark.createDataFrame(
    fact_data,
    ["transaction_id", "product_id", "transaction_date", "quantity", "amount"]
).withColumn("transaction_date", to_date("transaction_date"))

# Create SCD Type 2 dimension
dim_data = [
    (1, "P001", "Widget A",   "Electronics", "2023-01-01", "2024-01-10", False),
    (2, "P001", "Widget A+",  "Electronics", "2024-01-10", "9999-12-31", True),
    (3, "P002", "Gadget B",   "Home",        "2023-06-01", "9999-12-31", True),
    (4, "P003", "Tool C",     "Hardware",    "2023-01-01", "2024-01-01", False),
    (5, "P003", "Tool C Pro", "Tools",       "2024-01-01", "9999-12-31", True),
]

dimension = spark.createDataFrame(
    dim_data,
    ["surrogate_key", "product_id", "product_name", "category",
     "effective_start", "effective_end", "is_current"]
).withColumn("effective_start", to_date("effective_start")) \
 .withColumn("effective_end", to_date("effective_end"))

# Temporal join: match fact to the dimension version active at transaction_date
result = facts.join(
    dimension,
    (facts["product_id"] == dimension["product_id"]) &
    (facts["transaction_date"] >= dimension["effective_start"]) &
    (facts["transaction_date"] < dimension["effective_end"]),
    "left"
).select(
    facts["transaction_id"],
    facts["product_id"],
    facts["transaction_date"],
    facts["quantity"],
    facts["amount"],
    dimension["surrogate_key"],
    dimension["product_name"],
    dimension["category"]
).orderBy("transaction_id")

print("=== Facts joined to correct dimension version ===")
result.show(truncate=False)

spark.stop()
```

## Method 2: Handling Unmatched Late Facts with Default Dimension

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, when, coalesce, lit

spark = SparkSession.builder \
    .appName("LateArrivingFacts_WithDefault") \
    .master("local[*]") \
    .getOrCreate()

# Facts including one that arrives before any dimension record exists
fact_data = [
    (101, "P001", "2024-01-15", 2, 50.00),
    (102, "P002", "2024-02-20", 1, 30.00),
    (103, "P001", "2024-01-05", 3, 60.00),
    (104, "P003", "2023-12-25", 1, 100.00),
    (105, "P004", "2024-03-01", 5, 200.00),  # No dimension record at all
    (106, "P001", "2022-06-01", 1, 25.00),   # Before earliest dimension record
]

facts = spark.createDataFrame(
    fact_data,
    ["transaction_id", "product_id", "transaction_date", "quantity", "amount"]
).withColumn("transaction_date", to_date("transaction_date"))

dim_data = [
    (1, "P001", "Widget A",   "Electronics", "2023-01-01", "2024-01-10", False),
    (2, "P001", "Widget A+",  "Electronics", "2024-01-10", "9999-12-31", True),
    (3, "P002", "Gadget B",   "Home",        "2023-06-01", "9999-12-31", True),
    (4, "P003", "Tool C",     "Hardware",    "2023-01-01", "2024-01-01", False),
    (5, "P003", "Tool C Pro", "Tools",       "2024-01-01", "9999-12-31", True),
]

dimension = spark.createDataFrame(
    dim_data,
    ["surrogate_key", "product_id", "product_name", "category",
     "effective_start", "effective_end", "is_current"]
).withColumn("effective_start", to_date("effective_start")) \
 .withColumn("effective_end", to_date("effective_end"))

# Step 1: Temporal join
matched = facts.join(
    dimension,
    (facts["product_id"] == dimension["product_id"]) &
    (facts["transaction_date"] >= dimension["effective_start"]) &
    (facts["transaction_date"] < dimension["effective_end"]),
    "left"
)

# Step 2: Flag unmatched records and provide defaults
result = matched.select(
    facts["transaction_id"],
    facts["product_id"],
    facts["transaction_date"],
    facts["quantity"],
    facts["amount"],
    coalesce(dimension["surrogate_key"], lit(-1)).alias("surrogate_key"),
    coalesce(dimension["product_name"], lit("Unknown")).alias("product_name"),
    coalesce(dimension["category"], lit("Unknown")).alias("category"),
    when(dimension["surrogate_key"].isNull(), lit(True))
        .otherwise(lit(False)).alias("needs_reprocessing")
).orderBy("transaction_id")

print("=== All facts with default handling ===")
result.show(truncate=False)

# Step 3: Identify records that need reprocessing
print("=== Records needing reprocessing ===")
result.filter(col("needs_reprocessing") == True).show(truncate=False)

spark.stop()
```

## Method 3: Late Fact Reprocessing Pipeline

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, current_date, datediff, lit, when

spark = SparkSession.builder \
    .appName("LateArrivingFacts_Pipeline") \
    .master("local[*]") \
    .getOrCreate()

# Simulate existing fact table in warehouse (already loaded)
existing_facts = spark.createDataFrame([
    (100, "P001", "2024-01-12", 1, 25.00, 2, "Widget A+"),
], ["transaction_id", "product_id", "transaction_date", "quantity", "amount",
    "dim_surrogate_key", "product_name_snapshot"])

# New batch of incoming facts
incoming_facts = spark.createDataFrame([
    (101, "P001", "2024-01-15", 2, 50.00),
    (103, "P001", "2024-01-05", 3, 60.00),  # Late: references old dim version
], ["transaction_id", "product_id", "transaction_date", "quantity", "amount"]
).withColumn("transaction_date", to_date("transaction_date"))

# Dimension
dim_data = [
    (1, "P001", "Widget A",  "2023-01-01", "2024-01-10"),
    (2, "P001", "Widget A+", "2024-01-10", "9999-12-31"),
]
dimension = spark.createDataFrame(
    dim_data,
    ["sk", "product_id", "product_name", "eff_start", "eff_end"]
).withColumn("eff_start", to_date("eff_start")) \
 .withColumn("eff_end", to_date("eff_end"))

# Classify incoming facts
classified = incoming_facts.withColumn(
    "is_late",
    col("transaction_date") < to_date(lit("2024-01-12"))  # last load date
).withColumn(
    "lateness_days",
    datediff(current_date(), col("transaction_date"))
)

print("=== Classified incoming facts ===")
classified.show(truncate=False)

# Join all incoming facts with correct dimension version
enriched = incoming_facts.join(
    dimension,
    (incoming_facts["product_id"] == dimension["product_id"]) &
    (incoming_facts["transaction_date"] >= dimension["eff_start"]) &
    (incoming_facts["transaction_date"] < dimension["eff_end"]),
    "inner"
).select(
    incoming_facts["transaction_id"],
    incoming_facts["product_id"],
    incoming_facts["transaction_date"],
    incoming_facts["quantity"],
    incoming_facts["amount"],
    dimension["sk"].alias("dim_surrogate_key"),
    dimension["product_name"].alias("product_name_snapshot")
)

print("=== Enriched facts ready for warehouse ===")
enriched.show(truncate=False)

spark.stop()
```

## Key Concepts

- **Late-arriving fact**: A fact record whose event timestamp is earlier than the current processing window. It must be matched to the dimension version that was active at the time of the event, not the current version.
- **Temporal join**: Join the fact's event date to the dimension's effective date range (`effective_start <= event_date < effective_end`).
- **Default dimension member**: When no matching dimension version exists, assign a "Unknown" or "Inferred" surrogate key (commonly `-1`) and flag the record for later reprocessing.
- **Inferred members**: Some designs create a placeholder dimension row when a late fact references an unknown key, then update it when the real dimension data arrives.
- **Reprocessing**: Late facts may require reprocessing downstream aggregates that were computed without them.
- **Interview Tip**: Discuss the trade-off between accuracy (reprocessing all affected aggregates) and timeliness (accepting slightly stale aggregates). Also mention the importance of tracking the "load date" vs. "event date" to identify late arrivals.
