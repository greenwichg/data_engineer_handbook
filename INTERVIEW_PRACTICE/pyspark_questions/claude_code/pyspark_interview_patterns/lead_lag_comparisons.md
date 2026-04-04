# PySpark Implementation: Lead and Lag Comparisons

## Problem Statement

In data engineering interviews, you are frequently asked to compare a row's value with the previous or next row's value within a partition. The `lag()` and `lead()` window functions are essential tools for this. Common real-world scenarios include calculating stock price changes day-over-day, computing session durations from login/logout events, detecting trends in time-series data, and identifying consecutive increases or decreases in metrics.

**Interview Prompt:** Given a table of daily stock prices, calculate the day-over-day price change, percentage change, and flag any day where the price dropped more than 5% from the previous day.

### Sample Data

```
| ticker | trade_date | close_price |
|--------|------------|-------------|
| AAPL   | 2024-01-02 | 185.50      |
| AAPL   | 2024-01-03 | 188.20      |
| AAPL   | 2024-01-04 | 181.00      |
| AAPL   | 2024-01-05 | 179.50      |
| AAPL   | 2024-01-08 | 183.75      |
| GOOG   | 2024-01-02 | 140.25      |
| GOOG   | 2024-01-03 | 141.80      |
| GOOG   | 2024-01-04 | 138.50      |
| GOOG   | 2024-01-05 | 130.00      |
| GOOG   | 2024-01-08 | 132.10      |
```

### Expected Output

| ticker | trade_date | close_price | prev_close | price_change | pct_change | large_drop_flag |
|--------|------------|-------------|------------|--------------|------------|-----------------|
| AAPL   | 2024-01-02 | 185.50      | null       | null         | null       | false           |
| AAPL   | 2024-01-03 | 188.20      | 185.50     | 2.70         | 1.46       | false           |
| AAPL   | 2024-01-04 | 181.00      | 188.20     | -7.20        | -3.83      | false           |
| AAPL   | 2024-01-05 | 179.50      | 181.00     | -1.50        | -0.83      | false           |
| AAPL   | 2024-01-08 | 183.75      | 179.50     | 4.25         | 2.37       | false           |
| GOOG   | 2024-01-02 | 140.25      | null       | null         | null       | false           |
| GOOG   | 2024-01-03 | 141.80      | 140.25     | 1.55         | 1.11       | false           |
| GOOG   | 2024-01-04 | 138.50      | 141.80     | -3.30        | -2.33      | false           |
| GOOG   | 2024-01-05 | 130.00      | 138.50     | -8.50        | -6.14      | true            |
| GOOG   | 2024-01-08 | 132.10      | 130.00     | 2.10         | 1.62       | false           |

---

## Method 1: Using lag() with Window Functions

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Initialize Spark
spark = SparkSession.builder \
    .appName("LeadLagComparisons") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    ("AAPL", "2024-01-02", 185.50),
    ("AAPL", "2024-01-03", 188.20),
    ("AAPL", "2024-01-04", 181.00),
    ("AAPL", "2024-01-05", 179.50),
    ("AAPL", "2024-01-08", 183.75),
    ("GOOG", "2024-01-02", 140.25),
    ("GOOG", "2024-01-03", 141.80),
    ("GOOG", "2024-01-04", 138.50),
    ("GOOG", "2024-01-05", 130.00),
    ("GOOG", "2024-01-08", 132.10),
]

df = spark.createDataFrame(data, ["ticker", "trade_date", "close_price"])
df = df.withColumn("trade_date", F.to_date("trade_date"))

# Define window: partition by ticker, order by trade_date
window_spec = Window.partitionBy("ticker").orderBy("trade_date")

# Use lag() to get the previous day's close price
result = df.withColumn("prev_close", F.lag("close_price", 1).over(window_spec)) \
    .withColumn("price_change", F.round(F.col("close_price") - F.col("prev_close"), 2)) \
    .withColumn("pct_change", F.round(
        (F.col("close_price") - F.col("prev_close")) / F.col("prev_close") * 100, 2
    )) \
    .withColumn("large_drop_flag", F.col("pct_change") < -5)

# Replace null in large_drop_flag with false
result = result.withColumn("large_drop_flag",
    F.when(F.col("large_drop_flag").isNull(), False).otherwise(F.col("large_drop_flag"))
)

result.orderBy("ticker", "trade_date").show(truncate=False)
```

---

## Method 2: Using lead() to Look Ahead

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("LeadLagComparisons_Lead") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("AAPL", "2024-01-02", 185.50),
    ("AAPL", "2024-01-03", 188.20),
    ("AAPL", "2024-01-04", 181.00),
    ("AAPL", "2024-01-05", 179.50),
    ("AAPL", "2024-01-08", 183.75),
    ("GOOG", "2024-01-02", 140.25),
    ("GOOG", "2024-01-03", 141.80),
    ("GOOG", "2024-01-04", 138.50),
    ("GOOG", "2024-01-05", 130.00),
    ("GOOG", "2024-01-08", 132.10),
]

df = spark.createDataFrame(data, ["ticker", "trade_date", "close_price"])
df = df.withColumn("trade_date", F.to_date("trade_date"))

window_spec = Window.partitionBy("ticker").orderBy("trade_date")

# Use lead() to look at the NEXT day's price
# Useful when answering: "what will the price be tomorrow?"
result = df.withColumn("next_close", F.lead("close_price", 1).over(window_spec)) \
    .withColumn("next_day_change", F.round(F.col("next_close") - F.col("close_price"), 2)) \
    .withColumn("next_day_pct_change", F.round(
        (F.col("next_close") - F.col("close_price")) / F.col("close_price") * 100, 2
    ))

result.orderBy("ticker", "trade_date").show(truncate=False)
```

---

## Method 3: Combining lag() and lead() for Multi-Row Context

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("LeadLagComparisons_Combined") \
    .master("local[*]") \
    .getOrCreate()

# Session duration example: compute time between consecutive events
session_data = [
    ("user_1", "2024-01-10 08:00:00", "login"),
    ("user_1", "2024-01-10 08:15:00", "page_view"),
    ("user_1", "2024-01-10 08:45:00", "purchase"),
    ("user_1", "2024-01-10 09:00:00", "logout"),
    ("user_2", "2024-01-10 10:00:00", "login"),
    ("user_2", "2024-01-10 10:30:00", "page_view"),
    ("user_2", "2024-01-10 11:00:00", "logout"),
]

df = spark.createDataFrame(session_data, ["user_id", "event_time", "event_type"])
df = df.withColumn("event_time", F.to_timestamp("event_time"))

window_spec = Window.partitionBy("user_id").orderBy("event_time")

result = df \
    .withColumn("prev_event_time", F.lag("event_time", 1).over(window_spec)) \
    .withColumn("next_event_time", F.lead("event_time", 1).over(window_spec)) \
    .withColumn("prev_event_type", F.lag("event_type", 1).over(window_spec)) \
    .withColumn("next_event_type", F.lead("event_type", 1).over(window_spec)) \
    .withColumn("minutes_since_prev",
        F.round(
            (F.unix_timestamp("event_time") - F.unix_timestamp("prev_event_time")) / 60, 1
        )
    ) \
    .withColumn("minutes_until_next",
        F.round(
            (F.unix_timestamp("next_event_time") - F.unix_timestamp("event_time")) / 60, 1
        )
    )

result.orderBy("user_id", "event_time").show(truncate=False)
```

---

## Method 4: Using lag() with Offset > 1

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("LeadLag_MultiOffset") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("AAPL", "2024-01-02", 185.50),
    ("AAPL", "2024-01-03", 188.20),
    ("AAPL", "2024-01-04", 181.00),
    ("AAPL", "2024-01-05", 179.50),
    ("AAPL", "2024-01-08", 183.75),
]

df = spark.createDataFrame(data, ["ticker", "trade_date", "close_price"])
df = df.withColumn("trade_date", F.to_date("trade_date"))

window_spec = Window.partitionBy("ticker").orderBy("trade_date")

# Compare with 2 days ago and 3 days ago
result = df \
    .withColumn("prev_1_day", F.lag("close_price", 1).over(window_spec)) \
    .withColumn("prev_2_day", F.lag("close_price", 2).over(window_spec)) \
    .withColumn("prev_3_day", F.lag("close_price", 3).over(window_spec)) \
    .withColumn("change_vs_2_days_ago",
        F.round(F.col("close_price") - F.col("prev_2_day"), 2)
    ) \
    .withColumn("trend_direction",
        F.when(
            (F.col("close_price") > F.col("prev_1_day")) &
            (F.col("prev_1_day") > F.col("prev_2_day")),
            "uptrend"
        ).when(
            (F.col("close_price") < F.col("prev_1_day")) &
            (F.col("prev_1_day") < F.col("prev_2_day")),
            "downtrend"
        ).otherwise("mixed")
    )

result.show(truncate=False)
```

---

## Key Concepts

- **`lag(col, offset, default)`** - Returns the value of `col` from `offset` rows BEFORE the current row within the window partition. If no previous row exists, returns `default` (null by default).
- **`lead(col, offset, default)`** - Returns the value of `col` from `offset` rows AFTER the current row.
- **Window Specification** - Always requires `orderBy()`. Use `partitionBy()` to reset comparisons per group.
- **Default Values** - Use the third argument of lag/lead to provide a default instead of null: `lag("price", 1, 0)`.
- **Performance** - lag/lead are efficient window operations. They do not trigger additional shuffles beyond the initial partitioning.

## Interview Tips

- Always clarify whether the data has gaps (e.g., missing trading days) and how to handle them.
- Mention that lag/lead require a deterministic ordering; if timestamps can tie, add a tiebreaker column.
- When computing percentage change, handle division by zero when the previous value is 0.
- A common follow-up is to detect N consecutive increases/decreases, which combines lag() with conditional logic.
