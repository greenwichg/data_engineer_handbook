# PySpark Implementation: A/B Test Analysis

## Problem Statement 

A/B testing is fundamental to data-driven decision making. Given experiment data with user assignments to control/treatment groups and their conversion outcomes, compute conversion rates, statistical significance, and lift. This is a common interview question for data engineering roles at companies like Netflix, Airbnb, and Meta, where experimentation platforms are critical infrastructure.

You need to:
1. Calculate conversion rates per variant
2. Compute the lift (relative improvement) of treatment over control
3. Assess statistical significance using Z-test for proportions
4. Segment results by user attributes (e.g., device type)

### Sample Data

**Experiment Assignments:**

| user_id | variant   | device_type | signup_date |
|---------|-----------|-------------|-------------|
| 1       | control   | mobile      | 2024-01-01  |
| 2       | treatment | desktop     | 2024-01-01  |
| 3       | control   | mobile      | 2024-01-02  |
| 4       | treatment | mobile      | 2024-01-02  |
| 5       | control   | desktop     | 2024-01-03  |
| 6       | treatment | desktop     | 2024-01-03  |
| 7       | control   | mobile      | 2024-01-03  |
| 8       | treatment | mobile      | 2024-01-04  |
| 9       | control   | desktop     | 2024-01-04  |
| 10      | treatment | desktop     | 2024-01-04  |

**Conversion Events:**

| user_id | event_type | event_date  | revenue |
|---------|------------|-------------|---------|
| 1       | purchase   | 2024-01-05  | 25.00   |
| 2       | purchase   | 2024-01-04  | 45.00   |
| 4       | purchase   | 2024-01-06  | 30.00   |
| 6       | purchase   | 2024-01-07  | 55.00   |
| 8       | purchase   | 2024-01-08  | 35.00   |
| 10      | purchase   | 2024-01-09  | 60.00   |

### Expected Output

**Overall Results:**

| variant   | users | conversions | conversion_rate | avg_revenue |
|-----------|-------|-------------|-----------------|-------------|
| control   | 5     | 1           | 0.20            | 25.00       |
| treatment | 5     | 4           | 0.80            | 42.50       |

**Lift & Significance:**

| metric              | value  |
|---------------------|--------|
| lift                | 300.0% |
| z_score             | ~2.19  |
| p_value             | ~0.028 |
| statistically_significant | yes |

---

## Method 1: SQL-Based A/B Test Analysis

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    DateType, DoubleType
)
import math

# Initialize Spark
spark = SparkSession.builder \
    .appName("AB Test Analysis") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data Creation ---
assignments_data = [
    (1, "control", "mobile", "2024-01-01"),
    (2, "treatment", "desktop", "2024-01-01"),
    (3, "control", "mobile", "2024-01-02"),
    (4, "treatment", "mobile", "2024-01-02"),
    (5, "control", "desktop", "2024-01-03"),
    (6, "treatment", "desktop", "2024-01-03"),
    (7, "control", "mobile", "2024-01-03"),
    (8, "treatment", "mobile", "2024-01-04"),
    (9, "control", "desktop", "2024-01-04"),
    (10, "treatment", "desktop", "2024-01-04"),
]

assignments_df = spark.createDataFrame(
    assignments_data,
    ["user_id", "variant", "device_type", "signup_date"]
)

conversions_data = [
    (1, "purchase", "2024-01-05", 25.00),
    (2, "purchase", "2024-01-04", 45.00),
    (4, "purchase", "2024-01-06", 30.00),
    (6, "purchase", "2024-01-07", 55.00),
    (8, "purchase", "2024-01-08", 35.00),
    (10, "purchase", "2024-01-09", 60.00),
]

conversions_df = spark.createDataFrame(
    conversions_data,
    ["user_id", "event_type", "event_date", "revenue"]
)

# Register as temp views
assignments_df.createOrReplaceTempView("assignments")
conversions_df.createOrReplaceTempView("conversions")

# --- Overall conversion rates per variant ---
overall_results = spark.sql("""
    SELECT
        a.variant,
        COUNT(DISTINCT a.user_id) AS users,
        COUNT(DISTINCT c.user_id) AS conversions,
        ROUND(COUNT(DISTINCT c.user_id) / COUNT(DISTINCT a.user_id), 4) AS conversion_rate,
        ROUND(AVG(c.revenue), 2) AS avg_revenue
    FROM assignments a
    LEFT JOIN conversions c ON a.user_id = c.user_id
    GROUP BY a.variant
    ORDER BY a.variant
""")

print("=== Overall A/B Test Results ===")
overall_results.show()

# --- Compute lift and Z-test for proportions ---
stats = overall_results.collect()
control_row = [r for r in stats if r["variant"] == "control"][0]
treatment_row = [r for r in stats if r["variant"] == "treatment"][0]

n_c = control_row["users"]
x_c = control_row["conversions"]
p_c = control_row["conversion_rate"]

n_t = treatment_row["users"]
x_t = treatment_row["conversions"]
p_t = treatment_row["conversion_rate"]

# Lift
lift = (p_t - p_c) / p_c * 100 if p_c > 0 else float('inf')

# Pooled proportion for Z-test
p_pool = (x_c + x_t) / (n_c + n_t)
se = math.sqrt(p_pool * (1 - p_pool) * (1/n_c + 1/n_t))
z_score = (p_t - p_c) / se if se > 0 else 0

# Two-tailed p-value approximation using standard normal CDF
def normal_cdf(z):
    """Approximate the CDF of the standard normal distribution."""
    return 0.5 * (1 + math.erf(z / math.sqrt(2)))

p_value = 2 * (1 - normal_cdf(abs(z_score)))
significant = "yes" if p_value < 0.05 else "no"

print(f"=== Lift & Significance ===")
print(f"Lift: {lift:.1f}%")
print(f"Z-score: {z_score:.4f}")
print(f"P-value: {p_value:.4f}")
print(f"Statistically Significant (alpha=0.05): {significant}")

# --- Segmented results by device_type ---
segmented = spark.sql("""
    SELECT
        a.variant,
        a.device_type,
        COUNT(DISTINCT a.user_id) AS users,
        COUNT(DISTINCT c.user_id) AS conversions,
        ROUND(COUNT(DISTINCT c.user_id) / COUNT(DISTINCT a.user_id), 4) AS conversion_rate
    FROM assignments a
    LEFT JOIN conversions c ON a.user_id = c.user_id
    GROUP BY a.variant, a.device_type
    ORDER BY a.device_type, a.variant
""")

print("=== Segmented Results by Device Type ===")
segmented.show()
```

## Method 2: DataFrame API with UDF for Statistical Testing

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import DoubleType, StructType, StructField, StringType
import math

spark = SparkSession.builder \
    .appName("AB Test Analysis - DataFrame API") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
assignments_data = [
    (1, "control", "mobile"), (2, "treatment", "desktop"),
    (3, "control", "mobile"), (4, "treatment", "mobile"),
    (5, "control", "desktop"), (6, "treatment", "desktop"),
    (7, "control", "mobile"), (8, "treatment", "mobile"),
    (9, "control", "desktop"), (10, "treatment", "desktop"),
    (11, "control", "mobile"), (12, "treatment", "mobile"),
    (13, "control", "desktop"), (14, "treatment", "desktop"),
    (15, "control", "mobile"), (16, "treatment", "mobile"),
    (17, "control", "desktop"), (18, "treatment", "desktop"),
    (19, "control", "mobile"), (20, "treatment", "desktop"),
]

assignments_df = spark.createDataFrame(assignments_data, ["user_id", "variant", "device_type"])

conversions_data = [
    (1, 25.00), (2, 45.00), (4, 30.00), (6, 55.00),
    (8, 35.00), (10, 60.00), (12, 40.00), (14, 50.00),
    (16, 28.00), (18, 65.00), (20, 70.00),
]

conversions_df = spark.createDataFrame(conversions_data, ["user_id", "revenue"])

# --- Join and flag conversions ---
experiment_df = assignments_df.join(conversions_df, "user_id", "left") \
    .withColumn("converted", F.when(F.col("revenue").isNotNull(), 1).otherwise(0))

# --- Aggregate by variant ---
variant_stats = experiment_df.groupBy("variant").agg(
    F.count("user_id").alias("users"),
    F.sum("converted").alias("conversions"),
    F.round(F.mean("converted"), 4).alias("conversion_rate"),
    F.round(F.mean(F.when(F.col("converted") == 1, F.col("revenue"))), 2).alias("avg_revenue_per_converter"),
    F.round(F.sum(F.coalesce(F.col("revenue"), F.lit(0))) / F.count("user_id"), 2).alias("avg_revenue_per_user"),
)

print("=== Variant Statistics ===")
variant_stats.show()

# --- Cross-join control vs treatment for lift calculation ---
control_stats = variant_stats.filter(F.col("variant") == "control") \
    .select(
        F.col("users").alias("c_users"),
        F.col("conversions").alias("c_conv"),
        F.col("conversion_rate").alias("c_rate"),
    )

treatment_stats = variant_stats.filter(F.col("variant") == "treatment") \
    .select(
        F.col("users").alias("t_users"),
        F.col("conversions").alias("t_conv"),
        F.col("conversion_rate").alias("t_rate"),
    )

comparison = control_stats.crossJoin(treatment_stats)

# Calculate lift and pooled Z-test in DataFrame operations
comparison = comparison.withColumn(
    "lift_pct", F.round((F.col("t_rate") - F.col("c_rate")) / F.col("c_rate") * 100, 2)
).withColumn(
    "pooled_p",
    (F.col("c_conv") + F.col("t_conv")) / (F.col("c_users") + F.col("t_users"))
).withColumn(
    "standard_error",
    F.sqrt(
        F.col("pooled_p") * (1 - F.col("pooled_p")) *
        (1 / F.col("c_users") + 1 / F.col("t_users"))
    )
).withColumn(
    "z_score",
    F.round((F.col("t_rate") - F.col("c_rate")) / F.col("standard_error"), 4)
)

print("=== Comparison Metrics ===")
comparison.select("c_rate", "t_rate", "lift_pct", "z_score").show()

# --- Daily cumulative conversion rates to track experiment over time ---
experiment_with_day = experiment_df.withColumn(
    "day_bucket",
    F.when(F.col("user_id") <= 10, "day_1").otherwise("day_2")
)

daily_stats = experiment_with_day.groupBy("day_bucket", "variant").agg(
    F.count("user_id").alias("users"),
    F.sum("converted").alias("conversions"),
    F.round(F.mean("converted"), 4).alias("conversion_rate"),
)

print("=== Daily Breakdown ===")
daily_stats.orderBy("day_bucket", "variant").show()

spark.stop()
```

## Key Concepts

- **Conversion Rate**: The proportion of users who complete the desired action (purchases / total assigned users).
- **Lift**: Relative improvement of treatment over control: `(treatment_rate - control_rate) / control_rate * 100%`.
- **Z-Test for Proportions**: Uses the pooled proportion to compute a standard error, then calculates a Z-score. A |Z| > 1.96 indicates statistical significance at alpha = 0.05.
- **P-Value**: Probability of observing the result (or more extreme) under the null hypothesis of no difference.
- **Simpson's Paradox**: Always check segmented results -- a treatment that looks better overall may be worse in every segment if group sizes are unbalanced.
- **Sample Size**: Small samples lead to high variance in conversion rate estimates. In real interviews, mention minimum detectable effect (MDE) and power analysis.

## Interview Tips

- Always ask about the **randomization unit** (user-level vs session-level).
- Mention the need for **guardrail metrics** (e.g., ensuring the treatment doesn't degrade other KPIs).
- Discuss **novelty effects** and the importance of running experiments long enough.
- In PySpark at scale, you'd compute these metrics across millions of users -- emphasize that the Z-test formula works row-by-row in aggregations without needing to collect data to the driver.
