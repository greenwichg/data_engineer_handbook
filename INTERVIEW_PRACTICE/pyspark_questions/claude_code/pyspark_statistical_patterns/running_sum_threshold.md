# PySpark Implementation: Last Person to Fit in Bus (Running Sum with Threshold)

## Problem Statement

Given a queue of people with their `person_name`, `weight`, and `turn` order, find the **last person** who can board a bus with a **weight limit of 1000 kg**. People board in order of `turn`, and the bus cannot exceed the limit. This is **LeetCode 1204 — Last Person to Fit in the Bus**.

### Sample Data

```
person_id  person_name  weight  turn
1          Alice        250     1
2          Bob          350     2
3          Charlie      400     3
4          Diana        200     4
5          Eve          150     5
```

### Expected Output

| person_name |
|-------------|
| Charlie     |

**Explanation:** Alice(250) + Bob(350) + Charlie(400) = 1000 ≤ 1000. Adding Diana would make 1200 > 1000.

---

## Method 1: Running Sum with Window Function (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, desc
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("LastPersonBus").getOrCreate()

data = [
    (1, "Alice", 250, 1),
    (2, "Bob", 350, 2),
    (3, "Charlie", 400, 3),
    (4, "Diana", 200, 4),
    (5, "Eve", 150, 5)
]

columns = ["person_id", "person_name", "weight", "turn"]
df = spark.createDataFrame(data, columns)

WEIGHT_LIMIT = 1000

# Running sum ordered by turn
w = Window.orderBy("turn").rowsBetween(Window.unboundedPreceding, Window.currentRow)

result = df.withColumn("running_weight", spark_sum("weight").over(w)) \
    .filter(col("running_weight") <= WEIGHT_LIMIT) \
    .orderBy(desc("turn")) \
    .limit(1) \
    .select("person_name")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Compute running sum of weight ordered by turn
- **What happens:** Each row gets the cumulative weight of all people who boarded up to and including that person.

  | person_name | weight | turn | running_weight |
  |-------------|--------|------|----------------|
  | Alice       | 250    | 1    | 250            |
  | Bob         | 350    | 2    | 600            |
  | Charlie     | 400    | 3    | 1000           |
  | Diana       | 200    | 4    | 1200           |
  | Eve         | 150    | 5    | 1350           |

#### Step 2: Filter rows where running_weight ≤ 1000
- **What happens:** Only people who can board without exceeding the limit remain.

  | person_name | running_weight |
  |-------------|----------------|
  | Alice       | 250            |
  | Bob         | 600            |
  | Charlie     | 1000           |

#### Step 3: Take the last person (highest turn) from filtered set
- **Output:** Charlie

---

## Method 2: Using max(turn) After Filter

```python
from pyspark.sql.functions import col, sum as spark_sum, max as spark_max
from pyspark.sql.window import Window

w = Window.orderBy("turn").rowsBetween(Window.unboundedPreceding, Window.currentRow)

with_running = df.withColumn("running_weight", spark_sum("weight").over(w))

# Get the max turn where running_weight <= limit
last_turn = with_running.filter(col("running_weight") <= WEIGHT_LIMIT) \
    .agg(spark_max("turn").alias("last_turn"))

# Join back to get the person
result = with_running.join(last_turn, col("turn") == col("last_turn")) \
    .select("person_name")

result.show()
```

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("queue")

result = spark.sql("""
    SELECT person_name
    FROM (
        SELECT *,
            SUM(weight) OVER (ORDER BY turn ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_weight
        FROM queue
    ) t
    WHERE running_weight <= 1000
    ORDER BY turn DESC
    LIMIT 1
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| First person exceeds limit | No one can board | Return NULL or empty result |
| Exact weight match | Running sum equals limit exactly | That person CAN board (≤ not <) |
| All people fit | Everyone boards | Return the last person in queue |
| Ties in turn | Ambiguous boarding order | Clarify with interviewer; add tiebreaker column |
| Zero weight person | Doesn't affect running sum | Works correctly |

## Key Interview Talking Points

1. **Why running sum, not just total?**
   - We need the cumulative weight AT each boarding step, not the final total. The window function gives us this incrementally.

2. **Window frame specification:**
   - `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` ensures the sum includes all prior rows up to current. This is actually the default for `SUM() OVER (ORDER BY ...)` but being explicit is good practice.

3. **Follow-up: "What if you also need to return ALL people who board?"**
   - Simply remove the `LIMIT 1` and keep the filter `running_weight <= 1000`.

4. **Follow-up: "What if weight limit changes per trip?"**
   - Parameterize the limit. In PySpark, use a variable; in SQL, use a parameter or subquery.

5. **Greedy vs. Optimal:**
   - This problem uses a greedy approach (board in order). If asked to maximize people (knapsack), that's a different problem entirely.
