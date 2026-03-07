# PySpark Implementation: Cumulative Sum with Conditional Reset

## Problem Statement
You have a table of daily deposit transactions for multiple accounts. Compute a **running
balance** that **resets to zero at the start of each month**. Within a month, the balance
accumulates; when a new month begins, it starts fresh.

This is a generalization of the classic "running sum that resets when a condition is met"
pattern, which appears frequently in financial, IoT, and session-based analytics.

### Sample Data

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, sum as _sum, year, month, date_format, lit, when,
    lag, monotonically_increasing_id
)
from pyspark.sql.window import Window
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, DateType
from datetime import date

spark = SparkSession.builder.appName("CumulativeSumWithReset").getOrCreate()

data = [
    ("A001", date(2024, 1, 3),  100.0),
    ("A001", date(2024, 1, 10), 250.0),
    ("A001", date(2024, 1, 20), 150.0),
    ("A001", date(2024, 2, 5),  300.0),
    ("A001", date(2024, 2, 15), 100.0),
    ("A001", date(2024, 3, 1),  200.0),
    ("A001", date(2024, 3, 12), 400.0),
    ("A002", date(2024, 1, 7),  500.0),
    ("A002", date(2024, 1, 25), 200.0),
    ("A002", date(2024, 2, 3),  150.0),
    ("A002", date(2024, 2, 20), 350.0),
]

schema = StructType([
    StructField("account_id", StringType()),
    StructField("txn_date", DateType()),
    StructField("amount", DoubleType()),
])

df = spark.createDataFrame(data, schema)
df.show()
```

| account_id | txn_date   | amount |
|------------|------------|--------|
| A001       | 2024-01-03 | 100.0  |
| A001       | 2024-01-10 | 250.0  |
| A001       | 2024-01-20 | 150.0  |
| A001       | 2024-02-05 | 300.0  |
| A001       | 2024-02-15 | 100.0  |
| A001       | 2024-03-01 | 200.0  |
| A001       | 2024-03-12 | 400.0  |
| A002       | 2024-01-07 | 500.0  |
| A002       | 2024-01-25 | 200.0  |
| A002       | 2024-02-03 | 150.0  |
| A002       | 2024-02-20 | 350.0  |

### Expected Output

| account_id | txn_date   | amount | running_balance |
|------------|------------|--------|-----------------|
| A001       | 2024-01-03 | 100.0  | 100.0           |
| A001       | 2024-01-10 | 250.0  | 350.0           |
| A001       | 2024-01-20 | 150.0  | 500.0           |
| A001       | 2024-02-05 | 300.0  | 300.0           |
| A001       | 2024-02-15 | 100.0  | 400.0           |
| A001       | 2024-03-01 | 200.0  | 200.0           |
| A001       | 2024-03-12 | 400.0  | 600.0           |
| A002       | 2024-01-07 | 500.0  | 500.0           |
| A002       | 2024-01-25 | 200.0  | 700.0           |
| A002       | 2024-02-03 | 150.0  | 150.0           |
| A002       | 2024-02-20 | 350.0  | 500.0           |

---

## Method 1: Partition by Account and Month (Recommended)

When the reset condition aligns with a column you can derive (like year-month), the simplest
approach is to include it directly in the window partition.

```python
from pyspark.sql.functions import col, sum as _sum, year, month
from pyspark.sql.window import Window

# Derive the month group
df_with_month = df.withColumn("txn_year", year("txn_date")).withColumn("txn_month", month("txn_date"))

# Window: partition by account AND year-month, order by date, cumulative rows
w = (
    Window
    .partitionBy("account_id", "txn_year", "txn_month")
    .orderBy("txn_date")
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)
)

result = (
    df_with_month
    .withColumn("running_balance", _sum("amount").over(w))
    .select("account_id", "txn_date", "amount", "running_balance")
    .orderBy("account_id", "txn_date")
)

result.show()
```

### Step-by-Step Explanation

**Step 1 -- Derive year and month columns:**

| account_id | txn_date   | amount | txn_year | txn_month |
|------------|------------|--------|----------|-----------|
| A001       | 2024-01-03 | 100.0  | 2024     | 1         |
| A001       | 2024-01-10 | 250.0  | 2024     | 1         |
| A001       | 2024-01-20 | 150.0  | 2024     | 1         |
| A001       | 2024-02-05 | 300.0  | 2024     | 2         |
| A001       | 2024-02-15 | 100.0  | 2024     | 2         |

**Step 2 -- Apply cumulative sum within each (account_id, year, month) partition:**

For A001, January partition: 100 -> 350 -> 500
For A001, February partition: 300 -> 400 (reset happened naturally)
For A001, March partition: 200 -> 600

The partition boundary itself causes the reset -- no special logic needed.

---

## Method 2: Generic Conditional Reset with Group Assignment

This method works for **any** reset condition, not just calendar boundaries. For example,
"reset when the running total exceeds a threshold" or "reset when a flag column equals 1".

```python
from pyspark.sql.functions import col, sum as _sum, when, lag, lit
from pyspark.sql.window import Window

# Example: reset whenever a new month starts (general approach)
w_order = Window.partitionBy("account_id").orderBy("txn_date")

# Step 1: Detect reset points -- flag rows where the month changes
df_flagged = (
    df
    .withColumn("prev_date", lag("txn_date").over(w_order))
    .withColumn(
        "reset_flag",
        when(
            col("prev_date").isNull() |
            (month("txn_date") != month("prev_date")) |
            (year("txn_date") != year("prev_date")),
            lit(1)
        ).otherwise(lit(0))
    )
)

# Step 2: Create group_id by taking a cumulative sum of the reset_flag
# Each time reset_flag = 1, the group_id increments, creating a new group
df_grouped = df_flagged.withColumn(
    "group_id",
    _sum("reset_flag").over(w_order)
)

# Step 3: Cumulative sum within each group
w_group = (
    Window
    .partitionBy("account_id", "group_id")
    .orderBy("txn_date")
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)
)

result = (
    df_grouped
    .withColumn("running_balance", _sum("amount").over(w_group))
    .select("account_id", "txn_date", "amount", "running_balance")
    .orderBy("account_id", "txn_date")
)

result.show()
```

### Step-by-Step Explanation for Method 2

**Step 1 -- Flag reset points:**

| account_id | txn_date   | amount | prev_date  | reset_flag |
|------------|------------|--------|------------|------------|
| A001       | 2024-01-03 | 100.0  | NULL       | 1          |
| A001       | 2024-01-10 | 250.0  | 2024-01-03 | 0          |
| A001       | 2024-01-20 | 150.0  | 2024-01-10 | 0          |
| A001       | 2024-02-05 | 300.0  | 2024-01-20 | 1          |
| A001       | 2024-02-15 | 100.0  | 2024-02-05 | 0          |
| A001       | 2024-03-01 | 200.0  | 2024-02-15 | 1          |
| A001       | 2024-03-12 | 400.0  | 2024-03-01 | 0          |

**Step 2 -- Cumulative sum of reset_flag creates group_id:**

| account_id | txn_date   | amount | reset_flag | group_id |
|------------|------------|--------|------------|----------|
| A001       | 2024-01-03 | 100.0  | 1          | 1        |
| A001       | 2024-01-10 | 250.0  | 0          | 1        |
| A001       | 2024-01-20 | 150.0  | 0          | 1        |
| A001       | 2024-02-05 | 300.0  | 1          | 2        |
| A001       | 2024-02-15 | 100.0  | 0          | 2        |
| A001       | 2024-03-01 | 200.0  | 1          | 3        |
| A001       | 2024-03-12 | 400.0  | 0          | 3        |

**Step 3 -- Running sum within each (account_id, group_id):**

Group 1: 100 -> 350 -> 500
Group 2: 300 -> 400
Group 3: 200 -> 600

---

## Key Interview Talking Points

1. **Method 1 is the shortcut; Method 2 is the general pattern**: When the reset condition
   maps to a derivable column (month, week, category), just add it to `partitionBy`. When
   the condition is row-dependent (threshold exceeded, flag toggled), you need the
   flag-then-group technique from Method 2.

2. **The "cumulative sum of flags" trick**: This is one of the most powerful window function
   patterns. By assigning a 1 to each reset point and taking a running sum, you create
   unique group identifiers that let you partition the running sum.

3. **Threshold-based resets are harder**: If the reset condition depends on the running sum
   itself (e.g., "reset when balance exceeds 1000"), you have a circular dependency. Pure
   window functions cannot handle this because the reset depends on values that depend on
   the reset. You need a UDF with `pandas_udf` (GROUPED_MAP) or RDD-based iteration.

4. **rowsBetween matters**: Always specify `rowsBetween(Window.unboundedPreceding,
   Window.currentRow)` explicitly. The default frame for ordered windows with `rangeBetween`
   can produce unexpected results with non-unique ordering columns.

5. **Performance**: Both methods require a single sort per partition. Method 2 adds one extra
   window pass for the group_id calculation, but this is a minor cost compared to the sort.

6. **Year boundary bug**: If you partition only by month (not year+month), January 2024 and
   January 2025 will be in the same group. Always include the year in your partition or group
   derivation.

7. **Testing edge cases**: Always test with the first row of a partition (no previous row),
   consecutive months with single transactions, and months with no transactions at all.
