# PySpark Implementation: Percentile Rank Within Custom Groups

## Problem Statement
Given student test scores, compute each student's percentile rank within their grade level AND across the entire school. Then assign percentile-based bucket labels (e.g., "Top 10%", "Top 25%", "Top 50%", "Bottom 50%"). This tests mastery of `percent_rank()`, window specifications, and conditional labeling.

### Sample Data
```python
from pyspark.sql import SparkSession, Window
from pyspark.sql.functions import (
    percent_rank, col, when, round as _round
)

spark = SparkSession.builder.appName("PercentileRank").getOrCreate()

data = [
    ("Alice",   10, "Math",    92),
    ("Bob",     10, "Math",    85),
    ("Charlie", 10, "Math",    78),
    ("Diana",   10, "Math",    95),
    ("Eve",     11, "Math",    88),
    ("Frank",   11, "Math",    91),
    ("Grace",   11, "Math",    74),
    ("Hank",    11, "Math",    99),
    ("Ivy",     12, "Math",    82),
    ("Jack",    12, "Math",    90),
    ("Karen",   12, "Math",    67),
    ("Leo",     12, "Math",    94),
]

df = spark.createDataFrame(data, ["student", "grade", "subject", "score"])
df.show()
```

| student | grade | subject | score |
|---------|-------|---------|-------|
| Alice   | 10    | Math    | 92    |
| Bob     | 10    | Math    | 85    |
| Charlie | 10    | Math    | 78    |
| Diana   | 10    | Math    | 95    |
| Eve     | 11    | Math    | 88    |
| Frank   | 11    | Math    | 91    |
| Grace   | 11    | Math    | 74    |
| Hank    | 11    | Math    | 99    |
| Ivy     | 12    | Math    | 82    |
| Jack    | 12    | Math    | 90    |
| Karen   | 12    | Math    | 67    |
| Leo     | 12    | Math    | 94    |

### Expected Output

| student | grade | score | grade_pctl | school_pctl | bucket      |
|---------|-------|-------|------------|-------------|-------------|
| Hank    | 11    | 99    | 1.0        | 1.0         | Top 10%     |
| Diana   | 10    | 95    | 1.0        | 0.91        | Top 10%     |
| Leo     | 12    | 94    | 1.0        | 0.82        | Top 25%     |
| Alice   | 10    | 92    | 0.67       | 0.73        | Top 25%     |
| Frank   | 11    | 91    | 0.67       | 0.64        | Top 50%     |
| Jack    | 12    | 90    | 0.67       | 0.55        | Top 50%     |
| Eve     | 11    | 88    | 0.33       | 0.45        | Bottom 50%  |
| Bob     | 10    | 85    | 0.33       | 0.36        | Bottom 50%  |
| Ivy     | 12    | 82    | 0.33       | 0.27        | Bottom 50%  |
| Charlie | 10    | 78    | 0.0        | 0.18        | Bottom 50%  |
| Grace   | 11    | 74    | 0.0        | 0.09        | Bottom 50%  |
| Karen   | 12    | 67    | 0.0        | 0.0         | Bottom 50%  |

---

## Method 1: percent_rank with Multiple Window Specs (Recommended)

```python
# Step 1: Define window specs
grade_window = Window.partitionBy("grade").orderBy("score")
school_window = Window.orderBy("score")

# Step 2: Compute percentile ranks
result = df.withColumn(
    "grade_pctl", _round(percent_rank().over(grade_window), 2)
).withColumn(
    "school_pctl", _round(percent_rank().over(school_window), 2)
)

# Step 3: Assign bucket labels based on school-wide percentile
result = result.withColumn(
    "bucket",
    when(col("school_pctl") >= 0.90, "Top 10%")
    .when(col("school_pctl") >= 0.75, "Top 25%")
    .when(col("school_pctl") >= 0.50, "Top 50%")
    .otherwise("Bottom 50%")
)

result.orderBy(col("score").desc()).show()
```

### Step-by-Step Explanation

**After Step 1 -- Window definitions (no computation yet):**
- `grade_window`: partitions by grade, orders by score ascending. `percent_rank()` assigns 0.0 to the lowest score in each grade and 1.0 to the highest.
- `school_window`: no partition, orders by score. Treats all 12 students as one group.

**After Step 2 -- Percentile ranks computed:**

For grade 10 (4 students, scores 78, 85, 92, 95):
- Charlie (78): rank position 0 of 3 gaps = 0.0
- Bob (85): rank position 1 of 3 = 0.33
- Alice (92): rank position 2 of 3 = 0.67
- Diana (95): rank position 3 of 3 = 1.0

Formula: `percent_rank = (rank - 1) / (count_in_partition - 1)`

For school-wide (12 students):
- Karen (67): 0 / 11 = 0.0
- Hank (99): 11 / 11 = 1.0

**After Step 3 -- Bucket assignment:**

The `when` chain evaluates top-down. A student at the 92nd percentile hits `>= 0.90` first and gets "Top 10%", not "Top 25%".

---

## Method 2: Using ntile for Equal-Size Buckets

```python
from pyspark.sql.functions import ntile

# ntile(4) splits into 4 roughly equal groups (quartiles)
quartile_window = Window.orderBy("score")

result_ntile = df.withColumn(
    "quartile", ntile(4).over(quartile_window)
).withColumn(
    "bucket",
    when(col("quartile") == 4, "Top 25%")
    .when(col("quartile") == 3, "50th-75th")
    .when(col("quartile") == 2, "25th-50th")
    .otherwise("Bottom 25%")
)

result_ntile.orderBy(col("score").desc()).show()
```

Note: `ntile` divides rows into N roughly equal buckets by count, while `percent_rank` gives a continuous 0-1 value. They answer different questions: ntile guarantees equal group sizes, percent_rank gives relative standing.

---

## Method 3: Dual Ranking with Subgroup vs Overall Comparison

```python
from pyspark.sql.functions import abs as _abs

# Compute both ranks and their difference
comparison = df.withColumn(
    "grade_pctl", _round(percent_rank().over(grade_window), 2)
).withColumn(
    "school_pctl", _round(percent_rank().over(school_window), 2)
).withColumn(
    "pctl_diff", _round(col("grade_pctl") - col("school_pctl"), 2)
).withColumn(
    "interpretation",
    when(col("pctl_diff") > 0.15, "Weaker grade boosts rank")
    .when(col("pctl_diff") < -0.15, "Stronger grade suppresses rank")
    .otherwise("Consistent across levels")
)

comparison.orderBy(col("score").desc()).show(truncate=False)
```

This reveals students whose grade-level rank differs significantly from their school-wide rank -- a useful analytical pattern for identifying grade difficulty imbalances.

---

## Key Interview Talking Points

1. **`percent_rank()` vs `rank()` vs `dense_rank()`** -- `percent_rank` returns a value between 0 and 1 using the formula `(rank - 1) / (N - 1)`. `rank()` and `dense_rank()` return integer positions. Interviewers often ask you to explain the differences.

2. **Window spec reuse** -- defining window specs as variables and reusing them across multiple `withColumn` calls is both cleaner and safer than inlining. Spark optimizes multiple window functions sharing the same spec into a single sort.

3. **`when` chain order matters** -- conditions are evaluated top to bottom. Place the most restrictive condition first (>= 0.90 before >= 0.75) to avoid incorrect bucket assignment.

4. **`ntile` vs `percent_rank` distinction** -- `ntile(4)` always puts exactly N/4 rows in each bucket. `percent_rank` assigns a continuous score. For 12 rows, ntile(4) puts 3 per bucket. With ties, ntile arbitrarily breaks them; percent_rank assigns equal values.

5. **Performance with large datasets** -- `percent_rank` over the entire dataset (no partition) forces a single-partition sort, which is a full data shuffle. For very large datasets, consider approximate percentiles with `percentile_approx()`.

6. **Null handling** -- by default, nulls sort to the end in ascending order. Use `.orderBy(col("score").asc_nulls_first())` or `.asc_nulls_last()` to control this behavior explicitly.

7. **Multiple subjects extension** -- to rank within grade+subject, change the partition to `Window.partitionBy("grade", "subject")`. This is a natural follow-up question.
