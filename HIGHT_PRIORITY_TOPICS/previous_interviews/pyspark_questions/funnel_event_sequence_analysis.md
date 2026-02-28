# PySpark Implementation: Funnel and Event Sequence Analysis

## Problem Statement

Given a clickstream dataset of user page visits, build a **conversion funnel** to determine how many users completed each step of a multi-step process in order: **Home → Product → Cart → Checkout**. Identify where users drop off and calculate conversion rates between each step. This is a very common question at tech companies (e-commerce, SaaS, ad-tech).

### Sample Data

```
user_id  page       event_time
U001     Home       2025-01-15 10:00:00
U001     Product    2025-01-15 10:05:00
U001     Cart       2025-01-15 10:10:00
U001     Checkout   2025-01-15 10:15:00
U002     Home       2025-01-15 11:00:00
U002     Product    2025-01-15 11:05:00
U002     Home       2025-01-15 11:10:00
U003     Home       2025-01-15 12:00:00
U003     Product    2025-01-15 12:03:00
U003     Cart       2025-01-15 12:08:00
U004     Product    2025-01-15 13:00:00
U004     Cart       2025-01-15 13:05:00
U004     Checkout   2025-01-15 13:10:00
U005     Home       2025-01-15 14:00:00
```

### Expected Output (Funnel)

| step | page     | users_reached | conversion_rate | drop_off_rate |
|------|----------|---------------|-----------------|---------------|
| 1    | Home     | 4             | 100.0%          | 0.0%          |
| 2    | Product  | 3             | 75.0%           | 25.0%         |
| 3    | Cart     | 2             | 50.0%           | 25.0%         |
| 4    | Checkout | 1             | 25.0%           | 25.0%         |

(U004 is excluded — started at Product, didn't visit Home first. U005 only visited Home.)

---

## Method 1: Sequential Funnel Using Window Functions

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp, collect_list, struct, udf, \
    countDistinct, lit, round as spark_round, array_contains
from pyspark.sql.types import BooleanType, ArrayType, StringType
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("FunnelAnalysis").getOrCreate()

# Sample data
data = [
    ("U001", "Home", "2025-01-15 10:00:00"),
    ("U001", "Product", "2025-01-15 10:05:00"),
    ("U001", "Cart", "2025-01-15 10:10:00"),
    ("U001", "Checkout", "2025-01-15 10:15:00"),
    ("U002", "Home", "2025-01-15 11:00:00"),
    ("U002", "Product", "2025-01-15 11:05:00"),
    ("U002", "Home", "2025-01-15 11:10:00"),
    ("U003", "Home", "2025-01-15 12:00:00"),
    ("U003", "Product", "2025-01-15 12:03:00"),
    ("U003", "Cart", "2025-01-15 12:08:00"),
    ("U004", "Product", "2025-01-15 13:00:00"),
    ("U004", "Cart", "2025-01-15 13:05:00"),
    ("U004", "Checkout", "2025-01-15 13:10:00"),
    ("U005", "Home", "2025-01-15 14:00:00")
]
columns = ["user_id", "page", "event_time"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("event_time", to_timestamp(col("event_time")))

# Define funnel steps
funnel_steps = ["Home", "Product", "Cart", "Checkout"]

# Step 1: Collect ordered page sequence per user
window_user = Window.partitionBy("user_id").orderBy("event_time")

user_sequences = df.groupBy("user_id").agg(
    collect_list(struct("event_time", "page")).alias("events")
)

# Sort events within each user (collect_list doesn't guarantee order)
from pyspark.sql.functions import sort_array
user_sequences = df.orderBy("user_id", "event_time") \
    .groupBy("user_id") \
    .agg(collect_list("page").alias("page_sequence"))

# Step 2: Check if each user completed the funnel steps in order
@udf(BooleanType())
def completed_step_in_order(pages, step_index):
    """Check if user visited funnel steps 0..step_index in order."""
    steps = ["Home", "Product", "Cart", "Checkout"]
    current_step = 0
    for page in pages:
        if current_step <= step_index and page == steps[current_step]:
            current_step += 1
            if current_step > step_index:
                return True
    return False

# Step 3: For each funnel step, count users who reached it in order
funnel_results = []
total_users_at_step1 = None

for i, step in enumerate(funnel_steps):
    users_at_step = user_sequences.filter(
        completed_step_in_order(col("page_sequence"), lit(i))
    ).count()

    if i == 0:
        total_users_at_step1 = users_at_step

    funnel_results.append((i + 1, step, users_at_step))

# Create funnel DataFrame
funnel_df = spark.createDataFrame(funnel_results, ["step", "page", "users_reached"])
funnel_df = funnel_df.withColumn(
    "conversion_rate",
    spark_round(col("users_reached") / lit(total_users_at_step1) * 100, 1)
)

funnel_df.show(truncate=False)
```

### Output

| step | page     | users_reached | conversion_rate |
|------|----------|---------------|-----------------|
| 1    | Home     | 4             | 100.0           |
| 2    | Product  | 3             | 75.0            |
| 3    | Cart     | 2             | 50.0            |
| 4    | Checkout | 1             | 25.0            |

### Why Each User Did/Didn't Convert

| User | Pages Visited (in order) | Reached Step |
|------|--------------------------|-------------|
| U001 | Home → Product → Cart → Checkout | Checkout (all 4) |
| U002 | Home → Product → Home | Product (step 2) |
| U003 | Home → Product → Cart | Cart (step 3) |
| U004 | Product → Cart → Checkout | Excluded (no Home first) |
| U005 | Home | Home (step 1) |

---

## Method 2: SQL-Based Funnel (Simpler, No UDF)

```python
df.createOrReplaceTempView("events")

# Get min timestamp for each page per user
spark.sql("""
    CREATE OR REPLACE TEMP VIEW user_page_times AS
    SELECT user_id, page, MIN(event_time) AS first_visit
    FROM events
    GROUP BY user_id, page
""")

# Build funnel with sequential time checks
funnel_sql = spark.sql("""
    WITH step1 AS (
        SELECT user_id, first_visit AS home_time
        FROM user_page_times WHERE page = 'Home'
    ),
    step2 AS (
        SELECT s1.user_id, s1.home_time, upt.first_visit AS product_time
        FROM step1 s1
        JOIN user_page_times upt
            ON s1.user_id = upt.user_id
            AND upt.page = 'Product'
            AND upt.first_visit > s1.home_time
    ),
    step3 AS (
        SELECT s2.user_id, s2.product_time, upt.first_visit AS cart_time
        FROM step2 s2
        JOIN user_page_times upt
            ON s2.user_id = upt.user_id
            AND upt.page = 'Cart'
            AND upt.first_visit > s2.product_time
    ),
    step4 AS (
        SELECT s3.user_id, s3.cart_time, upt.first_visit AS checkout_time
        FROM step3 s3
        JOIN user_page_times upt
            ON s3.user_id = upt.user_id
            AND upt.page = 'Checkout'
            AND upt.first_visit > s3.cart_time
    )
    SELECT
        'Home' AS page, COUNT(DISTINCT user_id) AS users FROM step1
    UNION ALL
    SELECT 'Product', COUNT(DISTINCT user_id) FROM step2
    UNION ALL
    SELECT 'Cart', COUNT(DISTINCT user_id) FROM step3
    UNION ALL
    SELECT 'Checkout', COUNT(DISTINCT user_id) FROM step4
""")

funnel_sql.show(truncate=False)
```

### How the SQL Method Works

1. **step1:** Find all users who visited Home (with their first Home visit time)
2. **step2:** Of those, find who visited Product **after** Home
3. **step3:** Of those, find who visited Cart **after** Product
4. **step4:** Of those, find who visited Checkout **after** Cart

Each CTE narrows the funnel by requiring the next step happened **after** the previous one.

---

## Method 3: Step-by-Step Conversion with Drop-Off

```python
from pyspark.sql.functions import lag as spark_lag

# Add step-over-step conversion rate and drop-off
window_funnel = Window.orderBy("step")

funnel_analysis = funnel_df.withColumn(
    "prev_users", spark_lag("users_reached").over(window_funnel)
).withColumn(
    "step_conversion",
    spark_round(
        col("users_reached") / col("prev_users") * 100, 1
    )
).withColumn(
    "dropped_users",
    col("prev_users") - col("users_reached")
)

funnel_analysis.show(truncate=False)
```

- **Output:**

  | step | page     | users_reached | conversion_rate | prev_users | step_conversion | dropped_users |
  |------|----------|---------------|-----------------|------------|-----------------|---------------|
  | 1    | Home     | 4             | 100.0           | null       | null            | null          |
  | 2    | Product  | 3             | 75.0            | 4          | 75.0            | 1             |
  | 3    | Cart     | 2             | 50.0            | 3          | 66.7            | 1             |
  | 4    | Checkout | 1             | 25.0            | 2          | 50.0            | 1             |

  **Reading this:** 75% of Home visitors saw a Product. 66.7% of Product viewers added to Cart. 50% of Cart users completed Checkout. Overall: 25% end-to-end conversion.

---

## Variation: Time-Bounded Funnel

```python
# Only count conversions where the entire funnel completes within 30 minutes
from pyspark.sql.functions import unix_timestamp

spark.sql("""
    WITH step1 AS (
        SELECT user_id, MIN(event_time) AS home_time
        FROM events WHERE page = 'Home' GROUP BY user_id
    ),
    step4 AS (
        SELECT user_id, MIN(event_time) AS checkout_time
        FROM events WHERE page = 'Checkout' GROUP BY user_id
    )
    SELECT
        s1.user_id,
        s1.home_time,
        s4.checkout_time,
        (unix_timestamp(s4.checkout_time) - unix_timestamp(s1.home_time)) / 60 AS minutes_to_convert
    FROM step1 s1
    JOIN step4 s4 ON s1.user_id = s4.user_id
    WHERE s4.checkout_time > s1.home_time
      AND (unix_timestamp(s4.checkout_time) - unix_timestamp(s1.home_time)) <= 1800
""").show(truncate=False)
```

---

## Key Interview Talking Points

1. **Order matters in funnels:** A user visiting Cart → Home → Product → Checkout did NOT complete the funnel in order. The sequential check (`first_visit > previous_step_time`) is critical.

2. **First visit vs any visit:** Using `MIN(event_time)` per page gives the earliest visit. For strict funnels, you check if the first Product visit came after the first Home visit. For loose funnels, any Product visit after any Home visit counts.

3. **Strict vs loose funnel:**
   - **Strict:** Steps must happen consecutively (Home immediately followed by Product, no other pages in between)
   - **Loose:** Steps can have other pages between them (most common in practice)

4. **Performance:** The SQL CTE approach (Method 2) is efficient — it progressively narrows the user set at each step. The UDF approach (Method 1) requires collecting all pages per user, which can be memory-intensive.

5. **Real-world applications:**
   - E-commerce: Purchase conversion funnel
   - SaaS: Onboarding completion (signup → profile → first action → subscription)
   - Marketing: Ad impression → click → landing page → conversion
   - Mobile apps: Install → register → first purchase → repeat purchase
