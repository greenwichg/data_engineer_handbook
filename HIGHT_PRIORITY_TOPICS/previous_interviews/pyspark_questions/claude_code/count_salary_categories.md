# PySpark Implementation: Count Salary Categories

## Problem Statement

Given an `Accounts` table with `account_id` and `income`, classify each account into salary categories ("Low Salary" < 20000, "Average Salary" 20000-50000, "High Salary" > 50000) and count accounts in each category. **All three categories must appear** in the output even if count is 0. This is **LeetCode 1907 — Count Salary Categories**.

### Sample Data

```
account_id  income
1           8000
2           25000
3           60000
4           35000
5           12000
6           45000
```

### Expected Output

| category       | accounts_count |
|----------------|---------------|
| Average Salary | 3             |
| High Salary    | 1             |
| Low Salary     | 2             |

---

## Method 1: CASE WHEN + Union with Category Template (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, count, lit, coalesce

spark = SparkSession.builder.appName("SalaryCategories").getOrCreate()

data = [
    (1, 8000), (2, 25000), (3, 60000),
    (4, 35000), (5, 12000), (6, 45000)
]
columns = ["account_id", "income"]
df = spark.createDataFrame(data, columns)

# Classify each account
classified = df.withColumn(
    "category",
    when(col("income") < 20000, "Low Salary")
    .when(col("income") <= 50000, "Average Salary")
    .otherwise("High Salary")
)

# Count per category
counts = classified.groupBy("category") \
    .agg(count("*").alias("accounts_count"))

# Ensure all categories appear (even with 0 count)
all_categories = spark.createDataFrame(
    [("Low Salary",), ("Average Salary",), ("High Salary",)],
    ["category"]
)

result = all_categories.join(counts, on="category", how="left") \
    .withColumn("accounts_count", coalesce(col("accounts_count"), lit(0))) \
    .orderBy("category")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Classify each account

  | account_id | income | category       |
  |------------|--------|----------------|
  | 1          | 8000   | Low Salary     |
  | 2          | 25000  | Average Salary |
  | 3          | 60000  | High Salary    |
  | 4          | 35000  | Average Salary |
  | 5          | 12000  | Low Salary     |
  | 6          | 45000  | Average Salary |

#### Step 2: Group and count

  | category       | accounts_count |
  |----------------|---------------|
  | Low Salary     | 2             |
  | Average Salary | 3             |
  | High Salary    | 1             |

#### Step 3: Left join with category template to guarantee all 3 appear

---

## Method 2: UNION ALL Approach (Classic SQL Pattern)

```python
from pyspark.sql.functions import col, count, lit, when, sum as spark_sum

# Count each category separately and UNION
low = df.filter(col("income") < 20000).agg(count("*").alias("accounts_count")) \
    .withColumn("category", lit("Low Salary"))

avg_sal = df.filter((col("income") >= 20000) & (col("income") <= 50000)) \
    .agg(count("*").alias("accounts_count")) \
    .withColumn("category", lit("Average Salary"))

high = df.filter(col("income") > 50000).agg(count("*").alias("accounts_count")) \
    .withColumn("category", lit("High Salary"))

result = low.unionByName(avg_sal).unionByName(high) \
    .select("category", "accounts_count") \
    .orderBy("category")

result.show()
```

---

## Method 3: Using Conditional Sum (Single Pass)

```python
from pyspark.sql.functions import col, when, sum as spark_sum, lit
from pyspark.sql import Row

# Single-pass conditional aggregation
agg_result = df.agg(
    spark_sum(when(col("income") < 20000, 1).otherwise(0)).alias("low"),
    spark_sum(when((col("income") >= 20000) & (col("income") <= 50000), 1).otherwise(0)).alias("avg"),
    spark_sum(when(col("income") > 50000, 1).otherwise(0)).alias("high")
).first()

# Reshape to rows
result = spark.createDataFrame([
    ("Low Salary", agg_result["low"]),
    ("Average Salary", agg_result["avg"]),
    ("High Salary", agg_result["high"])
], ["category", "accounts_count"])

result.show()
```

---

## Method 4: Spark SQL

```python
df.createOrReplaceTempView("accounts")

result = spark.sql("""
    SELECT 'Low Salary' AS category, COUNT(*) AS accounts_count
    FROM accounts WHERE income < 20000
    UNION ALL
    SELECT 'Average Salary', COUNT(*)
    FROM accounts WHERE income BETWEEN 20000 AND 50000
    UNION ALL
    SELECT 'High Salary', COUNT(*)
    FROM accounts WHERE income > 50000
    ORDER BY category
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| No accounts in a category | UNION approach returns 0; groupBy may miss it | Use UNION ALL or LEFT JOIN with template |
| Empty table | All categories show 0 | UNION ALL with COUNT(*) returns 0 for each |
| Income exactly 20000 or 50000 | Boundary values — must be clear on ≤ vs < | Problem says: <20k is Low, 20k-50k is Average, >50k is High |
| NULL income | CASE WHEN returns NULL → uncategorized | Filter NULLs or add "Unknown" category |

## Key Interview Talking Points

1. **Guaranteeing all categories appear:**
   - GROUP BY only returns categories that exist in data.
   - UNION ALL with hardcoded categories guarantees all 3 appear.
   - LEFT JOIN with a categories template also works.

2. **UNION ALL vs. single GROUP BY:**
   - UNION ALL scans the table 3 times — less efficient.
   - Single pass with CASE WHEN + GROUP BY scans once.
   - But UNION ALL is what LeetCode expects and is more readable.

3. **Boundary conditions:**
   - Always clarify: is 20000 "Low" or "Average"? Is 50000 "Average" or "High"?
   - Use inclusive/exclusive notation: [20000, 50000] means both endpoints included.

4. **Pattern: "Fixed categories with possible zero counts"**
   - Common in reporting: show all dimensions even when measure is 0.
   - Same pattern for: status codes, rating buckets, date periods.
