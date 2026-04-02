# PySpark Implementation: Window Function Fundamentals

## Problem Statement

Window functions perform calculations across a set of rows that are related to the current row, without collapsing the rows into a single output (unlike `groupBy`). They are one of the most heavily tested topics in data engineering interviews because they demonstrate understanding of partitioning, ordering, and frame specifications.

Key concepts:
- `partitionBy`: Divides data into groups (like GROUP BY but without aggregation)
- `orderBy`: Orders rows within each partition
- `rowsBetween` / `rangeBetween`: Defines the window frame boundaries
- Ranking functions: `row_number`, `rank`, `dense_rank`, `ntile`, `percent_rank`, `cume_dist`
- Analytic functions: `lag`, `lead`, `first`, `last`, `nth_value`
- Aggregate functions used as window functions: `sum`, `avg`, `min`, `max`, `count`

---

## Setup

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("Window Function Fundamentals") \
    .master("local[*]") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")
```

---

## Part 1: Ranking Functions

### Sample Data

```python
data = [
    ("Engineering", "Alice",   95000),
    ("Engineering", "Bob",     95000),  # tied salary with Alice
    ("Engineering", "Charlie", 105000),
    ("Engineering", "Diana",   82000),
    ("Sales",       "Eve",     78000),
    ("Sales",       "Frank",   88000),
    ("Sales",       "Grace",   88000),  # tied salary with Frank
    ("Sales",       "Henry",   72000),
    ("Marketing",   "Ivy",     91000),
    ("Marketing",   "Jack",    67000),
]

df = spark.createDataFrame(data, ["dept", "name", "salary"])
df.show(truncate=False)
```

```
+-----------+-------+------+
|dept       |name   |salary|
+-----------+-------+------+
|Engineering|Alice  |95000 |
|Engineering|Bob    |95000 |
|Engineering|Charlie|105000|
|Engineering|Diana  |82000 |
|Sales      |Eve    |78000 |
|Sales      |Frank  |88000 |
|Sales      |Grace  |88000 |
|Sales      |Henry  |72000 |
|Marketing  |Ivy    |91000 |
|Marketing  |Jack   |67000 |
+-----------+-------+------+
```

### row_number() vs rank() vs dense_rank()

```python
w = Window.partitionBy("dept").orderBy(F.col("salary").desc())

df_ranked = df.select(
    "dept", "name", "salary",
    F.row_number().over(w).alias("row_number"),
    F.rank().over(w).alias("rank"),
    F.dense_rank().over(w).alias("dense_rank"),
)

df_ranked.show(truncate=False)
```

### Expected Output

```
+-----------+-------+------+----------+----+----------+
|dept       |name   |salary|row_number|rank|dense_rank|
+-----------+-------+------+----------+----+----------+
|Engineering|Charlie|105000|1         |1   |1         |
|Engineering|Alice  |95000 |2         |2   |2         |
|Engineering|Bob    |95000 |3         |2   |2         |
|Engineering|Diana  |82000 |4         |4   |3         |
|Sales      |Frank  |88000 |1         |1   |1         |
|Sales      |Grace  |88000 |2         |1   |1         |
|Sales      |Eve    |78000 |3         |3   |2         |
|Sales      |Henry  |72000 |4         |4   |3         |
|Marketing  |Ivy    |91000 |1         |1   |1         |
|Marketing  |Jack   |67000 |2         |2   |2         |
+-----------+-------+------+----------+----+----------+
```

**Key differences with ties (salary=95000 for Alice & Bob):**
- `row_number()`: Always sequential (2, 3) -- non-deterministic for ties
- `rank()`: Same rank for ties, then skips (2, 2, 4)
- `dense_rank()`: Same rank for ties, no gaps (2, 2, 3)

### ntile() -- Divide into N buckets

```python
w_dept = Window.partitionBy("dept").orderBy(F.col("salary").desc())

df.select(
    "dept", "name", "salary",
    F.ntile(2).over(w_dept).alias("ntile_2"),
    F.ntile(3).over(w_dept).alias("ntile_3"),
).show(truncate=False)
```

### Expected Output

```
+-----------+-------+------+-------+-------+
|dept       |name   |salary|ntile_2|ntile_3|
+-----------+-------+------+-------+-------+
|Engineering|Charlie|105000|1      |1      |
|Engineering|Alice  |95000 |1      |1      |
|Engineering|Bob    |95000 |2      |2      |
|Engineering|Diana  |82000 |2      |3      |
|Sales      |Frank  |88000 |1      |1      |
|Sales      |Grace  |88000 |1      |1      |
|Sales      |Eve    |78000 |2      |2      |
|Sales      |Henry  |72000 |2      |3      |
|Marketing  |Ivy    |91000 |1      |1      |
|Marketing  |Jack   |67000 |2      |2      |
+-----------+-------+------+-------+-------+
```

### percent_rank() and cume_dist()

```python
df.select(
    "dept", "name", "salary",
    F.percent_rank().over(w_dept).alias("percent_rank"),
    F.cume_dist().over(w_dept).alias("cume_dist"),
).show(truncate=False)
```

### Expected Output

```
+-----------+-------+------+------------------+------------------+
|dept       |name   |salary|percent_rank      |cume_dist         |
+-----------+-------+------+------------------+------------------+
|Engineering|Charlie|105000|0.0               |0.25              |
|Engineering|Alice  |95000 |0.3333333333333333|0.75              |
|Engineering|Bob    |95000 |0.3333333333333333|0.75              |
|Engineering|Diana  |82000 |1.0               |1.0               |
|Sales      |Frank  |88000 |0.0               |0.5               |
|Sales      |Grace  |88000 |0.0               |0.5               |
|Sales      |Eve    |78000 |0.6666666666666666|0.75              |
|Sales      |Henry  |72000 |1.0               |1.0               |
|Marketing  |Ivy    |91000 |0.0               |0.5               |
|Marketing  |Jack   |67000 |1.0               |1.0               |
+-----------+-------+------+------------------+------------------+
```

- `percent_rank()` = `(rank - 1) / (total_rows_in_partition - 1)`, ranges 0 to 1
- `cume_dist()` = `count of rows <= current / total_rows`, ranges >0 to 1

---

## Part 2: Analytic Functions (lag, lead, first, last, nth_value)

### Sample Data

```python
sales_data = [
    ("2024-01-01", "ProductA", 100),
    ("2024-01-02", "ProductA", 150),
    ("2024-01-03", "ProductA", 120),
    ("2024-01-04", "ProductA", 200),
    ("2024-01-05", "ProductA", 180),
    ("2024-01-01", "ProductB", 80),
    ("2024-01-02", "ProductB", 90),
    ("2024-01-03", "ProductB", 85),
]

df_sales = spark.createDataFrame(sales_data, ["date", "product", "revenue"])
df_sales.show(truncate=False)
```

### lag() and lead()

```python
w_product = Window.partitionBy("product").orderBy("date")

df_sales.select(
    "date", "product", "revenue",
    F.lag("revenue", 1).over(w_product).alias("prev_day_revenue"),
    F.lag("revenue", 2, 0).over(w_product).alias("two_days_ago"),  # default=0
    F.lead("revenue", 1).over(w_product).alias("next_day_revenue"),
).show(truncate=False)
```

### Expected Output

```
+----------+--------+-------+----------------+------------+----------------+
|date      |product |revenue|prev_day_revenue|two_days_ago|next_day_revenue|
+----------+--------+-------+----------------+------------+----------------+
|2024-01-01|ProductA|100    |null            |0           |150             |
|2024-01-02|ProductA|150    |100             |0           |120             |
|2024-01-03|ProductA|120    |150             |100         |200             |
|2024-01-04|ProductA|200    |120             |150         |180             |
|2024-01-05|ProductA|180    |200             |120         |null            |
|2024-01-01|ProductB|80     |null            |0           |90              |
|2024-01-02|ProductB|90     |80              |0           |85              |
|2024-01-03|ProductB|85     |90              |80          |null            |
+----------+--------+-------+----------------+------------+----------------+
```

### Day-over-Day Change (Common Interview Question)

```python
df_sales.select(
    "date", "product", "revenue",
    F.lag("revenue", 1).over(w_product).alias("prev_revenue"),
    (F.col("revenue") - F.lag("revenue", 1).over(w_product)).alias("daily_change"),
    F.round(
        (F.col("revenue") - F.lag("revenue", 1).over(w_product))
        / F.lag("revenue", 1).over(w_product) * 100, 2
    ).alias("pct_change"),
).show(truncate=False)
```

### first(), last(), nth_value()

```python
w_unbounded = Window.partitionBy("product").orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing)

df_sales.select(
    "date", "product", "revenue",
    F.first("revenue").over(w_unbounded).alias("first_revenue"),
    F.last("revenue").over(w_unbounded).alias("last_revenue"),
    F.nth_value("revenue", 2).over(w_unbounded).alias("second_revenue"),
).show(truncate=False)
```

### Expected Output

```
+----------+--------+-------+-------------+------------+--------------+
|date      |product |revenue|first_revenue|last_revenue|second_revenue|
+----------+--------+-------+-------------+------------+--------------+
|2024-01-01|ProductA|100    |100          |180         |150           |
|2024-01-02|ProductA|150    |100          |180         |150           |
|2024-01-03|ProductA|120    |100          |180         |150           |
|2024-01-04|ProductA|200    |100          |180         |150           |
|2024-01-05|ProductA|180    |100          |180         |150           |
|2024-01-01|ProductB|80     |80           |85          |90            |
|2024-01-02|ProductB|90     |80           |85          |90            |
|2024-01-03|ProductB|85     |80           |85          |90            |
+----------+--------+-------+-------------+------------+--------------+
```

**Important:** `first()` and `last()` without an explicit frame use the default frame, which only goes up to the current row when `orderBy` is specified. Always specify `rowsBetween` explicitly to get the true first/last of the entire partition.

---

## Part 3: Frame Specifications (rowsBetween and rangeBetween)

### Understanding Frame Boundaries

```python
"""
Frame boundary constants:
  Window.unboundedPreceding  = all rows before the current row
  Window.currentRow          = the current row
  Window.unboundedFollowing  = all rows after the current row
  Positive integer N         = N rows/values after current
  Negative integer -N        = N rows/values before current

rowsBetween: counts physical rows
rangeBetween: counts by column value range
"""
```

### rowsBetween Examples

```python
# 3-day moving average
w_3day = Window.partitionBy("product").orderBy("date") \
    .rowsBetween(-2, Window.currentRow)  # current row + 2 before

# 5-day centered moving average
w_5day_centered = Window.partitionBy("product").orderBy("date") \
    .rowsBetween(-2, 2)  # 2 before + current + 2 after

# Cumulative sum (running total)
w_cumulative = Window.partitionBy("product").orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# Entire partition (all rows)
w_all = Window.partitionBy("product").orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing)

df_sales.select(
    "date", "product", "revenue",
    F.round(F.avg("revenue").over(w_3day), 2).alias("moving_avg_3"),
    F.round(F.avg("revenue").over(w_5day_centered), 2).alias("centered_avg_5"),
    F.sum("revenue").over(w_cumulative).alias("cumulative_sum"),
    F.round(F.avg("revenue").over(w_all), 2).alias("partition_avg"),
).show(truncate=False)
```

### Expected Output

```
+----------+--------+-------+------------+--------------+--------------+-------------+
|date      |product |revenue|moving_avg_3|centered_avg_5|cumulative_sum|partition_avg|
+----------+--------+-------+------------+--------------+--------------+-------------+
|2024-01-01|ProductA|100    |100.0       |123.33        |100           |150.0        |
|2024-01-02|ProductA|150    |125.0       |142.5         |250           |150.0        |
|2024-01-03|ProductA|120    |123.33      |150.0         |370           |150.0        |
|2024-01-04|ProductA|200    |156.67      |162.5         |570           |150.0        |
|2024-01-05|ProductA|180    |166.67      |166.67        |750           |150.0        |
|2024-01-01|ProductB|80     |80.0        |85.0          |80            |85.0         |
|2024-01-02|ProductB|90     |85.0        |85.0          |170           |85.0         |
|2024-01-03|ProductB|85     |85.0        |87.5          |255           |85.0         |
+----------+--------+-------+------------+--------------+--------------+-------------+
```

### rangeBetween Examples

```python
# rangeBetween uses the actual ORDER BY column values, not row positions
# Useful with numeric or date columns

score_data = [
    ("Alice", 10, 100),
    ("Bob",   20, 200),
    ("Charlie", 25, 150),
    ("Diana", 30, 300),
    ("Eve",   50, 250),
]

df_score = spark.createDataFrame(score_data, ["name", "position", "score"])

# rangeBetween: include rows where position is within +/- 10 of current row's position
w_range = Window.orderBy("position") \
    .rangeBetween(-10, 10)

df_score.select(
    "name", "position", "score",
    F.collect_list("name").over(w_range).alias("neighbors"),
    F.avg("score").over(w_range).alias("avg_nearby_score"),
).show(truncate=False)
```

### Expected Output

```
+-------+--------+-----+-------------------------+----------------+
|name   |position|score|neighbors                |avg_nearby_score|
+-------+--------+-----+-------------------------+----------------+
|Alice  |10      |100  |[Alice, Bob]             |150.0           |
|Bob    |20      |200  |[Alice, Bob, Charlie, Diana]|187.5        |
|Charlie|25      |150  |[Bob, Charlie, Diana]    |216.67          |
|Diana  |30      |300  |[Bob, Charlie, Diana]    |216.67          |
|Eve    |50      |250  |[Eve]                    |250.0           |
+-------+--------+-----+-------------------------+----------------+
```

**Key difference:** `rowsBetween(-1, 1)` always includes exactly 3 rows (previous, current, next). `rangeBetween(-10, 10)` includes all rows whose ORDER BY value is within 10 of the current row's value -- could be 1 row or 100 rows.

---

## Part 4: Default Frame Behavior (Critical Interview Topic)

```python
"""
DEFAULT FRAME RULES (when not explicitly specified):

1. Window with orderBy but NO explicit frame:
   Default = rowsBetween(unboundedPreceding, currentRow)
   This is a CUMULATIVE frame.

2. Window WITHOUT orderBy:
   Default = rowsBetween(unboundedPreceding, unboundedFollowing)
   This covers the ENTIRE partition.

GOTCHA: This means F.sum("x").over(Window.partitionBy("g").orderBy("d"))
gives you a RUNNING SUM, not a partition total!
"""

w_with_order = Window.partitionBy("product").orderBy("date")
w_without_order = Window.partitionBy("product")

df_sales.select(
    "date", "product", "revenue",
    # With orderBy -> cumulative (running) sum
    F.sum("revenue").over(w_with_order).alias("running_sum"),
    # Without orderBy -> partition total
    F.sum("revenue").over(w_without_order).alias("partition_total"),
).show(truncate=False)
```

### Expected Output

```
+----------+--------+-------+-----------+---------------+
|date      |product |revenue|running_sum|partition_total|
+----------+--------+-------+-----------+---------------+
|2024-01-01|ProductA|100    |100        |750            |
|2024-01-02|ProductA|150    |250        |750            |
|2024-01-03|ProductA|120    |370        |750            |
|2024-01-04|ProductA|200    |570        |750            |
|2024-01-05|ProductA|180    |750        |750            |
|2024-01-01|ProductB|80     |80         |255            |
|2024-01-02|ProductB|90     |170        |255            |
|2024-01-03|ProductB|85     |255        |255            |
+----------+--------+-------+-----------+---------------+
```

---

## Part 5: Common Interview Patterns

### Pattern 1: Top N per group

```python
# Get the top 2 highest-paid employees per department
w_dept = Window.partitionBy("dept").orderBy(F.col("salary").desc())

df.withColumn("rn", F.row_number().over(w_dept)) \
  .filter(F.col("rn") <= 2) \
  .drop("rn") \
  .show(truncate=False)
```

### Expected Output

```
+-----------+-------+------+
|dept       |name   |salary|
+-----------+-------+------+
|Engineering|Charlie|105000|
|Engineering|Alice  |95000 |
|Sales      |Frank  |88000 |
|Sales      |Grace  |88000 |
|Marketing  |Ivy    |91000 |
|Marketing  |Jack   |67000 |
+-----------+-------+------+
```

### Pattern 2: Running total with percentage of partition

```python
w_running = Window.partitionBy("product").orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

w_total = Window.partitionBy("product")

df_sales.select(
    "date", "product", "revenue",
    F.sum("revenue").over(w_running).alias("running_total"),
    F.sum("revenue").over(w_total).alias("partition_total"),
    F.round(
        F.sum("revenue").over(w_running) / F.sum("revenue").over(w_total) * 100, 2
    ).alias("cumulative_pct"),
).show(truncate=False)
```

### Expected Output

```
+----------+--------+-------+-------------+---------------+--------------+
|date      |product |revenue|running_total|partition_total|cumulative_pct|
+----------+--------+-------+-------------+---------------+--------------+
|2024-01-01|ProductA|100    |100          |750            |13.33         |
|2024-01-02|ProductA|150    |250          |750            |33.33         |
|2024-01-03|ProductA|120    |370          |750            |49.33         |
|2024-01-04|ProductA|200    |570          |750            |76.0          |
|2024-01-05|ProductA|180    |750          |750            |100.0         |
|2024-01-01|ProductB|80     |80           |255            |31.37         |
|2024-01-02|ProductB|90     |170          |255            |66.67         |
|2024-01-03|ProductB|85     |255          |255            |100.0         |
+----------+--------+-------+-------------+---------------+--------------+
```

### Pattern 3: Deduplication (keep latest record)

```python
dedup_data = [
    (1, "Alice", "2024-01-01", "v1"),
    (1, "Alice", "2024-01-05", "v2"),  # latest
    (1, "Alice", "2024-01-03", "v1.5"),
    (2, "Bob",   "2024-02-01", "v1"),  # only record
]

df_dedup = spark.createDataFrame(dedup_data, ["id", "name", "updated_at", "version"])

w_latest = Window.partitionBy("id").orderBy(F.col("updated_at").desc())

df_dedup.withColumn("rn", F.row_number().over(w_latest)) \
    .filter(F.col("rn") == 1) \
    .drop("rn") \
    .show(truncate=False)
```

### Expected Output

```
+---+-----+----------+-------+
|id |name |updated_at|version|
+---+-----+----------+-------+
|1  |Alice|2024-01-05|v2     |
|2  |Bob  |2024-02-01|v1     |
+---+-----+----------+-------+
```

### Pattern 4: Gap detection (find missing dates)

```python
w_prev = Window.partitionBy("product").orderBy("date")

df_sales.select(
    "date", "product",
    F.lag("date", 1).over(w_prev).alias("prev_date"),
    F.datediff(
        F.to_date("date"), F.to_date(F.lag("date", 1).over(w_prev))
    ).alias("days_gap"),
).filter(F.col("days_gap") > 1).show(truncate=False)
```

### Pattern 5: Session detection (group events by time gaps)

```python
event_data = [
    ("user1", "2024-01-01 10:00:00"),
    ("user1", "2024-01-01 10:05:00"),  # same session (< 30 min gap)
    ("user1", "2024-01-01 10:10:00"),
    ("user1", "2024-01-01 12:00:00"),  # new session (> 30 min gap)
    ("user1", "2024-01-01 12:15:00"),
]

df_events = spark.createDataFrame(event_data, ["user_id", "event_time"])
df_events = df_events.withColumn("event_time", F.to_timestamp("event_time"))

w_user = Window.partitionBy("user_id").orderBy("event_time")

df_sessions = df_events.withColumn(
    "prev_time", F.lag("event_time", 1).over(w_user)
).withColumn(
    "gap_minutes",
    (F.unix_timestamp("event_time") - F.unix_timestamp("prev_time")) / 60
).withColumn(
    "new_session", F.when(
        (F.col("gap_minutes") > 30) | F.col("gap_minutes").isNull(), 1
    ).otherwise(0)
).withColumn(
    "session_id", F.sum("new_session").over(w_user)
)

df_sessions.show(truncate=False)
```

### Expected Output

```
+-------+-------------------+-------------------+-----------+-----------+----------+
|user_id|event_time         |prev_time          |gap_minutes|new_session|session_id|
+-------+-------------------+-------------------+-----------+-----------+----------+
|user1  |2024-01-01 10:00:00|null               |null       |1          |1         |
|user1  |2024-01-01 10:05:00|2024-01-01 10:00:00|5.0        |0          |1         |
|user1  |2024-01-01 10:10:00|2024-01-01 10:05:00|5.0        |0          |1         |
|user1  |2024-01-01 12:00:00|2024-01-01 10:10:00|110.0      |1          |2         |
|user1  |2024-01-01 12:15:00|2024-01-01 12:00:00|15.0       |0          |2         |
+-------+-------------------+-------------------+-----------+-----------+----------+
```

---

## Part 6: Multiple Window Specs in One Query

```python
# Combine different window specs efficiently
w_dept_salary = Window.partitionBy("dept").orderBy(F.col("salary").desc())
w_dept_all = Window.partitionBy("dept")
w_global = Window.orderBy(F.col("salary").desc())

df.select(
    "dept", "name", "salary",
    F.row_number().over(w_dept_salary).alias("dept_rank"),
    F.round(F.avg("salary").over(w_dept_all), 2).alias("dept_avg"),
    F.col("salary") - F.avg("salary").over(w_dept_all).alias("diff_from_dept_avg"),
    F.round(
        F.col("salary") / F.sum("salary").over(w_dept_all) * 100, 2
    ).alias("pct_of_dept_total"),
    F.row_number().over(w_global).alias("global_rank"),
).show(truncate=False)
```

---

## Interview Tips

1. **Default frame with `orderBy` is cumulative** (unboundedPreceding to currentRow). Without `orderBy`, it covers the entire partition. This is the single most common window function gotcha in interviews.

2. **`row_number()` is non-deterministic for ties.** If two rows have the same ORDER BY value, their row numbers are arbitrary. Add a tiebreaker column to make it deterministic: `orderBy(F.col("salary").desc(), F.col("name"))`.

3. **Know when to use each ranking function:**
   - `row_number()`: Deduplication, top-N queries, pagination
   - `rank()`: Competition-style ranking (1, 2, 2, 4)
   - `dense_rank()`: Bucket-style ranking (1, 2, 2, 3)

4. **`lag`/`lead` default value:** The third argument is a default for when there is no previous/next row. Use it to avoid NULL handling: `lag("col", 1, 0)`.

5. **`rowsBetween` vs `rangeBetween`:** Rows counts physical positions. Range uses the actual column values. For dates stored as integers or timestamps, `rangeBetween` can define time-based windows.

6. **Performance:** Window functions require a shuffle (to partition data). Minimize the number of distinct window specs in a query since each unique `partitionBy`+`orderBy` combination can trigger a separate sort.

7. **Session detection** using `lag()` + cumulative `sum()` is an extremely popular interview question. Practice the pattern: detect gaps, flag new sessions, assign session IDs.

8. **`first()` and `last()` with `ignorenulls=True`:** Use `F.first("col", ignorenulls=True)` to skip NULL values when finding the first non-null value in a window.
