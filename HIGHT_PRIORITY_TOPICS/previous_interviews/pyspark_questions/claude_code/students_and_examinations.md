# PySpark Implementation: Students and Examinations (Cross Join + Count)

## Problem Statement

Given three tables — `Students`, `Subjects`, and `Examinations` — find the number of times each student attended each exam. The result must include **all student-subject combinations**, even if the student never attended that exam (count = 0). This is **LeetCode 1280 — Students and Examinations**.

### Sample Data

```
Students:
student_id  student_name
1           Alice
2           Bob
3           Charlie

Subjects:
subject_name
Math
Physics
Programming

Examinations:
student_id  subject_name
1           Math
1           Physics
1           Math
2           Programming
2           Programming
```

### Expected Output

| student_id | student_name | subject_name | attended_exams |
|------------|-------------|--------------|----------------|
| 1          | Alice       | Math         | 2              |
| 1          | Alice       | Physics      | 1              |
| 1          | Alice       | Programming  | 0              |
| 2          | Bob         | Math         | 0              |
| 2          | Bob         | Physics      | 0              |
| 2          | Bob         | Programming  | 2              |
| 3          | Charlie     | Math         | 0              |
| 3          | Charlie     | Physics      | 0              |
| 3          | Charlie     | Programming  | 0              |

---

## Method 1: Cross Join + Left Join + Count (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, coalesce, lit

spark = SparkSession.builder.appName("StudentsExams").getOrCreate()

students_data = [(1, "Alice"), (2, "Bob"), (3, "Charlie")]
students = spark.createDataFrame(students_data, ["student_id", "student_name"])

subjects_data = [("Math",), ("Physics",), ("Programming",)]
subjects = spark.createDataFrame(subjects_data, ["subject_name"])

exams_data = [(1, "Math"), (1, "Physics"), (1, "Math"), (2, "Programming"), (2, "Programming")]
exams = spark.createDataFrame(exams_data, ["student_id", "subject_name"])

# Step 1: Cross join students x subjects to get all combinations
all_combos = students.crossJoin(subjects)

# Step 2: Count exams per student-subject
exam_counts = exams.groupBy("student_id", "subject_name") \
    .agg(count("*").alias("attended_exams"))

# Step 3: Left join to bring in counts (0 for missing)
result = all_combos.join(
    exam_counts,
    on=["student_id", "subject_name"],
    how="left"
).withColumn(
    "attended_exams", coalesce(col("attended_exams"), lit(0))
).orderBy("student_id", "subject_name")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Cross join to generate all student-subject pairs
- **What happens:** Every student is paired with every subject.
- **Output (all_combos):** 3 students × 3 subjects = 9 rows.

  | student_id | student_name | subject_name |
  |------------|-------------|--------------|
  | 1          | Alice       | Math         |
  | 1          | Alice       | Physics      |
  | 1          | Alice       | Programming  |
  | 2          | Bob         | Math         |
  | ... (9 rows total) | | |

#### Step 2: Count exam attendance per student-subject
- **Output (exam_counts):**

  | student_id | subject_name | attended_exams |
  |------------|-------------|----------------|
  | 1          | Math        | 2              |
  | 1          | Physics     | 1              |
  | 2          | Programming | 2              |

#### Step 3: Left join and fill NULLs with 0
- Student-subject combos without exam records get NULL from the left join, replaced with 0 via `coalesce`.

---

## Method 2: Single Join Chain

```python
from pyspark.sql.functions import col, count, coalesce, lit

result = students.crossJoin(subjects) \
    .join(exams.withColumnRenamed("student_id", "ex_sid")
               .withColumnRenamed("subject_name", "ex_sub"),
          (col("student_id") == col("ex_sid")) & (col("subject_name") == col("ex_sub")),
          "left") \
    .groupBy("student_id", "student_name", "subject_name") \
    .agg(count("ex_sid").alias("attended_exams")) \
    .orderBy("student_id", "subject_name")

result.show()
```

**Note:** `count("ex_sid")` counts only non-NULL matches, giving 0 for unmatched rows automatically.

---

## Method 3: Spark SQL

```python
students.createOrReplaceTempView("students")
subjects.createOrReplaceTempView("subjects")
exams.createOrReplaceTempView("examinations")

result = spark.sql("""
    SELECT
        s.student_id,
        s.student_name,
        sub.subject_name,
        COALESCE(e.attended_exams, 0) AS attended_exams
    FROM students s
    CROSS JOIN subjects sub
    LEFT JOIN (
        SELECT student_id, subject_name, COUNT(*) AS attended_exams
        FROM examinations
        GROUP BY student_id, subject_name
    ) e ON s.student_id = e.student_id AND sub.subject_name = e.subject_name
    ORDER BY s.student_id, sub.subject_name
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| Student with no exams at all | All subjects show count 0 | Cross join ensures all combos exist |
| Subject with no exams | All students show count 0 for it | Same — cross join handles it |
| Empty examinations table | All counts are 0 | Left join produces all NULLs → coalesce to 0 |
| Large number of subjects | Cross join can explode row count | Fine if subjects table is small (dimension table) |

## Key Interview Talking Points

1. **Why cross join is essential:**
   - Without it, student-subject pairs with zero exams would be missing entirely. The cross join creates the "complete grid."

2. **count(column) vs. count(*):**
   - `count("ex_sid")` counts non-NULL values — gives 0 for unmatched left joins.
   - `count("*")` counts all rows including NULLs — would give 1 for unmatched.

3. **Performance consideration:**
   - Cross join is O(students × subjects). Safe when both dimension tables are small.
   - The exam counts aggregation reduces the fact table before the join.

4. **Pattern generalization:**
   - This CROSS JOIN + LEFT JOIN + COUNT pattern appears in many reporting scenarios: "show zero where there's no data."
