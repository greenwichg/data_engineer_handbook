# PySpark Implementation: Count Character Occurrences in Words

## Problem Statement

Given a list of words, count the total number of occurrences of a specific character (e.g., 'a') across all words. This is a basic PySpark question that tests your understanding of both the RDD API and the DataFrame API.

### Sample Data

```
words: ["apple", "banana", "cherry", "date", "avocado", "grape"]
```

### Expected Output

```
Total occurrences of 'a': 8
```

Breakdown: apple(1) + banana(3) + cherry(0) + date(1) + avocado(2) + grape(1) = 8

---

## Method 1: Using DataFrame API (Recommended)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, length, regexp_replace, sum as spark_sum

# Initialize Spark session
spark = SparkSession.builder.appName("CountCharOccurrences").getOrCreate()

# Sample data
data = [("apple",), ("banana",), ("cherry",), ("date",), ("avocado",), ("grape",)]
df = spark.createDataFrame(data, ["word"])

# Count 'a' in each word: length(word) - length(word with 'a' removed)
df_counts = df.withColumn(
    "a_count",
    length(col("word")) - length(regexp_replace(col("word"), "a", ""))
)

df_counts.show()

# Total across all words
total = df_counts.agg(spark_sum("a_count").alias("total_a")).collect()[0][0]
print(f"Total occurrences of 'a': {total}")
```

### Step-by-Step Explanation

#### Step 1: Count per word using length difference
- `regexp_replace(col("word"), "a", "")` removes all 'a' characters
- Subtracting lengths gives the count of 'a' in each word

- **Output (df_counts):**

  | word    | a_count |
  |---------|---------|
  | apple   | 1       |
  | banana  | 3       |
  | cherry  | 0       |
  | date    | 1       |
  | avocado | 2       |
  | grape   | 1       |

#### Step 2: Aggregate total
- `spark_sum("a_count")` sums across all rows
- **Result:** Total occurrences of 'a': 8

---

## Method 2: Using RDD API

```python
from pyspark import SparkContext

# Initialize SparkContext
sc = SparkContext("local", "CountAOccurrences")

# Sample list of words
words = ["apple", "banana", "cherry", "date", "avocado", "grape"]

# Create an RDD from the list of words
rdd = sc.parallelize(words)

# Map each word to the count of 'a' in it, then reduce to sum the counts
count_a = rdd.map(lambda word: word.lower().count('a')).reduce(lambda x, y: x + y)

# Output the result
print(f"Total occurrences of 'a': {count_a}")

# Stop the SparkContext
sc.stop()
```

### RDD Explanation
1. `sc.parallelize(words)`: Distributes the list across the cluster as an RDD.
2. `map(lambda word: word.lower().count('a'))`: Transforms each word into its count of 'a'. Produces RDD: [1, 3, 0, 1, 2, 1].
3. `reduce(lambda x, y: x + y)`: Sums all values into a single result: 8.

---

## Method 3: Using SQL

```python
df.createOrReplaceTempView("words")

spark.sql("""
    SELECT
        word,
        LENGTH(word) - LENGTH(REPLACE(word, 'a', '')) AS a_count
    FROM words
""").show()

spark.sql("""
    SELECT SUM(LENGTH(word) - LENGTH(REPLACE(word, 'a', ''))) AS total_a
    FROM words
""").show()
```

---

## Key Interview Talking Points

1. **DataFrame vs RDD:** Always prefer the DataFrame API — it benefits from Catalyst optimizer and Tungsten execution engine. The RDD approach is shown for completeness but is rarely used in modern PySpark.

2. **The length-difference trick:** `length(word) - length(replace(word, 'a', ''))` is a common pattern for counting character occurrences without UDFs. It works in both PySpark and SQL.

3. **Case sensitivity:** Use `lower()` if you want case-insensitive matching: `regexp_replace(lower(col("word")), "a", "")`.

4. **Scaling:** This approach works efficiently on billions of rows because both `regexp_replace` and `length` are built-in Catalyst expressions — no Python UDF overhead.
