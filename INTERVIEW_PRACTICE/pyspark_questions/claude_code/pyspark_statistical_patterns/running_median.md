# PySpark Implementation: Rolling Median over Last N Rows

## Problem Statement
Given daily stock prices for multiple stocks, compute the **7-day rolling median** price
for each stock. Unlike a rolling mean (which is a simple `avg()` over a window), the
**median** requires sorting the values within the window and picking the middle element.
PySpark has no built-in `median()` window function, making this a classic interview challenge.

### Sample Data

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, collect_list, udf, sort_array, percentile_approx, size, element_at
)
from pyspark.sql.window import Window
from pyspark.sql.types import (
    StructType, StructField, StringType, DoubleType, DateType, ArrayType
)
from datetime import date, timedelta

spark = SparkSession.builder.appName("RunningMedian").getOrCreate()

# Generate 14 days of prices for two stocks
data = [
    ("AAPL", date(2024, 1, 1),  185.0),
    ("AAPL", date(2024, 1, 2),  187.5),
    ("AAPL", date(2024, 1, 3),  183.0),
    ("AAPL", date(2024, 1, 4),  190.0),
    ("AAPL", date(2024, 1, 5),  188.0),
    ("AAPL", date(2024, 1, 6),  192.0),
    ("AAPL", date(2024, 1, 7),  186.0),
    ("AAPL", date(2024, 1, 8),  195.0),
    ("AAPL", date(2024, 1, 9),  191.0),
    ("AAPL", date(2024, 1, 10), 189.0),
    ("GOOG", date(2024, 1, 1),  140.0),
    ("GOOG", date(2024, 1, 2),  142.5),
    ("GOOG", date(2024, 1, 3),  138.0),
    ("GOOG", date(2024, 1, 4),  145.0),
    ("GOOG", date(2024, 1, 5),  143.0),
    ("GOOG", date(2024, 1, 6),  147.0),
    ("GOOG", date(2024, 1, 7),  141.0),
    ("GOOG", date(2024, 1, 8),  150.0),
    ("GOOG", date(2024, 1, 9),  146.0),
    ("GOOG", date(2024, 1, 10), 144.0),
]

schema = StructType([
    StructField("ticker", StringType()),
    StructField("trade_date", DateType()),
    StructField("close_price", DoubleType()),
])

df = spark.createDataFrame(data, schema)
df.show(20)
```

| ticker | trade_date | close_price |
|--------|------------|-------------|
| AAPL   | 2024-01-01 | 185.0       |
| AAPL   | 2024-01-02 | 187.5       |
| AAPL   | 2024-01-03 | 183.0       |
| AAPL   | 2024-01-04 | 190.0       |
| AAPL   | 2024-01-05 | 188.0       |
| AAPL   | 2024-01-06 | 192.0       |
| AAPL   | 2024-01-07 | 186.0       |
| AAPL   | 2024-01-08 | 195.0       |
| AAPL   | 2024-01-09 | 191.0       |
| AAPL   | 2024-01-10 | 189.0       |
| GOOG   | 2024-01-01 | 140.0       |
| ...    | ...        | ...         |

### Expected Output (7-day rolling median for AAPL)

| ticker | trade_date | close_price | rolling_median_7 |
|--------|------------|-------------|-------------------|
| AAPL   | 2024-01-01 | 185.0       | 185.0             |
| AAPL   | 2024-01-02 | 187.5       | 186.25            |
| AAPL   | 2024-01-03 | 183.0       | 185.0             |
| AAPL   | 2024-01-04 | 190.0       | 186.25            |
| AAPL   | 2024-01-05 | 188.0       | 187.5             |
| AAPL   | 2024-01-06 | 192.0       | 187.75            |
| AAPL   | 2024-01-07 | 186.0       | 187.5             |
| AAPL   | 2024-01-08 | 195.0       | 188.0             |
| AAPL   | 2024-01-09 | 191.0       | 190.0             |
| AAPL   | 2024-01-10 | 189.0       | 189.0             |

Note: For windows with an even number of elements, the median is the average of the two
middle values. For early rows with fewer than 7 data points, the median is computed over
all available rows.

---

## Method 1: collect_list + UDF (Exact Median)

```python
from pyspark.sql.functions import col, collect_list, sort_array, udf
from pyspark.sql.types import DoubleType
from pyspark.sql.window import Window

# Window: last 6 preceding rows + current row = 7 rows total
w = (
    Window
    .partitionBy("ticker")
    .orderBy("trade_date")
    .rowsBetween(-6, Window.currentRow)
)

# Collect the prices in the window into a sorted array
df_with_list = df.withColumn(
    "price_window",
    sort_array(collect_list("close_price").over(w))
)

# UDF to compute exact median from a sorted list
@udf(DoubleType())
def exact_median(sorted_prices):
    if not sorted_prices:
        return None
    n = len(sorted_prices)
    mid = n // 2
    if n % 2 == 1:
        return float(sorted_prices[mid])
    else:
        return float((sorted_prices[mid - 1] + sorted_prices[mid]) / 2.0)

result = (
    df_with_list
    .withColumn("rolling_median_7", exact_median(col("price_window")))
    .select("ticker", "trade_date", "close_price", "rolling_median_7")
    .orderBy("ticker", "trade_date")
)

result.show(20)
```

### Step-by-Step Explanation

**Step 1 -- Define a sliding window of 7 rows (current + 6 preceding):**

`rowsBetween(-6, Window.currentRow)` captures up to 7 rows. For the first row, only 1 row
is available; for the second row, 2 rows; and so on until the window is full at row 7.

**Step 2 -- collect_list gathers prices into an array, then sort_array sorts them:**

For AAPL on 2024-01-07 (7th row, full window):

| trade_date | close_price | price_window (sorted)                     |
|------------|-------------|-------------------------------------------|
| 2024-01-07 | 186.0       | [183.0, 185.0, 186.0, 187.5, 188.0, 190.0, 192.0] |

**Step 3 -- The UDF picks the middle element(s):**

Sorted window has 7 elements (odd), so median = element at index 3 = **187.5**

For AAPL on 2024-01-02 (2nd row, only 2 elements):
Sorted: [185.0, 187.5] -- even count, median = (185.0 + 187.5) / 2 = **186.25**

---

## Method 2: percentile_approx (Approximate Median, No UDF)

```python
from pyspark.sql.functions import col, percentile_approx
from pyspark.sql.window import Window

# Same sliding window
w = (
    Window
    .partitionBy("ticker")
    .orderBy("trade_date")
    .rowsBetween(-6, Window.currentRow)
)

# percentile_approx computes an approximate percentile over the window
# The second argument (0.5) specifies the 50th percentile = median
# The third argument (accuracy) controls precision; higher = more accurate but slower
result = (
    df
    .withColumn(
        "rolling_median_7",
        percentile_approx("close_price", 0.5, 10000).over(w)
    )
    .orderBy("ticker", "trade_date")
)

result.show(20)
```

### Step-by-Step Explanation for Method 2

**How percentile_approx works:**

- Uses the Greenwald-Khanna algorithm internally to maintain a compressed summary of values
- The `accuracy` parameter (10000) means the error is at most `1/10000` of the data range
- For small window sizes like 7, the result is effectively exact
- No UDF overhead, no Python serialization -- runs entirely in the JVM

**When values differ from exact median:**

For large windows (hundreds or thousands of rows), `percentile_approx` may return a value
slightly different from the true median. For a 7-element window, the result matches exactly.

---

## Key Interview Talking Points

1. **Why median is harder than mean**: `avg()` is a built-in aggregate that Spark can compute
   incrementally. Median requires knowing all values in the window to find the middle one,
   which is fundamentally an O(n log n) operation per row.

2. **UDF performance penalty**: The `collect_list + UDF` approach serializes data from JVM
   to Python for every row. For large datasets, this is orders of magnitude slower than
   native Spark operations. Always mention this trade-off.

3. **percentile_approx is the production answer**: In most real-world scenarios, an
   approximate median with configurable accuracy is perfectly acceptable. It runs in the
   JVM with no serialization overhead. Mention it first in an interview, then show you
   know the exact approach too.

4. **collect_list memory risk**: If the window is very large (e.g., 10,000 rows), each row
   will collect 10,000 values into an array. This can cause OOM errors. The
   `percentile_approx` approach uses a streaming sketch and is memory-efficient.

5. **pandas_udf alternative**: For better performance than a regular UDF, use a
   `pandas_udf` with `GROUPED_MAP` or apply it via `applyInPandas`. Pandas can compute
   the median natively in C, avoiding Python-loop overhead.

6. **rowsBetween vs rangeBetween**: `rowsBetween(-6, 0)` always takes exactly 7 rows.
   `rangeBetween` would use the ordering column's value range (e.g., 7 calendar days),
   which handles gaps differently. Clarify which the interviewer wants.

7. **Handling NULLs**: `collect_list` silently drops NULLs. If your data has missing prices,
   your window might have fewer elements than expected. Decide whether to skip NULLs or
   fill them (forward-fill with `last()` is common for stock prices).

8. **Window size semantics**: "7-day rolling" can mean 7 calendar days (use `rangeBetween`
   with days cast to numeric) or 7 data points (use `rowsBetween`). In stock data with no
   weekend trading, these give different results. Always clarify.
