# PySpark Implementation: Linear Interpolation

## Problem Statement
Given temperature readings at a weather station where some days have missing values,
interpolate the missing values linearly between the nearest known readings before and
after the gap. Linear interpolation calculates a proportional value based on position
between two known data points:
`interpolated = prev_value + (next_value - prev_value) * (days_since_prev / total_gap_days)`

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("linear_interpolation").getOrCreate()

data = [
    ("station_A", "2024-01-01", 10.0),
    ("station_A", "2024-01-02", None),
    ("station_A", "2024-01-03", None),
    ("station_A", "2024-01-04", 22.0),
    ("station_A", "2024-01-05", None),
    ("station_A", "2024-01-06", 18.0),
    ("station_A", "2024-01-07", 19.0),
    ("station_A", "2024-01-08", None),
    ("station_A", "2024-01-09", None),
    ("station_A", "2024-01-10", None),
    ("station_A", "2024-01-11", 31.0),
]
columns = ["station_id", "date", "temperature"]
df = spark.createDataFrame(data, columns) \
    .withColumn("date", F.to_date("date"))

df.show()
```

| station_id | date       | temperature |
|------------|------------|-------------|
| station_A  | 2024-01-01 | 10.0        |
| station_A  | 2024-01-02 | null        |
| station_A  | 2024-01-03 | null        |
| station_A  | 2024-01-04 | 22.0        |
| station_A  | 2024-01-05 | null        |
| station_A  | 2024-01-06 | 18.0        |
| station_A  | 2024-01-07 | 19.0        |
| station_A  | 2024-01-08 | null        |
| station_A  | 2024-01-09 | null        |
| station_A  | 2024-01-10 | null        |
| station_A  | 2024-01-11 | 31.0        |

### Expected Output

| station_id | date       | temperature | interpolated |
|------------|------------|-------------|--------------|
| station_A  | 2024-01-01 | 10.0        | 10.0         |
| station_A  | 2024-01-02 | null        | 14.0         |
| station_A  | 2024-01-03 | null        | 18.0         |
| station_A  | 2024-01-04 | 22.0        | 22.0         |
| station_A  | 2024-01-05 | null        | 20.0         |
| station_A  | 2024-01-06 | 18.0        | 18.0         |
| station_A  | 2024-01-07 | 19.0        | 19.0         |
| station_A  | 2024-01-08 | null        | 22.0         |
| station_A  | 2024-01-09 | null        | 25.0         |
| station_A  | 2024-01-10 | null        | 28.0         |
| station_A  | 2024-01-11 | 31.0        | 31.0         |

---

## Method 1: Window Functions with Boundary Detection (Recommended)

```python
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Step 1: Create a numeric date column for arithmetic
df_num = df.withColumn("date_num", F.datediff("date", F.lit("2024-01-01")))

# Step 2: Find the previous known value and its date
#   last(ignorenulls=True) looks backward for the nearest non-null value
window_prev = Window \
    .partitionBy("station_id") \
    .orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

df_prev = df_num \
    .withColumn("prev_value", F.last("temperature", ignorenulls=True).over(window_prev)) \
    .withColumn("prev_date_num", F.last(
        F.when(F.col("temperature").isNotNull(), F.col("date_num")),
        ignorenulls=True
    ).over(window_prev))

# Step 3: Find the next known value and its date
#   first(ignorenulls=True) looks forward for the nearest non-null value
window_next = Window \
    .partitionBy("station_id") \
    .orderBy("date") \
    .rowsBetween(Window.currentRow, Window.unboundedFollowing)

df_boundaries = df_prev \
    .withColumn("next_value", F.first("temperature", ignorenulls=True).over(window_next)) \
    .withColumn("next_date_num", F.first(
        F.when(F.col("temperature").isNotNull(), F.col("date_num")),
        ignorenulls=True
    ).over(window_next))

# Step 4: Calculate linear interpolation
df_interpolated = df_boundaries \
    .withColumn("total_gap", F.col("next_date_num") - F.col("prev_date_num")) \
    .withColumn("position", F.col("date_num") - F.col("prev_date_num")) \
    .withColumn(
        "interpolated",
        F.when(
            F.col("temperature").isNotNull(),
            F.col("temperature")
        ).when(
            F.col("prev_value").isNull() | F.col("next_value").isNull(),
            F.coalesce(F.col("prev_value"), F.col("next_value"))
        ).otherwise(
            F.round(
                F.col("prev_value") +
                (F.col("next_value") - F.col("prev_value")) *
                (F.col("position") / F.col("total_gap")),
                2
            )
        )
    )

df_interpolated.select(
    "station_id", "date", "temperature", "interpolated"
).orderBy("station_id", "date").show(truncate=False)
```

### Step-by-Step Explanation

**After Step 2 — Previous known values:**

| date       | temperature | date_num | prev_value | prev_date_num |
|------------|-------------|----------|------------|---------------|
| 2024-01-01 | 10.0        | 0        | 10.0       | 0             |
| 2024-01-02 | null        | 1        | 10.0       | 0             |
| 2024-01-03 | null        | 2        | 10.0       | 0             |
| 2024-01-04 | 22.0        | 3        | 22.0       | 3             |
| 2024-01-05 | null        | 4        | 22.0       | 3             |

**After Step 3 — Next known values added:**

| date       | temperature | prev_value | prev_date_num | next_value | next_date_num |
|------------|-------------|------------|---------------|------------|---------------|
| 2024-01-01 | 10.0        | 10.0       | 0             | 10.0       | 0             |
| 2024-01-02 | null        | 10.0       | 0             | 22.0       | 3             |
| 2024-01-03 | null        | 10.0       | 0             | 22.0       | 3             |
| 2024-01-04 | 22.0        | 22.0       | 3             | 22.0       | 3             |
| 2024-01-05 | null        | 22.0       | 3             | 18.0       | 5             |

**After Step 4 — Interpolation calculation for Jan 02:**

- prev_value = 10.0, next_value = 22.0
- total_gap = 3 - 0 = 3 days
- position = 1 - 0 = 1 day
- interpolated = 10.0 + (22.0 - 10.0) * (1 / 3) = 10.0 + 4.0 = 14.0

**For Jan 08:**
- prev_value = 19.0, next_value = 31.0
- total_gap = 10 - 6 = 4 days
- position = 7 - 6 = 1 day
- interpolated = 19.0 + (31.0 - 19.0) * (1 / 4) = 19.0 + 3.0 = 22.0

---

## Method 2: applyInPandas with numpy.interp

```python
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, DateType, DoubleType
import pandas as pd
import numpy as np

output_schema = StructType([
    StructField("station_id", StringType()),
    StructField("date", DateType()),
    StructField("temperature", DoubleType()),
    StructField("interpolated", DoubleType()),
])

def interpolate_group(pdf: pd.DataFrame) -> pd.DataFrame:
    pdf = pdf.sort_values("date")
    known_mask = pdf["temperature"].notna()

    if known_mask.sum() < 2:
        pdf["interpolated"] = pdf["temperature"]
        return pdf

    # Convert dates to numeric for interpolation
    date_nums = (pdf["date"] - pdf["date"].min()).dt.days.values
    known_dates = date_nums[known_mask]
    known_values = pdf.loc[known_mask, "temperature"].values

    # numpy.interp performs linear interpolation
    pdf["interpolated"] = np.interp(date_nums, known_dates, known_values)

    # Keep original values where they exist
    pdf.loc[known_mask, "interpolated"] = pdf.loc[known_mask, "temperature"]

    return pdf

df_result = df.groupBy("station_id").applyInPandas(
    interpolate_group, schema=output_schema
)

df_result.orderBy("station_id", "date").show(truncate=False)
```

---

## Key Interview Talking Points

1. **Two-pass window approach** — the core idea is to find the surrounding known values
   using two separate windows: one looking backward (`last` with `ignorenulls`) and
   one looking forward (`first` with `ignorenulls`). This is the standard pattern.

2. **Numeric date conversion** — `datediff` converts dates to integers so you can do
   arithmetic. You need the gap in days, not the gap in rows, since rows may not be
   evenly spaced.

3. **Edge handling** — when there is no previous value (start of series) or no next
   value (end of series), linear interpolation is impossible. The code falls back to
   the nearest known value via `F.coalesce`. Mention this edge case proactively.

4. **Formula**: `prev + (next - prev) * (position / total_gap)`. This is simply the
   point-slope form of a line. It naturally handles gaps of any size.

5. **`applyInPandas` trade-off** — Method 2 uses `numpy.interp` which is battle-tested
   and handles edge cases (extrapolation clamping). But it serialises each group to
   Python, so it is slower for large datasets. Best for complex interpolation methods
   (spline, polynomial) that have no SQL equivalent.

6. **Performance** — Method 1 is fully Catalyst-optimized. The two window passes scan
   the data twice but stay in JVM memory. For billions of rows partitioned by sensor,
   this scales well.

7. **Interpolation vs forward fill** — forward fill is simpler (last known value only)
   and appropriate for discrete/categorical data. Linear interpolation is appropriate
   for continuous measurements (temperature, pressure, stock prices).

8. **Extension: spline interpolation** — for smoother curves between known points,
   use `applyInPandas` with `scipy.interpolate.CubicSpline`. Mention this shows you
   know the limitations of linear interpolation.
