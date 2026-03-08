# PySpark Implementation: Monthly Transactions Summary

## Problem Statement

Given a `Transactions` table with `id`, `country`, `state` (approved/declined), `amount`, and `trans_date`, summarize for each month and country: the total transaction count, approved count, total amount, and approved amount. This is **LeetCode 1193 — Monthly Transactions I**.

### Sample Data

```
id  country  state     amount  trans_date
1   US       approved  1000    2025-01-15
2   US       declined  500     2025-01-20
3   US       approved  2000    2025-01-25
4   UK       approved  800     2025-01-10
5   UK       declined  300     2025-02-05
6   US       approved  1500    2025-02-10
```

### Expected Output

| month   | country | trans_count | approved_count | trans_total_amount | approved_total_amount |
|---------|---------|-------------|----------------|--------------------|-----------------------|
| 2025-01 | UK      | 1           | 1              | 800                | 800                   |
| 2025-01 | US      | 3           | 2              | 3500               | 3000                  |
| 2025-02 | UK      | 1           | 0              | 300                | 0                     |
| 2025-02 | US      | 1           | 1              | 1500               | 1500                  |

---

## Method 1: Conditional Aggregation (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, sum as spark_sum, when,
    date_format, to_date
)

spark = SparkSession.builder.appName("MonthlyTransactions").getOrCreate()

data = [
    (1, "US", "approved", 1000, "2025-01-15"),
    (2, "US", "declined", 500, "2025-01-20"),
    (3, "US", "approved", 2000, "2025-01-25"),
    (4, "UK", "approved", 800, "2025-01-10"),
    (5, "UK", "declined", 300, "2025-02-05"),
    (6, "US", "approved", 1500, "2025-02-10")
]

columns = ["id", "country", "state", "amount", "trans_date"]
df = spark.createDataFrame(data, columns)

# Extract year-month
df = df.withColumn("month", date_format(to_date("trans_date"), "yyyy-MM"))

# Conditional aggregation
result = df.groupBy("month", "country") \
    .agg(
        count("*").alias("trans_count"),
        spark_sum(when(col("state") == "approved", 1).otherwise(0)).alias("approved_count"),
        spark_sum("amount").alias("trans_total_amount"),
        spark_sum(when(col("state") == "approved", col("amount")).otherwise(0)).alias("approved_total_amount")
    ).orderBy("month", "country")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Extract month from trans_date
- **What happens:** `date_format(to_date("trans_date"), "yyyy-MM")` converts `2025-01-15` → `2025-01`.

#### Step 2: Group by month and country

#### Step 3: Apply conditional aggregations
- `count("*")` → total transactions in group.
- `sum(when(state == "approved", 1).otherwise(0))` → count of approved.
- `sum(amount)` → total amount.
- `sum(when(state == "approved", amount).otherwise(0))` → total approved amount.

---

## Method 2: Using Filter Before Aggregation

```python
from pyspark.sql.functions import col, count, sum as spark_sum, date_format, to_date

df = df.withColumn("month", date_format(to_date("trans_date"), "yyyy-MM"))

# Total stats
total = df.groupBy("month", "country").agg(
    count("*").alias("trans_count"),
    spark_sum("amount").alias("trans_total_amount")
)

# Approved stats
approved = df.filter(col("state") == "approved").groupBy("month", "country").agg(
    count("*").alias("approved_count"),
    spark_sum("amount").alias("approved_total_amount")
)

# Join
from pyspark.sql.functions import coalesce, lit

result = total.join(approved, on=["month", "country"], how="left") \
    .withColumn("approved_count", coalesce(col("approved_count"), lit(0))) \
    .withColumn("approved_total_amount", coalesce(col("approved_total_amount"), lit(0))) \
    .orderBy("month", "country")

result.show()
```

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("transactions")

result = spark.sql("""
    SELECT
        DATE_FORMAT(trans_date, 'yyyy-MM') AS month,
        country,
        COUNT(*) AS trans_count,
        SUM(CASE WHEN state = 'approved' THEN 1 ELSE 0 END) AS approved_count,
        SUM(amount) AS trans_total_amount,
        SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END) AS approved_total_amount
    FROM transactions
    GROUP BY DATE_FORMAT(trans_date, 'yyyy-MM'), country
    ORDER BY month, country
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| Month with only declined transactions | approved_count = 0, approved_amount = 0 | CASE WHEN handles it |
| NULL country | Grouped as NULL | Filter or use COALESCE |
| NULL state | Not counted as approved | Correct behavior |
| Empty table | Empty result | No special handling |

## Key Interview Talking Points

1. **Single-pass vs. multi-pass:**
   - Method 1 (conditional aggregation) scans data once — more efficient.
   - Method 2 (separate filters + join) scans twice — easier to read but slower.

2. **date_format for grouping by month:**
   - `DATE_FORMAT(date, 'yyyy-MM')` is the standard pattern for month-level aggregation.
   - Alternative: `YEAR(date), MONTH(date)` but produces two columns.

3. **CASE WHEN inside SUM/COUNT:**
   - This is the most common conditional aggregation pattern. Used in almost every reporting query.
   - `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` = conditional count.
   - `SUM(CASE WHEN ... THEN amount ELSE 0 END)` = conditional sum.

4. **Follow-up: "What about showing months with no transactions?"**
   - Generate a calendar table and LEFT JOIN the results to it (see `calendar_generation.md`).
