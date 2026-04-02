# PySpark Implementation: Friend Requests Acceptance Rate

## Problem Statement

Given a `FriendRequest` table (sender_id, send_to_id, request_date) and a `RequestAccepted` table (requester_id, accepter_id, accept_date), find the **acceptance rate** = accepted requests / total requests. Round to 2 decimal places. If no requests, return 0.00. This is **LeetCode 597 — Friend Requests I: Overall Acceptance Rate**.

### Sample Data

```
FriendRequest:
sender_id  send_to_id  request_date
1          2           2025-01-01
1          3           2025-01-02
2          3           2025-01-03
3          4           2025-01-04

RequestAccepted:
requester_id  accepter_id  accept_date
1             2            2025-01-05
1             3            2025-01-06
```

### Expected Output

| accept_rate |
|-------------|
| 0.50        |

**Explanation:** 4 distinct requests, 2 accepted → 2/4 = 0.50.

---

## Method 1: Distinct Count Ratio (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, countDistinct, round as spark_round, lit, coalesce, when

spark = SparkSession.builder.appName("FriendRequestRate").getOrCreate()

request_data = [
    (1, 2, "2025-01-01"),
    (1, 3, "2025-01-02"),
    (2, 3, "2025-01-03"),
    (3, 4, "2025-01-04")
]
friend_request = spark.createDataFrame(request_data, ["sender_id", "send_to_id", "request_date"])

accepted_data = [
    (1, 2, "2025-01-05"),
    (1, 3, "2025-01-06")
]
request_accepted = spark.createDataFrame(accepted_data, ["requester_id", "accepter_id", "accept_date"])

# Count distinct requests
total_requests = friend_request.select(
    countDistinct("sender_id", "send_to_id").alias("total")
).first()["total"]

# Count distinct accepted
total_accepted = request_accepted.select(
    countDistinct("requester_id", "accepter_id").alias("accepted")
).first()["accepted"]

# Calculate rate
if total_requests == 0:
    rate = 0.0
else:
    rate = round(total_accepted / total_requests, 2)

result = spark.createDataFrame([(rate,)], ["accept_rate"])
result.show()
```

---

## Method 2: Pure DataFrame (No collect)

```python
from pyspark.sql.functions import countDistinct, round as spark_round, coalesce, lit

total_df = friend_request.agg(
    countDistinct("sender_id", "send_to_id").alias("total_requests")
)

accepted_df = request_accepted.agg(
    countDistinct("requester_id", "accepter_id").alias("total_accepted")
)

result = total_df.crossJoin(accepted_df).select(
    spark_round(
        coalesce(col("total_accepted") / col("total_requests"), lit(0.0)),
        2
    ).alias("accept_rate")
)

result.show()
```

---

## Method 3: Spark SQL

```python
friend_request.createOrReplaceTempView("friend_request")
request_accepted.createOrReplaceTempView("request_accepted")

result = spark.sql("""
    SELECT ROUND(
        COALESCE(
            (SELECT COUNT(DISTINCT requester_id, accepter_id) FROM request_accepted) /
            NULLIF((SELECT COUNT(DISTINCT sender_id, send_to_id) FROM friend_request), 0),
            0.0
        ),
        2
    ) AS accept_rate
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| No requests at all | Division by zero | COALESCE + NULLIF(total, 0) → returns 0 |
| No accepted requests | 0 / total = 0.00 | Correct behavior |
| Duplicate requests (same pair) | countDistinct handles it | Only unique pairs counted |
| Accepted but not in request table | Still counts as accepted | Depends on problem definition |
| All requests accepted | Rate = 1.00 | Correct |

## Key Interview Talking Points

1. **Why COUNT(DISTINCT sender_id, send_to_id)?**
   - A pair (1,2) might have multiple request rows. We count unique pairs, not total rows.

2. **Division by zero:**
   - Use `NULLIF(denominator, 0)` to convert 0 → NULL, then COALESCE to default.
   - Or check with a conditional before dividing.

3. **Two-table ratio pattern:**
   - Numerator from one table, denominator from another.
   - Cross join single-value results to compute the ratio.
   - Appears in: conversion rates, success rates, completion rates.

4. **Follow-up: "Per-sender acceptance rate?"**
   - Left join requests with accepted on (sender_id = requester_id, send_to_id = accepter_id).
   - Group by sender_id, compute rate per sender.

5. **NULLIF explained:**
   - `NULLIF(x, 0)` returns NULL if x = 0, otherwise returns x. Prevents division by zero.
