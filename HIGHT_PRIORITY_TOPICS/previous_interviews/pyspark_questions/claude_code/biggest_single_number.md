# PySpark Implementation: Biggest Single Number

## Problem Statement

Given a `MyNumbers` table with a `num` column, find the **biggest number that appears only once**. If no number appears exactly once, return NULL. This is **LeetCode 619 — Biggest Single Number**.

### Sample Data

```
num
8
8
3
3
1
4
5
6
```

### Expected Output

| num |
|-----|
| 6   |

**Explanation:** Numbers appearing once: 1, 4, 5, 6. Biggest = 6. Numbers 8 and 3 appear twice.

---

## Method 1: GroupBy + Having + Max (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, max as spark_max

spark = SparkSession.builder.appName("BiggestSingleNumber").getOrCreate()

data = [(8,), (8,), (3,), (3,), (1,), (4,), (5,), (6,)]
columns = ["num"]
df = spark.createDataFrame(data, columns)

# Find numbers appearing exactly once, then get the max
result = df.groupBy("num") \
    .agg(count("*").alias("cnt")) \
    .filter(col("cnt") == 1) \
    .agg(spark_max("num").alias("num"))

result.show()
```

### Step-by-Step Explanation

#### Step 1: Group by num and count occurrences

  | num | cnt |
  |-----|-----|
  | 8   | 2   |
  | 3   | 2   |
  | 1   | 1   |
  | 4   | 1   |
  | 5   | 1   |
  | 6   | 1   |

#### Step 2: Filter for cnt == 1 (single numbers)

  | num |
  |-----|
  | 1   |
  | 4   |
  | 5   |
  | 6   |

#### Step 3: Get max → 6

---

## Method 2: Using Subquery Style

```python
from pyspark.sql.functions import col, count, max as spark_max

singles = df.groupBy("num").agg(count("*").alias("cnt")).filter(col("cnt") == 1)
result = singles.select(spark_max("num").alias("num"))

result.show()
```

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("my_numbers")

result = spark.sql("""
    SELECT MAX(num) AS num
    FROM (
        SELECT num
        FROM my_numbers
        GROUP BY num
        HAVING COUNT(*) = 1
    ) singles
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| All numbers appear more than once | No singles → MAX of empty set = NULL | Returns NULL correctly |
| All numbers are unique | Every number is a "single" | Returns the maximum |
| Single row in table | That number appears once | Returns that number |
| Negative numbers | MAX works with negatives | Correct behavior |
| NULL values | GROUP BY treats NULLs as a group; COUNT(*) counts them | May need to filter NULLs |

## Key Interview Talking Points

1. **Two-step aggregation pattern:**
   - First aggregate to find qualifying groups (HAVING).
   - Then aggregate again to find the answer (MAX).
   - This "aggregate of aggregates" is a common SQL pattern.

2. **NULL result when no singles exist:**
   - `MAX()` on an empty set returns NULL — this is the expected LeetCode behavior.
   - No need for explicit NULL handling.

3. **Follow-up: "Find the Kth largest single number?"**
   - Replace MAX with `orderBy(desc("num")).limit(K)` or use `dense_rank()`.

4. **Alternative: window function approach:**
   ```python
   from pyspark.sql.window import Window
   # Add count per number using window, filter, then max
   w = Window.partitionBy("num")
   df.withColumn("cnt", count("*").over(w)) \
     .filter(col("cnt") == 1) \
     .agg(spark_max("num"))
   ```
   Works but less efficient — adds a column to every row before filtering.
