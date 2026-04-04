# PySpark Implementation: Constructing Effective Date Ranges from Change Records

## Problem Statement
You are given a table of product price changes. Each row records a product_id, the new price,
and the date the price was updated. Your task is to construct a **price history table** with
explicit `valid_from` and `valid_to` date ranges, so that for any given date you can look up
what price was in effect.

The final "current" record for each product should have `valid_to = NULL` (or a far-future
sentinel date) to indicate it is still active.

### Sample Data

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lead, lit, coalesce, date_sub
from pyspark.sql.window import Window
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, DateType
from datetime import date

spark = SparkSession.builder.appName("EffectiveDateRanges").getOrCreate()

data = [
    ("P001", 10.00, date(2024, 1, 1)),
    ("P001", 12.50, date(2024, 3, 15)),
    ("P001", 11.00, date(2024, 6, 1)),
    ("P001", 14.00, date(2024, 9, 10)),
    ("P002", 25.00, date(2024, 2, 1)),
    ("P002", 27.50, date(2024, 5, 20)),
    ("P002", 23.00, date(2024, 8, 1)),
    ("P003", 5.00,  date(2024, 1, 15)),
    ("P003", 6.50,  date(2024, 7, 1)),
]

schema = StructType([
    StructField("product_id", StringType()),
    StructField("price", DoubleType()),
    StructField("update_date", DateType()),
])

df = spark.createDataFrame(data, schema)
df.show()
```

| product_id | price | update_date |
|------------|-------|-------------|
| P001       | 10.00 | 2024-01-01  |
| P001       | 12.50 | 2024-03-15  |
| P001       | 11.00 | 2024-06-01  |
| P001       | 14.00 | 2024-09-10  |
| P002       | 25.00 | 2024-02-01  |
| P002       | 27.50 | 2024-05-20  |
| P002       | 23.00 | 2024-08-01  |
| P003       | 5.00  | 2024-01-15  |
| P003       | 6.50  | 2024-07-01  |

### Expected Output

| product_id | price | valid_from | valid_to   |
|------------|-------|------------|------------|
| P001       | 10.00 | 2024-01-01 | 2024-03-14 |
| P001       | 12.50 | 2024-03-15 | 2024-05-31 |
| P001       | 11.00 | 2024-06-01 | 2024-09-09 |
| P001       | 14.00 | 2024-09-10 | NULL       |
| P002       | 25.00 | 2024-02-01 | 2024-05-19 |
| P002       | 27.50 | 2024-05-20 | 2024-07-31 |
| P002       | 23.00 | 2024-08-01 | NULL       |
| P003       | 5.00  | 2024-01-15 | 2024-06-30 |
| P003       | 6.50  | 2024-07-01 | NULL       |

---

## Method 1: lead() Window Function (Recommended)

```python
from pyspark.sql.functions import col, lead, date_sub
from pyspark.sql.window import Window

# Define a window partitioned by product, ordered by update_date
w = Window.partitionBy("product_id").orderBy("update_date")

# Use lead() to get the next update_date, then subtract 1 day for valid_to
result = (
    df
    .withColumn("valid_from", col("update_date"))
    .withColumn(
        "next_update_date",
        lead("update_date").over(w)
    )
    .withColumn(
        "valid_to",
        date_sub(col("next_update_date"), 1)   # day before next change
    )
    .select("product_id", "price", "valid_from", "valid_to")
)

result.orderBy("product_id", "valid_from").show()
```

### Step-by-Step Explanation

**Step 1 -- Rename update_date to valid_from (trivial rename for clarity):**

| product_id | price | valid_from | update_date |
|------------|-------|------------|-------------|
| P001       | 10.00 | 2024-01-01 | 2024-01-01  |
| P001       | 12.50 | 2024-03-15 | 2024-03-15  |
| P001       | 11.00 | 2024-06-01 | 2024-06-01  |
| P001       | 14.00 | 2024-09-10 | 2024-09-10  |

**Step 2 -- Apply lead() to get next_update_date within each product partition:**

| product_id | price | valid_from | next_update_date |
|------------|-------|------------|------------------|
| P001       | 10.00 | 2024-01-01 | 2024-03-15       |
| P001       | 12.50 | 2024-03-15 | 2024-06-01       |
| P001       | 11.00 | 2024-06-01 | 2024-09-10       |
| P001       | 14.00 | 2024-09-10 | NULL             |

**Step 3 -- Subtract 1 day from next_update_date to get valid_to:**

The last row for each product has `next_update_date = NULL`, so `date_sub(NULL, 1) = NULL`,
which naturally represents the still-active record.

| product_id | price | valid_from | valid_to   |
|------------|-------|------------|------------|
| P001       | 10.00 | 2024-01-01 | 2024-03-14 |
| P001       | 12.50 | 2024-03-15 | 2024-05-31 |
| P001       | 11.00 | 2024-06-01 | 2024-09-09 |
| P001       | 14.00 | 2024-09-10 | NULL       |

---

## Method 2: Self-Join on Row Numbers

```python
from pyspark.sql.functions import col, row_number, date_sub
from pyspark.sql.window import Window

w = Window.partitionBy("product_id").orderBy("update_date")

numbered = df.withColumn("rn", row_number().over(w))

# Self-join: current row joins to the next row (rn + 1) on the same product
current = numbered.alias("curr")
next_row = numbered.alias("nxt")

result = (
    current.join(
        next_row,
        (col("curr.product_id") == col("nxt.product_id")) &
        (col("curr.rn") + 1 == col("nxt.rn")),
        "left"
    )
    .select(
        col("curr.product_id"),
        col("curr.price"),
        col("curr.update_date").alias("valid_from"),
        date_sub(col("nxt.update_date"), 1).alias("valid_to"),
    )
    .orderBy("product_id", "valid_from")
)

result.show()
```

---

## Key Interview Talking Points

1. **lead() vs self-join**: The `lead()` approach is a single-pass window operation and avoids
   the shuffle cost of a self-join. Always prefer window functions when the logic allows it.

2. **Handling the current record**: The last row per partition naturally gets `NULL` from
   `lead()`, which propagates through `date_sub()` as `NULL`. No special-case logic is needed
   unless the business requires a sentinel date like `9999-12-31`.

3. **valid_to = next_valid_from - 1 day**: This creates non-overlapping, gap-free ranges.
   Some systems use half-open intervals `[valid_from, valid_to)` where `valid_to` equals
   the next `valid_from` exactly. Clarify the convention with your interviewer.

4. **Partition and order matter**: The window must be `partitionBy("product_id")` to avoid
   mixing products, and `orderBy("update_date")` to ensure chronological sequencing.

5. **Duplicate timestamps**: If two updates can share the same date, you need a tiebreaker
   column (e.g., a sequence_id or ingestion timestamp) in the `orderBy` clause.

6. **SCD Type 2 connection**: This pattern is the foundation of Slowly Changing Dimension
   Type 2 in data warehousing. The same lead() technique builds the `effective_start` and
   `effective_end` columns used in dimensional models.

7. **Performance**: Window functions require a sort within each partition. For very large
   datasets, ensure the partition key has reasonable cardinality to avoid data skew.
