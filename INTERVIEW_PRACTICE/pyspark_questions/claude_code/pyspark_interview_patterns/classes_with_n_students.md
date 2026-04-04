# PySpark Implementation: Classes With At Least N Students

## Problem Statement

Given a `Courses` table with `student` and `class`, find all classes that have **at least 5 students**. This is **LeetCode 596 — Classes More Than 5 Students**.

### Sample Data

```
student  class
Alice    Math
Bob      Math
Charlie  Math
Diana    Math
Eve      Math
Frank    Math
Grace    Science
Hank     Science
Alice    Science
```

### Expected Output

| class |
|-------|
| Math  |

**Explanation:** Math has 6 students, Science has 3.

---

## Method 1: GroupBy + Having (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, countDistinct

spark = SparkSession.builder.appName("ClassesNStudents").getOrCreate()

data = [
    ("Alice", "Math"), ("Bob", "Math"), ("Charlie", "Math"),
    ("Diana", "Math"), ("Eve", "Math"), ("Frank", "Math"),
    ("Grace", "Science"), ("Hank", "Science"), ("Alice", "Science")
]

columns = ["student", "class"]
df = spark.createDataFrame(data, columns)

N = 5

result = df.groupBy("class") \
    .agg(countDistinct("student").alias("student_count")) \
    .filter(col("student_count") >= N) \
    .select("class")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Group by class

#### Step 2: Count distinct students per class

  | class   | student_count |
  |---------|--------------|
  | Math    | 6            |
  | Science | 3            |

#### Step 3: Filter >= 5
- Math (6 ≥ 5) ✓
- Science (3 < 5) ✗

---

## Method 2: Using count (if no duplicates expected)

```python
from pyspark.sql.functions import count

# If each (student, class) pair is unique, count(*) suffices
result = df.groupBy("class") \
    .agg(count("student").alias("student_count")) \
    .filter(col("student_count") >= N) \
    .select("class")

result.show()
```

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("courses")

result = spark.sql("""
    SELECT class
    FROM courses
    GROUP BY class
    HAVING COUNT(DISTINCT student) >= 5
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| Duplicate enrollment (same student, same class) | countDistinct handles it | Use DISTINCT to avoid double counting |
| Student enrolled in multiple classes | Each class counted independently | Correct behavior |
| Class with exactly N students | Included (>= N) | Correct |
| Empty table | No groups → empty result | Correct |

## Key Interview Talking Points

1. **COUNT vs. COUNT(DISTINCT):**
   - If a student can appear multiple times in the same class (duplicate rows), use `COUNT(DISTINCT student)`.
   - If rows are guaranteed unique, `COUNT(*)` is sufficient and faster.

2. **HAVING in PySpark:**
   - PySpark doesn't have a `.having()` method. The equivalent is `.filter()` after `.agg()`.
   - The filter is applied to aggregated columns.

3. **This is the simplest GROUP BY + HAVING pattern:**
   - Appears in many variations: "departments with > N employees", "products sold in > N countries", etc.
   - The core pattern: GROUP BY entity → aggregate → filter on aggregate → select entity.

4. **Follow-up: "Also return the student count?"**
   - Just include `student_count` in the select: `.select("class", "student_count")`.
