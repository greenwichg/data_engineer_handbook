# PySpark Implementation: Conditional Routing to Multiple Outputs

## Problem Statement
Given a DataFrame of incoming records, split them into three separate DataFrames in a single
logical pass based on validation rules:
- **valid**: complete records that pass all checks
- **needs_review**: records with minor issues that can be fixed (e.g., missing optional fields)
- **rejected**: records that fail critical validation (e.g., null required fields, invalid formats)

This pattern is common in ETL pipelines for data quality routing.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, IntegerType

spark = SparkSession.builder.appName("ConditionalRouting").getOrCreate()

data = [
    (1,  "Alice",   "alice@email.com",    28, 55000.0),
    (2,  "Bob",     None,                 35, 72000.0),   # missing email -> needs_review
    (3,  None,      "carol@email.com",    30, 61000.0),   # missing name -> rejected
    (4,  "Dave",    "dave@email.com",     -5, 48000.0),   # negative age -> rejected
    (5,  "Eve",     "eve@email.com",      22, None),      # missing salary -> needs_review
    (6,  "Frank",   "frank@email.com",    45, 95000.0),
    (7,  "Grace",   "invalid-email",      29, 67000.0),   # bad email format -> needs_review
    (8,  "",        "hank@email.com",     50, 80000.0),   # empty name -> rejected
    (9,  "Ivy",     "ivy@email.com",      33, 71000.0),
    (10, "Jack",    "jack@email.com",     27, -1000.0),   # negative salary -> rejected
]

df = spark.createDataFrame(
    data, ["id", "name", "email", "age", "salary"]
)
df.show(truncate=False)
```

| id | name  | email           | age | salary  |
|----|-------|-----------------|-----|---------|
| 1  | Alice | alice@email.com | 28  | 55000.0 |
| 2  | Bob   | null            | 35  | 72000.0 |
| 3  | null  | carol@email.com | 30  | 61000.0 |
| 4  | Dave  | dave@email.com  | -5  | 48000.0 |
| 5  | Eve   | eve@email.com   | 22  | null    |
| 6  | Frank | frank@email.com | 45  | 95000.0 |
| 7  | Grace | invalid-email   | 29  | 67000.0 |
| 8  |       | hank@email.com  | 50  | 80000.0 |
| 9  | Ivy   | ivy@email.com   | 33  | 71000.0 |
| 10 | Jack  | jack@email.com  | 27  | -1000.0 |

### Expected Output

**valid** (4 rows): ids 1, 6, 9
**needs_review** (3 rows): ids 2, 5, 7
**rejected** (3 rows): ids 3, 4, 8, 10

---

## Method 1: Tag-Then-Filter with `persist()` (Recommended)

```python
from pyspark.sql import functions as F

# Step 1 -- Define validation conditions
is_name_missing    = F.col("name").isNull() | (F.trim(F.col("name")) == "")
is_age_invalid     = F.col("age") < 0
is_salary_invalid  = F.col("salary") < 0
has_valid_email    = F.col("email").rlike(r"^[^@]+@[^@]+\.[^@]+$")
is_email_missing   = F.col("email").isNull()

# Critical failures -> rejected
is_rejected = is_name_missing | is_age_invalid | is_salary_invalid

# Minor issues -> needs_review (only if not already rejected)
is_needs_review = ~is_rejected & (is_email_missing | ~has_valid_email)

# Step 2 -- Tag each row with its routing destination
df_tagged = df.withColumn(
    "route",
    F.when(is_rejected, "rejected")
     .when(is_needs_review, "needs_review")
     .otherwise("valid")
)

# Step 3 -- Persist the tagged DataFrame to avoid recomputation
df_tagged.persist()

# Step 4 -- Split into three DataFrames via filter
df_valid        = df_tagged.filter(F.col("route") == "valid").drop("route")
df_needs_review = df_tagged.filter(F.col("route") == "needs_review").drop("route")
df_rejected     = df_tagged.filter(F.col("route") == "rejected").drop("route")

print("=== VALID ===")
df_valid.show(truncate=False)

print("=== NEEDS REVIEW ===")
df_needs_review.show(truncate=False)

print("=== REJECTED ===")
df_rejected.show(truncate=False)

# Step 5 -- Unpersist when done
df_tagged.unpersist()
```

### Step-by-Step Explanation

**After Step 2** -- every row is tagged with its destination:

| id | name  | email           | age | salary  | route        |
|----|-------|-----------------|-----|---------|--------------|
| 1  | Alice | alice@email.com | 28  | 55000.0 | valid        |
| 2  | Bob   | null            | 35  | 72000.0 | needs_review |
| 3  | null  | carol@email.com | 30  | 61000.0 | rejected     |
| 4  | Dave  | dave@email.com  | -5  | 48000.0 | rejected     |
| 5  | Eve   | eve@email.com   | 22  | null    | needs_review |
| 6  | Frank | frank@email.com | 45  | 95000.0 | valid        |
| 7  | Grace | invalid-email   | 29  | 67000.0 | needs_review |
| 8  |       | hank@email.com  | 50  | 80000.0 | rejected     |
| 9  | Ivy   | ivy@email.com   | 33  | 71000.0 | valid        |
| 10 | Jack  | jack@email.com  | 27  | -1000.0 | rejected     |

**After Step 4** -- three separate DataFrames:

*df_valid:*

| id | name  | email           | age | salary  |
|----|-------|-----------------|-----|---------|
| 1  | Alice | alice@email.com | 28  | 55000.0 |
| 6  | Frank | frank@email.com | 45  | 95000.0 |
| 9  | Ivy   | ivy@email.com   | 33  | 71000.0 |

*df_needs_review:*

| id | name  | email         | age | salary  |
|----|-------|---------------|-----|---------|
| 2  | Bob   | null          | 35  | 72000.0 |
| 5  | Eve   | eve@email.com | 22  | null    |
| 7  | Grace | invalid-email | 29  | 67000.0 |

*df_rejected:*

| id | name | email           | age | salary  |
|----|------|-----------------|-----|---------|
| 3  | null | carol@email.com | 30  | 61000.0 |
| 4  | Dave | dave@email.com  | -5  | 48000.0 |
| 8  |      | hank@email.com  | 50  | 80000.0 |
| 10 | Jack | jack@email.com  | 27  | -1000.0 |

---

## Method 2: Write Partitioned by Route Tag

Instead of creating separate DataFrames, write the tagged DataFrame partitioned by the `route`
column. Each partition becomes its own directory, achieving the same logical split.

```python
from pyspark.sql import functions as F

# Reuse df_tagged from Method 1

# Write all three outputs in a single action
(
    df_tagged
    .write
    .partitionBy("route")
    .mode("overwrite")
    .parquet("/output/routed_records")
)

# Reading back a specific route is efficient -- Spark prunes partitions
df_valid_back = spark.read.parquet("/output/routed_records/route=valid")
df_valid_back.show()
```

This produces the directory structure:
```
/output/routed_records/
    route=valid/          part-00000.parquet
    route=needs_review/   part-00000.parquet
    route=rejected/       part-00000.parquet
```

---

## Method 3: Adding Rejection Reason Metadata

In production pipelines, it is useful to attach *why* a record was rejected or flagged.

```python
from pyspark.sql import functions as F

df_annotated = df.withColumn(
    "issues",
    F.array_remove(
        F.array(
            F.when(F.col("name").isNull() | (F.trim(F.col("name")) == ""), F.lit("missing_name")),
            F.when(F.col("age") < 0, F.lit("invalid_age")),
            F.when(F.col("salary") < 0, F.lit("invalid_salary")),
            F.when(F.col("email").isNull(), F.lit("missing_email")),
            F.when(~F.col("email").rlike(r"^[^@]+@[^@]+\.[^@]+$") & F.col("email").isNotNull(),
                   F.lit("invalid_email_format")),
        ),
        ""  # remove nulls (non-matching conditions)
    )
).withColumn("issue_count", F.size("issues"))

# NOTE: array_remove("", ...) removes empty strings; null entries from
# non-matching when() are already excluded by array() in Spark 3.x.
# Use array_compact() in Spark 3.4+ instead.

df_annotated.select("id", "name", "issues", "issue_count").show(truncate=False)
```

| id | name  | issues                 | issue_count |
|----|-------|------------------------|-------------|
| 1  | Alice | []                     | 0           |
| 2  | Bob   | [missing_email]        | 1           |
| 3  | null  | [missing_name]         | 1           |
| 4  | Dave  | [invalid_age]          | 1           |
| 10 | Jack  | [invalid_salary]       | 1           |
| 7  | Grace | [invalid_email_format] | 1           |

---

## Key Interview Talking Points

1. **`persist()` / `cache()` is critical** -- without it, each `filter()` triggers a full
   re-read and re-evaluation of the source DataFrame. Three filters = three full scans.
   With `persist()`, the data is computed once and reused.

2. **Tag-then-filter is the standard PySpark pattern** -- Spark has no built-in "demux" or
   "tee" operator. Tagging with a `route` column and filtering is idiomatic.

3. **Partition-by-route writes are more efficient** -- a single `.write.partitionBy("route")`
   avoids holding three DataFrames in memory and produces a clean directory layout.

4. **Rule priority matters** -- check critical failures first (rejected), then minor issues
   (needs_review), then default to valid. A row should land in exactly one bucket.

5. **Attach rejection reasons** -- production pipelines should record *why* a row was rejected,
   not just *that* it was rejected. This enables downstream investigation and data quality
   dashboards.

6. **`rlike` for regex validation** -- PySpark uses Java regex syntax. The `@` email check
   shown is simplified; production code should use a more robust pattern or UDF.

7. **Unpersist after use** -- forgetting to call `.unpersist()` leaks memory in long-running
   Spark applications. Use `try/finally` in production code.

8. **Metrics collection** -- always log the count of records in each route. Sudden spikes in
   rejected records signal upstream data quality issues.
