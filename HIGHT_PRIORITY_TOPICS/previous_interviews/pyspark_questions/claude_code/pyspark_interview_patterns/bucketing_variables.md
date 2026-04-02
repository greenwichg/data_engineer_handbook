# PySpark Implementation: Bucketing Continuous Variables

## Problem Statement
Given a DataFrame of customers with their ages, bucket each customer into a labeled age group:
- **minor**: 0-17
- **young_adult**: 18-25
- **adult**: 26-65
- **senior**: 65+

Then compute the count of customers in each bucket. Demonstrate both a manual
`when/otherwise` approach and MLlib's `Bucketizer` for equal-width or custom binning.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("Bucketing").getOrCreate()

data = [
    (1, "Alice",   8),
    (2, "Bob",     17),
    (3, "Carol",   19),
    (4, "Dave",    25),
    (5, "Eve",     30),
    (6, "Frank",   45),
    (7, "Grace",   65),
    (8, "Hank",    70),
    (9, "Ivy",     88),
    (10, "Jack",   22),
    (11, "Karen",  55),
    (12, "Leo",    12),
]

df = spark.createDataFrame(data, ["customer_id", "name", "age"])
df.show()
```

| customer_id | name  | age |
|-------------|-------|-----|
| 1           | Alice | 8   |
| 2           | Bob   | 17  |
| 3           | Carol | 19  |
| 4           | Dave  | 25  |
| 5           | Eve   | 30  |
| 6           | Frank | 45  |
| 7           | Grace | 65  |
| 8           | Hank  | 70  |
| 9           | Ivy   | 88  |
| 10          | Jack  | 22  |
| 11          | Karen | 55  |
| 12          | Leo   | 12  |

### Expected Output

**Bucketed DataFrame:**

| customer_id | name  | age | age_group   |
|-------------|-------|-----|-------------|
| 1           | Alice | 8   | minor       |
| 2           | Bob   | 17  | minor       |
| 3           | Carol | 19  | young_adult |
| 4           | Dave  | 25  | young_adult |
| 5           | Eve   | 30  | adult       |
| 7           | Grace | 65  | adult       |
| 8           | Hank  | 70  | senior      |

**Bucket Counts:**

| age_group   | count |
|-------------|-------|
| minor       | 3     |
| young_adult | 3     |
| adult       | 4     |
| senior      | 2     |

---

## Method 1: `when` / `otherwise` Chain (Recommended)

```python
from pyspark.sql import functions as F

df_bucketed = df.withColumn(
    "age_group",
    F.when(F.col("age") <= 17, "minor")
     .when(F.col("age") <= 25, "young_adult")
     .when(F.col("age") <= 65, "adult")
     .otherwise("senior")
)

df_bucketed.orderBy("age").show()

# Compute counts per bucket
df_counts = (
    df_bucketed
    .groupBy("age_group")
    .agg(F.count("*").alias("count"))
    .orderBy("count", ascending=False)
)
df_counts.show()
```

### Step-by-Step Explanation

**Step 1** -- The `when/otherwise` chain evaluates top-to-bottom. The first matching condition
wins, so order matters. Because earlier conditions are checked first, we only need upper bounds:

| Condition checked     | If age = 19          | Result      |
|-----------------------|----------------------|-------------|
| `age <= 17`           | 19 <= 17? No         | skip        |
| `age <= 25`           | 19 <= 25? Yes        | young_adult |
| `age <= 65`           | (not evaluated)      | --          |
| `otherwise`           | (not evaluated)      | --          |

**After `withColumn`:**

| customer_id | name  | age | age_group   |
|-------------|-------|-----|-------------|
| 1           | Alice | 8   | minor       |
| 2           | Bob   | 17  | minor       |
| 3           | Carol | 19  | young_adult |
| 4           | Dave  | 25  | young_adult |
| 5           | Eve   | 30  | adult       |
| 6           | Frank | 45  | adult       |
| 7           | Grace | 65  | adult       |
| 8           | Hank  | 70  | senior      |
| 9           | Ivy   | 88  | senior      |
| 10          | Jack  | 22  | young_adult |
| 11          | Karen | 55  | adult       |
| 12          | Leo   | 12  | minor       |

**After `groupBy` + `count`:**

| age_group   | count |
|-------------|-------|
| adult       | 4     |
| minor       | 3     |
| young_adult | 3     |
| senior      | 2     |

---

## Method 2: MLlib Bucketizer

```python
from pyspark.ml.feature import Bucketizer

# Define split points: (-inf, 18, 26, 66, +inf)
# Bucketizer uses [lower, upper) -- left-inclusive, right-exclusive
splits = [float("-inf"), 18.0, 26.0, 66.0, float("inf")]

bucketizer = Bucketizer(
    splits=splits,
    inputCol="age",
    outputCol="age_bucket_index"
)

df_indexed = bucketizer.transform(df)
df_indexed.show()
```

The output has numeric bucket indices (0.0, 1.0, 2.0, 3.0). Map them to labels:

```python
bucket_labels = {0.0: "minor", 1.0: "young_adult", 2.0: "adult", 3.0: "senior"}

# Create a mapping DataFrame and join, or use a when chain on the index
from pyspark.sql import functions as F

label_expr = (
    F.when(F.col("age_bucket_index") == 0.0, "minor")
     .when(F.col("age_bucket_index") == 1.0, "young_adult")
     .when(F.col("age_bucket_index") == 2.0, "adult")
     .when(F.col("age_bucket_index") == 3.0, "senior")
)

df_labeled = df_indexed.withColumn("age_group", label_expr).drop("age_bucket_index")
df_labeled.orderBy("age").show()

# Counts
df_labeled.groupBy("age_group").count().show()
```

**Intermediate -- after Bucketizer transform:**

| customer_id | name  | age | age_bucket_index |
|-------------|-------|-----|------------------|
| 1           | Alice | 8   | 0.0              |
| 3           | Carol | 19  | 1.0              |
| 5           | Eve   | 30  | 2.0              |
| 8           | Hank  | 70  | 3.0              |

---

## Method 3: SQL Expression with `CASE WHEN`

```python
df.createOrReplaceTempView("customers")

df_sql = spark.sql("""
    SELECT
        customer_id,
        name,
        age,
        CASE
            WHEN age <= 17 THEN 'minor'
            WHEN age <= 25 THEN 'young_adult'
            WHEN age <= 65 THEN 'adult'
            ELSE 'senior'
        END AS age_group
    FROM customers
""")

df_sql.show()

# Counts via SQL
spark.sql("""
    SELECT age_group, COUNT(*) AS cnt
    FROM (
        SELECT CASE
            WHEN age <= 17 THEN 'minor'
            WHEN age <= 25 THEN 'young_adult'
            WHEN age <= 65 THEN 'adult'
            ELSE 'senior'
        END AS age_group
        FROM customers
    )
    GROUP BY age_group
    ORDER BY cnt DESC
""").show()
```

---

## Key Interview Talking Points

1. **`when/otherwise` is the most readable and flexible** -- it requires no imports beyond
   `pyspark.sql.functions` and the logic is immediately clear to reviewers.

2. **Order of conditions matters** -- conditions are evaluated top-to-bottom; the first match
   wins. Getting the boundary conditions wrong (< vs <=) is the most common bug.

3. **Bucketizer uses `[lower, upper)` intervals** -- the left boundary is inclusive, the right
   is exclusive. The boundary value 18 falls into bucket 1 (young_adult), not bucket 0 (minor).
   Adjust splits carefully.

4. **Null handling** -- `when/otherwise` returns null if no condition matches and there is no
   `otherwise`. `Bucketizer` raises an error on nulls unless `handleInvalid="keep"` is set,
   which assigns nulls to a special extra bucket.

5. **Performance** -- all three methods execute in a single pass with no shuffle. The `groupBy`
   for counts triggers one shuffle stage. For very large datasets, bucketing is effectively free
   compared to the aggregation.

6. **Equal-width vs. custom bins** -- `Bucketizer` supports arbitrary split points. For
   equal-width bins use `numpy.linspace` or compute `(max - min) / n_bins` to generate splits.
   For quantile-based bins, use `QuantileDiscretizer` from MLlib.

7. **Downstream usage** -- bucketed columns are often used as join keys for stratified sampling,
   as group-by dimensions in reporting, or as features after one-hot encoding.

8. **Testing boundary values** -- always verify the edge cases (age = 17, 18, 25, 26, 65, 66)
   to confirm they land in the expected bucket. Off-by-one errors are interview red flags.
