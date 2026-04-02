# PySpark Implementation: Moving Averages and Rolling Windows

## Problem Statement 

Given a dataset of daily stock prices, calculate the **7-day moving average** and **3-day moving average** for each stock. Also compute a **rolling sum** and **rolling min/max** over a specified window. Moving averages are fundamental in time-series analysis and are frequently asked in data engineering interviews at finance, e-commerce, and analytics companies.

### Sample Data

```
stock   trade_date   close_price
AAPL    2025-01-01   180
AAPL    2025-01-02   182
AAPL    2025-01-03   179
AAPL    2025-01-04   185
AAPL    2025-01-05   188
AAPL    2025-01-06   186
AAPL    2025-01-07   190
AAPL    2025-01-08   192
GOOG    2025-01-01   140
GOOG    2025-01-02   142
GOOG    2025-01-03   138
GOOG    2025-01-04   145
GOOG    2025-01-05   147
```

### Expected Output (3-Day Moving Average for AAPL)

| stock | trade_date | close_price | ma_3day |
|-------|------------|-------------|---------|
| AAPL  | 2025-01-01 | 180         | 180.00  |
| AAPL  | 2025-01-02 | 182         | 181.00  |
| AAPL  | 2025-01-03 | 179         | 180.33  |
| AAPL  | 2025-01-04 | 185         | 182.00  |
| AAPL  | 2025-01-05 | 188         | 184.00  |
| AAPL  | 2025-01-06 | 186         | 186.33  |
| AAPL  | 2025-01-07 | 190         | 188.00  |
| AAPL  | 2025-01-08 | 192         | 189.33  |

---

## Method 1: Row-Based Rolling Window (rowsBetween)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, avg, sum as spark_sum, min as spark_min, \
    max as spark_max, round as spark_round, to_date
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("MovingAverages").getOrCreate()

# Sample data
data = [
    ("AAPL", "2025-01-01", 180), ("AAPL", "2025-01-02", 182),
    ("AAPL", "2025-01-03", 179), ("AAPL", "2025-01-04", 185),
    ("AAPL", "2025-01-05", 188), ("AAPL", "2025-01-06", 186),
    ("AAPL", "2025-01-07", 190), ("AAPL", "2025-01-08", 192),
    ("GOOG", "2025-01-01", 140), ("GOOG", "2025-01-02", 142),
    ("GOOG", "2025-01-03", 138), ("GOOG", "2025-01-04", 145),
    ("GOOG", "2025-01-05", 147)
]

columns = ["stock", "trade_date", "close_price"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("trade_date", to_date(col("trade_date")))

# 3-day moving average: current row + 2 preceding rows
window_3day = Window.partitionBy("stock").orderBy("trade_date") \
    .rowsBetween(-2, 0)

# 7-day moving average: current row + 6 preceding rows
window_7day = Window.partitionBy("stock").orderBy("trade_date") \
    .rowsBetween(-6, 0)

# Calculate moving averages
df_ma = df.withColumn("ma_3day", spark_round(avg("close_price").over(window_3day), 2)) \
          .withColumn("ma_7day", spark_round(avg("close_price").over(window_7day), 2))

df_ma.orderBy("stock", "trade_date").show()
```

### Step-by-Step Explanation

#### Step 1: Understanding rowsBetween(-2, 0)
- **What happens:** The window frame includes the current row (0) and the 2 preceding rows (-2, -1).
- For the first row: only 1 row available → average of just that row.
- For the second row: 2 rows available → average of rows 1-2.
- From the third row onward: full 3-row window.

#### Step 2: Moving Average Calculation for AAPL
- **Output (df_ma for AAPL):**

  | stock | trade_date | close_price | ma_3day | ma_7day |
  |-------|------------|-------------|---------|---------|
  | AAPL  | 2025-01-01 | 180         | 180.00  | 180.00  |
  | AAPL  | 2025-01-02 | 182         | 181.00  | 181.00  |
  | AAPL  | 2025-01-03 | 179         | 180.33  | 180.33  |
  | AAPL  | 2025-01-04 | 185         | 182.00  | 181.50  |
  | AAPL  | 2025-01-05 | 188         | 184.00  | 182.80  |
  | AAPL  | 2025-01-06 | 186         | 186.33  | 183.33  |
  | AAPL  | 2025-01-07 | 190         | 188.00  | 184.29  |
  | AAPL  | 2025-01-08 | 192         | 189.33  | 186.00  |

  **Calculation for Jan 05 (ma_3day):** avg(179, 185, 188) = 184.00
  **Calculation for Jan 07 (ma_7day):** avg(180, 182, 179, 185, 188, 186, 190) = 184.29

---

## Method 2: Range-Based Rolling Window (rangeBetween)

```python
from pyspark.sql.functions import unix_timestamp

# Convert dates to seconds for range-based window
df_ts = df.withColumn("date_seconds", unix_timestamp("trade_date"))

# 7-day range window (7 days = 7 * 86400 seconds)
SEVEN_DAYS = 7 * 86400

window_range = Window.partitionBy("stock").orderBy("date_seconds") \
    .rangeBetween(-SEVEN_DAYS, 0)

df_range_ma = df_ts.withColumn(
    "ma_7day_range",
    spark_round(avg("close_price").over(window_range), 2)
)

df_range_ma.select("stock", "trade_date", "close_price", "ma_7day_range") \
    .orderBy("stock", "trade_date").show()
```

### Key Difference: rowsBetween vs rangeBetween

| Aspect | rowsBetween | rangeBetween |
|--------|-------------|-------------|
| Window frame | Fixed number of rows | Based on value range |
| Missing dates | Ignores gaps (uses row position) | Respects actual date gaps |
| Use when | Data has no gaps (daily records) | Data may have missing days |
| Performance | Faster | Slightly slower |

**Example:** If Jan 03 is missing, `rowsBetween(-2, 0)` for Jan 04 would use Jan 02 and Jan 04 (2 rows before). `rangeBetween(-2_days, 0)` would correctly only include Jan 02 and Jan 04 based on actual date values.

---

## Method 3: Rolling Sum, Min, Max

```python
window_3day = Window.partitionBy("stock").orderBy("trade_date") \
    .rowsBetween(-2, 0)

df_rolling = df.withColumn("rolling_sum_3d", spark_sum("close_price").over(window_3day)) \
    .withColumn("rolling_min_3d", spark_min("close_price").over(window_3day)) \
    .withColumn("rolling_max_3d", spark_max("close_price").over(window_3day)) \
    .withColumn("rolling_avg_3d", spark_round(avg("close_price").over(window_3day), 2))

df_rolling.filter(col("stock") == "AAPL").orderBy("trade_date").show()
```

- **Output (AAPL):**

  | stock | trade_date | close_price | rolling_sum_3d | rolling_min_3d | rolling_max_3d | rolling_avg_3d |
  |-------|------------|-------------|---------------|---------------|---------------|----------------|
  | AAPL  | 2025-01-01 | 180         | 180           | 180           | 180           | 180.00         |
  | AAPL  | 2025-01-02 | 182         | 362           | 180           | 182           | 181.00         |
  | AAPL  | 2025-01-03 | 179         | 541           | 179           | 182           | 180.33         |
  | AAPL  | 2025-01-04 | 185         | 546           | 179           | 185           | 182.00         |
  | AAPL  | 2025-01-05 | 188         | 552           | 185           | 188           | 184.00         |

---

## Method 4: Exponential Moving Average (EMA) Using UDF

```python
from pyspark.sql.functions import collect_list, struct, udf
from pyspark.sql.types import DoubleType

# EMA cannot be done with built-in window functions because it requires
# recursive computation. Use a UDF on collected window data.

@udf(DoubleType())
def ema_udf(prices, span):
    """Calculate Exponential Moving Average."""
    if not prices:
        return None
    alpha = 2.0 / (span + 1)
    ema = float(prices[0])
    for price in prices[1:]:
        ema = alpha * float(price) + (1 - alpha) * ema
    return ema

# Collect all prices up to current row
window_all = Window.partitionBy("stock").orderBy("trade_date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

df_ema = df.withColumn(
    "prices_so_far",
    collect_list("close_price").over(window_all)
).withColumn(
    "ema_3day",
    spark_round(ema_udf(col("prices_so_far"), col("close_price").cast("int")), 2)
)
```

- **Note:** EMA is a common follow-up question. Built-in window functions only support simple moving averages. For EMA, you need a UDF or Pandas UDF.

---

## Method 5: Using SQL

```python
df.createOrReplaceTempView("stock_prices")

ma_sql = spark.sql("""
    SELECT
        stock,
        trade_date,
        close_price,
        ROUND(AVG(close_price) OVER (
            PARTITION BY stock ORDER BY trade_date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2) AS ma_3day,
        ROUND(AVG(close_price) OVER (
            PARTITION BY stock ORDER BY trade_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2) AS ma_7day
    FROM stock_prices
    ORDER BY stock, trade_date
""")

ma_sql.show()
```

---

## Window Frame Reference

| Frame Specification | Meaning |
|-------------------|---------|
| `rowsBetween(-2, 0)` | 2 rows before to current row |
| `rowsBetween(-2, 2)` | 2 rows before to 2 rows after (centered) |
| `rowsBetween(Window.unboundedPreceding, 0)` | All rows from start to current |
| `rowsBetween(0, Window.unboundedFollowing)` | Current to all rows after |
| `rangeBetween(-86400, 0)` | Values within 1 day before (in seconds) |

## Key Interview Talking Points

1. **rowsBetween vs rangeBetween:** `rowsBetween` counts physical rows (positions). `rangeBetween` uses the actual ordering column values. For time-series with gaps, `rangeBetween` is more correct.

2. **Partial windows:** When there aren't enough preceding rows (e.g., first 2 rows for a 3-day MA), Spark computes the average of whatever rows are available. This is called a "partial window" or "expanding window."

3. **Centered moving average:** Use `rowsBetween(-1, 1)` for a 3-point centered MA. Used in signal processing and smoothing.

4. **Performance:** Window functions with `ROWS BETWEEN` are more efficient than `RANGE BETWEEN` because Spark doesn't need to compare values.

5. **Real-world applications:**
   - Finance: Stock price smoothing, Bollinger Bands
   - IoT: Sensor data smoothing
   - E-commerce: 7-day/30-day rolling revenue
   - Marketing: Rolling conversion rates
