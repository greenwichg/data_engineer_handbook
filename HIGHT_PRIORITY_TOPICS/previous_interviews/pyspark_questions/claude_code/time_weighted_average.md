# PySpark Implementation: Time-Weighted Average (TWAP / VWAP)

## Problem Statement
Given a table of stock prices or sensor readings recorded at irregular time intervals, calculate the time-weighted average price (TWAP). Each value should be weighted by the duration it was in effect (until the next reading). This is a common pattern in financial data engineering and IoT analytics interviews.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("TimeWeightedAverage").getOrCreate()

data = [
    ("AAPL", "2025-01-15 09:30:00", 185.00),
    ("AAPL", "2025-01-15 10:15:00", 186.50),
    ("AAPL", "2025-01-15 11:00:00", 184.75),
    ("AAPL", "2025-01-15 13:30:00", 187.00),
    ("AAPL", "2025-01-15 15:00:00", 186.25),
    ("GOOG", "2025-01-15 09:30:00", 142.00),
    ("GOOG", "2025-01-15 11:00:00", 143.50),
    ("GOOG", "2025-01-15 14:00:00", 141.75),
    ("GOOG", "2025-01-15 15:00:00", 142.50),
]

columns = ["ticker", "timestamp", "price"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("timestamp", F.to_timestamp("timestamp"))
df.show(truncate=False)
```

```
+------+-------------------+------+
|ticker|timestamp          |price |
+------+-------------------+------+
|AAPL  |2025-01-15 09:30:00|185.0 |
|AAPL  |2025-01-15 10:15:00|186.5 |
|AAPL  |2025-01-15 11:00:00|184.75|
|AAPL  |2025-01-15 13:30:00|187.0 |
|AAPL  |2025-01-15 15:00:00|186.25|
|GOOG  |2025-01-15 09:30:00|142.0 |
|GOOG  |2025-01-15 11:00:00|143.5 |
|GOOG  |2025-01-15 14:00:00|141.75|
|GOOG  |2025-01-15 15:00:00|142.5 |
+------+-------------------+------+
```

### Expected Output (TWAP per ticker)
```
+------+-----+
|ticker| twap|
+------+-----+
|  AAPL|185.8|
|  GOOG|142.6|
+------+-----+
```
Each price is weighted by the duration (in minutes) it was in effect.

---

## Method 1: lead() to Compute Duration Weights (Recommended)

```python
# Step 1: Get the next timestamp per ticker using lead()
window_spec = Window.partitionBy("ticker").orderBy("timestamp")

df_with_next = df.withColumn(
    "next_timestamp", F.lead("timestamp").over(window_spec)
)

# Step 2: Calculate duration in minutes each price was in effect
df_with_duration = df_with_next.withColumn(
    "duration_minutes",
    (F.unix_timestamp("next_timestamp") - F.unix_timestamp("timestamp")) / 60
)

# Step 3: Exclude the last row per ticker (no next timestamp → duration is null)
df_valid = df_with_duration.filter(F.col("duration_minutes").isNotNull())

# Step 4: Calculate TWAP = sum(price * duration) / sum(duration)
twap = df_valid.groupBy("ticker").agg(
    F.round(
        F.sum(F.col("price") * F.col("duration_minutes")) / F.sum("duration_minutes"),
        2,
    ).alias("twap")
)
twap.show()
```

### Step-by-Step Explanation

#### Step 1: lead() to get next timestamp
- **Output (df_with_next):**

  | ticker | timestamp           | price  | next_timestamp      |
  |--------|---------------------|--------|---------------------|
  | AAPL   | 09:30               | 185.00 | 10:15               |
  | AAPL   | 10:15               | 186.50 | 11:00               |
  | AAPL   | 11:00               | 184.75 | 13:30               |
  | AAPL   | 13:30               | 187.00 | 15:00               |
  | AAPL   | 15:00               | 186.25 | null                |

#### Step 2: Calculate duration
- **Output (df_with_duration):**

  | ticker | price  | duration_minutes |
  |--------|--------|------------------|
  | AAPL   | 185.00 | 45               |
  | AAPL   | 186.50 | 45               |
  | AAPL   | 184.75 | 150              |
  | AAPL   | 187.00 | 90               |
  | AAPL   | 186.25 | null             |

#### Step 3: Exclude nulls (last row per ticker)
- AAPL's last price (186.25 at 15:00) is excluded because we don't know when it ends.

#### Step 4: Calculate TWAP
- AAPL: `(185.00×45 + 186.50×45 + 184.75×150 + 187.00×90) / (45+45+150+90)`
- AAPL: `(8325 + 8392.5 + 27712.5 + 16830) / 330 = 61260 / 330 ≈ 185.64`

---

## Method 2: VWAP (Volume-Weighted Average Price)

```python
vwap_data = [
    ("AAPL", "2025-01-15 09:30:00", 185.00, 10000),
    ("AAPL", "2025-01-15 10:15:00", 186.50, 8000),
    ("AAPL", "2025-01-15 11:00:00", 184.75, 15000),
    ("AAPL", "2025-01-15 13:30:00", 187.00, 12000),
    ("AAPL", "2025-01-15 15:00:00", 186.25, 20000),
]

vwap_df = spark.createDataFrame(vwap_data, ["ticker", "timestamp", "price", "volume"])

# VWAP = sum(price * volume) / sum(volume)
vwap = vwap_df.groupBy("ticker").agg(
    F.round(
        F.sum(F.col("price") * F.col("volume")) / F.sum("volume"),
        2,
    ).alias("vwap")
)
vwap.show()
```

- **VWAP** is simpler than TWAP — no window functions needed, just a weighted average using volume as the weight.

---

## Method 3: TWAP with Custom End Time

```python
# Often you need TWAP over a fixed period (e.g., trading day 09:30 - 16:00)
trading_end = F.to_timestamp(F.lit("2025-01-15 16:00:00"))

# For the last reading, use the trading day end time as the boundary
df_with_end = df.withColumn(
    "next_timestamp",
    F.coalesce(F.lead("timestamp").over(window_spec), trading_end)
)

df_with_dur = df_with_end.withColumn(
    "duration_minutes",
    (F.unix_timestamp("next_timestamp") - F.unix_timestamp("timestamp")) / 60
)

twap_full_day = df_with_dur.groupBy("ticker").agg(
    F.round(
        F.sum(F.col("price") * F.col("duration_minutes")) / F.sum("duration_minutes"),
        2,
    ).alias("twap")
)
twap_full_day.show()
```

- **Key difference:** Uses `coalesce(lead(), trading_end)` so the last price of the day is weighted until market close instead of being discarded.

---

## Method 4: Spark SQL

```python
df.createOrReplaceTempView("prices")

twap_sql = spark.sql("""
    WITH with_next AS (
        SELECT
            ticker,
            price,
            timestamp,
            LEAD(timestamp) OVER (PARTITION BY ticker ORDER BY timestamp) AS next_ts
        FROM prices
    ),
    with_duration AS (
        SELECT
            ticker,
            price,
            (UNIX_TIMESTAMP(next_ts) - UNIX_TIMESTAMP(timestamp)) / 60 AS duration_min
        FROM with_next
        WHERE next_ts IS NOT NULL
    )
    SELECT
        ticker,
        ROUND(SUM(price * duration_min) / SUM(duration_min), 2) AS twap
    FROM with_duration
    GROUP BY ticker
""")
twap_sql.show()
```

---

## Variation: Time-Weighted Average for Sensor/IoT Data

```python
sensor_data = [
    ("sensor_1", "2025-01-15 00:00:00", 22.5),
    ("sensor_1", "2025-01-15 00:05:00", 23.1),
    ("sensor_1", "2025-01-15 00:20:00", 22.8),  # Gap — sensor reported after 15min
    ("sensor_1", "2025-01-15 00:25:00", 23.5),
]

sensor_df = spark.createDataFrame(sensor_data, ["sensor_id", "timestamp", "temperature"])
sensor_df = sensor_df.withColumn("timestamp", F.to_timestamp("timestamp"))

# Same TWAP logic — longer durations get more weight
sensor_window = Window.partitionBy("sensor_id").orderBy("timestamp")
sensor_twap = (
    sensor_df
    .withColumn("next_ts", F.lead("timestamp").over(sensor_window))
    .withColumn("duration_sec", F.unix_timestamp("next_ts") - F.unix_timestamp("timestamp"))
    .filter(F.col("duration_sec").isNotNull())
    .groupBy("sensor_id")
    .agg(
        F.round(
            F.sum(F.col("temperature") * F.col("duration_sec")) / F.sum("duration_sec"),
            2
        ).alias("twap_temp")
    )
)
sensor_twap.show()
```

---

## Comparison of Methods

| Method | Use Case | Handles Irregular Intervals? | Needs Volume? |
|--------|----------|------------------------------|---------------|
| TWAP (lead-based) | Financial, IoT | Yes — core purpose | No |
| VWAP | Stock analysis | N/A — uses volume | Yes |
| TWAP with end time | Fixed-window analysis | Yes + includes last value | No |

## Key Interview Talking Points

1. **TWAP vs VWAP:** TWAP weights by time duration, VWAP weights by trade volume. Different use cases — TWAP for sensor data, VWAP for stock execution benchmarks.
2. **Irregular intervals matter:** A simple `avg(price)` would give equal weight to each reading, even if some were 5 minutes apart and others 3 hours apart. TWAP corrects for this.
3. **Handling the last value:** Discuss whether to discard it (conservative) or use a known boundary like market close (practical). This shows real-world awareness.
4. **Performance:** The lead() approach is efficient — single pass with a window function, no self-join needed.
5. This pattern generalizes to any "duration-weighted metric": weighted average temperature, weighted average CPU utilization, weighted average exchange rate.
