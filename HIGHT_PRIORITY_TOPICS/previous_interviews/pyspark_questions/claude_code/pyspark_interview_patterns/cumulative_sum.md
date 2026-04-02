# PySpark Implementation: Cumulative / Running Sum

## Problem Statement

A cumulative (running) sum adds up values row by row in a specified order. This is a classic window function problem that tests your understanding of frame specifications (`rowsBetween`, `rangeBetween`), ordering, and partitioning. Interviewers frequently ask this for financial data (running balance), time-series analysis (cumulative revenue), and inventory tracking.

### Sample Data

```python
data = [
    ("2024-01-01", "Electronics", 1000),
    ("2024-01-01", "Clothing", 500),
    ("2024-01-02", "Electronics", 1500),
    ("2024-01-02", "Clothing", 300),
    ("2024-01-03", "Electronics", 800),
    ("2024-01-03", "Electronics", 200),  # Two entries same day same category
    ("2024-01-03", "Clothing", 700),
    ("2024-01-04", "Electronics", 1200),
    ("2024-01-04", "Clothing", 600),
]
columns = ["date", "category", "revenue"]
```

### Expected Output

**Cumulative revenue by category (ordered by date):**

| date       | category    | revenue | cumulative_revenue |
|------------|-------------|---------|--------------------|
| 2024-01-01 | Electronics | 1000    | 1000               |
| 2024-01-02 | Electronics | 1500    | 2500               |
| 2024-01-03 | Electronics | 800     | 3300               |
| 2024-01-03 | Electronics | 200     | 3500               |
| 2024-01-04 | Electronics | 1200    | 4700               |

---

## Method 1: Basic Cumulative Sum with Window Function

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("CumulativeSum").getOrCreate()

data = [
    ("2024-01-01", "Electronics", 1000),
    ("2024-01-01", "Clothing", 500),
    ("2024-01-02", "Electronics", 1500),
    ("2024-01-02", "Clothing", 300),
    ("2024-01-03", "Electronics", 800),
    ("2024-01-03", "Electronics", 200),
    ("2024-01-03", "Clothing", 700),
    ("2024-01-04", "Electronics", 1200),
    ("2024-01-04", "Clothing", 600),
]
columns = ["date", "category", "revenue"]
df = spark.createDataFrame(data, columns)

# Cumulative sum by category, ordered by date
window_cum = (
    Window.partitionBy("category")
    .orderBy("date")
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)
)

result = df.withColumn("cumulative_revenue", F.sum("revenue").over(window_cum))
result.orderBy("category", "date").show()
```

**Note:** `rowsBetween(Window.unboundedPreceding, Window.currentRow)` is actually the **default frame** when `orderBy` is specified. You can omit it and get the same result. However, explicitly stating it in an interview shows you understand what is happening under the hood.

---

## Method 2: Overall Cumulative Sum (No Partition)

```python
# Running total across ALL categories, ordered by date
window_overall = (
    Window.orderBy("date")
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)
)

overall_result = df.withColumn("running_total", F.sum("revenue").over(window_overall))
overall_result.orderBy("date").show()
```

---

## Method 3: ROWS vs RANGE -- The Critical Difference

This is the most important concept interviewers test. When there are **duplicate values in the orderBy column**, ROWS and RANGE behave differently.

```python
# ROWS BETWEEN: counts physical rows
window_rows = (
    Window.partitionBy("category")
    .orderBy("date")
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)
)

# RANGE BETWEEN: counts logical values (groups ties together)
window_range = (
    Window.partitionBy("category")
    .orderBy("date")
    .rangeBetween(Window.unboundedPreceding, 0)  # 0 = currentRow for range
)

comparison = (
    df.withColumn("cum_rows", F.sum("revenue").over(window_rows))
    .withColumn("cum_range", F.sum("revenue").over(window_range))
)
comparison.filter(F.col("category") == "Electronics").orderBy("date").show()
```

**Output for Electronics:**

| date       | revenue | cum_rows | cum_range |
|------------|---------|----------|-----------|
| 2024-01-01 | 1000    | 1000     | 1000      |
| 2024-01-02 | 1500    | 2500     | 2500      |
| 2024-01-03 | 800     | 3300     | 3500      |
| 2024-01-03 | 200     | 3500     | 3500      |
| 2024-01-04 | 1200    | 4700     | 4700      |

**Key difference on 2024-01-03:**
- `ROWS`: Processes each row individually. First row gets 3300, second gets 3500.
- `RANGE`: Treats both rows with the same date as peers. Both get 3500 (includes all rows with the same date value).

**Default behavior:** When you specify `orderBy` without explicitly setting `rowsBetween` or `rangeBetween`, PySpark defaults to `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. This is a common source of bugs.

---

## Method 4: Cumulative Sum with Multiple Aggregations

```python
# Cumulative sum, count, and average in one pass
window_cum = (
    Window.partitionBy("category")
    .orderBy("date")
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)
)

multi_agg = (
    df.withColumn("cum_revenue", F.sum("revenue").over(window_cum))
    .withColumn("cum_count", F.count("revenue").over(window_cum))
    .withColumn("running_avg", F.avg("revenue").over(window_cum))
    .withColumn("cum_max", F.max("revenue").over(window_cum))
)
multi_agg.orderBy("category", "date").show()
```

---

## Method 5: Moving/Rolling Window (Bonus)

Not strictly cumulative, but interviewers often extend the question to rolling windows.

```python
# 3-row moving sum (current row + 2 preceding rows)
window_moving = (
    Window.partitionBy("category")
    .orderBy("date")
    .rowsBetween(-2, Window.currentRow)  # -2 = 2 rows before current
)

moving_result = df.withColumn("moving_3_sum", F.sum("revenue").over(window_moving))
moving_result.filter(F.col("category") == "Electronics").orderBy("date").show()

# 7-day rolling sum (range-based, using days)
# For this to work, date must be numeric (e.g., unix timestamp in seconds/days)
df_with_days = df.withColumn(
    "date_num", F.datediff(F.col("date"), F.lit("2024-01-01"))
)

window_7day = (
    Window.partitionBy("category")
    .orderBy("date_num")
    .rangeBetween(-6, 0)  # Current day and 6 preceding days = 7-day window
)

rolling_result = df_with_days.withColumn(
    "rolling_7day_revenue", F.sum("revenue").over(window_7day)
)
rolling_result.filter(F.col("category") == "Electronics").orderBy("date").show()
```

---

## Method 6: Cumulative Sum Without Window Functions (Alternative)

Using a self-join -- less efficient but shows you know alternatives.

```python
# Aggregate first to have one row per date per category
daily = df.groupBy("date", "category").agg(F.sum("revenue").alias("daily_revenue"))

# Self-join: for each row, sum all rows with date <= current date
cumulative_join = (
    daily.alias("a")
    .join(daily.alias("b"),
          (F.col("a.category") == F.col("b.category")) &
          (F.col("b.date") <= F.col("a.date")))
    .groupBy(F.col("a.date"), F.col("a.category"), F.col("a.daily_revenue"))
    .agg(F.sum(F.col("b.daily_revenue")).alias("cumulative_revenue"))
    .orderBy("category", "date")
)
cumulative_join.show()
```

**Warning:** This self-join approach is O(n^2) and should only be used when window functions are unavailable. Mention this to the interviewer to show awareness of performance.

---

## Frame Specification Reference

```
rowsBetween(start, end) / rangeBetween(start, end)

Special values:
  Window.unboundedPreceding  = from the first row of the partition
  Window.unboundedFollowing  = to the last row of the partition
  Window.currentRow          = the current row (0 for rangeBetween)

Common patterns:
  rowsBetween(unboundedPreceding, currentRow)   -- cumulative up to current
  rowsBetween(unboundedPreceding, unboundedFollowing) -- entire partition
  rowsBetween(-2, 0)                            -- 3-row moving window
  rowsBetween(0, 2)                             -- current + 2 following
  rangeBetween(-7, 0)                           -- 7-unit range window
```

---

## Key Takeaways

- **Default frame is RANGE, not ROWS.** When you write `Window.orderBy("date")` without specifying a frame, PySpark uses `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. This groups ties together, which may not be what you want.
- **ROWS = physical position.** Each row is processed individually regardless of value.
- **RANGE = logical value.** Rows with the same orderBy value are treated as peers and included together.
- **Always explicitly specify the frame** in production code to avoid surprises with the default behavior.
- `unboundedPreceding` to `currentRow` gives a cumulative sum. `unboundedPreceding` to `unboundedFollowing` gives the partition total on every row.
- **Cumulative sum requires orderBy.** Without it, there is no notion of "previous" rows.

## Interview Tips

- Lead with the window function approach. If asked, mention the self-join alternative and explain why it is worse (O(n^2) vs O(n log n)).
- Proactively explain ROWS vs RANGE. This is the depth that separates good candidates from great ones.
- Know the default frame. If the interviewer asks "What happens if you do not specify rowsBetween?" you need to know it defaults to RANGE.
- Be ready to extend to moving/rolling windows. This is the natural follow-up question.
- Mention that `rangeBetween` requires a **numeric or date-compatible** orderBy column. You cannot use RANGE with string columns.
