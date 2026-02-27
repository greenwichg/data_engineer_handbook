# PySpark Implementation: Range Joins and Temporal Joins

## Problem Statement

Given two datasets — **events** with timestamps and **promotional periods** with start/end dates — join each event to the promotional period that was active at the time of the event. This is a **range join** (also called a temporal join or interval join) where the join condition involves a range check: `event_date BETWEEN promo_start AND promo_end`. This is commonly asked in interviews for ad-tech, finance, and IoT companies.

### Sample Data

**Events:**
```
event_id  user_id  event_date   purchase_amount
E001      U001     2025-01-05   100
E002      U001     2025-01-15   250
E003      U002     2025-01-08   75
E004      U002     2025-01-25   300
E005      U003     2025-02-10   200
```

**Promotions:**
```
promo_id  promo_name       start_date  end_date
P001      New Year Sale    2025-01-01  2025-01-10
P002      Winter Clearance 2025-01-11  2025-01-20
P003      Flash Deal       2025-01-07  2025-01-09
P004      Feb Special      2025-02-01  2025-02-15
```

### Expected Output

| event_id | user_id | event_date | purchase_amount | promo_id | promo_name       |
|----------|---------|------------|-----------------|----------|------------------|
| E001     | U001    | 2025-01-05 | 100             | P001     | New Year Sale    |
| E002     | U001    | 2025-01-15 | 250             | P002     | Winter Clearance |
| E003     | U002    | 2025-01-08 | 75              | P001     | New Year Sale    |
| E003     | U002    | 2025-01-08 | 75              | P003     | Flash Deal       |
| E004     | U002    | 2025-01-25 | 300             | null     | null             |
| E005     | U003    | 2025-02-10 | 200             | P004     | Feb Special      |

**Note:** E003 matches two promotions (overlapping ranges). E004 has no active promotion.

---

## Method 1: Range Join with Between Condition

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date

# Initialize Spark session
spark = SparkSession.builder.appName("RangeJoin").getOrCreate()

# Events data
events_data = [
    ("E001", "U001", "2025-01-05", 100),
    ("E002", "U001", "2025-01-15", 250),
    ("E003", "U002", "2025-01-08", 75),
    ("E004", "U002", "2025-01-25", 300),
    ("E005", "U003", "2025-02-10", 200)
]
events_df = spark.createDataFrame(events_data,
    ["event_id", "user_id", "event_date", "purchase_amount"])
events_df = events_df.withColumn("event_date", to_date(col("event_date")))

# Promotions data
promos_data = [
    ("P001", "New Year Sale", "2025-01-01", "2025-01-10"),
    ("P002", "Winter Clearance", "2025-01-11", "2025-01-20"),
    ("P003", "Flash Deal", "2025-01-07", "2025-01-09"),
    ("P004", "Feb Special", "2025-02-01", "2025-02-15")
]
promos_df = spark.createDataFrame(promos_data,
    ["promo_id", "promo_name", "start_date", "end_date"])
promos_df = promos_df.withColumn("start_date", to_date(col("start_date"))) \
                     .withColumn("end_date", to_date(col("end_date")))

# Range join: event_date between promo start_date and end_date
result = events_df.join(
    promos_df,
    (events_df.event_date >= promos_df.start_date) &
    (events_df.event_date <= promos_df.end_date),
    "left"
)

result.select("event_id", "user_id", "event_date", "purchase_amount",
              "promo_id", "promo_name") \
    .orderBy("event_id", "promo_id").show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: The Join Condition
- **What happens:** For each event, Spark checks all promotions to find where `event_date >= start_date AND event_date <= end_date`.
- This is a **cross join followed by filter** (Cartesian product) — potentially expensive.

#### Step 2: Output

  | event_id | user_id | event_date | purchase_amount | promo_id | promo_name       |
  |----------|---------|------------|-----------------|----------|------------------|
  | E001     | U001    | 2025-01-05 | 100             | P001     | New Year Sale    |
  | E002     | U001    | 2025-01-15 | 250             | P002     | Winter Clearance |
  | E003     | U002    | 2025-01-08 | 75              | P001     | New Year Sale    |
  | E003     | U002    | 2025-01-08 | 75              | P003     | Flash Deal       |
  | E004     | U002    | 2025-01-25 | 300             | null     | null             |
  | E005     | U003    | 2025-02-10 | 200             | P004     | Feb Special      |

  **Key observations:**
  - E003 (Jan 08) matches both P001 (Jan 01-10) and P003 (Jan 07-09) → two rows
  - E004 (Jan 25) has no matching promo → null values (left join)

---

## Method 2: Optimized Range Join with Broadcast

```python
from pyspark.sql.functions import broadcast

# If promotions table is small, broadcast it to avoid shuffle
result_broadcast = events_df.join(
    broadcast(promos_df),
    (events_df.event_date >= promos_df.start_date) &
    (events_df.event_date <= promos_df.end_date),
    "left"
)

result_broadcast.select("event_id", "user_id", "event_date",
                        "purchase_amount", "promo_id", "promo_name") \
    .orderBy("event_id").show(truncate=False)
```

- **Why broadcast?** Range joins can't use sort-merge join (no equality condition). Spark defaults to a broadcast nested loop join or Cartesian product. Broadcasting the smaller table is critical for performance.

---

## Method 3: Effective-Dated Join (SCD Lookup)

A common variant: join a fact table to a dimension table where each dimension record has an effective date range.

```python
# Dimension table with effective dates (like SCD Type 2)
dim_data = [
    ("C001", "Gold", "2024-01-01", "2024-12-31"),
    ("C001", "Platinum", "2025-01-01", "9999-12-31"),
    ("C002", "Silver", "2024-06-01", "9999-12-31")
]
dim_df = spark.createDataFrame(dim_data,
    ["customer_id", "tier", "eff_start", "eff_end"])
dim_df = dim_df.withColumn("eff_start", to_date(col("eff_start"))) \
               .withColumn("eff_end", to_date(col("eff_end")))

# Fact table with transaction dates
fact_data = [
    ("T001", "C001", "2024-06-15", 500),
    ("T002", "C001", "2025-03-10", 800),
    ("T003", "C002", "2025-01-05", 300)
]
fact_df = spark.createDataFrame(fact_data,
    ["txn_id", "customer_id", "txn_date", "amount"])
fact_df = fact_df.withColumn("txn_date", to_date(col("txn_date")))

# Effective-dated join: find the tier active at transaction time
enriched = fact_df.join(
    dim_df,
    (fact_df.customer_id == dim_df.customer_id) &
    (fact_df.txn_date >= dim_df.eff_start) &
    (fact_df.txn_date <= dim_df.eff_end),
    "left"
).select(
    fact_df.txn_id, fact_df.customer_id, fact_df.txn_date,
    fact_df.amount, dim_df.tier
)

enriched.show(truncate=False)
```

- **Output:**

  | txn_id | customer_id | txn_date   | amount | tier     |
  |--------|-------------|------------|--------|----------|
  | T001   | C001        | 2024-06-15 | 500    | Gold     |
  | T002   | C001        | 2025-03-10 | 800    | Platinum |
  | T003   | C002        | 2025-01-05 | 300    | Silver   |

  C001 was Gold in June 2024, but Platinum by March 2025.

---

## Method 4: Closest Match Join (Nearest Timestamp)

```python
from pyspark.sql.functions import abs as spark_abs, datediff, row_number, desc
from pyspark.sql.window import Window

# Find the closest promotion to each event (even if not within range)
cross = events_df.crossJoin(promos_df)

cross_with_dist = cross.withColumn(
    "days_diff",
    spark_abs(datediff(col("event_date"), col("start_date")))
)

# Window to pick closest promotion per event
window_closest = Window.partitionBy("event_id").orderBy("days_diff")

closest = cross_with_dist.withColumn("rn", row_number().over(window_closest)) \
    .filter(col("rn") == 1) \
    .drop("rn", "days_diff")

closest.select("event_id", "event_date", "promo_id", "promo_name").show()
```

- **Use case:** When you need the nearest match even if there's no exact overlap (e.g., nearest weather station, closest price quote).

---

## Method 5: Using SQL

```python
events_df.createOrReplaceTempView("events")
promos_df.createOrReplaceTempView("promotions")

range_join_sql = spark.sql("""
    SELECT
        e.event_id,
        e.user_id,
        e.event_date,
        e.purchase_amount,
        p.promo_id,
        p.promo_name
    FROM events e
    LEFT JOIN promotions p
        ON e.event_date BETWEEN p.start_date AND p.end_date
    ORDER BY e.event_id
""")

range_join_sql.show(truncate=False)
```

---

## Performance Considerations

| Strategy | When to Use | Performance |
|----------|-------------|-------------|
| Broadcast + range condition | Small lookup table (< 10MB) | Good — avoids shuffle |
| Bucketed join on equality + range | Has equality key + range | Best — reduces comparisons |
| Bin/bucket dates then join | Very large tables | Good — reduces Cartesian |

### Optimization: Binning Dates to Reduce Cartesian Product

```python
from pyspark.sql.functions import date_format, month, year

# Add a coarse date bin (month) to both tables
events_binned = events_df.withColumn("event_month", date_format("event_date", "yyyy-MM"))
promos_binned = promos_df.withColumn("start_month", date_format("start_date", "yyyy-MM"))

# Join on month equality first (reduces Cartesian), then filter on exact range
result_binned = events_binned.join(
    promos_binned,
    (events_binned.event_month == promos_binned.start_month) &
    (events_binned.event_date >= promos_binned.start_date) &
    (events_binned.event_date <= promos_binned.end_date),
    "left"
)
```

- **Caveat:** This misses promotions that span month boundaries. Handle by adding overlapping bins or using UNION of multiple month matches.

---

## Key Interview Talking Points

1. **Why range joins are expensive:** No equality condition means Spark can't use hash join or sort-merge join. It falls back to broadcast nested loop join or Cartesian product + filter.

2. **Always broadcast the smaller table:** This converts the Cartesian product to a much smaller operation performed locally on each executor.

3. **Handling overlapping ranges:** One event may match multiple ranges (E003 matched two promos). Decide if you want:
   - All matches (default)
   - First/last match (use `row_number()` to pick one)
   - Prioritized match (add priority column to the range table)

4. **Common real-world scenarios:**
   - Ad attribution: Which campaign was active when the click happened?
   - Price lookup: What was the price at the time of the order?
   - Employee reporting: Who was the manager on a specific date?
   - IoT: Which maintenance window was active during the sensor alert?

5. **Delta Lake optimization:** For large-scale temporal joins, use Z-ordering on the date columns in Delta Lake to co-locate relevant data.
