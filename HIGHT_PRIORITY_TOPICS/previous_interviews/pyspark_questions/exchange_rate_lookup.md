# PySpark Implementation: Exchange Rate Lookup by Date

## Problem Statement

Given a dataset of international transactions with amounts in foreign currencies and a separate table of **daily exchange rates**, look up the correct exchange rate for each transaction based on its date and convert amounts to USD. If no rate exists for the exact date (e.g., weekends), use the **most recent available rate**. This is the finance version of the `range_temporal_joins` pattern — a temporal lookup where each fact row needs to find the matching dimension row based on date proximity.

### Sample Data

**Transactions:**
```
txn_id  txn_date     currency  amount
T001    2025-01-06   EUR       1000
T002    2025-01-07   EUR       2500
T003    2025-01-08   GBP       1500
T004    2025-01-11   EUR       3000
T005    2025-01-12   GBP       800
T006    2025-01-06   GBP       4000
```

**Exchange Rates (to USD):**
```
rate_date    currency  rate_to_usd
2025-01-06   EUR       1.08
2025-01-06   GBP       1.27
2025-01-07   EUR       1.09
2025-01-07   GBP       1.26
2025-01-08   EUR       1.07
2025-01-08   GBP       1.28
2025-01-09   EUR       1.10
2025-01-09   GBP       1.25
2025-01-10   EUR       1.08
2025-01-10   GBP       1.27
```

Note: No rates for Jan 11-12 (weekend). Need to use Jan 10 rates.

### Expected Output

| txn_id | txn_date   | currency | amount | rate_used | rate_date  | amount_usd |
|--------|-----------|----------|--------|-----------|-----------|------------|
| T001   | 2025-01-06 | EUR      | 1000   | 1.08      | 2025-01-06 | 1080.00    |
| T002   | 2025-01-07 | EUR      | 2500   | 1.09      | 2025-01-07 | 2725.00    |
| T003   | 2025-01-08 | GBP      | 1500   | 1.28      | 2025-01-08 | 1920.00    |
| T004   | 2025-01-11 | EUR      | 3000   | 1.08      | 2025-01-10 | 3240.00    |
| T005   | 2025-01-12 | GBP      | 800    | 1.27      | 2025-01-10 | 1016.00    |
| T006   | 2025-01-06 | GBP      | 4000   | 1.27      | 2025-01-06 | 5080.00    |

---

## Method 1: Range Join + Row Number (Pick Latest Available Rate)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, round as spark_round, row_number, \
    datediff
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("ExchangeRateLookup").getOrCreate()

# Transactions data
txn_data = [
    ("T001", "2025-01-06", "EUR", 1000),
    ("T002", "2025-01-07", "EUR", 2500),
    ("T003", "2025-01-08", "GBP", 1500),
    ("T004", "2025-01-11", "EUR", 3000),
    ("T005", "2025-01-12", "GBP", 800),
    ("T006", "2025-01-06", "GBP", 4000)
]
txn_df = spark.createDataFrame(txn_data, ["txn_id", "txn_date", "currency", "amount"])
txn_df = txn_df.withColumn("txn_date", to_date("txn_date"))

# Exchange rates data
rate_data = [
    ("2025-01-06", "EUR", 1.08), ("2025-01-06", "GBP", 1.27),
    ("2025-01-07", "EUR", 1.09), ("2025-01-07", "GBP", 1.26),
    ("2025-01-08", "EUR", 1.07), ("2025-01-08", "GBP", 1.28),
    ("2025-01-09", "EUR", 1.10), ("2025-01-09", "GBP", 1.25),
    ("2025-01-10", "EUR", 1.08), ("2025-01-10", "GBP", 1.27)
]
rate_df = spark.createDataFrame(rate_data, ["rate_date", "currency", "rate_to_usd"])
rate_df = rate_df.withColumn("rate_date", to_date("rate_date"))

# Step 1: Join transactions to all rates on or before the transaction date
# for the same currency
joined = txn_df.join(
    rate_df,
    (txn_df.currency == rate_df.currency) &
    (rate_df.rate_date <= txn_df.txn_date),    # Rate must be on or before txn
    "left"
)

# Step 2: Pick the most recent rate (closest date)
window_latest = Window.partitionBy("txn_id").orderBy(col("rate_date").desc())

result = joined.withColumn("rn", row_number().over(window_latest)) \
    .filter(col("rn") == 1) \
    .drop("rn")

# Step 3: Calculate USD amount
result = result.withColumn(
    "amount_usd",
    spark_round(col("amount") * col("rate_to_usd"), 2)
).select(
    txn_df.txn_id, txn_df.txn_date, txn_df.currency,
    txn_df.amount, col("rate_to_usd").alias("rate_used"),
    col("rate_date"), col("amount_usd")
).orderBy("txn_id")

result.show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Range Join — All Rates On or Before Transaction Date

For T004 (EUR, Jan 11), the join finds:
| rate_date  | rate_to_usd |
|-----------|------------|
| 2025-01-10 | 1.08       |
| 2025-01-09 | 1.10       |
| 2025-01-08 | 1.07       |
| 2025-01-07 | 1.09       |
| 2025-01-06 | 1.08       |

#### Step 2: Pick Most Recent (row_number by rate_date desc)

The row with `rate_date = 2025-01-10` gets `rn = 1` → this is the rate used.

**This is the same pattern as range_temporal_joins** (Method 4: Closest Match), but with a directional constraint (only past rates, not future ones).

---

## Method 2: Using asof Join Logic (Manual Implementation)

```python
from pyspark.sql.functions import max as spark_max

# Step 1: For each transaction, find the max rate_date that is <= txn_date
max_rate_dates = txn_df.alias("t").join(
    rate_df.alias("r"),
    (col("t.currency") == col("r.currency")) &
    (col("r.rate_date") <= col("t.txn_date")),
    "left"
).groupBy("txn_id", "t.txn_date", "t.currency", "amount").agg(
    spark_max("rate_date").alias("effective_rate_date")
)

# Step 2: Join back to get the actual rate
final = max_rate_dates.join(
    rate_df,
    (max_rate_dates.currency == rate_df.currency) &
    (max_rate_dates.effective_rate_date == rate_df.rate_date),
    "left"
).withColumn(
    "amount_usd",
    spark_round(col("amount") * col("rate_to_usd"), 2)
).select(
    "txn_id", max_rate_dates.txn_date, max_rate_dates.currency,
    "amount", "rate_to_usd", "effective_rate_date", "amount_usd"
).orderBy("txn_id")

final.show(truncate=False)
```

This approach avoids the window function by using `max(rate_date)` in the aggregate, then joining back. Two joins but no window.

---

## Method 3: Broadcast for Performance

```python
from pyspark.sql.functions import broadcast

# Exchange rate tables are typically small — broadcast for efficiency
result_broadcast = txn_df.join(
    broadcast(rate_df),
    (txn_df.currency == rate_df.currency) &
    (rate_df.rate_date <= txn_df.txn_date),
    "left"
)

window_latest = Window.partitionBy("txn_id").orderBy(col("rate_date").desc())

result_broadcast = result_broadcast.withColumn("rn", row_number().over(window_latest)) \
    .filter(col("rn") == 1).drop("rn") \
    .withColumn("amount_usd", spark_round(col("amount") * col("rate_to_usd"), 2)) \
    .select(txn_df.txn_id, txn_df.txn_date, txn_df.currency,
            txn_df.amount, col("rate_to_usd"), col("rate_date"), col("amount_usd"))

result_broadcast.orderBy("txn_id").show(truncate=False)
```

---

## Method 4: Using SQL

```python
txn_df.createOrReplaceTempView("transactions")
rate_df.createOrReplaceTempView("exchange_rates")

spark.sql("""
    WITH ranked_rates AS (
        SELECT
            t.txn_id,
            t.txn_date,
            t.currency,
            t.amount,
            r.rate_to_usd,
            r.rate_date,
            ROW_NUMBER() OVER (
                PARTITION BY t.txn_id
                ORDER BY r.rate_date DESC
            ) AS rn
        FROM transactions t
        LEFT JOIN exchange_rates r
            ON t.currency = r.currency
            AND r.rate_date <= t.txn_date
    )
    SELECT
        txn_id,
        txn_date,
        currency,
        amount,
        rate_to_usd AS rate_used,
        rate_date,
        ROUND(amount * rate_to_usd, 2) AS amount_usd
    FROM ranked_rates
    WHERE rn = 1
    ORDER BY txn_id
""").show(truncate=False)
```

---

## Practical Extension: Multi-Currency Portfolio Valuation

```python
from pyspark.sql.functions import sum as spark_sum

# Portfolio holdings in multiple currencies — value in USD as of a given date
holdings_data = [
    ("Portfolio_A", "EUR", 50000),
    ("Portfolio_A", "GBP", 30000),
    ("Portfolio_A", "USD", 20000),
    ("Portfolio_B", "EUR", 100000),
    ("Portfolio_B", "GBP", 75000)
]
holdings_df = spark.createDataFrame(holdings_data, ["portfolio", "currency", "amount"])

# Valuation date
valuation_date = "2025-01-10"

# Get rates as of valuation date
latest_rates = rate_df.filter(col("rate_date") <= valuation_date)
window_latest_rate = Window.partitionBy("currency").orderBy(col("rate_date").desc())
current_rates = latest_rates.withColumn("rn", row_number().over(window_latest_rate)) \
    .filter(col("rn") == 1).drop("rn").select("currency", "rate_to_usd")

# Add USD rate
from pyspark.sql import Row
usd_rate = spark.createDataFrame([Row(currency="USD", rate_to_usd=1.0)])
current_rates = current_rates.unionAll(usd_rate)

# Calculate portfolio value
portfolio_value = holdings_df.join(current_rates, on="currency", how="left") \
    .withColumn("value_usd", spark_round(col("amount") * col("rate_to_usd"), 2))

portfolio_summary = portfolio_value.groupBy("portfolio").agg(
    spark_sum("value_usd").alias("total_value_usd")
)

portfolio_value.show(truncate=False)
portfolio_summary.show(truncate=False)
```

---

## Connection to Parent Pattern (range_temporal_joins)

| Concept | range_temporal_joins | exchange_rate_lookup |
|---------|---------------------|---------------------|
| **Fact table** | Events | Transactions |
| **Dimension table** | Promotions (start/end) | Exchange rates (point-in-time) |
| **Join type** | BETWEEN range | <= (on or before) + row_number |
| **Match selection** | All matches (or first) | Most recent match only |
| **Core technique** | Range join | Range join + pick closest |

The key difference: promotions have start AND end dates (BETWEEN join), while exchange rates have only a single date (find the most recent one ≤ txn_date).

---

## Key Interview Talking Points

1. **Point-in-time lookup vs range lookup:** Exchange rates are point-in-time (one date per rate). Promotions/SCD have ranges (start/end). For point-in-time, use `rate_date <= txn_date` + row_number to pick the latest. For ranges, use `BETWEEN`.

2. **Weekend/holiday gap handling:** This is the main reason you can't use a simple equality join (`txn_date = rate_date`). The `<=` with row_number pattern automatically handles missing dates by falling back to the most recent available rate.

3. **Broadcast the rate table:** Exchange rate tables are small (365 days × number of currencies). Always broadcast to avoid expensive shuffle joins.

4. **Data warehouse best practice:** In production, pre-compute a "filled" rate table that has one row per day per currency (forward-fill missing dates). Then you can use a simple equality join, which is much faster.

5. **Real-world use cases:**
   - Currency conversion for international transactions
   - Stock price lookup at time of trade
   - Tax rate lookup by date (effective rates change)
   - Commodity pricing (oil, gold) for contract valuation
   - Interest rate lookup for loan calculations
