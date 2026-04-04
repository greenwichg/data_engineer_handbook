# PySpark Implementation: Latest Transaction for Frequent Customers

## Problem Statement 

Given a dataset of customer transactions, find the **latest transaction** for each customer who has **more than 3 transactions**. This tests your ability to combine window functions (`count`, `row_number`) with filtering logic.

### Sample Data

```
Cid  transaction_date  transaction_amount
1    01-08-2025        100
1    02-08-2025        250
1    04-08-2025        150
2    01-08-2025        190
1    07-08-2025        300
2    09-08-2025        450
3    01-08-2025        350
4    11-08-2025        280
3    10-08-2025        170
3    14-08-2025        150
3    18-08-2025        300
```

### Expected Output

| Cid | transaction_date | transaction_amount |
|-----|------------------|--------------------|
| 1   | 2025-08-07       | 300                |
| 3   | 2025-08-18       | 300                |

Only Cid 1 (4 transactions) and Cid 3 (4 transactions) qualify. Cid 2 (2) and Cid 4 (1) are excluded.

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import to_date, count, row_number, desc, col
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("LatestTransactions").getOrCreate()

data = [
    (1, "01-08-2025", 100),
    (1, "02-08-2025", 250),
    (1, "04-08-2025", 150),
    (2, "01-08-2025", 190),
    (1, "07-08-2025", 300),
    (2, "09-08-2025", 450),
    (3, "01-08-2025", 350),
    (4, "11-08-2025", 280),
    (3, "10-08-2025", 170),
    (3, "14-08-2025", 150),
    (3, "18-08-2025", 300)
]

columns = ["Cid", "transaction_date", "transaction_amount"]
df = spark.createDataFrame(data, columns)

# Convert string date to proper date type
df = df.withColumn("transaction_date", to_date("transaction_date", "dd-MM-yyyy"))

# Step 1: Count transactions per customer using window
window_count = Window.partitionBy("Cid")
df_with_count = df.withColumn("trans_count", count("*").over(window_count))

# Step 2: Filter customers with more than 3 transactions
filtered_df = df_with_count.filter("trans_count > 3")

# Step 3: Rank by date descending and keep the latest
window_latest = Window.partitionBy("Cid").orderBy(desc("transaction_date"))
latest_transactions = filtered_df.withColumn("rn", row_number().over(window_latest)) \
                                 .filter("rn == 1") \
                                 .drop("rn", "trans_count")

latest_transactions.show()
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Count Transactions Per Customer

- **What happens:** A window partitioned by `Cid` counts total transactions per customer. This count is replicated on every row for that customer.
- **Output (df_with_count):**

  | Cid | transaction_date | transaction_amount | trans_count |
  |-----|------------------|--------------------|-------------|
  | 1   | 2025-08-01       | 100                | 4           |
  | 1   | 2025-08-02       | 250                | 4           |
  | 1   | 2025-08-04       | 150                | 4           |
  | 1   | 2025-08-07       | 300                | 4           |
  | 2   | 2025-08-01       | 190                | 2           |
  | 2   | 2025-08-09       | 450                | 2           |
  | 3   | 2025-08-01       | 350                | 4           |
  | 3   | 2025-08-10       | 170                | 4           |
  | 3   | 2025-08-14       | 150                | 4           |
  | 3   | 2025-08-18       | 300                | 4           |
  | 4   | 2025-08-11       | 280                | 1           |

### Step 2: Filter Customers with > 3 Transactions

- **What happens:** Removes all rows where `trans_count <= 3`. This eliminates Cid 2 (2 transactions) and Cid 4 (1 transaction).
- **Output (filtered_df):**

  | Cid | transaction_date | transaction_amount | trans_count |
  |-----|------------------|--------------------|-------------|
  | 1   | 2025-08-01       | 100                | 4           |
  | 1   | 2025-08-02       | 250                | 4           |
  | 1   | 2025-08-04       | 150                | 4           |
  | 1   | 2025-08-07       | 300                | 4           |
  | 3   | 2025-08-01       | 350                | 4           |
  | 3   | 2025-08-10       | 170                | 4           |
  | 3   | 2025-08-14       | 150                | 4           |
  | 3   | 2025-08-18       | 300                | 4           |

### Step 3: Rank by Date and Keep Latest

- **What happens:** A second window partitions by `Cid` and orders by `transaction_date` descending. `row_number()` assigns rank 1 to the most recent transaction per customer. Filtering `rn == 1` keeps only the latest.
- **Intermediate (before filter):**

  | Cid | transaction_date | transaction_amount | trans_count | rn |
  |-----|------------------|--------------------|-------------|----|
  | 1   | 2025-08-07       | 300                | 4           | 1  |
  | 1   | 2025-08-04       | 150                | 4           | 2  |
  | 1   | 2025-08-02       | 250                | 4           | 3  |
  | 1   | 2025-08-01       | 100                | 4           | 4  |
  | 3   | 2025-08-18       | 300                | 4           | 1  |
  | 3   | 2025-08-14       | 150                | 4           | 2  |
  | 3   | 2025-08-10       | 170                | 4           | 3  |
  | 3   | 2025-08-01       | 350                | 4           | 4  |

- **Final Output (latest_transactions):**

  | Cid | transaction_date | transaction_amount |
  |-----|------------------|--------------------|
  | 1   | 2025-08-07       | 300                |
  | 3   | 2025-08-18       | 300                |

---

## Alternative: Using GroupBy + Join (Without Window for Counting)

```python
from pyspark.sql.functions import max as spark_max

# Count transactions per customer using groupBy
customer_counts = df.groupBy("Cid").agg(
    count("*").alias("trans_count")
).filter("trans_count > 3")

# Get latest transaction date per qualifying customer
latest_dates = df.join(customer_counts.select("Cid"), "Cid") \
    .groupBy("Cid").agg(
        spark_max("transaction_date").alias("max_date")
    )

# Join back to get the full row
result = df.join(latest_dates,
    (df.Cid == latest_dates.Cid) & (df.transaction_date == latest_dates.max_date),
    "inner"
).select(df.Cid, df.transaction_date, df.transaction_amount)

result.show()
```

This approach avoids window functions entirely but requires multiple joins, which may be less efficient for large datasets.

---

## Key Interview Talking Points

1. **Window count vs groupBy count:** Using `count().over(Window.partitionBy("Cid"))` preserves all original rows (adds count as a new column), while `groupBy().agg(count())` collapses rows. The window approach lets you filter and rank in a single pass without re-joining.

2. **Why two separate windows?** The count window has no `orderBy` (we want the total count per customer), while the ranking window needs `orderBy(desc("transaction_date"))` to identify the latest row.

3. **row_number vs rank vs dense_rank:** If two transactions share the same latest date, `row_number()` picks one arbitrarily, while `rank()` would return both. Discuss which behavior is desired.

4. **Date parsing:** The `to_date("col", "dd-MM-yyyy")` format string must match the input exactly. A common bug is using `DD` (day of year) instead of `dd` (day of month).
