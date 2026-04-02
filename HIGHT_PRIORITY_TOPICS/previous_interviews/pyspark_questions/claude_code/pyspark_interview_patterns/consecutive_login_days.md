# PySpark Implementation: Finding Consecutive Login Days (Islands and Gaps)

## Problem Statement 

Given a dataset of user login dates, find the **longest streak of consecutive login days** for each user. This is a classic "Islands and Gaps" problem that frequently appears in data engineering and SQL interviews. It tests your ability to work with window functions and date arithmetic.

### Sample Data

```
user_id  login_date
U001     2025-01-01
U001     2025-01-02
U001     2025-01-03
U001     2025-01-05
U001     2025-01-06
U001     2025-01-10
U002     2025-01-01
U002     2025-01-02
U002     2025-01-04
U002     2025-01-05
U002     2025-01-06
U002     2025-01-07
```

### Expected Output

| user_id | streak_start | streak_end | consecutive_days |
|---------|-------------|------------|------------------|
| U001    | 2025-01-01  | 2025-01-03 | 3                |
| U001    | 2025-01-05  | 2025-01-06 | 2                |
| U001    | 2025-01-10  | 2025-01-10 | 1                |
| U002    | 2025-01-01  | 2025-01-02 | 2                |
| U002    | 2025-01-04  | 2025-01-07 | 4                |

### Longest Streak Per User

| user_id | longest_streak |
|---------|---------------|
| U001    | 3             |
| U002    | 4             |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, row_number, date_sub, min as spark_min, \
    max as spark_max, datediff, count
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("ConsecutiveLoginDays").getOrCreate()

# Sample data
data = [
    ("U001", "2025-01-01"),
    ("U001", "2025-01-02"),
    ("U001", "2025-01-03"),
    ("U001", "2025-01-05"),
    ("U001", "2025-01-06"),
    ("U001", "2025-01-10"),
    ("U002", "2025-01-01"),
    ("U002", "2025-01-02"),
    ("U002", "2025-01-04"),
    ("U002", "2025-01-05"),
    ("U002", "2025-01-06"),
    ("U002", "2025-01-07")
]

columns = ["user_id", "login_date"]
df = spark.createDataFrame(data, columns)

# Convert to date type and remove duplicate login dates
df = df.withColumn("login_date", to_date(col("login_date"))) \
       .dropDuplicates(["user_id", "login_date"])

# Step 1: Assign row numbers per user ordered by date
window_rn = Window.partitionBy("user_id").orderBy("login_date")
df_rn = df.withColumn("rn", row_number().over(window_rn))

# Step 2: Compute group_date = login_date - row_number (the "islands" trick)
# Consecutive dates will produce the same group_date
df_grouped = df_rn.withColumn("group_date", date_sub(col("login_date"), col("rn")))

# Step 3: Group by user_id and group_date to find each streak
streaks = df_grouped.groupBy("user_id", "group_date").agg(
    spark_min("login_date").alias("streak_start"),
    spark_max("login_date").alias("streak_end"),
    count("*").alias("consecutive_days")
).drop("group_date")

# Show all streaks
streaks.orderBy("user_id", "streak_start").show()

# Step 4: Find the longest streak per user
longest = streaks.groupBy("user_id").agg(
    spark_max("consecutive_days").alias("longest_streak")
)

longest.show()
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Assign Row Numbers

- **What happens:** For each user, assign a sequential row number ordered by `login_date`.
- **Output (df_rn):**

  | user_id | login_date | rn |
  |---------|------------|----|
  | U001    | 2025-01-01 | 1  |
  | U001    | 2025-01-02 | 2  |
  | U001    | 2025-01-03 | 3  |
  | U001    | 2025-01-05 | 4  |
  | U001    | 2025-01-06 | 5  |
  | U001    | 2025-01-10 | 6  |
  | U002    | 2025-01-01 | 1  |
  | U002    | 2025-01-02 | 2  |
  | U002    | 2025-01-04 | 3  |
  | U002    | 2025-01-05 | 4  |
  | U002    | 2025-01-06 | 5  |
  | U002    | 2025-01-07 | 6  |

### Step 2: Compute group_date (The Core Trick)

- **What happens:** Subtracts the row number (in days) from the login_date. If dates are consecutive, `login_date - rn` produces the **same date** — this identifies the "island" (consecutive group).
- **Why this works:** Consecutive dates increase by 1 each day. Row numbers also increase by 1. So `date - rn` is constant for consecutive sequences.
- **Output (df_grouped):**

  | user_id | login_date | rn | group_date |
  |---------|------------|----|------------|
  | U001    | 2025-01-01 | 1  | 2024-12-31 |
  | U001    | 2025-01-02 | 2  | 2024-12-31 |
  | U001    | 2025-01-03 | 3  | 2024-12-31 |
  | U001    | 2025-01-05 | 4  | 2025-01-01 |
  | U001    | 2025-01-06 | 5  | 2025-01-01 |
  | U001    | 2025-01-10 | 6  | 2025-01-04 |
  | U002    | 2025-01-01 | 1  | 2024-12-31 |
  | U002    | 2025-01-02 | 2  | 2024-12-31 |
  | U002    | 2025-01-04 | 3  | 2025-01-01 |
  | U002    | 2025-01-05 | 4  | 2025-01-01 |
  | U002    | 2025-01-06 | 5  | 2025-01-01 |
  | U002    | 2025-01-07 | 6  | 2025-01-01 |

  Notice how:
  - U001's first 3 logins (Jan 1-3) all have `group_date = 2024-12-31` → one streak
  - U001's next 2 logins (Jan 5-6) both have `group_date = 2025-01-01` → another streak
  - U001's Jan 10 has a unique `group_date = 2025-01-04` → single-day streak
  - U002's Jan 4-7 all share `group_date = 2025-01-01` → a 4-day streak

### Step 3: Group by Islands to Get Streaks

- **What happens:** Groups by `user_id` and `group_date` to compute start, end, and length of each streak.
- **Output (streaks):**

  | user_id | streak_start | streak_end | consecutive_days |
  |---------|-------------|------------|------------------|
  | U001    | 2025-01-01  | 2025-01-03 | 3                |
  | U001    | 2025-01-05  | 2025-01-06 | 2                |
  | U001    | 2025-01-10  | 2025-01-10 | 1                |
  | U002    | 2025-01-01  | 2025-01-02 | 2                |
  | U002    | 2025-01-04  | 2025-01-07 | 4                |

### Step 4: Longest Streak Per User

- **What happens:** Simple aggregation to find the max consecutive_days per user.
- **Output (longest):**

  | user_id | longest_streak |
  |---------|---------------|
  | U001    | 3             |
  | U002    | 4             |

---

## Alternative: Using lag() Approach

```python
from pyspark.sql.functions import lag, sum as spark_sum, when

# Define window
window = Window.partitionBy("user_id").orderBy("login_date")

# Flag where a new streak starts (gap > 1 day from previous login)
df_flag = df.withColumn("prev_date", lag("login_date").over(window)) \
    .withColumn("new_streak",
        when(
            datediff(col("login_date"), col("prev_date")) > 1, 1
        ).otherwise(0)
    )

# Create streak_id using cumulative sum of new_streak flags
df_streaks = df_flag.withColumn(
    "streak_id",
    spark_sum("new_streak").over(window)
)

# Group by user_id and streak_id
streaks_alt = df_streaks.groupBy("user_id", "streak_id").agg(
    spark_min("login_date").alias("streak_start"),
    spark_max("login_date").alias("streak_end"),
    count("*").alias("consecutive_days")
).drop("streak_id")

streaks_alt.orderBy("user_id", "streak_start").show()
```

---

## Key Interview Talking Points

1. **The "date minus row_number" trick:** This is the most elegant solution. When dates are consecutive, subtracting a sequential row number produces the same result — identifying the "island."

2. **Why deduplicate first?** If a user logs in multiple times on the same day, it would break the consecutive logic. Always `dropDuplicates(["user_id", "login_date"])` first.

3. **Two approaches:**
   - **date_sub + row_number:** Cleaner, fewer steps, works well for daily granularity.
   - **lag + cumulative sum:** More flexible — works for non-daily intervals (e.g., consecutive weeks, hours with a threshold).

4. **Real-world applications:**
   - Gaming: Login streaks for rewards
   - E-commerce: Consecutive purchase days
   - Healthcare: Consecutive days of medication adherence
   - Finance: Consecutive days of positive returns
