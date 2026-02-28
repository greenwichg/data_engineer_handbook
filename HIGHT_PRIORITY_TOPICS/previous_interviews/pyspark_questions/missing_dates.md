# PySpark Implementation: Finding Missing Billing Dates

## Problem Statement

Given a dataset of customer billing dates, identify the **gaps (missing dates)** in each customer's billing history. For each gap, report the start and end of the missing date range. This tests your ability to use `lag()` window functions and date arithmetic to detect discontinuities.

### Sample Data

```
customer_id  billing_date
C001         2024-01-01
C001         2024-01-02
C001         2024-01-04
C001         2024-01-06
C002         2024-01-03
C002         2024-01-06
```

### Expected Output

| customer_id | missing_from | missing_to |
|-------------|--------------|------------|
| C001        | 2024-01-03   | 2024-01-03 |
| C001        | 2024-01-05   | 2024-01-05 |
| C002        | 2024-01-04   | 2024-01-05 |

- C001 is missing Jan 3 (single day) and Jan 5 (single day)
- C002 is missing Jan 4-5 (two-day range)

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lag, datediff, date_add, to_date
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("MissingBillingDates").getOrCreate()

data = [
    ("C001", "2024-01-01"),
    ("C001", "2024-01-02"),
    ("C001", "2024-01-04"),
    ("C001", "2024-01-06"),
    ("C002", "2024-01-03"),
    ("C002", "2024-01-06"),
]
df = spark.createDataFrame(data, ["customer_id", "billing_date"])
df = df.withColumn("billing_date", to_date(col("billing_date")))

# Step 1: Define window and add previous date using lag
window = Window.partitionBy("customer_id").orderBy("billing_date")
df_with_lag = df.withColumn("prev_date", lag("billing_date").over(window))

# Step 2: Filter for gaps and compute missing ranges
gaps = df_with_lag.filter(datediff(col("billing_date"), col("prev_date")) > 1) \
    .withColumn("missing_from", date_add(col("prev_date"), 1)) \
    .withColumn("missing_to", date_add(col("billing_date"), -1)) \
    .select("customer_id", "missing_from", "missing_to")

gaps.show(truncate=False)
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Add Previous Date Using lag()

- **What happens:** For each row, `lag("billing_date")` retrieves the previous billing date within the same customer partition. The first row per customer gets `null`.
- **Output (df_with_lag):**

  | customer_id | billing_date | prev_date  |
  |-------------|--------------|------------|
  | C001        | 2024-01-01   | null       |
  | C001        | 2024-01-02   | 2024-01-01 |
  | C001        | 2024-01-04   | 2024-01-02 |
  | C001        | 2024-01-06   | 2024-01-04 |
  | C002        | 2024-01-03   | null       |
  | C002        | 2024-01-06   | 2024-01-03 |

### Step 2: Filter for Gaps (datediff > 1)

- **What happens:** `datediff(billing_date, prev_date)` computes the number of days between consecutive billing dates. Rows where this is > 1 indicate a gap. Rows with `null` prev_date are automatically excluded (null comparisons return null, not true).
- **Output (after filter):**

  | customer_id | billing_date | prev_date  |
  |-------------|--------------|------------|
  | C001        | 2024-01-04   | 2024-01-02 |
  | C001        | 2024-01-06   | 2024-01-04 |
  | C002        | 2024-01-06   | 2024-01-03 |

### Step 3: Compute Missing Date Ranges

- **What happens:** For each gap row:
  - `missing_from = prev_date + 1` (day after last known billing date)
  - `missing_to = billing_date - 1` (day before next known billing date)
  - Single-day gaps have `missing_from == missing_to`
- **Output (gaps):**

  | customer_id | missing_from | missing_to |
  |-------------|--------------|------------|
  | C001        | 2024-01-03   | 2024-01-03 |
  | C001        | 2024-01-05   | 2024-01-05 |
  | C002        | 2024-01-04   | 2024-01-05 |

---

## Alternative: Using explode() to List Every Missing Date

```python
from pyspark.sql.functions import explode, sequence, expr

# Instead of showing ranges, list each individual missing date
gaps_with_dates = df_with_lag.filter(datediff(col("billing_date"), col("prev_date")) > 1) \
    .withColumn("missing_from", date_add(col("prev_date"), 1)) \
    .withColumn("missing_to", date_add(col("billing_date"), -1)) \
    .withColumn("missing_date", explode(sequence(col("missing_from"), col("missing_to")))) \
    .select("customer_id", "missing_date")

gaps_with_dates.show(truncate=False)
```

**Output:**

| customer_id | missing_date |
|-------------|--------------|
| C001        | 2024-01-03   |
| C001        | 2024-01-05   |
| C002        | 2024-01-04   |
| C002        | 2024-01-05   |

This approach uses `sequence()` to generate a date array for each gap, then `explode()` to create one row per missing date. Useful when you need to fill in data for every missing day.

---

## Key Interview Talking Points

1. **lag() vs lead():** This solution uses `lag()` to look backward. You could equivalently use `lead()` and check the next date — the filter logic would be on the current row looking forward instead of backward.

2. **Why datediff > 1?** A difference of exactly 1 means consecutive days (no gap). Greater than 1 means at least one day is missing. The `date_add` arithmetic then extracts the exact missing range.

3. **Null handling:** `lag()` returns null for the first row in each partition. The `datediff > 1` filter naturally excludes these rows because `datediff(anything, null)` returns null, which is not > 1.

4. **Edge cases:**
   - **No gaps:** The filter returns an empty DataFrame.
   - **Single-day gaps:** `missing_from == missing_to` (e.g., C001 missing Jan 3).
   - **Multi-day gaps:** `missing_from < missing_to` (e.g., C002 missing Jan 4-5).
   - **Gaps at boundaries:** This approach only detects internal gaps. To find gaps up to the current date, you'd add a synthetic "today" row per customer before applying the logic.
