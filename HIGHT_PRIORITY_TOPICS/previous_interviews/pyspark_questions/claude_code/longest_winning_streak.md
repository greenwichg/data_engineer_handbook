# PySpark Implementation: Longest Consecutive Winning Streak

## Problem Statement
Given a table of match results for multiple teams, find each team's longest consecutive winning streak. This requires the classic "gaps and islands" technique where consecutive rows sharing the same value are grouped together, and we measure the length of each group.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("WinningStreak").getOrCreate()

data = [
    ("Tigers", "2024-01-01", "Win"),
    ("Tigers", "2024-01-08", "Win"),
    ("Tigers", "2024-01-15", "Win"),
    ("Tigers", "2024-01-22", "Loss"),
    ("Tigers", "2024-01-29", "Win"),
    ("Tigers", "2024-02-05", "Win"),
    ("Tigers", "2024-02-12", "Loss"),
    ("Tigers", "2024-02-19", "Win"),
    ("Eagles", "2024-01-01", "Loss"),
    ("Eagles", "2024-01-08", "Win"),
    ("Eagles", "2024-01-15", "Win"),
    ("Eagles", "2024-01-22", "Win"),
    ("Eagles", "2024-01-29", "Win"),
    ("Eagles", "2024-02-05", "Loss"),
    ("Eagles", "2024-02-12", "Win"),
    ("Eagles", "2024-02-19", "Win"),
]

df = spark.createDataFrame(data, ["team", "match_date", "result"])
df = df.withColumn("match_date", F.to_date("match_date"))
df.show()
```

```
+------+----------+------+
|  team|match_date|result|
+------+----------+------+
|Tigers|2024-01-01|   Win|
|Tigers|2024-01-08|   Win|
|Tigers|2024-01-15|   Win|
|Tigers|2024-01-22|  Loss|
|Tigers|2024-01-29|   Win|
|Tigers|2024-02-05|   Win|
|Tigers|2024-02-12|  Loss|
|Tigers|2024-02-19|   Win|
|Eagles|2024-01-01|  Loss|
|Eagles|2024-01-08|   Win|
|Eagles|2024-01-15|   Win|
|Eagles|2024-01-22|   Win|
|Eagles|2024-01-29|   Win|
|Eagles|2024-02-05|  Loss|
|Eagles|2024-02-12|   Win|
|Eagles|2024-02-19|   Win|
+------+----------+------+
```

### Expected Output
```
+------+-----------------------+------------+----------+
|  team|longest_winning_streak |streak_start|streak_end|
+------+-----------------------+------------+----------+
|Eagles|                      4|  2024-01-08|2024-01-29|
|Tigers|                      3|  2024-01-01|2024-01-15|
+------+-----------------------+------------+----------+
```

---

## Method 1: Gaps-and-Islands with Row Number Difference (Recommended)
```python
# Step 1: Assign a sequential row number per team ordered by date
team_window = Window.partitionBy("team").orderBy("match_date")
df_rn = df.withColumn("rn", F.row_number().over(team_window))

# Step 2: Assign a row number only among wins per team
win_window = Window.partitionBy("team", "result").orderBy("match_date")
df_rn2 = df_rn.withColumn("rn_win", F.row_number().over(win_window))

# Step 3: Compute the island group identifier (difference of the two row numbers)
df_island = df_rn2.withColumn("grp", F.col("rn") - F.col("rn_win"))

# Step 4: Filter to wins only, then count streak length per group
win_streaks = (
    df_island.filter(F.col("result") == "Win")
    .groupBy("team", "grp")
    .agg(
        F.count("*").alias("streak_length"),
        F.min("match_date").alias("streak_start"),
        F.max("match_date").alias("streak_end"),
    )
)

# Step 5: Keep the longest streak per team
streak_window = Window.partitionBy("team").orderBy(F.desc("streak_length"))
result = (
    win_streaks.withColumn("rank", F.row_number().over(streak_window))
    .filter(F.col("rank") == 1)
    .select("team", "streak_length", "streak_start", "streak_end")
    .orderBy("team")
)
result.show()
```

### Step-by-Step Explanation

**Step 1 -- Row number per team (all results):**
```
+------+----------+------+---+
|  team|match_date|result| rn|
+------+----------+------+---+
|Eagles|2024-01-01|  Loss|  1|
|Eagles|2024-01-08|   Win|  2|
|Eagles|2024-01-15|   Win|  3|
|Eagles|2024-01-22|   Win|  4|
|Eagles|2024-01-29|   Win|  5|
|Eagles|2024-02-05|  Loss|  6|
|Eagles|2024-02-12|   Win|  7|
|Eagles|2024-02-19|   Win|  8|
+------+----------+------+---+
```

**Step 2 -- Row number among wins only (rn_win):**
```
+------+----------+------+---+------+
|  team|match_date|result| rn|rn_win|
+------+----------+------+---+------+
|Eagles|2024-01-08|   Win|  2|     1|
|Eagles|2024-01-15|   Win|  3|     2|
|Eagles|2024-01-22|   Win|  4|     3|
|Eagles|2024-01-29|   Win|  5|     4|
|Eagles|2024-02-12|   Win|  7|     5|
|Eagles|2024-02-19|   Win|  8|     6|
+------+----------+------+---+------+
```

**Step 3 -- The island key: `grp = rn - rn_win`:**
Consecutive wins share the same `grp` value. When a loss interrupts, `rn` increases but `rn_win` does not, so the difference changes.
```
+------+----------+---+------+---+
|  team|match_date| rn|rn_win|grp|
+------+----------+---+------+---+
|Eagles|2024-01-08|  2|     1|  1|  <-- streak A
|Eagles|2024-01-15|  3|     2|  1|  <-- streak A
|Eagles|2024-01-22|  4|     3|  1|  <-- streak A
|Eagles|2024-01-29|  5|     4|  1|  <-- streak A
|Eagles|2024-02-12|  7|     5|  2|  <-- streak B
|Eagles|2024-02-19|  8|     6|  2|  <-- streak B
+------+----------+---+------+---+
```

**Step 4 -- Group by (team, grp) and count:**
```
+------+---+-------------+------------+----------+
|  team|grp|streak_length|streak_start|streak_end|
+------+---+-------------+------------+----------+
|Eagles|  1|            4|  2024-01-08|2024-01-29|
|Eagles|  2|            2|  2024-02-12|2024-02-19|
|Tigers|  0|            3|  2024-01-01|2024-01-15|
|Tigers|  1|            2|  2024-01-29|2024-02-05|
|Tigers|  2|            1|  2024-02-19|2024-02-19|
+------+---+-------------+------------+----------+
```

**Step 5 -- Pick the longest streak per team using `row_number()` ranked by streak_length descending.**

---

## Method 2: Spark SQL with Gaps-and-Islands
```python
df.createOrReplaceTempView("matches")

result_sql = spark.sql("""
    WITH numbered AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY team ORDER BY match_date) AS rn,
            ROW_NUMBER() OVER (PARTITION BY team, result ORDER BY match_date) AS rn_result
        FROM matches
    ),
    islands AS (
        SELECT team, result, (rn - rn_result) AS grp,
               COUNT(*) AS streak_length,
               MIN(match_date) AS streak_start,
               MAX(match_date) AS streak_end
        FROM numbered
        WHERE result = 'Win'
        GROUP BY team, result, (rn - rn_result)
    ),
    ranked AS (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY team ORDER BY streak_length DESC) AS rnk
        FROM islands
    )
    SELECT team, streak_length, streak_start, streak_end
    FROM ranked
    WHERE rnk = 1
    ORDER BY team
""")
result_sql.show()
```

---

## Method 3: Lag-Based Island Detection
```python
team_window = Window.partitionBy("team").orderBy("match_date")

df_lag = df.withColumn("prev_result", F.lag("result").over(team_window))

# A new island starts whenever the result differs from the previous row
df_boundary = df_lag.withColumn(
    "new_island",
    F.when(
        (F.col("result") != F.col("prev_result")) | F.col("prev_result").isNull(), 1
    ).otherwise(0),
)

# Cumulative sum of boundaries gives a unique island id
df_islands = df_boundary.withColumn(
    "island_id",
    F.sum("new_island").over(team_window),
)

# Filter wins, group by island, find longest
win_streaks = (
    df_islands.filter(F.col("result") == "Win")
    .groupBy("team", "island_id")
    .agg(
        F.count("*").alias("streak_length"),
        F.min("match_date").alias("streak_start"),
        F.max("match_date").alias("streak_end"),
    )
)

streak_window = Window.partitionBy("team").orderBy(F.desc("streak_length"))
result_lag = (
    win_streaks.withColumn("rank", F.row_number().over(streak_window))
    .filter(F.col("rank") == 1)
    .select("team", "streak_length", "streak_start", "streak_end")
)
result_lag.show()
```

---

## Handling Ties
If two streaks have the same max length and you want all of them, replace `row_number()` with `rank()` or `dense_rank()` in the final ranking step:
```python
# Use rank() instead of row_number() to keep ties
streak_window = Window.partitionBy("team").orderBy(F.desc("streak_length"))
result_ties = (
    win_streaks.withColumn("rank", F.rank().over(streak_window))
    .filter(F.col("rank") == 1)
    .select("team", "streak_length", "streak_start", "streak_end")
)
```

---

## Key Interview Talking Points
1. The **gaps-and-islands** technique is the standard approach. The key insight: `row_number_overall - row_number_within_category` produces a constant for consecutive rows of the same category.
2. The **lag-based** method (detect boundaries, cumulative sum) is more intuitive but uses an extra window pass. Both produce the same result.
3. Always specify a deterministic `orderBy` in window functions. If match dates can have ties, add a tiebreaker column.
4. Use `row_number()` in the final ranking to get exactly one result per team. Use `rank()` or `dense_rank()` if you want to retain ties.
5. This pattern generalizes to any consecutive sequence problem: login streaks, consecutive days with sales, uptime windows, etc.
6. Spark does not support recursive CTEs, so iterative expansion is not needed here -- the row-number-difference trick avoids recursion entirely.
7. Window functions in Spark trigger a **sort-based shuffle** on the partition key. Mention that partitioning by team keeps the shuffle manageable if there are many teams.
8. If results can be "Win", "Loss", or "Draw", the logic still works because the `rn - rn_win` difference only groups consecutive Win rows together.
