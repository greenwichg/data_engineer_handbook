# PySpark Implementation: Temporal Validity Queries

## Problem Statement

Many datasets include temporal validity columns (valid_from, valid_to) indicating when a record is active. Given such data, find records that are active at a specific point in time, identify the version of a record that was current on a given date, and handle gaps and overlaps in validity periods. This is a common interview question at insurance, finance, and HR companies where bitemporal data and slowly changing dimensions are standard. It tests your ability to work with date ranges and interval-based filtering.

### Sample Data

**Employee Positions (with temporal validity):**

| emp_id | department  | salary | valid_from | valid_to   |
|--------|-------------|--------|------------|------------|
| E001   | Engineering | 90000  | 2022-01-01 | 2023-03-31 |
| E001   | Engineering | 95000  | 2023-04-01 | 2024-01-31 |
| E001   | Management  | 120000 | 2024-02-01 | 9999-12-31 |
| E002   | Marketing   | 70000  | 2022-06-01 | 2023-12-31 |
| E002   | Marketing   | 80000  | 2024-01-01 | 9999-12-31 |
| E003   | Sales       | 65000  | 2023-01-01 | 2023-09-30 |
| E003   | Engineering | 85000  | 2024-01-01 | 9999-12-31 |

### Expected Output

**Active records as of 2024-03-15:**

| emp_id | department  | salary | valid_from | valid_to   |
|--------|-------------|--------|------------|------------|
| E001   | Management  | 120000 | 2024-02-01 | 9999-12-31 |
| E002   | Marketing   | 80000  | 2024-01-01 | 9999-12-31 |
| E003   | Engineering | 85000  | 2024-01-01 | 9999-12-31 |

---

## Method 1: Point-in-Time Query with DataFrame API

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Initialize Spark
spark = SparkSession.builder \
    .appName("Temporal Validity Queries") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
positions_data = [
    ("E001", "Engineering", 90000, "2022-01-01", "2023-03-31"),
    ("E001", "Engineering", 95000, "2023-04-01", "2024-01-31"),
    ("E001", "Management", 120000, "2024-02-01", "9999-12-31"),
    ("E002", "Marketing", 70000, "2022-06-01", "2023-12-31"),
    ("E002", "Marketing", 80000, "2024-01-01", "9999-12-31"),
    ("E003", "Sales", 65000, "2023-01-01", "2023-09-30"),
    ("E003", "Engineering", 85000, "2024-01-01", "9999-12-31"),
]

positions_df = spark.createDataFrame(
    positions_data,
    ["emp_id", "department", "salary", "valid_from", "valid_to"]
).withColumn("valid_from", F.to_date("valid_from")) \
 .withColumn("valid_to", F.to_date("valid_to"))

print("=== All Temporal Records ===")
positions_df.orderBy("emp_id", "valid_from").show()

# --- Query 1: Point-in-Time - Records active on a specific date ---
query_date = "2024-03-15"

active_records = positions_df.filter(
    (F.col("valid_from") <= F.lit(query_date)) &
    (F.col("valid_to") >= F.lit(query_date))
)

print(f"=== Active Records as of {query_date} ===")
active_records.show()

# --- Query 2: Records active during a date range ---
range_start = "2023-06-01"
range_end = "2023-12-31"

# A record overlaps with the range if:
# record.valid_from <= range_end AND record.valid_to >= range_start
overlapping_records = positions_df.filter(
    (F.col("valid_from") <= F.lit(range_end)) &
    (F.col("valid_to") >= F.lit(range_start))
)

print(f"=== Records active during {range_start} to {range_end} ===")
overlapping_records.show()

# --- Query 3: Find the most recent valid record per employee ---
w = Window.partitionBy("emp_id").orderBy(F.desc("valid_from"))

latest_records = positions_df \
    .withColumn("rn", F.row_number().over(w)) \
    .filter(F.col("rn") == 1) \
    .drop("rn")

print("=== Latest Record Per Employee ===")
latest_records.show()

# --- Query 4: Detect gaps in validity ---
w_lag = Window.partitionBy("emp_id").orderBy("valid_from")

gaps = positions_df \
    .withColumn("prev_valid_to", F.lag("valid_to").over(w_lag)) \
    .withColumn(
        "gap_days",
        F.datediff(F.col("valid_from"), F.col("prev_valid_to")) - 1
    ) \
    .filter(F.col("gap_days").isNotNull() & (F.col("gap_days") > 0))

print("=== Gaps in Temporal Validity ===")
gaps.select("emp_id", "prev_valid_to", "valid_from", "gap_days").show()

# --- Query 5: Timeline for a specific employee ---
print("=== E001 Timeline ===")
positions_df.filter(F.col("emp_id") == "E001") \
    .withColumn("duration_days", F.datediff("valid_to", "valid_from")) \
    .orderBy("valid_from") \
    .show()

spark.stop()
```

## Method 2: SQL with Temporal Joins

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Temporal Validity - SQL") \
    .master("local[*]") \
    .getOrCreate()

# --- Data ---
positions_data = [
    ("E001", "Engineering", 90000, "2022-01-01", "2023-03-31"),
    ("E001", "Engineering", 95000, "2023-04-01", "2024-01-31"),
    ("E001", "Management", 120000, "2024-02-01", "9999-12-31"),
    ("E002", "Marketing", 70000, "2022-06-01", "2023-12-31"),
    ("E002", "Marketing", 80000, "2024-01-01", "9999-12-31"),
    ("E003", "Sales", 65000, "2023-01-01", "2023-09-30"),
    ("E003", "Engineering", 85000, "2024-01-01", "9999-12-31"),
]

positions_df = spark.createDataFrame(
    positions_data, ["emp_id", "department", "salary", "valid_from", "valid_to"]
)
positions_df = positions_df.withColumn("valid_from", F.to_date("valid_from")) \
                           .withColumn("valid_to", F.to_date("valid_to"))
positions_df.createOrReplaceTempView("positions")

# Exchange rates with validity periods
rates_data = [
    ("USD", "EUR", 0.85, "2023-01-01", "2023-06-30"),
    ("USD", "EUR", 0.92, "2023-07-01", "2023-12-31"),
    ("USD", "EUR", 0.88, "2024-01-01", "9999-12-31"),
    ("USD", "GBP", 0.79, "2023-01-01", "2023-12-31"),
    ("USD", "GBP", 0.81, "2024-01-01", "9999-12-31"),
]

rates_df = spark.createDataFrame(
    rates_data, ["from_currency", "to_currency", "rate", "valid_from", "valid_to"]
)
rates_df = rates_df.withColumn("valid_from", F.to_date("valid_from")) \
                   .withColumn("valid_to", F.to_date("valid_to"))
rates_df.createOrReplaceTempView("exchange_rates")

# Transactions
txn_data = [
    (1, "E001", "2023-02-15", 1000, "USD"),
    (2, "E001", "2023-08-20", 2000, "USD"),
    (3, "E002", "2024-03-10", 1500, "USD"),
]

txn_df = spark.createDataFrame(txn_data, ["txn_id", "emp_id", "txn_date", "amount", "currency"])
txn_df = txn_df.withColumn("txn_date", F.to_date("txn_date"))
txn_df.createOrReplaceTempView("transactions")

# --- Temporal join: get employee department at time of transaction ---
emp_at_txn_time = spark.sql("""
    SELECT
        t.txn_id,
        t.emp_id,
        t.txn_date,
        t.amount,
        p.department,
        p.salary AS salary_at_time
    FROM transactions t
    JOIN positions p
        ON t.emp_id = p.emp_id
        AND t.txn_date BETWEEN p.valid_from AND p.valid_to
    ORDER BY t.txn_id
""")

print("=== Employee Department at Transaction Time ===")
emp_at_txn_time.show()

# --- Temporal join: convert amount using exchange rate valid at txn date ---
converted = spark.sql("""
    SELECT
        t.txn_id,
        t.txn_date,
        t.amount AS amount_usd,
        r.rate,
        ROUND(t.amount * r.rate, 2) AS amount_eur
    FROM transactions t
    JOIN exchange_rates r
        ON r.from_currency = 'USD'
        AND r.to_currency = 'EUR'
        AND t.txn_date BETWEEN r.valid_from AND r.valid_to
""")

print("=== Transactions Converted with Temporal Exchange Rates ===")
converted.show()

# --- Detect overlapping validity periods (data quality check) ---
overlaps = spark.sql("""
    SELECT
        a.emp_id,
        a.valid_from AS period_a_from,
        a.valid_to AS period_a_to,
        b.valid_from AS period_b_from,
        b.valid_to AS period_b_to
    FROM positions a
    JOIN positions b
        ON a.emp_id = b.emp_id
        AND a.valid_from < b.valid_from
        AND a.valid_to >= b.valid_from
""")

print("=== Overlapping Validity Periods (Data Quality Issue) ===")
overlaps.show()

# --- Timeline aggregation: total salary cost per month ---
monthly_cost = spark.sql("""
    WITH months AS (
        SELECT explode(sequence(
            DATE '2023-01-01',
            DATE '2024-06-01',
            INTERVAL 1 MONTH
        )) AS month_start
    )
    SELECT
        m.month_start,
        COUNT(DISTINCT p.emp_id) AS active_employees,
        SUM(p.salary) AS total_annual_salary_basis
    FROM months m
    JOIN positions p
        ON m.month_start BETWEEN p.valid_from AND p.valid_to
    GROUP BY m.month_start
    ORDER BY m.month_start
""")

print("=== Monthly Active Employees and Salary Basis ===")
monthly_cost.show(20)

spark.stop()
```

## Key Concepts

- **Point-in-Time Query**: `WHERE valid_from <= query_date AND valid_to >= query_date`. The most basic temporal query pattern.
- **Range Overlap**: Two intervals [A_start, A_end] and [B_start, B_end] overlap if `A_start <= B_end AND A_end >= B_start`.
- **Temporal Join**: Joining a fact table (with an event date) to a dimension table (with validity periods) using the BETWEEN condition.
- **Gap Detection**: Use `LAG(valid_to)` to compare the previous record's end date with the current record's start date. If `valid_from - prev_valid_to > 1 day`, there is a gap.
- **Overlap Detection**: Self-join where `a.valid_from < b.valid_from AND a.valid_to >= b.valid_from` finds overlapping periods for the same entity.
- **Open-Ended Periods**: Use a far-future date like `9999-12-31` to represent currently active records (no known end date).

## Interview Tips

- Always clarify whether validity bounds are **inclusive or exclusive** (e.g., does valid_to = '2024-01-31' mean the record is valid on Jan 31 or only up to Jan 30?).
- Mention **bitemporal modeling**: tracks both when a fact was true in the real world (valid_from/valid_to) and when it was recorded in the system (transaction_time).
- For performance, **partition temporal tables by date** so point-in-time queries benefit from partition pruning.
- Discuss how this pattern is used in **SCD Type 2** implementations and **Delta Lake time travel**.
- In Spark, temporal joins without bucketing or broadcast can cause cartesian-like behavior -- mention the importance of adding additional join predicates beyond just the BETWEEN.
