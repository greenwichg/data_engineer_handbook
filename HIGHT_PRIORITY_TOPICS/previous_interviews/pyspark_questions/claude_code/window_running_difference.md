# PySpark Implementation: Window Running Difference

## Problem Statement

Compute running differences and period-over-period changes using window functions. Given time-series data, calculate day-over-day changes, week-over-week growth, rolling differences, and cumulative change metrics. This is a common interview question at analytics-heavy companies (fintech, e-commerce, SaaS) where tracking trends and changes over time is a core capability.

### Sample Data

**Daily Sales:**

| store_id | sale_date  | revenue | units_sold |
|----------|------------|---------|------------|
| S1       | 2024-01-01 | 1000    | 50         |
| S1       | 2024-01-02 | 1200    | 55         |
| S1       | 2024-01-03 | 900     | 40         |
| S1       | 2024-01-04 | 1500    | 70         |
| S1       | 2024-01-05 | 1100    | 52         |
| S2       | 2024-01-01 | 800     | 30         |
| S2       | 2024-01-02 | 950     | 38         |
| S2       | 2024-01-03 | 1050    | 42         |

### Expected Output

| store_id | sale_date  | revenue | prev_revenue | daily_change | pct_change | running_diff |
|----------|------------|---------|--------------|--------------|------------|--------------|
| S1       | 2024-01-01 | 1000    | null         | null         | null       | 0            |
| S1       | 2024-01-02 | 1200    | 1000         | 200          | 20.0%      | 200          |
| S1       | 2024-01-03 | 900     | 1200         | -300         | -25.0%     | -100         |
| S1       | 2024-01-04 | 1500    | 900          | 600          | 66.7%      | 500          |
| S1       | 2024-01-05 | 1100    | 1500         | -400         | -26.7%     | 100          |

---

## Method 1: DataFrame API with Window Functions

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Initialize Spark
spark = SparkSession.builder \
    .appName("Window Running Difference") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
sales_data = [
    ("S1", "2024-01-01", 1000, 50),
    ("S1", "2024-01-02", 1200, 55),
    ("S1", "2024-01-03", 900, 40),
    ("S1", "2024-01-04", 1500, 70),
    ("S1", "2024-01-05", 1100, 52),
    ("S1", "2024-01-06", 1300, 60),
    ("S1", "2024-01-07", 1400, 65),
    ("S2", "2024-01-01", 800, 30),
    ("S2", "2024-01-02", 950, 38),
    ("S2", "2024-01-03", 1050, 42),
    ("S2", "2024-01-04", 900, 35),
    ("S2", "2024-01-05", 1100, 45),
]

sales_df = spark.createDataFrame(
    sales_data, ["store_id", "sale_date", "revenue", "units_sold"]
).withColumn("sale_date", F.to_date("sale_date"))

# --- Window definitions ---
w_store = Window.partitionBy("store_id").orderBy("sale_date")
w_store_rows = Window.partitionBy("store_id").orderBy("sale_date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# --- Day-over-Day difference ---
result = sales_df \
    .withColumn("prev_revenue", F.lag("revenue", 1).over(w_store)) \
    .withColumn("daily_change", F.col("revenue") - F.col("prev_revenue")) \
    .withColumn(
        "pct_change",
        F.round(
            (F.col("revenue") - F.col("prev_revenue")) / F.col("prev_revenue") * 100, 1
        )
    )

# --- Running cumulative difference from first day ---
result = result.withColumn(
    "first_day_revenue", F.first("revenue").over(w_store)
).withColumn(
    "running_diff_from_start",
    F.col("revenue") - F.col("first_day_revenue")
)

# --- Cumulative sum of daily changes ---
result = result.withColumn(
    "cumulative_daily_change",
    F.sum("daily_change").over(w_store_rows)
)

# --- 3-day moving difference (current vs 3 days ago) ---
result = result.withColumn(
    "three_day_diff",
    F.col("revenue") - F.lag("revenue", 3).over(w_store)
)

print("=== Day-over-Day and Running Differences ===")
result.select(
    "store_id", "sale_date", "revenue", "prev_revenue",
    "daily_change", "pct_change", "running_diff_from_start",
    "cumulative_daily_change", "three_day_diff"
).orderBy("store_id", "sale_date").show(20)

# --- Acceleration: change in the daily change (2nd derivative) ---
result2 = result.withColumn(
    "prev_daily_change", F.lag("daily_change", 1).over(w_store)
).withColumn(
    "acceleration",
    F.col("daily_change") - F.col("prev_daily_change")
)

print("=== Acceleration (Change in Change) ===")
result2.select(
    "store_id", "sale_date", "revenue", "daily_change", "acceleration"
).orderBy("store_id", "sale_date").show(20)

spark.stop()
```

## Method 2: SQL with Period-over-Period Comparisons

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Running Difference - SQL") \
    .master("local[*]") \
    .getOrCreate()

# --- Monthly revenue data ---
monthly_data = [
    ("S1", "2024-01", 30000), ("S1", "2024-02", 35000),
    ("S1", "2024-03", 28000), ("S1", "2024-04", 42000),
    ("S1", "2024-05", 38000), ("S1", "2024-06", 45000),
    ("S1", "2024-07", 50000), ("S1", "2024-08", 48000),
    ("S1", "2024-09", 52000), ("S1", "2024-10", 55000),
    ("S1", "2024-11", 60000), ("S1", "2024-12", 58000),
    ("S1", "2023-01", 25000), ("S1", "2023-02", 28000),
    ("S1", "2023-03", 22000), ("S1", "2023-04", 35000),
    ("S1", "2023-05", 30000), ("S1", "2023-06", 38000),
]

monthly_df = spark.createDataFrame(monthly_data, ["store_id", "month", "revenue"])
monthly_df.createOrReplaceTempView("monthly_revenue")

# --- Month-over-Month change ---
mom = spark.sql("""
    SELECT
        store_id,
        month,
        revenue,
        LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month) AS prev_month_revenue,
        revenue - LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month) AS mom_change,
        ROUND(
            (revenue - LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month))
            / LAG(revenue, 1) OVER (PARTITION BY store_id ORDER BY month) * 100, 1
        ) AS mom_pct
    FROM monthly_revenue
    ORDER BY store_id, month
""")

print("=== Month-over-Month Changes ===")
mom.show(20)

# --- Year-over-Year comparison ---
yoy = spark.sql("""
    WITH parsed AS (
        SELECT
            store_id,
            month,
            revenue,
            SUBSTRING(month, 1, 4) AS year,
            SUBSTRING(month, 6, 2) AS month_num
        FROM monthly_revenue
    )
    SELECT
        a.store_id,
        a.month AS current_month,
        a.revenue AS current_revenue,
        b.month AS prior_year_month,
        b.revenue AS prior_year_revenue,
        a.revenue - b.revenue AS yoy_change,
        ROUND((a.revenue - b.revenue) / b.revenue * 100, 1) AS yoy_pct
    FROM parsed a
    LEFT JOIN parsed b
        ON a.store_id = b.store_id
        AND a.month_num = b.month_num
        AND CAST(a.year AS INT) = CAST(b.year AS INT) + 1
    WHERE b.revenue IS NOT NULL
    ORDER BY a.month
""")

print("=== Year-over-Year Changes ===")
yoy.show(20)

# --- Running total and difference from target ---
target_sql = spark.sql("""
    SELECT
        store_id,
        month,
        revenue,
        SUM(revenue) OVER (
            PARTITION BY store_id, SUBSTRING(month, 1, 4)
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS ytd_revenue,
        500000 AS annual_target,
        SUM(revenue) OVER (
            PARTITION BY store_id, SUBSTRING(month, 1, 4)
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) - 500000 AS diff_from_target
    FROM monthly_revenue
    WHERE SUBSTRING(month, 1, 4) = '2024'
    ORDER BY month
""")

print("=== YTD Revenue vs Target ===")
target_sql.show(20)

spark.stop()
```

## Method 3: Advanced Running Differences

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("Running Difference - Advanced") \
    .master("local[*]") \
    .getOrCreate()

# --- Stock price data ---
stock_data = [
    ("AAPL", "2024-01-02", 185.0), ("AAPL", "2024-01-03", 183.5),
    ("AAPL", "2024-01-04", 181.0), ("AAPL", "2024-01-05", 184.0),
    ("AAPL", "2024-01-08", 187.5), ("AAPL", "2024-01-09", 186.0),
    ("AAPL", "2024-01-10", 189.0), ("AAPL", "2024-01-11", 191.0),
    ("AAPL", "2024-01-12", 190.5), ("AAPL", "2024-01-16", 192.0),
]

stock_df = spark.createDataFrame(stock_data, ["ticker", "date", "close_price"])
stock_df = stock_df.withColumn("date", F.to_date("date"))

w = Window.partitionBy("ticker").orderBy("date")
w_all = Window.partitionBy("ticker").orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# --- Daily return (percentage change) ---
result = stock_df \
    .withColumn("prev_close", F.lag("close_price", 1).over(w)) \
    .withColumn(
        "daily_return_pct",
        F.round((F.col("close_price") - F.col("prev_close")) / F.col("prev_close") * 100, 2)
    )

# --- Consecutive up/down days ---
result = result.withColumn(
    "direction",
    F.when(F.col("daily_return_pct") > 0, 1)
     .when(F.col("daily_return_pct") < 0, -1)
     .otherwise(0)
)

# --- Running max and drawdown ---
result = result.withColumn(
    "running_max", F.max("close_price").over(w_all)
).withColumn(
    "drawdown_pct",
    F.round((F.col("close_price") - F.col("running_max")) / F.col("running_max") * 100, 2)
)

# --- Distance from N-day high and low ---
w_5day = Window.partitionBy("ticker").orderBy("date").rowsBetween(-4, 0)

result = result \
    .withColumn("five_day_high", F.max("close_price").over(w_5day)) \
    .withColumn("five_day_low", F.min("close_price").over(w_5day)) \
    .withColumn(
        "pct_from_5d_high",
        F.round((F.col("close_price") - F.col("five_day_high")) / F.col("five_day_high") * 100, 2)
    )

print("=== Stock Analysis with Running Differences ===")
result.select(
    "ticker", "date", "close_price", "daily_return_pct",
    "running_max", "drawdown_pct", "five_day_high", "pct_from_5d_high"
).show(20)

spark.stop()
```

## Key Concepts

- **lag() / lead()**: Access previous/next row values within a window. `lag(col, n)` gets the value n rows before the current row.
- **Daily Change**: `current - lag(value, 1)`. Percentage change: `(current - previous) / previous * 100`.
- **Running Difference from Start**: `current - first(value)` using unbounded preceding window.
- **Acceleration**: The second derivative -- change in the change. `current_change - previous_change`.
- **Drawdown**: Distance from running maximum. Common in financial analysis: `(current - running_max) / running_max`.
- **Year-over-Year**: Compare with the same period in the prior year. Can use `lag(value, 12)` for monthly data or a self-join matching on month.

## Interview Tips

- Clarify the **ordering** of the window -- running differences are meaningless without a clear sort order (usually date).
- Distinguish between **rows-based** and **range-based** window frames. For time series with gaps, range-based may be more appropriate.
- Mention handling **null values**: the first row in each partition will have null for lag-based calculations. Use `coalesce()` or filter nulls depending on requirements.
- For **percentage change**, always handle division by zero (when previous value is 0).
- Period-over-period calculations are foundational for **KPI dashboards** and **anomaly detection** -- mention real-world applications.
