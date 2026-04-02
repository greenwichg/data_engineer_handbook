# PySpark Implementation: Deduplicating Records

## Problem Statement 

Given a dataset of customer orders where some records are duplicated (either exact duplicates or partial duplicates based on certain key columns), remove the duplicates while keeping the most recent record. This is one of the most frequently asked PySpark interview questions, as deduplication is a fundamental data engineering operation.

### Sample Data

```
order_id  customer_id  product    amount  order_date
1001      C001         Laptop     1200    2025-01-15
1002      C001         Laptop     1200    2025-01-15
1003      C002         Phone      800     2025-01-16
1004      C002         Phone      850     2025-01-17
1005      C003         Tablet     600     2025-01-18
1006      C003         Tablet     600     2025-01-20
1007      C003         Tablet     700     2025-01-22
```

### Scenario 1: Remove exact duplicate rows
**Expected Output:** Remove row 1002 (exact duplicate of 1001)

### Scenario 2: Keep latest record per customer + product
**Expected Output:** Keep only the most recent order for each customer-product combination

---

## Method 1: dropDuplicates() for Exact Duplicates

```python
from pyspark.sql import SparkSession

# Initialize Spark session
spark = SparkSession.builder.appName("DeduplicateRecords").getOrCreate()

# Sample data
data = [
    (1001, "C001", "Laptop", 1200, "2025-01-15"),
    (1002, "C001", "Laptop", 1200, "2025-01-15"),
    (1003, "C002", "Phone", 800, "2025-01-16"),
    (1004, "C002", "Phone", 850, "2025-01-17"),
    (1005, "C003", "Tablet", 600, "2025-01-18"),
    (1006, "C003", "Tablet", 600, "2025-01-20"),
    (1007, "C003", "Tablet", 700, "2025-01-22")
]

columns = ["order_id", "customer_id", "product", "amount", "order_date"]
df = spark.createDataFrame(data, columns)

# Remove exact duplicates based on subset of columns (ignoring order_id)
deduped_exact = df.dropDuplicates(["customer_id", "product", "amount", "order_date"])
deduped_exact.show()
```

### Step-by-Step Explanation

#### Step 1: Initial DataFrame
- **Output:**

  | order_id | customer_id | product | amount | order_date |
  |----------|-------------|---------|--------|------------|
  | 1001     | C001        | Laptop  | 1200   | 2025-01-15 |
  | 1002     | C001        | Laptop  | 1200   | 2025-01-15 |
  | 1003     | C002        | Phone   | 800    | 2025-01-16 |
  | 1004     | C002        | Phone   | 850    | 2025-01-17 |
  | 1005     | C003        | Tablet  | 600    | 2025-01-18 |
  | 1006     | C003        | Tablet  | 600    | 2025-01-20 |
  | 1007     | C003        | Tablet  | 700    | 2025-01-22 |

#### Step 2: dropDuplicates(["customer_id", "product", "amount", "order_date"])
- **What happens:** Removes rows where the combination of `customer_id`, `product`, `amount`, and `order_date` is identical. Rows 1001 and 1002 have the same values for these columns — one is removed.
- **Output:**

  | order_id | customer_id | product | amount | order_date |
  |----------|-------------|---------|--------|------------|
  | 1001     | C001        | Laptop  | 1200   | 2025-01-15 |
  | 1003     | C002        | Phone   | 800    | 2025-01-16 |
  | 1004     | C002        | Phone   | 850    | 2025-01-17 |
  | 1005     | C003        | Tablet  | 600    | 2025-01-18 |
  | 1006     | C003        | Tablet  | 600    | 2025-01-20 |
  | 1007     | C003        | Tablet  | 700    | 2025-01-22 |

**Note:** `dropDuplicates()` does NOT guarantee which row is kept. If you need to control which row to retain, use Method 2.

---

## Method 2: Window Function with row_number() — Keep Latest Record

```python
from pyspark.sql.functions import row_number, col, to_date, desc
from pyspark.sql.window import Window

# Convert order_date to date type
df = df.withColumn("order_date", to_date(col("order_date")))

# Define window: partition by customer_id and product, order by order_date descending
window_spec = Window.partitionBy("customer_id", "product").orderBy(desc("order_date"))

# Add row number — 1 = most recent per group
df_ranked = df.withColumn("rn", row_number().over(window_spec))

# Keep only the latest record per customer-product
deduped_latest = df_ranked.filter(col("rn") == 1).drop("rn")

deduped_latest.show()
```

### Step-by-Step Explanation

#### Step 1: Convert order_date to DateType
- **What happens:** Converts string dates to proper DateType for correct ordering.
- **Output:** Same data but `order_date` is now DateType.

#### Step 2: Define Window Specification
- **What happens:** Creates a window that:
  1. Partitions (groups) by `customer_id` and `product`
  2. Orders by `order_date` descending (newest first)
- **No output:** Just a specification for the next step.

#### Step 3: Add row_number()
- **What happens:** Assigns a sequential row number within each partition. The most recent record gets `rn = 1`.
- **Output (df_ranked):**

  | order_id | customer_id | product | amount | order_date | rn |
  |----------|-------------|---------|--------|------------|----|
  | 1001     | C001        | Laptop  | 1200   | 2025-01-15 | 1  |
  | 1002     | C001        | Laptop  | 1200   | 2025-01-15 | 2  |
  | 1004     | C002        | Phone   | 850    | 2025-01-17 | 1  |
  | 1003     | C002        | Phone   | 800    | 2025-01-16 | 2  |
  | 1007     | C003        | Tablet  | 700    | 2025-01-22 | 1  |
  | 1006     | C003        | Tablet  | 600    | 2025-01-20 | 2  |
  | 1005     | C003        | Tablet  | 600    | 2025-01-18 | 3  |

#### Step 4: Filter rn == 1 and drop rn
- **What happens:** Keeps only the latest (most recent) record per customer-product combination.
- **Output (deduped_latest):**

  | order_id | customer_id | product | amount | order_date |
  |----------|-------------|---------|--------|------------|
  | 1001     | C001        | Laptop  | 1200   | 2025-01-15 |
  | 1004     | C002        | Phone   | 850    | 2025-01-17 |
  | 1007     | C003        | Tablet  | 700    | 2025-01-22 |

---

## Method 3: Using groupBy with max (Aggregation Approach)

```python
from pyspark.sql.functions import max as spark_max, first

# Keep the record with the latest order_date per customer-product
deduped_agg = df.groupBy("customer_id", "product") \
    .agg(
        spark_max("order_date").alias("order_date"),
        spark_max("amount").alias("amount"),
        first("order_id").alias("order_id")
    )

deduped_agg.show()
```

- **Explanation:** Groups by the dedup key columns and takes the max date. Note that `first()` on `order_id` is non-deterministic — use this approach only when you don't need precise control over which specific row's values are retained for non-key columns.

---

## Comparison of Methods

| Method | Use Case | Deterministic? | Performance |
|--------|----------|----------------|-------------|
| `dropDuplicates()` | Exact duplicate removal | No (random row kept) | Fast — single shuffle |
| `row_number()` window | Keep specific record (latest, earliest) | Yes — fully controlled | Moderate — sort + shuffle |
| `groupBy + agg` | Aggregate dedup with flexibility | Partial (depends on agg functions) | Fast — single shuffle |

## Key Interview Talking Points

1. **dropDuplicates vs distinct:** `distinct()` checks all columns; `dropDuplicates(subset)` checks only specified columns.
2. **row_number vs rank vs dense_rank:**
   - `row_number()`: Always unique — 1, 2, 3 (use for strict dedup)
   - `rank()`: Ties get same rank, gaps after — 1, 1, 3
   - `dense_rank()`: Ties get same rank, no gaps — 1, 1, 2
3. **Performance consideration:** Window functions require a sort, which is expensive on large datasets. For simple exact dedup, prefer `dropDuplicates()`.
4. **Null handling:** `dropDuplicates()` treats two null values as equal.
