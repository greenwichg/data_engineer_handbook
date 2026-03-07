# PySpark Implementation: Conditional Window Boundaries with rangeBetween

## Problem Statement
Given a table of daily sales transactions, compute a rolling 30-day revenue sum for each store. Unlike `rowsBetween`, which counts rows, `rangeBetween` operates on the actual values of the ordering column, making it possible to define windows based on calendar time even when data has gaps (missing days). This requires converting dates to numeric timestamps to use with `rangeBetween`.

### Sample Data
```python
from pyspark.sql import SparkSession, Window
from pyspark.sql.functions import (
    col, sum as _sum, unix_timestamp, to_date, lit,
    datediff, round as _round, count
)
from pyspark.sql.types import LongType

spark = SparkSession.builder.appName("ConditionalWindow").getOrCreate()

data = [
    ("Store_A", "2024-01-01", 500),
    ("Store_A", "2024-01-10", 300),
    ("Store_A", "2024-01-20", 700),
    ("Store_A", "2024-02-05", 400),
    ("Store_A", "2024-02-15", 600),
    ("Store_A", "2024-03-01", 200),
    ("Store_B", "2024-01-05", 800),
    ("Store_B", "2024-01-25", 350),
    ("Store_B", "2024-02-10", 450),
    ("Store_B", "2024-02-28", 550),
    ("Store_B", "2024-03-15", 300),
]

df = spark.createDataFrame(data, ["store", "sale_date", "amount"])
df = df.withColumn("sale_date", to_date("sale_date"))
df.show()
```

| store   | sale_date  | amount |
|---------|------------|--------|
| Store_A | 2024-01-01 | 500    |
| Store_A | 2024-01-10 | 300    |
| Store_A | 2024-01-20 | 700    |
| Store_A | 2024-02-05 | 400    |
| Store_A | 2024-02-15 | 600    |
| Store_A | 2024-03-01 | 200    |
| Store_B | 2024-01-05 | 800    |
| Store_B | 2024-01-25 | 350    |
| Store_B | 2024-02-10 | 450    |
| Store_B | 2024-02-28 | 550    |
| Store_B | 2024-03-15 | 300    |

### Expected Output

| store   | sale_date  | amount | rolling_30d_sum |
|---------|------------|--------|-----------------|
| Store_A | 2024-01-01 | 500    | 500             |
| Store_A | 2024-01-10 | 300    | 800             |
| Store_A | 2024-01-20 | 700    | 1500            |
| Store_A | 2024-02-05 | 400    | 1400            |
| Store_A | 2024-02-15 | 600    | 1700            |
| Store_A | 2024-03-01 | 200    | 800             |
| Store_B | 2024-01-05 | 800    | 800             |
| Store_B | 2024-01-25 | 350    | 1150            |
| Store_B | 2024-02-10 | 450    | 800             |
| Store_B | 2024-02-28 | 550    | 1000            |
| Store_B | 2024-03-15 | 300    | 850             |

---

## Method 1: rangeBetween with Unix Timestamps (Recommended)

```python
# Step 1: Convert sale_date to a numeric value (seconds since epoch)
SECONDS_IN_DAY = 86400  # 60 * 60 * 24

df_with_ts = df.withColumn(
    "date_long", unix_timestamp("sale_date").cast(LongType())
)

# Step 2: Define window with rangeBetween using seconds
#   -30 days in seconds to current row (0)
rolling_window = (
    Window
    .partitionBy("store")
    .orderBy("date_long")
    .rangeBetween(-30 * SECONDS_IN_DAY, 0)
)

# Step 3: Apply the rolling sum
result = df_with_ts.withColumn(
    "rolling_30d_sum", _sum("amount").over(rolling_window)
)

# Step 4: Drop the helper column and display
result.drop("date_long").orderBy("store", "sale_date").show()
```

### Step-by-Step Explanation

**After Step 1 -- Date converted to epoch seconds:**

| store   | sale_date  | amount | date_long  |
|---------|------------|--------|------------|
| Store_A | 2024-01-01 | 500    | 1704067200 |
| Store_A | 2024-01-10 | 300    | 1704844800 |
| Store_A | 2024-01-20 | 700    | 1705708800 |
| Store_A | 2024-02-05 | 400    | 1707091200 |

The `date_long` column is the numeric column that `rangeBetween` operates on.

**After Step 2 -- Window definition (no computation yet):**

`rangeBetween(-2592000, 0)` means: for each row, include all rows in the same partition whose `date_long` value falls within `[current_date_long - 2592000, current_date_long]`. This is exactly 30 days expressed in seconds.

**After Step 3 -- Rolling sum computed:**

For Store_A on 2024-02-05 (date_long = 1707091200):
- Window lower bound = 1707091200 - 2592000 = 1704499200 (= 2024-01-06)
- Rows included: Jan 10 (300), Jan 20 (700), Feb 5 (400) = 1400
- Jan 1 is excluded because it falls before Jan 6

For Store_A on 2024-03-01:
- Window lower bound = 2024-01-31
- Rows included: Feb 15 (600), Mar 1 (200) = 800

---

## Method 2: Self-Join with Date Range Condition

```python
# Join each row with all rows in the same store within 30 days before
df_left = df.alias("a")
df_right = df.alias("b")

joined = df_left.join(
    df_right,
    (col("a.store") == col("b.store"))
    & (col("b.sale_date") >= col("a.sale_date") - 30)
    & (col("b.sale_date") <= col("a.sale_date")),
    "inner"
)

result_join = (
    joined
    .groupBy(col("a.store"), col("a.sale_date"), col("a.amount"))
    .agg(_sum(col("b.amount")).alias("rolling_30d_sum"))
    .orderBy("store", "sale_date")
)

result_join.show()
```

This approach is more intuitive but far less efficient. The self-join creates a cartesian-like explosion within each store, and grouping afterward is expensive. Use this only when `rangeBetween` is not feasible (e.g., complex multi-column range conditions).

---

## Method 3: SQL Expression with RANGE BETWEEN

```python
df.createOrReplaceTempView("sales")

result_sql = spark.sql("""
    SELECT
        store,
        sale_date,
        amount,
        SUM(amount) OVER (
            PARTITION BY store
            ORDER BY CAST(sale_date AS LONG)
            RANGE BETWEEN 2592000 PRECEDING AND CURRENT ROW
        ) AS rolling_30d_sum
    FROM sales
    ORDER BY store, sale_date
""")

result_sql.show()
```

The SQL syntax mirrors the DataFrame API. `CAST(sale_date AS LONG)` converts the date to epoch seconds inside the SQL expression.

---

## Key Interview Talking Points

1. **`rangeBetween` vs `rowsBetween`** -- `rowsBetween(-3, 0)` always includes exactly 4 rows (3 preceding + current). `rangeBetween(-30 * 86400, 0)` includes all rows whose ordering column value falls within the range, regardless of how many rows that is. This distinction is critical for time-series with gaps.

2. **Why convert to seconds** -- `rangeBetween` requires a numeric ordering column and integer boundary values. Dates are not numeric, so converting to unix timestamp (seconds since epoch) makes the range arithmetic work. The boundary is `30 * 86400 = 2592000` seconds.

3. **Inclusive boundaries** -- both endpoints of `rangeBetween` are inclusive. A range of `(-2592000, 0)` includes exactly 30 days plus the current day, which means it covers a 31-day calendar span. Adjust to `-29 * 86400` if you need exactly 30 calendar days.

4. **Performance advantage over self-join** -- `rangeBetween` is computed within a single sort pass per partition. A self-join creates O(N^2) row combinations per store, which is drastically worse for large datasets.

5. **Data gaps are handled correctly** -- if a store has no sales on certain days, `rangeBetween` still works correctly because it uses values, not row positions. A store with sales on day 1 and day 31 will not include day 1 in the day-31 window.

6. **Timezone awareness** -- `unix_timestamp` uses the session timezone. In production, explicitly set `spark.sql.session.timeZone` to avoid surprises when clusters run in different zones.

7. **Dynamic window size from a column** -- if each store has its own lookback period stored in a column, `rangeBetween` cannot reference columns for boundaries (they must be literal integers). In that case, use a self-join with the column-based condition, or restructure the problem with explode and a fixed window.
