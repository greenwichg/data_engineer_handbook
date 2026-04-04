# PySpark Implementation: Financial Calculations (FIFO Cost Basis)

## Problem Statement
Given a trade log with BUY and SELL transactions for a stock, compute:
1. **FIFO cost basis** -- match sells to the earliest available buys to determine the cost of shares sold.
2. **Realized P&L** -- the profit or loss on each sell based on FIFO matching.
3. **Remaining inventory** -- unsold shares and their cost.

Additionally demonstrate compound interest and daily portfolio return calculations.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("FinancialCalculations").getOrCreate()

trades_data = [
    ("AAPL", "2024-01-02", "BUY",  100, 150.00),
    ("AAPL", "2024-01-05", "BUY",   50, 155.00),
    ("AAPL", "2024-01-10", "SELL",  80, 160.00),   # sells 80 from first buy at 150
    ("AAPL", "2024-01-15", "BUY",   30, 158.00),
    ("AAPL", "2024-01-20", "SELL", 60,  165.00),    # sells 20 from 1st buy @150 + 40 from 2nd @155
    ("AAPL", "2024-01-25", "SELL",  20, 162.00),    # sells 10 from 2nd @155 + 10 from 3rd @158
]

schema = StructType([
    StructField("symbol", StringType()),
    StructField("trade_date", StringType()),
    StructField("side", StringType()),
    StructField("quantity", IntegerType()),
    StructField("price", DoubleType()),
])

trades = spark.createDataFrame(trades_data, schema) \
    .withColumn("trade_date", to_date("trade_date"))
```

### Expected Output
FIFO Matching for the first SELL (80 shares at $160):

| sell_date  | sell_qty | buy_date   | matched_qty | buy_price | sell_price | realized_pnl |
|------------|----------|------------|-------------|-----------|------------|--------------|
| 2024-01-10 | 80       | 2024-01-02 | 80          | 150.00    | 160.00     | 800.00       |

FIFO Matching for the second SELL (60 shares at $165):

| sell_date  | sell_qty | buy_date   | matched_qty | buy_price | sell_price | realized_pnl |
|------------|----------|------------|-------------|-----------|------------|--------------|
| 2024-01-20 | 60       | 2024-01-02 | 20          | 150.00    | 165.00     | 300.00       |
| 2024-01-20 | 60       | 2024-01-05 | 40          | 155.00    | 165.00     | 400.00       |

Total realized P&L: $800 + $300 + $400 + $70 + $40 = **$1,610**

---

## Method 1: Explode to Unit Shares and Match (Recommended)
```python
# ---- FIFO COST BASIS ----
# Strategy: Expand each trade into individual share units, assign FIFO ranks,
# then join buys to sells by rank position.

# Add a running sequence to preserve trade ordering
w_symbol = Window.partitionBy("symbol").orderBy("trade_date")
trades_seq = trades.withColumn("trade_seq", row_number().over(w_symbol))

# Separate buys and sells
buys = trades_seq.filter(col("side") == "BUY")
sells = trades_seq.filter(col("side") == "SELL")

# Explode each buy into individual share rows
buy_units = buys.select(
    "symbol", "trade_date", "price", "quantity",
    explode(sequence(lit(1), col("quantity"))).alias("unit_idx")
).withColumn(
    "buy_rank", row_number().over(
        Window.partitionBy("symbol").orderBy("trade_date", "unit_idx")
    )
).select(
    col("symbol"),
    col("trade_date").alias("buy_date"),
    col("price").alias("buy_price"),
    col("buy_rank")
)

# Explode each sell into individual share rows
sell_units = sells.select(
    "symbol", "trade_date", "price", "quantity",
    explode(sequence(lit(1), col("quantity"))).alias("unit_idx")
).withColumn(
    "sell_rank", row_number().over(
        Window.partitionBy("symbol").orderBy("trade_date", "unit_idx")
    )
).select(
    col("symbol"),
    col("trade_date").alias("sell_date"),
    col("price").alias("sell_price"),
    col("sell_rank")
)

# FIFO match: the Nth share sold matches the Nth share bought
fifo_matched = sell_units.join(
    buy_units,
    on=[sell_units.symbol == buy_units.symbol,
        sell_units.sell_rank == buy_units.buy_rank],
    how="inner"
).select(
    sell_units.symbol,
    "sell_date", "sell_price",
    "buy_date", "buy_price",
    (col("sell_price") - col("buy_price")).alias("unit_pnl")
)

# Aggregate back to trade-level P&L
fifo_pnl = fifo_matched.groupBy("symbol", "sell_date", "sell_price", "buy_date", "buy_price") \
    .agg(
        count("*").alias("matched_qty"),
        sum("unit_pnl").alias("realized_pnl")
    ).orderBy("sell_date", "buy_date")

fifo_pnl.show(truncate=False)

# Total realized P&L
fifo_matched.groupBy("symbol").agg(
    sum("unit_pnl").alias("total_realized_pnl")
).show()

# Remaining inventory: buy units with no matching sell
remaining = buy_units.join(
    sell_units,
    on=[buy_units.symbol == sell_units.symbol,
        buy_units.buy_rank == sell_units.sell_rank],
    how="left_anti"
)
remaining.groupBy("symbol", "buy_date", "buy_price") \
    .agg(count("*").alias("remaining_qty")) \
    .orderBy("buy_date") \
    .show()
```

### Step-by-Step Explanation

**Step 1 -- Explode buys into unit shares:**

| symbol | buy_date   | buy_price | buy_rank |
|--------|------------|-----------|----------|
| AAPL   | 2024-01-02 | 150.00    | 1        |
| AAPL   | 2024-01-02 | 150.00    | 2        |
| ...    | ...        | ...       | ...      |
| AAPL   | 2024-01-02 | 150.00    | 100      |
| AAPL   | 2024-01-05 | 155.00    | 101      |
| ...    | ...        | ...       | ...      |
| AAPL   | 2024-01-05 | 155.00    | 150      |
| AAPL   | 2024-01-15 | 158.00    | 151      |
| ...    | ...        | ...       | ...      |
| AAPL   | 2024-01-15 | 158.00    | 180      |

**Step 2 -- Explode sells similarly:** 80 sell units (rank 1-80), 60 sell units (rank 81-140), 20 sell units (rank 141-160).

**Step 3 -- Join on rank:** sell_rank 1 matches buy_rank 1 (first share bought = first share sold). This is the core FIFO principle.

**Step 4 -- Aggregate** back from unit-level to trade-level to get matched_qty and realized_pnl per buy-sell pair.

**Remaining inventory:** Buy ranks 161-180 (20 shares from the Jan 15 buy at $158) have no matching sell rank.

---

## Method 2: Running Sum Approach (No Explode)
```python
# ---- COMPOUND INTEREST CALCULATION ----
# Given principal, rate, and periods, calculate compound growth
periods_data = [(1000.0, 0.05, i) for i in range(1, 13)]  # monthly for 12 months
periods_schema = StructType([
    StructField("principal", DoubleType()),
    StructField("monthly_rate", DoubleType()),
    StructField("month", IntegerType()),
])

periods_df = spark.createDataFrame(periods_data, periods_schema)

compound = periods_df.withColumn(
    "balance",
    col("principal") * pow(1 + col("monthly_rate"), col("month"))
).withColumn(
    "interest_earned",
    col("balance") - col("principal")
)
compound.show()

# ---- DAILY PORTFOLIO RETURNS ----
portfolio_data = [
    ("2024-01-02", 100000.0),
    ("2024-01-03", 100500.0),
    ("2024-01-04",  99800.0),
    ("2024-01-05", 101200.0),
    ("2024-01-08", 101800.0),
]

port_schema = StructType([
    StructField("date", StringType()),
    StructField("portfolio_value", DoubleType()),
])

portfolio = spark.createDataFrame(portfolio_data, port_schema) \
    .withColumn("date", to_date("date"))

w_date = Window.orderBy("date")

returns = portfolio.withColumn(
    "prev_value", lag("portfolio_value", 1).over(w_date)
).withColumn(
    "daily_return", (col("portfolio_value") - col("prev_value")) / col("prev_value")
).withColumn(
    "cumulative_return",
    (col("portfolio_value") / first("portfolio_value").over(w_date)) - 1
)
returns.show()
```

| date       | portfolio_value | prev_value | daily_return | cumulative_return |
|------------|----------------|------------|--------------|-------------------|
| 2024-01-02 | 100000.0       | null       | null         | 0.0               |
| 2024-01-03 | 100500.0       | 100000.0   | 0.005        | 0.005             |
| 2024-01-04 | 99800.0        | 100500.0   | -0.00697     | -0.002            |
| 2024-01-05 | 101200.0       | 99800.0    | 0.01403      | 0.012             |
| 2024-01-08 | 101800.0       | 101200.0   | 0.00593      | 0.018             |

---

## Key Interview Talking Points
1. **The unit-explode FIFO approach** is intuitive and correct but creates N rows per share, which is expensive for large quantities. It works well for typical trade sizes (hundreds of shares).
2. **For large quantities**, a running-sum approach with cumulative buy/sell quantities and range overlap logic avoids the explosion but is significantly more complex to implement.
3. **FIFO vs LIFO vs Average Cost:** Interviewers may ask about alternatives. LIFO reverses the buy ranking; average cost simply divides total cost by total shares.
4. **Window functions** (`lag`, `row_number`, `sum().over()`) are the backbone of financial time-series calculations in PySpark.
5. **Cumulative return** is calculated relative to the first value, not by chaining daily returns (which introduces floating point drift).
6. **Partitioning matters:** Always partition by symbol in multi-asset portfolios to prevent cross-asset contamination in window functions.
7. **Precision:** Use `DecimalType(18, 6)` instead of `DoubleType` for monetary values in production to avoid floating-point rounding errors.
8. **Real-world complexity:** Trades may have fees, partial fills, and corporate actions (splits, dividends) that adjust the cost basis. The FIFO framework extends naturally by adjusting the buy_price column.
