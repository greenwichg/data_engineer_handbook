# PySpark Implementation: Forward Fill Missing Values

## Problem Statement
Given sparse sensor readings where some dates have no recorded value, produce a complete
daily time series for each sensor. Missing values should be filled with the last known
observation (forward fill, also called Last Observation Carried Forward — LOCF). This is
a foundational time series operation in IoT, finance, and healthcare data engineering.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("forward_fill").getOrCreate()

data = [
    ("sensor_1", "2024-01-01", 20.5),
    ("sensor_1", "2024-01-02", None),
    ("sensor_1", "2024-01-03", None),
    ("sensor_1", "2024-01-04", 22.0),
    ("sensor_1", "2024-01-05", None),
    ("sensor_1", "2024-01-06", 21.0),
    ("sensor_2", "2024-01-01", None),
    ("sensor_2", "2024-01-02", 15.0),
    ("sensor_2", "2024-01-03", None),
    ("sensor_2", "2024-01-04", None),
    ("sensor_2", "2024-01-05", 16.5),
    ("sensor_2", "2024-01-06", None),
]
columns = ["sensor_id", "date", "value"]
df = spark.createDataFrame(data, columns) \
    .withColumn("date", F.to_date("date"))

df.show()
```

| sensor_id | date       | value |
|-----------|------------|-------|
| sensor_1  | 2024-01-01 | 20.5  |
| sensor_1  | 2024-01-02 | null  |
| sensor_1  | 2024-01-03 | null  |
| sensor_1  | 2024-01-04 | 22.0  |
| sensor_1  | 2024-01-05 | null  |
| sensor_1  | 2024-01-06 | 21.0  |
| sensor_2  | 2024-01-01 | null  |
| sensor_2  | 2024-01-02 | 15.0  |
| sensor_2  | 2024-01-03 | null  |
| sensor_2  | 2024-01-04 | null  |
| sensor_2  | 2024-01-05 | 16.5  |
| sensor_2  | 2024-01-06 | null  |

### Expected Output

| sensor_id | date       | value | filled_value |
|-----------|------------|-------|--------------|
| sensor_1  | 2024-01-01 | 20.5  | 20.5         |
| sensor_1  | 2024-01-02 | null  | 20.5         |
| sensor_1  | 2024-01-03 | null  | 20.5         |
| sensor_1  | 2024-01-04 | 22.0  | 22.0         |
| sensor_1  | 2024-01-05 | null  | 22.0         |
| sensor_1  | 2024-01-06 | 21.0  | 21.0         |
| sensor_2  | 2024-01-01 | null  | null         |
| sensor_2  | 2024-01-02 | 15.0  | 15.0         |
| sensor_2  | 2024-01-03 | null  | 15.0         |
| sensor_2  | 2024-01-04 | null  | 15.0         |
| sensor_2  | 2024-01-05 | 16.5  | 16.5         |
| sensor_2  | 2024-01-06 | null  | 16.5         |

---

## Method 1: last() with ignorenulls over Window (Recommended)

```python
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Step 1: Define a window partitioned by sensor, ordered by date,
#         spanning from the beginning of the partition to the current row
window_spec = Window \
    .partitionBy("sensor_id") \
    .orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# Step 2: Apply last() with ignorenulls=True
df_filled = df.withColumn(
    "filled_value",
    F.last("value", ignorenulls=True).over(window_spec)
)

df_filled.orderBy("sensor_id", "date").show()
```

### Step-by-Step Explanation

**The window function `last(value, ignorenulls=True)`** scans from the start of the
partition up to the current row and returns the last non-null value it encounters.

For sensor_1, walking through each row:

| date       | value | Window sees (non-null) | last() returns |
|------------|-------|------------------------|----------------|
| 2024-01-01 | 20.5  | [20.5]                 | 20.5           |
| 2024-01-02 | null  | [20.5]                 | 20.5           |
| 2024-01-03 | null  | [20.5]                 | 20.5           |
| 2024-01-04 | 22.0  | [20.5, 22.0]           | 22.0           |
| 2024-01-05 | null  | [20.5, 22.0]           | 22.0           |
| 2024-01-06 | 21.0  | [20.5, 22.0, 21.0]     | 21.0           |

For sensor_2, the first date has no prior non-null value, so `filled_value` stays null.
This is the correct behaviour — we cannot forward fill when no observation exists yet.

---

## Method 2: Date Spine Cross Join + Forward Fill (Complete Gap Filling)

Use this approach when raw data has **missing rows entirely** (not just null values)
and you need to generate the missing date rows first.

```python
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Sparse source data: some dates are completely absent
sparse_data = [
    ("sensor_1", "2024-01-01", 20.5),
    ("sensor_1", "2024-01-04", 22.0),
    ("sensor_1", "2024-01-06", 21.0),
    ("sensor_2", "2024-01-02", 15.0),
    ("sensor_2", "2024-01-05", 16.5),
]
sparse_df = spark.createDataFrame(sparse_data, ["sensor_id", "date", "value"]) \
    .withColumn("date", F.to_date("date"))

# Step 1: Generate a complete date spine
date_spine = spark.range(1).select(
    F.explode(
        F.sequence(
            F.to_date(F.lit("2024-01-01")),
            F.to_date(F.lit("2024-01-06")),
            F.expr("INTERVAL 1 DAY")
        )
    ).alias("date")
)

# Step 2: Get distinct sensors
sensors = sparse_df.select("sensor_id").distinct()

# Step 3: Cross join to get all (sensor, date) combinations
full_grid = sensors.crossJoin(date_spine)

# Step 4: Left join with actual readings
full_df = full_grid.join(sparse_df, on=["sensor_id", "date"], how="left")

# Step 5: Forward fill
window_spec = Window \
    .partitionBy("sensor_id") \
    .orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

result = full_df.withColumn(
    "filled_value",
    F.last("value", ignorenulls=True).over(window_spec)
)

result.orderBy("sensor_id", "date").show()
```

### Intermediate DataFrames

**After Step 3 — Full grid (sensor_1 only):**

| sensor_id | date       |
|-----------|------------|
| sensor_1  | 2024-01-01 |
| sensor_1  | 2024-01-02 |
| sensor_1  | 2024-01-03 |
| sensor_1  | 2024-01-04 |
| sensor_1  | 2024-01-05 |
| sensor_1  | 2024-01-06 |

**After Step 4 — Left join (sensor_1 only):**

| sensor_id | date       | value |
|-----------|------------|-------|
| sensor_1  | 2024-01-01 | 20.5  |
| sensor_1  | 2024-01-02 | null  |
| sensor_1  | 2024-01-03 | null  |
| sensor_1  | 2024-01-04 | 22.0  |
| sensor_1  | 2024-01-05 | null  |
| sensor_1  | 2024-01-06 | 21.0  |

**After Step 5 — Forward fill applied (same as Method 1 output).**

---

## Key Interview Talking Points

1. **`last(col, ignorenulls=True)` is the core trick** — without `ignorenulls=True`
   the function returns the literal last value in the window (which is null for null
   rows), defeating the purpose entirely. This is the single most important detail.

2. **Window frame matters** — you must specify `rowsBetween(unboundedPreceding, currentRow)`.
   The default window with an ORDER BY is `rangeBetween(unboundedPreceding, currentRow)`
   which can behave differently with duplicate ordering keys.

3. **Missing rows vs null values** — Method 1 handles nulls in existing rows. Method 2
   handles the case where entire rows are absent. Real pipelines often need both:
   generate the date spine first, then forward fill.

4. **Cross join size** — the full grid is `num_sensors * num_days`. For 1000 sensors
   over 365 days that is only 365K rows, which is small. Mention this to show you think
   about data volumes.

5. **Backward fill** — to fill backwards instead, change the window to
   `rowsBetween(currentRow, unboundedFollowing)` and use `F.first(col, ignorenulls=True)`.

6. **Fill limit** — Spark does not natively support "fill at most N rows forward".
   To implement this, create a helper column counting consecutive nulls and null out
   filled values where the count exceeds the limit.

7. **Partitioning** — always partition by the entity key (sensor_id). Without it,
   values bleed across sensors, which is a data correctness bug.

8. **Alternative: pandas_on_Spark** — for small groups, `applyInPandas` with
   `df.ffill()` is simpler but forfeits Catalyst optimization. Mention it as a
   trade-off for readability vs performance.
