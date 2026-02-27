# PySpark Implementation: Top N Records Per Group

## Problem Statement

Given a dataset of employee salaries across different departments, find the **top 3 highest-paid employees in each department**. This is one of the most commonly asked PySpark/SQL interview questions and tests your understanding of window functions, ranking, and filtering.

### Sample Data

```
emp_id  emp_name    department  salary
E001    Alice       Engineering 95000
E002    Bob         Engineering 88000
E003    Charlie     Engineering 92000
E004    Diana       Engineering 87000
E005    Eve         Sales       75000
E006    Frank       Sales       82000
E007    Grace       Sales       79000
E008    Hank        Sales       82000
E009    Ivy         HR          68000
E010    Jack        HR          72000
E011    Kate        HR          70000
```

### Expected Output (Top 3 per department)

| emp_id | emp_name | department  | salary | rank |
|--------|----------|-------------|--------|------|
| E001   | Alice    | Engineering | 95000  | 1    |
| E003   | Charlie  | Engineering | 92000  | 2    |
| E002   | Bob      | Engineering | 88000  | 3    |
| E006   | Frank    | Sales       | 82000  | 1    |
| E008   | Hank     | Sales       | 82000  | 1    |
| E007   | Grace    | Sales       | 79000  | 3    |
| E010   | Jack     | HR          | 72000  | 1    |
| E011   | Kate     | HR          | 70000  | 2    |
| E009   | Ivy      | HR          | 68000  | 3    |

---

## Method 1: Using dense_rank()

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, dense_rank, desc
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("TopNPerGroup").getOrCreate()

# Sample data
data = [
    ("E001", "Alice", "Engineering", 95000),
    ("E002", "Bob", "Engineering", 88000),
    ("E003", "Charlie", "Engineering", 92000),
    ("E004", "Diana", "Engineering", 87000),
    ("E005", "Eve", "Sales", 75000),
    ("E006", "Frank", "Sales", 82000),
    ("E007", "Grace", "Sales", 79000),
    ("E008", "Hank", "Sales", 82000),
    ("E009", "Ivy", "HR", 68000),
    ("E010", "Jack", "HR", 72000),
    ("E011", "Kate", "HR", 70000)
]

columns = ["emp_id", "emp_name", "department", "salary"]
df = spark.createDataFrame(data, columns)

# Define window: partition by department, order by salary descending
window_spec = Window.partitionBy("department").orderBy(desc("salary"))

# Add dense_rank
df_ranked = df.withColumn("rank", dense_rank().over(window_spec))

# Filter for top 3
top_3 = df_ranked.filter(col("rank") <= 3)

top_3.orderBy("department", "rank").show()
```

### Step-by-Step Explanation

#### Step 1: Define Window Specification
- **What happens:** Creates a window that partitions by `department` and orders by `salary` in descending order.
- **No output:** Just a definition.

#### Step 2: Add dense_rank()
- **What happens:** Assigns a rank within each department. Employees with the same salary get the same rank, and the next distinct salary gets the next consecutive rank (no gaps).
- **Output (df_ranked):**

  | emp_id | emp_name | department  | salary | rank |
  |--------|----------|-------------|--------|------|
  | E001   | Alice    | Engineering | 95000  | 1    |
  | E003   | Charlie  | Engineering | 92000  | 2    |
  | E002   | Bob      | Engineering | 88000  | 3    |
  | E004   | Diana    | Engineering | 87000  | 4    |
  | E006   | Frank    | Sales       | 82000  | 1    |
  | E008   | Hank     | Sales       | 82000  | 1    |
  | E007   | Grace    | Sales       | 79000  | 2    |
  | E005   | Eve      | Sales       | 75000  | 3    |
  | E010   | Jack     | HR          | 72000  | 1    |
  | E011   | Kate     | HR          | 70000  | 2    |
  | E009   | Ivy      | HR          | 68000  | 3    |

#### Step 3: Filter rank <= 3
- **What happens:** Keeps only employees ranked in the top 3 per department.
- **Output (top_3):**

  | emp_id | emp_name | department  | salary | rank |
  |--------|----------|-------------|--------|------|
  | E001   | Alice    | Engineering | 95000  | 1    |
  | E003   | Charlie  | Engineering | 92000  | 2    |
  | E002   | Bob      | Engineering | 88000  | 3    |
  | E006   | Frank    | Sales       | 82000  | 1    |
  | E008   | Hank     | Sales       | 82000  | 1    |
  | E007   | Grace    | Sales       | 79000  | 2    |
  | E005   | Eve      | Sales       | 75000  | 3    |
  | E010   | Jack     | HR          | 72000  | 1    |
  | E011   | Kate     | HR          | 70000  | 2    |
  | E009   | Ivy      | HR          | 68000  | 3    |

  **Note:** Sales has 4 employees in top 3 because Frank and Hank are tied at rank 1.

---

## Method 2: Using row_number() (Strict Top N)

```python
from pyspark.sql.functions import row_number

# row_number gives unique ranks — no ties
df_rn = df.withColumn("rn", row_number().over(window_spec))

# Strict top 3 — exactly 3 rows per group
strict_top_3 = df_rn.filter(col("rn") <= 3).drop("rn")

strict_top_3.orderBy("department", desc("salary")).show()
```

- **Explanation:** Unlike `dense_rank()`, `row_number()` assigns unique sequential numbers. For tied records, the assignment is arbitrary. Use this when you need **exactly N rows** per group.

---

## Method 3: Using rank()

```python
from pyspark.sql.functions import rank

# rank() leaves gaps after ties — 1, 1, 3 (not 1, 1, 2)
df_rank = df.withColumn("rnk", rank().over(window_spec))

top_3_rank = df_rank.filter(col("rnk") <= 3)

top_3_rank.orderBy("department", "rnk").show()
```

---

## Comparison: row_number vs rank vs dense_rank

Using the Sales department as an example (Frank and Hank both earn 82000):

| emp_name | salary | row_number | rank | dense_rank |
|----------|--------|------------|------|------------|
| Frank    | 82000  | 1          | 1    | 1          |
| Hank     | 82000  | 2          | 1    | 1          |
| Grace    | 79000  | 3          | 3    | 2          |
| Eve      | 75000  | 4          | 4    | 3          |

**With filter <= 3:**

| Function     | Rows returned for Sales | Eve included? |
|-------------|------------------------|---------------|
| row_number  | 3 (Frank, Hank, Grace) | No            |
| rank        | 2 (Frank, Hank)        | No — Grace gets rank 3, Eve gets rank 4 |
| dense_rank  | 4 (Frank, Hank, Grace, Eve) | Yes — Eve gets dense_rank 3 |

**Correction on rank:** With `rank() <= 3`:
- Frank: rank 1 ✓
- Hank: rank 1 ✓
- Grace: rank 3 ✓
- Eve: rank 4 ✗

So `rank() <= 3` returns 3 employees for Sales.

---

## Method 4: Without Window Functions (Using Join)

```python
from pyspark.sql.functions import count, lit

# For each department, find the 3rd highest salary threshold
thresholds = df.groupBy("department") \
    .agg({"salary": "collect_list"})

# Alternative: self-join approach
# Count how many employees in the same dept have a higher salary
df_with_count = df.alias("a").join(
    df.alias("b"),
    (col("a.department") == col("b.department")) & (col("a.salary") < col("b.salary")),
    "left"
).groupBy(
    col("a.emp_id"), col("a.emp_name"), col("a.department"), col("a.salary")
).agg(
    count(col("b.emp_id")).alias("higher_count")
).filter(col("higher_count") < 3)

df_with_count.show()
```

- **Explanation:** For each employee, counts how many people in the same department earn more. If fewer than 3 people earn more, that employee is in the top 3. This avoids window functions but is less efficient.

---

## Key Interview Talking Points

1. **Which ranking function to use?**
   - `row_number()`: Exactly N results, no ties. Use for strict limits.
   - `dense_rank()`: Handles ties, may return more than N rows. Use when ties should be included.
   - `rank()`: Similar to dense_rank but with gaps in ranking after ties.

2. **Performance:** Window functions require sorting within each partition. Ensure the partition key has good cardinality (not too few, not too many groups).

3. **Follow-up questions interviewers ask:**
   - "What if there are ties?" → Explain the difference between the three ranking functions.
   - "What if N is very large?" → Consider using `percentile_approx()` or sampling instead.
   - "How would you do this in SQL?" → Same logic with `OVER(PARTITION BY ... ORDER BY ...)`.

4. **Real-world use cases:**
   - Top N products by revenue per category
   - Top N customers by spend per region
   - Most recent N events per user (with `orderBy(desc("timestamp"))`)
