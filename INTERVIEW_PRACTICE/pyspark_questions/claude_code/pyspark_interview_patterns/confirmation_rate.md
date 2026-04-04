# PySpark Implementation: Confirmation Rate

## Problem Statement

Given a `Signups` table and a `Confirmations` table, find the **confirmation rate** for each user. The confirmation rate is the number of `'confirmed'` messages divided by total messages. Users with no confirmation messages have a rate of 0. This is **LeetCode 1934 — Confirmation Rate**.

### Sample Data

```
Signups:
user_id  time_stamp
1        2025-01-01
2        2025-01-02
3        2025-01-03

Confirmations:
user_id  time_stamp           action
1        2025-01-01 10:00:00  confirmed
1        2025-01-01 11:00:00  timeout
2        2025-01-02 10:00:00  confirmed
2        2025-01-02 11:00:00  confirmed
```

### Expected Output

| user_id | confirmation_rate |
|---------|------------------|
| 1       | 0.50             |
| 2       | 1.00             |
| 3       | 0.00             |

---

## Method 1: Left Join + Conditional AVG (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, avg, round as spark_round, coalesce, lit

spark = SparkSession.builder.appName("ConfirmationRate").getOrCreate()

signups_data = [(1, "2025-01-01"), (2, "2025-01-02"), (3, "2025-01-03")]
signups = spark.createDataFrame(signups_data, ["user_id", "time_stamp"])

confirmations_data = [
    (1, "2025-01-01 10:00:00", "confirmed"),
    (1, "2025-01-01 11:00:00", "timeout"),
    (2, "2025-01-02 10:00:00", "confirmed"),
    (2, "2025-01-02 11:00:00", "confirmed")
]
confirmations = spark.createDataFrame(confirmations_data, ["user_id", "time_stamp", "action"])

# Left join signups with confirmations
result = signups.join(confirmations.drop("time_stamp"), on="user_id", how="left") \
    .groupBy("user_id") \
    .agg(
        spark_round(
            coalesce(
                avg(when(col("action") == "confirmed", 1).otherwise(0)),
                lit(0)
            ),
            2
        ).alias("confirmation_rate")
    ).orderBy("user_id")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Left join signups with confirmations
- **What happens:** Every user from signups is preserved. Users with no confirmations get NULLs.

  | user_id | action    |
  |---------|-----------|
  | 1       | confirmed |
  | 1       | timeout   |
  | 2       | confirmed |
  | 2       | confirmed |
  | 3       | null      |

#### Step 2: Conditional AVG
- **What happens:** `WHEN action = 'confirmed' THEN 1 ELSE 0` converts to binary, then AVG gives the rate.
- User 1: (1+0)/2 = 0.50
- User 2: (1+1)/2 = 1.00
- User 3: AVG of NULL action → need COALESCE to handle

#### Step 3: Handle users with no confirmations
- User 3 has only NULL action. `when(NULL == 'confirmed', 1).otherwise(0)` returns 0. So AVG = 0.

---

## Method 2: Count-Based Approach

```python
from pyspark.sql.functions import col, count, sum as spark_sum, when, round as spark_round, coalesce, lit

result = signups.join(confirmations.drop("time_stamp"), on="user_id", how="left") \
    .groupBy("user_id") \
    .agg(
        spark_round(
            coalesce(
                spark_sum(when(col("action") == "confirmed", 1).otherwise(0)) /
                count(col("action")),
                lit(0)
            ),
            2
        ).alias("confirmation_rate")
    ).orderBy("user_id")

result.show()
```

**Note:** `count(col("action"))` counts non-NULL actions, so users with no confirmations get 0/0. COALESCE handles the division by zero.

---

## Method 3: Spark SQL

```python
signups.createOrReplaceTempView("signups")
confirmations.createOrReplaceTempView("confirmations")

result = spark.sql("""
    SELECT
        s.user_id,
        ROUND(
            COALESCE(
                AVG(CASE WHEN c.action = 'confirmed' THEN 1.0 ELSE 0.0 END),
                0
            ),
            2
        ) AS confirmation_rate
    FROM signups s
    LEFT JOIN confirmations c ON s.user_id = c.user_id
    GROUP BY s.user_id
    ORDER BY s.user_id
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| User with no confirmation messages | LEFT JOIN produces NULLs | COALESCE result to 0 |
| All messages are 'timeout' | AVG of all 0s = 0.00 | Correct behavior |
| All messages are 'confirmed' | AVG of all 1s = 1.00 | Correct behavior |
| User not in signups but in confirmations | Ignored (LEFT JOIN from signups) | Correct — signups is the master |

## Key Interview Talking Points

1. **AVG(CASE WHEN) pattern:**
   - This is the standard SQL idiom for computing a conditional rate. `AVG(0s and 1s)` = proportion of 1s.

2. **LEFT JOIN importance:**
   - Must use LEFT from signups to include users with zero confirmations. INNER JOIN would miss them.

3. **COALESCE for zero-activity users:**
   - Users with no confirmations have NULL aggregation results. COALESCE(NULL, 0) = 0.

4. **count(col) vs. count(*):**
   - `count(col("action"))` ignores NULLs — gives correct denominator.
   - `count("*")` counts all rows including NULL-action rows — would give 1 for user 3 (the NULL left-join row).

5. **Pattern generalization:**
   - Confirmation rate = conversion rate = success rate. Same pattern applies to email open rates, click-through rates, test pass rates, etc.
