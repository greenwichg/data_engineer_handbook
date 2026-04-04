# PySpark Implementation: Multi-Column Ranking

## Problem Statement

A common data engineering interview question involves ranking rows where ties need to be broken using additional columns. For example, ranking employees within each department by salary, but when two employees have the same salary, the one hired earlier gets a higher rank. This tests your understanding of window functions, `orderBy` with multiple columns, and the differences between `rank()`, `dense_rank()`, and `row_number()`.

**Interview Prompt:** Rank employees within each department by salary (highest first). Break ties using hire date (earlier date ranks higher). If salary and hire date are the same, break by employee name alphabetically.

### Sample Data

```
| emp_id | emp_name  | department | salary | hire_date  |
|--------|-----------|------------|--------|------------|
| 101    | Alice     | Engineering| 120000 | 2020-03-15 |
| 102    | Bob       | Engineering| 120000 | 2019-07-01 |
| 103    | Charlie   | Engineering| 110000 | 2021-01-10 |
| 104    | Diana     | Engineering| 130000 | 2018-06-20 |
| 105    | Eve       | Sales      | 90000  | 2020-01-05 |
| 106    | Frank     | Sales      | 95000  | 2021-03-15 |
| 107    | Grace     | Sales      | 95000  | 2021-03-15 |
| 108    | Hank      | Sales      | 85000  | 2019-11-20 |
```

### Expected Output

| emp_id | emp_name  | department  | salary | hire_date  | rank |
|--------|-----------|-------------|--------|------------|------|
| 104    | Diana     | Engineering | 130000 | 2018-06-20 | 1    |
| 102    | Bob       | Engineering | 120000 | 2019-07-01 | 2    |
| 101    | Alice     | Engineering | 120000 | 2020-03-15 | 3    |
| 103    | Charlie   | Engineering | 110000 | 2021-01-10 | 4    |
| 106    | Frank     | Sales       | 95000  | 2021-03-15 | 1    |
| 107    | Grace     | Sales       | 95000  | 2021-03-15 | 2    |
| 105    | Eve       | Sales       | 90000  | 2020-01-05 | 3    |
| 108    | Hank      | Sales       | 85000  | 2019-11-20 | 4    |

---

## Method 1: row_number() with Multi-Column OrderBy

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("MultiColumnRanking") \
    .master("local[*]") \
    .getOrCreate()

data = [
    (101, "Alice",   "Engineering", 120000, "2020-03-15"),
    (102, "Bob",     "Engineering", 120000, "2019-07-01"),
    (103, "Charlie", "Engineering", 110000, "2021-01-10"),
    (104, "Diana",   "Engineering", 130000, "2018-06-20"),
    (105, "Eve",     "Sales",       90000,  "2020-01-05"),
    (106, "Frank",   "Sales",       95000,  "2021-03-15"),
    (107, "Grace",   "Sales",       95000,  "2021-03-15"),
    (108, "Hank",    "Sales",       85000,  "2019-11-20"),
]

df = spark.createDataFrame(data, ["emp_id", "emp_name", "department", "salary", "hire_date"])
df = df.withColumn("hire_date", F.to_date("hire_date"))

# row_number() guarantees unique ranks (no ties)
# Order: salary DESC, hire_date ASC (earlier = better), emp_name ASC (alphabetical tiebreaker)
window_spec = Window.partitionBy("department").orderBy(
    F.col("salary").desc(),
    F.col("hire_date").asc(),
    F.col("emp_name").asc()
)

result = df.withColumn("rank", F.row_number().over(window_spec))

result.orderBy("department", "rank").show(truncate=False)
```

---

## Method 2: Comparing rank(), dense_rank(), and row_number()

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("MultiColumnRanking_Compare") \
    .master("local[*]") \
    .getOrCreate()

data = [
    (101, "Alice",   "Engineering", 120000, "2020-03-15"),
    (102, "Bob",     "Engineering", 120000, "2019-07-01"),
    (103, "Charlie", "Engineering", 110000, "2021-01-10"),
    (104, "Diana",   "Engineering", 130000, "2018-06-20"),
    (105, "Eve",     "Sales",       90000,  "2020-01-05"),
    (106, "Frank",   "Sales",       95000,  "2021-03-15"),
    (107, "Grace",   "Sales",       95000,  "2021-03-15"),
    (108, "Hank",    "Sales",       85000,  "2019-11-20"),
]

df = spark.createDataFrame(data, ["emp_id", "emp_name", "department", "salary", "hire_date"])
df = df.withColumn("hire_date", F.to_date("hire_date"))

# Window ordered ONLY by salary to show tie behavior
window_salary_only = Window.partitionBy("department").orderBy(F.col("salary").desc())

# Window with full tiebreaking
window_full = Window.partitionBy("department").orderBy(
    F.col("salary").desc(),
    F.col("hire_date").asc(),
    F.col("emp_name").asc()
)

result = df \
    .withColumn("rank_salary_only", F.rank().over(window_salary_only)) \
    .withColumn("dense_rank_salary_only", F.dense_rank().over(window_salary_only)) \
    .withColumn("row_number_salary_only", F.row_number().over(window_salary_only)) \
    .withColumn("row_number_full", F.row_number().over(window_full))

result.orderBy("department", "row_number_full").show(truncate=False)

# Key differences visible in output:
# rank()       -> Ties get same rank, next rank is skipped (1, 1, 3)
# dense_rank() -> Ties get same rank, next rank is NOT skipped (1, 1, 2)
# row_number() -> No ties ever, non-deterministic for ties unless fully ordered
```

---

## Method 3: Using Spark SQL Syntax

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("MultiColumnRanking_SQL") \
    .master("local[*]") \
    .getOrCreate()

data = [
    (101, "Alice",   "Engineering", 120000, "2020-03-15"),
    (102, "Bob",     "Engineering", 120000, "2019-07-01"),
    (103, "Charlie", "Engineering", 110000, "2021-01-10"),
    (104, "Diana",   "Engineering", 130000, "2018-06-20"),
    (105, "Eve",     "Sales",       90000,  "2020-01-05"),
    (106, "Frank",   "Sales",       95000,  "2021-03-15"),
    (107, "Grace",   "Sales",       95000,  "2021-03-15"),
    (108, "Hank",    "Sales",       85000,  "2019-11-20"),
]

df = spark.createDataFrame(data, ["emp_id", "emp_name", "department", "salary", "hire_date"])
df = df.withColumn("hire_date", F.to_date("hire_date"))
df.createOrReplaceTempView("employees")

result = spark.sql("""
    SELECT
        emp_id,
        emp_name,
        department,
        salary,
        hire_date,
        ROW_NUMBER() OVER (
            PARTITION BY department
            ORDER BY salary DESC, hire_date ASC, emp_name ASC
        ) AS rank,
        RANK() OVER (
            PARTITION BY department
            ORDER BY salary DESC
        ) AS salary_rank,
        DENSE_RANK() OVER (
            PARTITION BY department
            ORDER BY salary DESC
        ) AS salary_dense_rank
    FROM employees
    ORDER BY department, rank
""")

result.show(truncate=False)
```

---

## Method 4: Top-N Per Group with Multi-Column Ranking

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("TopN_MultiColumn") \
    .master("local[*]") \
    .getOrCreate()

data = [
    (101, "Alice",   "Engineering", 120000, "2020-03-15"),
    (102, "Bob",     "Engineering", 120000, "2019-07-01"),
    (103, "Charlie", "Engineering", 110000, "2021-01-10"),
    (104, "Diana",   "Engineering", 130000, "2018-06-20"),
    (105, "Eve",     "Sales",       90000,  "2020-01-05"),
    (106, "Frank",   "Sales",       95000,  "2021-03-15"),
    (107, "Grace",   "Sales",       95000,  "2021-03-15"),
    (108, "Hank",    "Sales",       85000,  "2019-11-20"),
]

df = spark.createDataFrame(data, ["emp_id", "emp_name", "department", "salary", "hire_date"])
df = df.withColumn("hire_date", F.to_date("hire_date"))

window_spec = Window.partitionBy("department").orderBy(
    F.col("salary").desc(),
    F.col("hire_date").asc(),
    F.col("emp_name").asc()
)

# Get top 2 employees per department
top_2 = df.withColumn("rank", F.row_number().over(window_spec)) \
    .filter(F.col("rank") <= 2)

top_2.orderBy("department", "rank").show(truncate=False)
```

---

## Key Concepts

- **`row_number()`** always produces unique sequential integers. If the ordering is not fully deterministic, the assignment among tied rows is arbitrary but still unique.
- **`rank()`** assigns the same rank to tied rows but leaves gaps (1, 1, 3, 4).
- **`dense_rank()`** assigns the same rank to tied rows without gaps (1, 1, 2, 3).
- **Multi-column `orderBy`** is the key technique for deterministic ranking. Always add enough columns to break all possible ties.
- **Descending vs ascending** - Use `.desc()` and `.asc()` explicitly to control direction per column.

## Interview Tips

- Interviewers will test whether you know the difference between rank(), dense_rank(), and row_number(). Be ready to explain with an example.
- If asked for "top N per group," use `row_number()` with a filter, not `rank()`, unless the interviewer says ties should share the same position.
- Always mention determinism: `row_number()` on tied rows is non-deterministic unless the ordering is fully specified.
- A common mistake is forgetting `.desc()` for salary rankings. By default, `orderBy` is ascending.
