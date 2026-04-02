# PySpark Implementation: Deduplication with Merge

## Problem Statement

When integrating data from multiple sources, you often encounter duplicate or partial records for the same entity. The goal is to merge these partial records into a single "golden record" by selecting the best (most complete, most recent, or highest priority) value for each field. This goes beyond simple deduplication (removing exact duplicates) into record consolidation. This is a common interview question for data integration and master data management roles.

### Sample Data

**Source 1 (CRM):**
```
customer_id | name          | email            | phone        | city
C001        | Alice Smith   | alice@work.com   | NULL         | New York
C002        | Bob J.        | NULL             | 555-0102     | NULL
C003        | Charlie Brown | charlie@home.com | 555-0103     | Boston
```

**Source 2 (E-Commerce):**
```
customer_id | name        | email            | phone        | city
C001        | A. Smith    | alice@home.com   | 555-0101     | NULL
C002        | Bob Johnson | bob@email.com    | NULL         | Chicago
C004        | Diana Prince| diana@email.com  | 555-0104     | Seattle
```

### Expected Output (Golden Records)

| customer_id | name          | email            | phone    | city     |
|-------------|---------------|------------------|----------|----------|
| C001        | Alice Smith   | alice@work.com   | 555-0101 | New York |
| C002        | Bob Johnson   | bob@email.com    | 555-0102 | Chicago  |
| C003        | Charlie Brown | charlie@home.com | 555-0103 | Boston   |
| C004        | Diana Prince  | diana@email.com  | 555-0104 | Seattle  |

---

## Method 1: Coalesce with Source Priority

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, coalesce, when, length, lit

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("DeduplicationWithMerge") \
    .master("local[*]") \
    .getOrCreate()

# Source 1: CRM (higher priority for name, email)
source1_data = [
    ("C001", "Alice Smith",   "alice@work.com",   None,       "New York"),
    ("C002", "Bob J.",        None,               "555-0102", None),
    ("C003", "Charlie Brown", "charlie@home.com", "555-0103", "Boston"),
]

source1 = spark.createDataFrame(
    source1_data,
    ["customer_id", "name", "email", "phone", "city"]
)

# Source 2: E-Commerce
source2_data = [
    ("C001", "A. Smith",     "alice@home.com", "555-0101", None),
    ("C002", "Bob Johnson",  "bob@email.com",  None,       "Chicago"),
    ("C004", "Diana Prince", "diana@email.com","555-0104", "Seattle"),
]

source2 = spark.createDataFrame(
    source2_data,
    ["customer_id", "name", "email", "phone", "city"]
)

# Full outer join on business key
merged = source1.alias("s1").join(
    source2.alias("s2"),
    "customer_id",
    "full_outer"
)

# Coalesce: take source1 value first (higher priority), fall back to source2
golden_records = merged.select(
    coalesce(col("s1.customer_id"), col("s2.customer_id")).alias("customer_id"),
    coalesce(col("s1.name"), col("s2.name")).alias("name"),
    coalesce(col("s1.email"), col("s2.email")).alias("email"),
    coalesce(col("s1.phone"), col("s2.phone")).alias("phone"),
    coalesce(col("s1.city"), col("s2.city")).alias("city"),
).orderBy("customer_id")

print("=== Golden Records (Source 1 Priority) ===")
golden_records.show(truncate=False)

spark.stop()
```

## Method 2: Longest/Most Complete Value Selection

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, coalesce, when, length, greatest, lit
)

spark = SparkSession.builder \
    .appName("DeduplicationWithMerge_LongestValue") \
    .master("local[*]") \
    .getOrCreate()

source1_data = [
    ("C001", "Alice Smith",   "alice@work.com",   None,       "New York"),
    ("C002", "Bob J.",        None,               "555-0102", None),
    ("C003", "Charlie Brown", "charlie@home.com", "555-0103", "Boston"),
]

source1 = spark.createDataFrame(
    source1_data,
    ["customer_id", "name", "email", "phone", "city"]
)

source2_data = [
    ("C001", "A. Smith",     "alice@home.com", "555-0101", None),
    ("C002", "Bob Johnson",  "bob@email.com",  None,       "Chicago"),
    ("C004", "Diana Prince", "diana@email.com","555-0104", "Seattle"),
]

source2 = spark.createDataFrame(
    source2_data,
    ["customer_id", "name", "email", "phone", "city"]
)

merged = source1.alias("s1").join(
    source2.alias("s2"),
    "customer_id",
    "full_outer"
)

# For string fields, prefer the longer (more complete) value
def prefer_longer(col1, col2):
    """Return the longer non-null string value."""
    return when(col1.isNull(), col2) \
        .when(col2.isNull(), col1) \
        .when(length(col1) >= length(col2), col1) \
        .otherwise(col2)

golden_records = merged.select(
    coalesce(col("s1.customer_id"), col("s2.customer_id")).alias("customer_id"),
    prefer_longer(col("s1.name"), col("s2.name")).alias("name"),
    prefer_longer(col("s1.email"), col("s2.email")).alias("email"),
    coalesce(col("s1.phone"), col("s2.phone")).alias("phone"),
    prefer_longer(col("s1.city"), col("s2.city")).alias("city"),
).orderBy("customer_id")

print("=== Golden Records (Longest Value Wins) ===")
golden_records.show(truncate=False)

spark.stop()
```

## Method 3: Multi-Source Merge with Completeness Scoring

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, coalesce, when, lit, sum as spark_sum,
    row_number, struct, first
)
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("DeduplicationWithMerge_Scoring") \
    .master("local[*]") \
    .getOrCreate()

# Three sources with varying completeness
all_records = [
    ("C001", "Alice Smith",   "alice@work.com",   None,       "New York",  "CRM"),
    ("C001", "A. Smith",      "alice@home.com",   "555-0101", None,        "ECOM"),
    ("C001", "Alice S.",      None,               "555-0101", "New York",  "SUPPORT"),
    ("C002", "Bob J.",        None,               "555-0102", None,        "CRM"),
    ("C002", "Bob Johnson",   "bob@email.com",    None,       "Chicago",   "ECOM"),
    ("C003", "Charlie Brown", "charlie@home.com", "555-0103", "Boston",    "CRM"),
]

df = spark.createDataFrame(
    all_records,
    ["customer_id", "name", "email", "phone", "city", "source"]
)

# Source priority weights
source_priority = {"CRM": 3, "ECOM": 2, "SUPPORT": 1}

# Calculate completeness score per record
scored = df.withColumn(
    "completeness_score",
    (when(col("name").isNotNull(), lit(1)).otherwise(lit(0)) +
     when(col("email").isNotNull(), lit(1)).otherwise(lit(0)) +
     when(col("phone").isNotNull(), lit(1)).otherwise(lit(0)) +
     when(col("city").isNotNull(), lit(1)).otherwise(lit(0)))
).withColumn(
    "source_weight",
    when(col("source") == "CRM", lit(3))
    .when(col("source") == "ECOM", lit(2))
    .otherwise(lit(1))
).withColumn(
    "total_score",
    col("completeness_score") * lit(10) + col("source_weight")
)

print("=== Records with Completeness Scores ===")
scored.show(truncate=False)

# For each customer, pick the best value per field
# Strategy: For each field, take the non-null value from the highest-priority source
fields_to_merge = ["name", "email", "phone", "city"]

# Order records by total score descending within each customer
window_spec = Window.partitionBy("customer_id").orderBy(col("total_score").desc())

ranked = scored.withColumn("rank", row_number().over(window_spec))

# Collect non-null values per field, preferring higher-ranked sources
# Use first non-null value from ordered records
from pyspark.sql.functions import collect_list, array_except, element_at, filter as array_filter

golden_aggs = []
for field in fields_to_merge:
    golden_aggs.append(
        first(col(field), ignorenulls=True).alias(field)
    )

# Window ordered by score to use first(ignorenulls=True)
golden = scored.orderBy("customer_id", col("total_score").desc()) \
    .groupBy("customer_id").agg(*golden_aggs) \
    .orderBy("customer_id")

print("=== Golden Records (Scored Merge) ===")
golden.show(truncate=False)

spark.stop()
```

## Method 4: Fuzzy Key Matching Before Merge

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, lower, trim, regexp_replace, soundex, coalesce, when, length
)

spark = SparkSession.builder \
    .appName("DeduplicationWithMerge_FuzzyMatch") \
    .master("local[*]") \
    .getOrCreate()

# Records that might refer to the same entity but with different keys
records = [
    (1, "Alice Smith",     "alice@work.com",   "555-0101", "CRM"),
    (2, "ALICE SMITH",     "alice@home.com",   None,       "ECOM"),
    (3, "Bob Johnson",     "bob@email.com",    "555-0102", "CRM"),
    (4, "Robert Johnson",  None,               "555-0102", "SUPPORT"),
    (5, "Charlie Brown",   "charlie@home.com", "555-0103", "CRM"),
]

df = spark.createDataFrame(
    records,
    ["record_id", "name", "email", "phone", "source"]
)

# Normalize fields for matching
normalized = df.withColumn(
    "name_normalized", lower(trim(regexp_replace(col("name"), r"[^a-zA-Z\s]", "")))
).withColumn(
    "name_soundex", soundex(col("name"))
).withColumn(
    "phone_normalized", regexp_replace(col("phone"), r"[^0-9]", "")
)

print("=== Normalized Records ===")
normalized.show(truncate=False)

# Match on exact normalized name OR same phone number
matched = normalized.alias("a").join(
    normalized.alias("b"),
    (col("a.record_id") < col("b.record_id")) &
    (
        (col("a.name_normalized") == col("b.name_normalized")) |
        (
            col("a.phone_normalized").isNotNull() &
            col("b.phone_normalized").isNotNull() &
            (col("a.phone_normalized") == col("b.phone_normalized"))
        )
    ),
    "inner"
)

print("=== Matched Pairs ===")
matched.select(
    col("a.record_id").alias("id_1"),
    col("a.name").alias("name_1"),
    col("b.record_id").alias("id_2"),
    col("b.name").alias("name_2"),
).show(truncate=False)

# In practice, you would use connected components to build match clusters
# then apply the merge logic from Method 1 or 3 within each cluster

spark.stop()
```

## Key Concepts

- **Golden record**: A single consolidated record per entity that combines the best data from all sources.
- **Source priority**: Not all sources are equal. CRM data may be more authoritative for names while transaction data is better for purchase history.
- **Coalesce pattern**: `coalesce(source1_col, source2_col, source3_col)` returns the first non-null value. Order determines priority.
- **Completeness scoring**: Score each source record by how many fields are populated, weighted by source reliability.
- **Fuzzy matching**: Before merging, you may need to identify which records across sources refer to the same entity using normalized names, soundex, phone matching, or more advanced entity resolution.

## Interview Tips

- Explain the difference between **deduplication** (removing exact duplicates) and **entity resolution** (identifying records that refer to the same real-world entity across sources).
- Discuss **survivorship rules**: the logic for choosing which value "survives" into the golden record. This is often configurable per field.
- Mention **conflict resolution**: when two trusted sources disagree on a value, how do you decide? Options include most recent, most frequent, or manual review.
- In production, tools like Zingg, Dedupe.io, or Splink are used for probabilistic record linkage at scale.
- Always preserve source lineage (which source contributed each field) for auditability.
