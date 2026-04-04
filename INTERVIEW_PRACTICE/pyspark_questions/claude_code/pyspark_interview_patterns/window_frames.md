# PySpark Implementation: Window Frame Specifications

## Problem Statement

Window functions in PySpark support different frame specifications that control which rows are included in the computation. Understanding the difference between `ROWS` and `RANGE` frames is critical for getting correct results in running totals, moving averages, and bounded aggregations. This is a frequently tested topic in data engineering interviews because subtle differences between frame types can produce dramatically different results.

Given a dataset of daily stock prices, demonstrate how ROWS BETWEEN, RANGE BETWEEN, and default window frames behave differently, and when to use each.

### Sample Data

```
+------+----------+-------+--------+
|ticker| trade_dt | close | volume |
+------+----------+-------+--------+
| AAPL |2024-01-01| 150.0 | 100000 |
| AAPL |2024-01-02| 152.0 | 120000 |
| AAPL |2024-01-02| 152.0 |  80000 |
| AAPL |2024-01-03| 155.0 | 110000 |
| AAPL |2024-01-04| 153.0 |  90000 |
| AAPL |2024-01-05| 158.0 | 140000 |
| AAPL |2024-01-06| 160.0 | 130000 |
| AAPL |2024-01-07| 157.0 | 105000 |
| GOOG |2024-01-01| 140.0 |  70000 |
| GOOG |2024-01-02| 142.0 |  85000 |
| GOOG |2024-01-03| 138.0 |  95000 |
| GOOG |2024-01-04| 145.0 |  60000 |
| GOOG |2024-01-05| 147.0 |  75000 |
+------+----------+-------+--------+
```

### Expected Output

**ROWS vs RANGE Running Sum (notice difference on duplicate dates):**

| ticker | trade_dt   | close | rows_running_sum | range_running_sum |
|--------|------------|-------|------------------|-------------------|
| AAPL   | 2024-01-01 | 150.0 | 150.0            | 150.0             |
| AAPL   | 2024-01-02 | 152.0 | 302.0            | 454.0             |
| AAPL   | 2024-01-02 | 152.0 | 454.0            | 454.0             |
| AAPL   | 2024-01-03 | 155.0 | 609.0            | 609.0             |

---

## Method 1: ROWS vs RANGE Frame Comparison (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("WindowFrameSpecifications") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data (note: two rows for AAPL on 2024-01-02 to show ROWS vs RANGE difference)
data = [
    ("AAPL", "2024-01-01", 150.0, 100000),
    ("AAPL", "2024-01-02", 152.0, 120000),
    ("AAPL", "2024-01-02", 152.0,  80000),
    ("AAPL", "2024-01-03", 155.0, 110000),
    ("AAPL", "2024-01-04", 153.0,  90000),
    ("AAPL", "2024-01-05", 158.0, 140000),
    ("AAPL", "2024-01-06", 160.0, 130000),
    ("AAPL", "2024-01-07", 157.0, 105000),
    ("GOOG", "2024-01-01", 140.0,  70000),
    ("GOOG", "2024-01-02", 142.0,  85000),
    ("GOOG", "2024-01-03", 138.0,  95000),
    ("GOOG", "2024-01-04", 145.0,  60000),
    ("GOOG", "2024-01-05", 147.0,  75000),
]

columns = ["ticker", "trade_dt", "close", "volume"]
df = spark.createDataFrame(data, columns)

# ============================================================
# KEY CONCEPT: ROWS BETWEEN vs RANGE BETWEEN
# ============================================================

# ROWS frame: counts physical rows regardless of values
# RANGE frame: includes all rows with the same ORDER BY value (peers)

# --- ROWS frame: unbounded preceding to current row ---
rows_window = Window.partitionBy("ticker").orderBy("trade_dt") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# --- RANGE frame: unbounded preceding to current row ---
range_window = Window.partitionBy("ticker").orderBy("trade_dt") \
    .rangeBetween(Window.unboundedPreceding, Window.currentRow)

result = df.withColumn("rows_running_sum", F.sum("close").over(rows_window)) \
           .withColumn("range_running_sum", F.sum("close").over(range_window))

print("=== ROWS vs RANGE Running Sum (notice duplicate date rows) ===")
result.orderBy("ticker", "trade_dt").show(truncate=False)

# ============================================================
# ROWS-based moving average (exactly N physical rows)
# ============================================================

# 3-row moving average (current + 2 preceding rows)
rows_3 = Window.partitionBy("ticker").orderBy("trade_dt") \
    .rowsBetween(-2, 0)

result_ma = df.withColumn("close_3row_ma", F.avg("close").over(rows_3)) \
              .withColumn("close_3row_sum", F.sum("close").over(rows_3)) \
              .withColumn("close_3row_count", F.count("close").over(rows_3))

print("=== 3-Row Moving Average ===")
result_ma.orderBy("ticker", "trade_dt").show(truncate=False)

# ============================================================
# ROWS: fixed look-ahead and look-behind
# ============================================================

# Window: 1 row before to 1 row after (centered window)
centered = Window.partitionBy("ticker").orderBy("trade_dt") \
    .rowsBetween(-1, 1)

result_centered = df.withColumn("centered_avg", F.avg("close").over(centered)) \
                    .withColumn("centered_min", F.min("close").over(centered)) \
                    .withColumn("centered_max", F.max("close").over(centered))

print("=== Centered Window (-1 to +1 rows) ===")
result_centered.orderBy("ticker", "trade_dt").show(truncate=False)
```

## Method 2: Various Frame Boundaries with Practical Examples

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("WindowFramePractical") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("AAPL", "2024-01-01", 150.0, 100000),
    ("AAPL", "2024-01-02", 152.0, 120000),
    ("AAPL", "2024-01-02", 152.0,  80000),
    ("AAPL", "2024-01-03", 155.0, 110000),
    ("AAPL", "2024-01-04", 153.0,  90000),
    ("AAPL", "2024-01-05", 158.0, 140000),
    ("AAPL", "2024-01-06", 160.0, 130000),
    ("AAPL", "2024-01-07", 157.0, 105000),
    ("GOOG", "2024-01-01", 140.0,  70000),
    ("GOOG", "2024-01-02", 142.0,  85000),
    ("GOOG", "2024-01-03", 138.0,  95000),
    ("GOOG", "2024-01-04", 145.0,  60000),
    ("GOOG", "2024-01-05", 147.0,  75000),
]

columns = ["ticker", "trade_dt", "close", "volume"]
df = spark.createDataFrame(data, columns)

# Convert trade_dt to a numeric type for RANGE to work with day offsets
df = df.withColumn("trade_dt_num", F.datediff(F.col("trade_dt"), F.lit("2024-01-01")))

# ============================================================
# RANGE with numeric offset: 2-day range window
# ============================================================
# RANGE BETWEEN -2 AND 0 means: include all rows whose order-by value
# is within [current_value - 2, current_value]

range_2day = Window.partitionBy("ticker").orderBy("trade_dt_num") \
    .rangeBetween(-2, 0)

result_range = df.withColumn("range_2day_avg", F.avg("close").over(range_2day)) \
                 .withColumn("range_2day_cnt", F.count("close").over(range_2day))

print("=== RANGE-based 2-day lookback ===")
result_range.select("ticker", "trade_dt", "close", "trade_dt_num",
                    "range_2day_avg", "range_2day_cnt") \
    .orderBy("ticker", "trade_dt").show(truncate=False)

# ============================================================
# Common frame specifications summary
# ============================================================

# 1. Entire partition
full_partition = Window.partitionBy("ticker").orderBy("trade_dt") \
    .rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing)

# 2. Running total (default for most aggregate functions with ORDER BY)
running = Window.partitionBy("ticker").orderBy("trade_dt") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# 3. Future only
future_only = Window.partitionBy("ticker").orderBy("trade_dt") \
    .rowsBetween(1, Window.unboundedFollowing)

# 4. Current row to end
current_to_end = Window.partitionBy("ticker").orderBy("trade_dt") \
    .rowsBetween(Window.currentRow, Window.unboundedFollowing)

result_frames = df.select(
    "ticker", "trade_dt", "close",
    F.sum("close").over(full_partition).alias("partition_total"),
    F.sum("close").over(running).alias("running_total"),
    F.sum("close").over(future_only).alias("future_sum"),
    F.sum("close").over(current_to_end).alias("current_to_end_sum"),
)

print("=== Various Frame Specifications ===")
result_frames.orderBy("ticker", "trade_dt").show(truncate=False)
```

## Method 3: Spark SQL with Frame Clauses

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("WindowFrameSQL") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("AAPL", "2024-01-01", 150.0, 100000),
    ("AAPL", "2024-01-02", 152.0, 120000),
    ("AAPL", "2024-01-02", 152.0,  80000),
    ("AAPL", "2024-01-03", 155.0, 110000),
    ("AAPL", "2024-01-04", 153.0,  90000),
    ("AAPL", "2024-01-05", 158.0, 140000),
    ("AAPL", "2024-01-06", 160.0, 130000),
    ("AAPL", "2024-01-07", 157.0, 105000),
]

columns = ["ticker", "trade_dt", "close", "volume"]
df = spark.createDataFrame(data, columns)
df.createOrReplaceTempView("stock_prices")

spark.sql("""
    SELECT
        ticker,
        trade_dt,
        close,

        -- ROWS frame: physical row based
        SUM(close) OVER (
            PARTITION BY ticker ORDER BY trade_dt
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS rows_running_sum,

        -- RANGE frame: value/peer based
        SUM(close) OVER (
            PARTITION BY ticker ORDER BY trade_dt
            RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS range_running_sum,

        -- 3-row moving average
        AVG(close) OVER (
            PARTITION BY ticker ORDER BY trade_dt
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg_3,

        -- Entire partition
        AVG(close) OVER (
            PARTITION BY ticker
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS partition_avg,

        -- Remaining sum after current row
        SUM(close) OVER (
            PARTITION BY ticker ORDER BY trade_dt
            ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
        ) AS remaining_sum

    FROM stock_prices
    ORDER BY ticker, trade_dt
""").show(truncate=False)
```

## Key Concepts

| Frame Type | Behavior | Use When |
|-----------|----------|----------|
| `ROWS BETWEEN` | Counts physical rows | You want exactly N preceding/following rows |
| `RANGE BETWEEN` | Includes all peers with same ORDER BY value | You want all rows within a value range |
| Default (no frame) | `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` for aggregates with ORDER BY | Running totals where duplicates should share the same result |
| `rowsBetween(-N, 0)` | Sliding window of N+1 rows | Fixed-size moving averages |
| `rangeBetween(-N, 0)` | All rows within value offset N | Time-based or value-based windows |

## Interview Tips

1. **The critical difference**: ROWS counts physical rows; RANGE includes all rows sharing the same ORDER BY value (peers). With no duplicates in the ORDER BY column, they produce identical results.

2. **Default frame trap**: When you specify ORDER BY in a window without an explicit frame, Spark uses `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. This means duplicate order values get the same running total, which catches many candidates off guard.

3. **When there is no ORDER BY**: The default frame is the entire partition (`ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`).

4. **RANGE with numeric offsets**: RANGE BETWEEN -7 AND 0 means include all rows whose ORDER BY value is within 7 units of the current value. This requires a numeric or date ORDER BY column.

5. **Performance**: ROWS frames are generally faster because Spark can use a sliding window optimization. RANGE frames may require sorting and scanning more rows.

6. **Common mistake**: Using `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` for a running total when the ORDER BY column has duplicates. This gives non-deterministic results because the physical row order among peers is undefined.
