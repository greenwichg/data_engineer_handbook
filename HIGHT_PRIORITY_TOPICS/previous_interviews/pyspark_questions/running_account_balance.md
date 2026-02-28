# PySpark Implementation: Running Account Balance with Overdraft Detection

## Problem Statement

Given a dataset of bank transactions (deposits and withdrawals) for multiple accounts, compute a **running balance** after each transaction and **flag any overdrafts** (balance going negative). This is the financial version of the `running_total` pattern — same cumulative sum window function, but with sign-aware amounts and business logic on top.

### Sample Data

```
account_id  txn_date     txn_type    amount   description
A001        2025-01-01   DEPOSIT     5000     Initial deposit
A001        2025-01-05   WITHDRAWAL  1200     Rent payment
A001        2025-01-10   WITHDRAWAL  800      Utilities
A001        2025-01-12   DEPOSIT     3000     Salary
A001        2025-01-15   WITHDRAWAL  7500     Car purchase
A001        2025-01-18   DEPOSIT     2000     Freelance
A002        2025-01-01   DEPOSIT     10000    Initial deposit
A002        2025-01-08   WITHDRAWAL  3000     Transfer
A002        2025-01-15   WITHDRAWAL  4000     Investment
```

### Expected Output

| account_id | txn_date   | txn_type   | amount | running_balance | is_overdraft |
|------------|-----------|------------|--------|-----------------|-------------|
| A001       | 2025-01-01 | DEPOSIT    | 5000   | 5000            | false       |
| A001       | 2025-01-05 | WITHDRAWAL | 1200   | 3800            | false       |
| A001       | 2025-01-10 | WITHDRAWAL | 800    | 3000            | false       |
| A001       | 2025-01-12 | DEPOSIT    | 3000   | 6000            | false       |
| A001       | 2025-01-15 | WITHDRAWAL | 7500   | -1500           | true        |
| A001       | 2025-01-18 | DEPOSIT    | 2000   | 500             | false       |
| A002       | 2025-01-01 | DEPOSIT    | 10000  | 10000           | false       |
| A002       | 2025-01-08 | WITHDRAWAL | 3000   | 7000            | false       |
| A002       | 2025-01-15 | WITHDRAWAL | 4000   | 3000            | false       |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, when, sum as spark_sum, lit, \
    min as spark_min, max as spark_max, count, round as spark_round
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("RunningBalance").getOrCreate()

# Sample data
data = [
    ("A001", "2025-01-01", "DEPOSIT", 5000, "Initial deposit"),
    ("A001", "2025-01-05", "WITHDRAWAL", 1200, "Rent payment"),
    ("A001", "2025-01-10", "WITHDRAWAL", 800, "Utilities"),
    ("A001", "2025-01-12", "DEPOSIT", 3000, "Salary"),
    ("A001", "2025-01-15", "WITHDRAWAL", 7500, "Car purchase"),
    ("A001", "2025-01-18", "DEPOSIT", 2000, "Freelance"),
    ("A002", "2025-01-01", "DEPOSIT", 10000, "Initial deposit"),
    ("A002", "2025-01-08", "WITHDRAWAL", 3000, "Transfer"),
    ("A002", "2025-01-15", "WITHDRAWAL", 4000, "Investment")
]
columns = ["account_id", "txn_date", "txn_type", "amount", "description"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("txn_date", to_date("txn_date"))

# Step 1: Convert amount to signed value (deposits +, withdrawals -)
df_signed = df.withColumn(
    "signed_amount",
    when(col("txn_type") == "DEPOSIT", col("amount"))
    .when(col("txn_type") == "WITHDRAWAL", -col("amount"))
    .otherwise(col("amount"))
)

# Step 2: Define window for running sum
window_account = Window.partitionBy("account_id").orderBy("txn_date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# Step 3: Compute running balance
df_balanced = df_signed.withColumn(
    "running_balance",
    spark_sum("signed_amount").over(window_account)
)

# Step 4: Flag overdrafts
df_result = df_balanced.withColumn(
    "is_overdraft",
    col("running_balance") < 0
)

df_result.select(
    "account_id", "txn_date", "txn_type", "amount",
    "running_balance", "is_overdraft"
).orderBy("account_id", "txn_date").show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Convert to Signed Amounts

| txn_type   | amount | signed_amount |
|------------|--------|---------------|
| DEPOSIT    | 5000   | +5000         |
| WITHDRAWAL | 1200   | -1200         |
| WITHDRAWAL | 800    | -800          |

#### Step 2-3: Cumulative Sum = Running Balance

| txn_date   | signed_amount | running_balance (sum so far) |
|------------|--------------|------------------------------|
| 2025-01-01 | +5000        | 5000                         |
| 2025-01-05 | -1200        | 3800 (5000-1200)             |
| 2025-01-10 | -800         | 3000 (3800-800)              |
| 2025-01-12 | +3000        | 6000 (3000+3000)             |
| 2025-01-15 | -7500        | -1500 (6000-7500)            |
| 2025-01-18 | +2000        | 500 (-1500+2000)             |

Same `sum().over(window)` as running_total, but with signed amounts.

---

## Extension 1: Account Summary with Overdraft History

```python
# Per-account summary including overdraft metrics
account_summary = df_result.groupBy("account_id").agg(
    spark_max("running_balance").alias("peak_balance"),
    spark_min("running_balance").alias("lowest_balance"),
    count(when(col("is_overdraft"), True)).alias("overdraft_count"),
    spark_sum(when(col("txn_type") == "DEPOSIT", col("amount")).otherwise(0)).alias("total_deposits"),
    spark_sum(when(col("txn_type") == "WITHDRAWAL", col("amount")).otherwise(0)).alias("total_withdrawals")
).withColumn(
    "net_flow", col("total_deposits") - col("total_withdrawals")
).withColumn(
    "ever_overdrawn", col("lowest_balance") < 0
)

account_summary.show(truncate=False)
```

- **Output:**

  | account_id | peak_balance | lowest_balance | overdraft_count | total_deposits | total_withdrawals | net_flow | ever_overdrawn |
  |------------|-------------|---------------|----------------|---------------|------------------|----------|---------------|
  | A001       | 6000        | -1500         | 1              | 10000         | 9500             | 500      | true          |
  | A002       | 10000       | 3000          | 0              | 10000         | 7000             | 3000     | false         |

---

## Extension 2: Daily End-of-Day Balance

```python
from pyspark.sql.functions import last

# When multiple transactions happen on the same day,
# get the end-of-day balance (last balance of the day)
window_eod = Window.partitionBy("account_id", "txn_date").orderBy("txn_date")

# If you have intra-day ordering (timestamps), use that instead
# For this example, compute daily aggregated balance
daily_balance = df_signed.groupBy("account_id", "txn_date").agg(
    spark_sum("signed_amount").alias("daily_net")
)

window_daily = Window.partitionBy("account_id").orderBy("txn_date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

eod_balance = daily_balance.withColumn(
    "eod_balance", spark_sum("daily_net").over(window_daily)
)

eod_balance.orderBy("account_id", "txn_date").show(truncate=False)
```

---

## Extension 3: Running Balance with Interest Calculation

```python
from pyspark.sql.functions import lag, datediff

# Simple daily interest: 0.01% per day on positive balance
DAILY_RATE = 0.0001

# Get previous balance and days between transactions
window_prev = Window.partitionBy("account_id").orderBy("txn_date")

df_with_interest = df_balanced.withColumn(
    "prev_balance", lag("running_balance").over(window_prev)
).withColumn(
    "prev_date", lag("txn_date").over(window_prev)
).withColumn(
    "days_elapsed", datediff(col("txn_date"), col("prev_date"))
).withColumn(
    "accrued_interest",
    when(
        col("prev_balance").isNotNull() & (col("prev_balance") > 0),
        spark_round(col("prev_balance") * DAILY_RATE * col("days_elapsed"), 2)
    ).otherwise(0)
)

df_with_interest.select(
    "account_id", "txn_date", "txn_type", "signed_amount",
    "running_balance", "accrued_interest"
).orderBy("account_id", "txn_date").show(truncate=False)
```

---

## Method 2: Using SQL

```python
df.createOrReplaceTempView("transactions")

spark.sql("""
    SELECT
        account_id,
        txn_date,
        txn_type,
        amount,
        SUM(
            CASE WHEN txn_type = 'DEPOSIT' THEN amount
                 WHEN txn_type = 'WITHDRAWAL' THEN -amount
                 ELSE amount END
        ) OVER (
            PARTITION BY account_id
            ORDER BY txn_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_balance,
        CASE WHEN SUM(
            CASE WHEN txn_type = 'DEPOSIT' THEN amount
                 WHEN txn_type = 'WITHDRAWAL' THEN -amount
                 ELSE amount END
        ) OVER (
            PARTITION BY account_id
            ORDER BY txn_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) < 0 THEN true ELSE false END AS is_overdraft
    FROM transactions
    ORDER BY account_id, txn_date
""").show(truncate=False)
```

---

## Connection to Parent Pattern (running_total)

| Concept | running_total | running_account_balance |
|---------|--------------|------------------------|
| **Input** | Orders with amounts | Transactions with types |
| **Pre-processing** | None (all positive) | Sign amounts by txn_type |
| **Window function** | `sum(amount).over(window)` | `sum(signed_amount).over(window)` |
| **Post-processing** | None | Overdraft flag, interest calc |
| **Core technique** | Cumulative sum | Cumulative sum (identical) |

The only real difference is the sign conversion step. Everything else is the same cumulative sum.

---

## Key Interview Talking Points

1. **Same cumulative sum, signed amounts:** This is `running_total` with one extra step — converting deposits to positive and withdrawals to negative. The window function is identical.

2. **Handling same-day transactions:** If multiple transactions happen on the same date, the running balance depends on their order. Use a timestamp or transaction ID for precise ordering: `orderBy("txn_date", "txn_id")`.

3. **Overdraft detection is a filter on the running result:** You don't need a separate pass. Just add `when(running_balance < 0, True)` as a derived column.

4. **Real-world extensions:**
   - **Daily interest accrual** on positive balances
   - **Overdraft fees** — triggered when balance goes negative
   - **Minimum balance alerts** — flag when balance drops below threshold
   - **Monthly statement generation** — filter running balance at month-end dates

5. **Performance:** Same as running_total — one sort per partition, one scan. The signed_amount conversion adds zero overhead (column expression, not a shuffle).
