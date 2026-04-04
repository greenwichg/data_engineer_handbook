# PySpark Implementation: Fiscal Period Mapping

## Problem Statement
Given a table of transactions with calendar dates, map each date to its corresponding **fiscal year**,
**fiscal quarter**, and **fiscal week**. The fiscal year starts on **April 1** (a common pattern for
companies in the UK, India, Japan, and Canada). For example, April 1 2024 through March 31 2025 is
fiscal year 2025 (FY2025). Generalize the approach so the fiscal year start month can be configured.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, month, year, when, lit, floor as spark_floor,
    dayofyear, date_format, to_date, datediff, date_trunc, concat
)

spark = SparkSession.builder.appName("FiscalPeriodMapping").getOrCreate()

data = [
    (1, "2024-01-15", 1200.00),   # Jan 2024 -> FY2024 Q4
    (2, "2024-03-31", 450.00),    # Mar 2024 -> FY2024 Q4 (last day of FY2024)
    (3, "2024-04-01", 890.00),    # Apr 2024 -> FY2025 Q1 (first day of FY2025)
    (4, "2024-06-15", 2300.00),   # Jun 2024 -> FY2025 Q1
    (5, "2024-07-20", 670.00),    # Jul 2024 -> FY2025 Q2
    (6, "2024-10-05", 1100.00),   # Oct 2024 -> FY2025 Q3
    (7, "2025-01-22", 3400.00),   # Jan 2025 -> FY2025 Q4
    (8, "2025-03-31", 550.00),    # Mar 2025 -> FY2025 Q4
    (9, "2025-04-01", 780.00),    # Apr 2025 -> FY2026 Q1
    (10, "2025-12-25", 920.00),   # Dec 2025 -> FY2026 Q3
]

transactions = spark.createDataFrame(data, ["txn_id", "txn_date", "amount"])
transactions = transactions.withColumn("txn_date", to_date("txn_date"))
```

### Expected Output
| txn_id | txn_date   | amount  | fiscal_year | fiscal_quarter | fiscal_month | fiscal_week |
|--------|------------|---------|-------------|----------------|--------------|-------------|
| 1      | 2024-01-15 | 1200.00 | FY2024      | Q4             | 10           | 42          |
| 2      | 2024-03-31 | 450.00  | FY2024      | Q4             | 12           | 52          |
| 3      | 2024-04-01 | 890.00  | FY2025      | Q1             | 1            | 1           |
| 4      | 2024-06-15 | 2300.00 | FY2025      | Q1             | 3            | 11          |
| 5      | 2024-07-20 | 670.00  | FY2025      | Q2             | 4            | 16          |
| 6      | 2024-10-05 | 1100.00 | FY2025      | Q3             | 7            | 27          |
| 7      | 2025-01-22 | 3400.00 | FY2025      | Q4             | 10           | 43          |
| 8      | 2025-03-31 | 550.00  | FY2025      | Q4             | 12           | 52          |
| 9      | 2025-04-01 | 780.00  | FY2026      | Q1             | 1            | 1           |
| 10     | 2025-12-25 | 920.00  | FY2026      | Q3             | 9            | 39          |

---

## Method 1: Configurable Offset Arithmetic (Recommended)
```python
from pyspark.sql.functions import (
    col, month, year, when, lit, floor as spark_floor, ceil as spark_ceil,
    to_date, datediff, concat, make_date
)

# ----- CONFIGURATION -----
FISCAL_YEAR_START_MONTH = 4   # April. Change to 7 for July, 10 for October, etc.
# --------------------------

# The offset shifts calendar months so that the fiscal start month becomes month 1
MONTH_OFFSET = 12 - FISCAL_YEAR_START_MONTH + 1  # For April start: 9

result = transactions.withColumn(
    # Shifted month: April->1, May->2, ..., Jan->10, Feb->11, Mar->12
    "fiscal_month",
    ((month("txn_date") - lit(FISCAL_YEAR_START_MONTH) + lit(12)) % lit(12)) + lit(1)
).withColumn(
    # Fiscal year: if month >= start_month, fiscal year = calendar year + 1
    # (convention: FY is named after the year it ENDS in)
    "fiscal_year_num",
    when(month("txn_date") >= lit(FISCAL_YEAR_START_MONTH), year("txn_date") + 1)
    .otherwise(year("txn_date"))
).withColumn(
    "fiscal_year", concat(lit("FY"), col("fiscal_year_num"))
).withColumn(
    # Fiscal quarter from fiscal month
    "fiscal_quarter",
    concat(lit("Q"), spark_ceil(col("fiscal_month") / lit(3)).cast("int"))
).withColumn(
    # Fiscal week: days since fiscal year start / 7 + 1
    "fy_start_date",
    when(month("txn_date") >= lit(FISCAL_YEAR_START_MONTH),
         make_date(year("txn_date"), lit(FISCAL_YEAR_START_MONTH), lit(1)))
    .otherwise(
         make_date(year("txn_date") - 1, lit(FISCAL_YEAR_START_MONTH), lit(1)))
).withColumn(
    "fiscal_week",
    (datediff(col("txn_date"), col("fy_start_date")) / lit(7)).cast("int") + lit(1)
).select(
    "txn_id", "txn_date", "amount",
    "fiscal_year", "fiscal_quarter", "fiscal_month", "fiscal_week"
)

result.show(truncate=False)
```

### Step-by-Step Explanation

**Step 1 -- Compute fiscal_month using modular arithmetic:**

Formula: `((calendar_month - start_month + 12) % 12) + 1`

| txn_date   | calendar_month | calculation        | fiscal_month |
|------------|---------------|--------------------|--------------|
| 2024-01-15 | 1             | (1 - 4 + 12) % 12 + 1 = 10 | 10   |
| 2024-04-01 | 4             | (4 - 4 + 12) % 12 + 1 = 1  | 1    |
| 2024-07-20 | 7             | (7 - 4 + 12) % 12 + 1 = 4  | 4    |
| 2025-01-22 | 1             | (1 - 4 + 12) % 12 + 1 = 10 | 10   |

**Step 2 -- Compute fiscal_year_num:**

If `calendar_month >= 4` (April), then `fiscal_year = calendar_year + 1`, else `calendar_year`.
Convention: the fiscal year is named for the calendar year in which it ends.

| txn_date   | calendar_year | calendar_month | fiscal_year_num |
|------------|--------------|----------------|-----------------|
| 2024-01-15 | 2024         | 1 (< 4)       | 2024            |
| 2024-04-01 | 2024         | 4 (>= 4)      | 2025            |
| 2025-01-22 | 2025         | 1 (< 4)       | 2025            |
| 2025-04-01 | 2025         | 4 (>= 4)      | 2026            |

**Step 3 -- Compute fiscal_quarter from fiscal_month:**

`ceil(fiscal_month / 3)` maps months 1-3 -> Q1, 4-6 -> Q2, 7-9 -> Q3, 10-12 -> Q4.

**Step 4 -- Compute fiscal_week:**

Calculate the start date of the fiscal year, then: `floor(days_since_fy_start / 7) + 1`.

---

## Method 2: Lookup Table Join Approach
```python
from pyspark.sql.functions import explode, sequence, to_date, month, year

# Build a fiscal calendar lookup table for a range of years
fiscal_years = [(y,) for y in range(2023, 2028)]
fy_df = spark.createDataFrame(fiscal_years, ["end_year"])

# Generate all dates in each fiscal year
fiscal_calendar = fy_df.select(
    col("end_year"),
    explode(
        sequence(
            make_date(col("end_year") - 1, lit(FISCAL_YEAR_START_MONTH), lit(1)),
            make_date(col("end_year"), lit(FISCAL_YEAR_START_MONTH - 1), lit(28)),
        )
    ).alias("calendar_date")
).withColumn(
    "fiscal_year", concat(lit("FY"), col("end_year"))
).withColumn(
    "fiscal_month",
    ((month("calendar_date") - lit(FISCAL_YEAR_START_MONTH) + lit(12)) % lit(12)) + lit(1)
).withColumn(
    "fiscal_quarter",
    concat(lit("Q"), spark_ceil(col("fiscal_month") / lit(3)).cast("int"))
)

# Join transactions to the fiscal calendar
result_v2 = transactions.join(
    fiscal_calendar,
    transactions["txn_date"] == fiscal_calendar["calendar_date"],
    "left"
).select(
    "txn_id", "txn_date", "amount",
    "fiscal_year", "fiscal_quarter", "fiscal_month"
)

result_v2.show(truncate=False)
```

---

## Key Interview Talking Points

1. **Modular arithmetic is the key insight**: The formula `((month - start + 12) % 12) + 1`
   universally converts any calendar month to a fiscal month regardless of the fiscal start
   month. This single expression replaces a 12-branch CASE/WHEN statement.

2. **Fiscal year naming convention matters**: Some companies name the fiscal year after the
   year it starts in (e.g., FY2024 = Apr 2024 - Mar 2025), others after the year it ends in
   (FY2025 = Apr 2024 - Mar 2025). Always clarify the convention before coding.

3. **Method 1 vs Method 2 tradeoffs**:
   - Method 1 is purely computational -- no extra data, no joins, works for any date range.
   - Method 2 (lookup table) is useful when fiscal calendars have irregular rules (e.g.,
     4-4-5 week counting, holiday adjustments). The lookup table can encode these exceptions.

4. **Performance**: Method 1 adds only column-level expressions (no shuffle, no join). It runs
   in O(n) time with zero network overhead. Method 2 requires a broadcast join but provides
   flexibility for complex fiscal rules.

5. **4-4-5 fiscal calendar**: Many retail companies use a 4-4-5 week pattern within each
   quarter (4 weeks, 4 weeks, 5 weeks). This ensures each fiscal month has complete weeks,
   making week-over-week comparisons cleaner. This requires a lookup table approach.

6. **Edge case -- leap years**: When computing fiscal week with `datediff`, leap years are
   handled automatically since `datediff` counts actual calendar days. No special logic needed.

7. **Reusable UDF pattern**: In production, wrap the fiscal mapping in a reusable function:
   ```python
   def add_fiscal_columns(df, date_col, fy_start_month=4):
       # ... returns df with fiscal_year, fiscal_quarter, fiscal_month, fiscal_week
   ```
