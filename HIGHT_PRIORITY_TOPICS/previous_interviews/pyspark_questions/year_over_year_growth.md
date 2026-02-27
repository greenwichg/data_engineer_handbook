# PySpark Implementation: Year-over-Year (YoY) Growth Calculation

## Problem Statement

Given a dataset of monthly revenue figures, calculate the **Year-over-Year (YoY) growth percentage** for each month. YoY growth compares a metric in a given month to the same month in the previous year. This is a common analytics and reporting interview question that tests your understanding of window functions with custom offsets.

### Sample Data

```
year  month  revenue
2023  1      50000
2023  2      55000
2023  3      60000
2023  6      70000
2023  12     80000
2024  1      58000
2024  2      62000
2024  3      65000
2024  6      78000
2024  12     90000
2025  1      63000
2025  2      70000
2025  3      72000
```

### Expected Output

| year | month | revenue | prev_year_revenue | yoy_growth_pct |
|------|-------|---------|-------------------|----------------|
| 2023 | 1     | 50000   | null              | null           |
| 2023 | 2     | 55000   | null              | null           |
| 2023 | 3     | 60000   | null              | null           |
| 2023 | 6     | 70000   | null              | null           |
| 2023 | 12    | 80000   | null              | null           |
| 2024 | 1     | 58000   | 50000             | 16.0           |
| 2024 | 2     | 62000   | 55000             | 12.73          |
| 2024 | 3     | 65000   | 60000             | 8.33           |
| 2024 | 6     | 78000   | 70000             | 11.43          |
| 2024 | 12    | 90000   | 80000             | 12.5           |
| 2025 | 1     | 63000   | 58000             | 8.62           |
| 2025 | 2     | 70000   | 62000             | 12.9           |
| 2025 | 3     | 72000   | 65000             | 10.77          |

---

## Method 1: Self-Join Approach

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, round as spark_round

# Initialize Spark session
spark = SparkSession.builder.appName("YoYGrowth").getOrCreate()

# Sample data
data = [
    (2023, 1, 50000), (2023, 2, 55000), (2023, 3, 60000),
    (2023, 6, 70000), (2023, 12, 80000),
    (2024, 1, 58000), (2024, 2, 62000), (2024, 3, 65000),
    (2024, 6, 78000), (2024, 12, 90000),
    (2025, 1, 63000), (2025, 2, 70000), (2025, 3, 72000)
]

columns = ["year", "month", "revenue"]
df = spark.createDataFrame(data, columns)

# Self-join: current year with previous year on the same month
df_current = df.alias("curr")
df_prev = df.alias("prev")

yoy = df_current.join(
    df_prev,
    (col("curr.month") == col("prev.month")) &
    (col("curr.year") == col("prev.year") + 1),
    "left"
).select(
    col("curr.year"),
    col("curr.month"),
    col("curr.revenue"),
    col("prev.revenue").alias("prev_year_revenue"),
    spark_round(
        ((col("curr.revenue") - col("prev.revenue")) / col("prev.revenue")) * 100, 2
    ).alias("yoy_growth_pct")
)

yoy.orderBy("year", "month").show()
```

### Step-by-Step Explanation

#### Step 1: Self-Join on month and year + 1
- **What happens:** Joins the table with itself, matching each row with the same month from the previous year.
  - 2024-Jan (revenue=58000) joins with 2023-Jan (revenue=50000)
  - 2023-Jan has no match for 2022-Jan (left join produces null)

#### Step 2: Calculate YoY Growth
- **Formula:** `((current_revenue - previous_revenue) / previous_revenue) * 100`
- **Example:** Jan 2024: `((58000 - 50000) / 50000) * 100 = 16.0%`

#### Step 3: Output
- **Output:**

  | year | month | revenue | prev_year_revenue | yoy_growth_pct |
  |------|-------|---------|-------------------|----------------|
  | 2023 | 1     | 50000   | null              | null           |
  | 2023 | 2     | 55000   | null              | null           |
  | 2023 | 3     | 60000   | null              | null           |
  | 2023 | 6     | 70000   | null              | null           |
  | 2023 | 12    | 80000   | null              | null           |
  | 2024 | 1     | 58000   | 50000             | 16.0           |
  | 2024 | 2     | 62000   | 55000             | 12.73          |
  | 2024 | 3     | 65000   | 60000             | 8.33           |
  | 2024 | 6     | 78000   | 70000             | 11.43          |
  | 2024 | 12    | 90000   | 80000             | 12.5           |
  | 2025 | 1     | 63000   | 58000             | 8.62           |
  | 2025 | 2     | 70000   | 62000             | 12.9           |
  | 2025 | 3     | 72000   | 65000             | 10.77          |

---

## Method 2: Using lag() Window Function

```python
from pyspark.sql.functions import lag
from pyspark.sql.window import Window

# Window: partition by month, order by year
# This ensures lag(1) gives the same month from the previous year
window_spec = Window.partitionBy("month").orderBy("year")

# Add previous year's revenue using lag
df_yoy = df.withColumn("prev_year_revenue", lag("revenue", 1).over(window_spec))

# Calculate YoY growth percentage
df_yoy = df_yoy.withColumn(
    "yoy_growth_pct",
    spark_round(
        ((col("revenue") - col("prev_year_revenue")) / col("prev_year_revenue")) * 100, 2
    )
)

df_yoy.orderBy("year", "month").show()
```

### Step-by-Step Explanation

#### Step 1: Define Window
- **What happens:** Partitions by `month` and orders by `year`. So for month=1, the window contains: [2023, 2024, 2025]. `lag(1)` gives the previous row in this window — which is the same month in the previous year.

#### Step 2: lag("revenue", 1)
- **What happens:** For each row, retrieves the revenue from the previous year's same month.
- **Output (df_yoy before growth calc):**

  | year | month | revenue | prev_year_revenue |
  |------|-------|---------|-------------------|
  | 2023 | 1     | 50000   | null              |
  | 2024 | 1     | 58000   | 50000             |
  | 2025 | 1     | 63000   | 58000             |
  | 2023 | 2     | 55000   | null              |
  | 2024 | 2     | 62000   | 55000             |
  | 2025 | 2     | 70000   | 62000             |
  | ...  | ...   | ...     | ...               |

#### Step 3: Growth Calculation
- **Formula:** Same as Method 1.

---

## Method 3: Month-over-Month (MoM) Growth (Bonus)

```python
# Create a year_month column for sequential ordering
from pyspark.sql.functions import concat, lpad, lit

df_mom = df.withColumn(
    "year_month",
    concat(col("year"), lit("-"), lpad(col("month"), 2, "0"))
)

# Window ordered by year_month
window_mom = Window.orderBy("year_month")

# Previous month's revenue
df_mom = df_mom.withColumn("prev_month_revenue", lag("revenue", 1).over(window_mom))

# MoM growth
df_mom = df_mom.withColumn(
    "mom_growth_pct",
    spark_round(
        ((col("revenue") - col("prev_month_revenue")) / col("prev_month_revenue")) * 100, 2
    )
)

df_mom.orderBy("year_month").show()
```

- **Explanation:** Unlike YoY (which compares the same month across years), MoM compares each month to its immediate predecessor. This is useful for detecting short-term trends.

---

## Method 4: Using SQL

```python
df.createOrReplaceTempView("monthly_revenue")

yoy_sql = spark.sql("""
    SELECT
        curr.year,
        curr.month,
        curr.revenue,
        prev.revenue AS prev_year_revenue,
        ROUND(((curr.revenue - prev.revenue) / prev.revenue) * 100, 2) AS yoy_growth_pct
    FROM monthly_revenue curr
    LEFT JOIN monthly_revenue prev
        ON curr.month = prev.month
        AND curr.year = prev.year + 1
    ORDER BY curr.year, curr.month
""")

yoy_sql.show()
```

---

## Key Interview Talking Points

1. **Self-join vs lag():**
   - **Self-join:** More explicit, works when data has gaps (e.g., missing months). Flexible for any offset.
   - **lag():** Cleaner code, but requires data to be ordered correctly. `lag(1)` assumes the previous row is the previous year — only true if partitioned by month.

2. **Handling missing data:** If some months don't have data for every year, the lag approach may return incorrect results (the previous row might not be the correct previous year). The self-join approach handles this correctly.

3. **Handling zero revenue:** Division by zero when `prev_year_revenue = 0`. Use `when(col("prev_year_revenue") != 0, ...)` or `nullif()` in SQL.

4. **Common follow-up:** "Calculate the compound annual growth rate (CAGR)."
   ```python
   # CAGR = (ending_value / beginning_value) ^ (1/years) - 1
   from pyspark.sql.functions import pow as spark_pow
   ```

5. **Real-world applications:**
   - Financial reporting (revenue, profit growth)
   - E-commerce (order volume trends)
   - SaaS metrics (ARR growth, churn rates)
