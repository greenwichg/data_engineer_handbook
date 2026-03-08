# PySpark Implementation: Stadium Consecutive Visits (Human Traffic of Stadium)

## Problem Statement

Given a stadium attendance log with `id` (auto-increment), `visit_date`, and `people` (count of visitors), return the rows where the stadium had **more than 200 people** for **3 or more consecutive days**. This is the classic **LeetCode 601 — Human Traffic of Stadium** problem, frequently asked in data engineering interviews.

### Sample Data

```
id   visit_date   people
1    2025-01-01   100
2    2025-01-02   250
3    2025-01-03   300
4    2025-01-04   400
5    2025-01-05   150
6    2025-01-06   350
7    2025-01-07   500
8    2025-01-08   280
9    2025-01-09   90
10   2025-01-10   600
```

### Expected Output

Return rows where people > 200 AND the row belongs to a streak of 3+ consecutive days:

| id | visit_date | people |
|----|------------|--------|
| 2  | 2025-01-02 | 250    |
| 3  | 2025-01-03 | 300    |
| 4  | 2025-01-04 | 400    |
| 6  | 2025-01-06 | 350    |
| 7  | 2025-01-07 | 500    |
| 8  | 2025-01-08 | 280    |

**Why?**
- Days 2, 3, 4 → all have people > 200, 3 consecutive IDs → included
- Day 5 → people = 150 (breaks the streak)
- Days 6, 7, 8 → all have people > 200, 3 consecutive IDs → included
- Day 10 → people > 200 but only 1 day streak → excluded

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, row_number, count, min as spark_min, \
    max as spark_max
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("StadiumConsecutiveVisits").getOrCreate()

# Sample data
data = [
    (1, "2025-01-01", 100), (2, "2025-01-02", 250),
    (3, "2025-01-03", 300), (4, "2025-01-04", 400),
    (5, "2025-01-05", 150), (6, "2025-01-06", 350),
    (7, "2025-01-07", 500), (8, "2025-01-08", 280),
    (9, "2025-01-09", 90),  (10, "2025-01-10", 600)
]
columns = ["id", "visit_date", "people"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("visit_date", to_date(col("visit_date")))

# Step 1: Filter rows where people > 200
df_filtered = df.filter(col("people") > 200)

# Step 2: Use the islands trick — id minus row_number gives a group key
#   Since id is auto-increment and we removed some rows, consecutive surviving
#   rows will produce the same (id - row_number) value
df_grouped = df_filtered.withColumn(
    "rn", row_number().over(Window.orderBy("id"))
).withColumn(
    "grp", col("id") - col("rn")
)

# Step 3: Find groups with 3 or more consecutive days
group_sizes = df_grouped.groupBy("grp").agg(
    count("*").alias("streak_len")
).filter(col("streak_len") >= 3)

# Step 4: Join back to get the original rows belonging to qualifying groups
result = df_grouped.join(group_sizes, on="grp", how="inner") \
    .select("id", "visit_date", "people") \
    .orderBy("id")

result.show(truncate=False)
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Filter rows where people > 200

| id | visit_date | people |
|----|------------|--------|
| 2  | 2025-01-02 | 250    |
| 3  | 2025-01-03 | 300    |
| 4  | 2025-01-04 | 400    |
| 6  | 2025-01-06 | 350    |
| 7  | 2025-01-07 | 500    |
| 8  | 2025-01-08 | 280    |
| 10 | 2025-01-10 | 600    |

### Step 2: Assign row_number and compute grp = id - rn

| id | visit_date | people | rn | grp (id - rn) |
|----|------------|--------|----|---------------|
| 2  | 2025-01-02 | 250    | 1  | **1**         |
| 3  | 2025-01-03 | 300    | 2  | **1**         |
| 4  | 2025-01-04 | 400    | 3  | **1**         |
| 6  | 2025-01-06 | 350    | 4  | **2**         |
| 7  | 2025-01-07 | 500    | 5  | **2**         |
| 8  | 2025-01-08 | 280    | 6  | **2**         |
| 10 | 2025-01-10 | 600    | 7  | **3**         |

**Key insight:** After filtering, consecutive IDs that survived produce the same `id - rn` value. IDs 2,3,4 → grp=1. IDs 6,7,8 → grp=2. ID 10 alone → grp=3.

### Step 3: Filter groups with streak_len >= 3

| grp | streak_len |
|-----|------------|
| 1   | 3          |
| 2   | 3          |

Group 3 (only ID 10) is excluded because streak_len = 1 < 3.

### Step 4: Join back to get qualifying rows

| id | visit_date | people |
|----|------------|--------|
| 2  | 2025-01-02 | 250    |
| 3  | 2025-01-03 | 300    |
| 4  | 2025-01-04 | 400    |
| 6  | 2025-01-06 | 350    |
| 7  | 2025-01-07 | 500    |
| 8  | 2025-01-08 | 280    |

---

## Alternative: Using lag/lead Without the Islands Trick

```python
from pyspark.sql.functions import lag, lead

# For each row where people > 200, check if the two previous,
# two next, or one previous + one next also have people > 200
df_filtered = df.filter(col("people") > 200)

w = Window.orderBy("id")

df_with_neighbors = df_filtered.withColumn("prev1", lag("id", 1).over(w)) \
    .withColumn("prev2", lag("id", 2).over(w)) \
    .withColumn("next1", lead("id", 1).over(w)) \
    .withColumn("next2", lead("id", 2).over(w))

# A row qualifies if it is part of any group of 3 consecutive IDs:
#   Case 1: id, id-1, id-2 are all present (current is the end of a 3-streak)
#   Case 2: id-1, id, id+1 are all present (current is the middle)
#   Case 3: id, id+1, id+2 are all present (current is the start of a 3-streak)
result_alt = df_with_neighbors.filter(
    # Current row is the 3rd in a consecutive triple
    ((col("id") - col("prev1") == 1) & (col("prev1") - col("prev2") == 1)) |
    # Current row is the middle of a consecutive triple
    ((col("id") - col("prev1") == 1) & (col("next1") - col("id") == 1)) |
    # Current row is the 1st in a consecutive triple
    ((col("next1") - col("id") == 1) & (col("next2") - col("next1") == 1))
).select("id", "visit_date", "people") \
 .orderBy("id")

result_alt.show(truncate=False)
```

---

## Alternative: Spark SQL

```python
df.createOrReplaceTempView("stadium")

result_sql = spark.sql("""
    WITH filtered AS (
        SELECT *,
            id - ROW_NUMBER() OVER (ORDER BY id) AS grp
        FROM stadium
        WHERE people > 200
    ),
    qualifying_groups AS (
        SELECT grp
        FROM filtered
        GROUP BY grp
        HAVING COUNT(*) >= 3
    )
    SELECT f.id, f.visit_date, f.people
    FROM filtered f
    INNER JOIN qualifying_groups q ON f.grp = q.grp
    ORDER BY f.id
""")

result_sql.show(truncate=False)
```

---

## Variation: Using visit_date Instead of id

If the table does not have an auto-increment `id` but only `visit_date`, use `date_sub` instead:

```python
from pyspark.sql.functions import date_sub

df_filtered = df.filter(col("people") > 200)

df_grouped = df_filtered.withColumn(
    "rn", row_number().over(Window.orderBy("visit_date"))
).withColumn(
    "grp", date_sub(col("visit_date"), col("rn"))
)

group_sizes = df_grouped.groupBy("grp").agg(
    count("*").alias("streak_len")
).filter(col("streak_len") >= 3)

result = df_grouped.join(group_sizes, on="grp", how="inner") \
    .select("id", "visit_date", "people") \
    .orderBy("visit_date")

result.show(truncate=False)
```

---

## Key Interview Talking Points

1. **Filter first, then find islands:** The trick is to filter rows meeting the condition (people > 200) first, then apply the consecutive-detection logic on the surviving rows.

2. **id - row_number trick:** After filtering, the original IDs have gaps. But `row_number()` is always sequential. So `id - rn` is constant for consecutive IDs — exactly the "islands" technique.

3. **Why not just use 3 self-joins?** A self-join approach (t1 JOIN t2 ON t2.id = t1.id+1 JOIN t3 ON t3.id = t2.id+1) works but only finds exactly-3 streaks and is harder to generalize. The islands approach handles any streak length with a simple `HAVING COUNT(*) >= 3`.

4. **Performance:** The islands approach is O(n log n) for the sort, then a single pass with window functions, followed by a small join on group keys. Much better than O(n³) for triple self-joins.

5. **Common follow-up questions:**
   - "What if the threshold is 5 consecutive days instead of 3?" → Just change `>= 3` to `>= 5`.
   - "What if IDs are not sequential?" → Use `visit_date` with `date_sub` instead of `id - rn`.
   - "Return the streak start/end dates too?" → Add `min(visit_date)` and `max(visit_date)` in the group aggregation.
