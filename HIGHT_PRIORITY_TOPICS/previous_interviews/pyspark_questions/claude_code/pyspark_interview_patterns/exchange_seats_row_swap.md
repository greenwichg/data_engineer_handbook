# PySpark Implementation: Exchange Seats (Row Swapping)

## Problem Statement

Given a table of students with `id` (auto-increment) and `student` name, swap every two adjacent students' seats. If the number of students is odd, the last student stays in place. This is **LeetCode 626 — Exchange Seats**.

### Sample Data

```
id  student
1   Alice
2   Bob
3   Charlie
4   Diana
5   Eve
```

### Expected Output

| id | student |
|----|---------|
| 1  | Bob     |
| 2  | Alice   |
| 3  | Diana   |
| 4  | Charlie |
| 5  | Eve     |

---

## Method 1: Using CASE with MOD (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, max as spark_max, lead, lag
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("ExchangeSeats").getOrCreate()

data = [
    (1, "Alice"),
    (2, "Bob"),
    (3, "Charlie"),
    (4, "Diana"),
    (5, "Eve")
]

columns = ["id", "student"]
df = spark.createDataFrame(data, columns)

# Get the total count
total = df.count()

# Swap logic: odd id -> id+1, even id -> id-1, last odd stays
result = df.withColumn(
    "new_id",
    when((col("id") % 2 == 1) & (col("id") == total), col("id"))    # last odd row stays
    .when(col("id") % 2 == 1, col("id") + 1)                        # odd -> next
    .otherwise(col("id") - 1)                                         # even -> previous
).drop("id").withColumnRenamed("new_id", "id").orderBy("id")

result.select("id", "student").show()
```

### Step-by-Step Explanation

#### Step 1: Determine parity and total count
- **What happens:** We check if each `id` is odd or even using `MOD(id, 2)`.
- Count total rows to handle the last-row edge case.

#### Step 2: Apply swapping logic
- **Odd id (not last):** Assign `id + 1` → moves down one seat.
- **Even id:** Assign `id - 1` → moves up one seat.
- **Last odd id:** Keep same `id` → no swap partner.

#### Step 3: Reorder by new id
- **Output:**

  | id | student |
  |----|---------|
  | 1  | Bob     |
  | 2  | Alice   |
  | 3  | Diana   |
  | 4  | Charlie |
  | 5  | Eve     |

---

## Method 2: Using LEAD/LAG Window Functions

```python
from pyspark.sql.functions import col, when, lead, lag, coalesce
from pyspark.sql.window import Window

w = Window.orderBy("id")

result = df.withColumn(
    "swapped_student",
    when(col("id") % 2 == 1,
         coalesce(lead("student").over(w), col("student")))  # odd: take next, or self if last
    .otherwise(lag("student").over(w))                        # even: take previous
).select("id", col("swapped_student").alias("student"))

result.show()
```

### Step-by-Step Explanation

#### Step 1: Window ordered by id
- Creates a window so LEAD/LAG can reference adjacent rows.

#### Step 2: Apply swap
- **Odd rows:** Take the student from the NEXT row via `lead()`. If no next row (last), use `coalesce` to keep the current student.
- **Even rows:** Take the student from the PREVIOUS row via `lag()`.

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("seat")

result = spark.sql("""
    SELECT
        id,
        CASE
            WHEN id % 2 = 1 AND id = (SELECT MAX(id) FROM seat) THEN student
            WHEN id % 2 = 1 THEN LEAD(student) OVER (ORDER BY id)
            ELSE LAG(student) OVER (ORDER BY id)
        END AS student
    FROM seat
    ORDER BY id
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| Single row | Odd count, last row = only row | Stays in place (no swap) |
| Even total count | All rows have swap partners | No special handling needed |
| Odd total count | Last row has no partner | Keep last row unchanged |
| Non-sequential ids | Gaps in id sequence | Use `row_number()` first to create sequential ids |

## Key Interview Talking Points

1. **Why MOD-based approach?**
   - Simple, no joins needed. O(n) scan with a single pass.

2. **LEAD/LAG vs. id arithmetic:**
   - LEAD/LAG is more robust when ids are not sequential.
   - Id arithmetic only works with contiguous auto-increment ids.

3. **Follow-up: "What if ids have gaps?"**
   - Use `row_number()` to assign sequential positions first, then apply swap logic on the row numbers.

4. **SQL vs. DataFrame API:**
   - The CASE + LEAD/LAG approach translates directly between SQL and DataFrame API, making it easy to explain in either format.
