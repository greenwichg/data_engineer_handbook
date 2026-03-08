# PySpark Implementation: Managers with At Least N Direct Reports

## Problem Statement

Given an `Employee` table with `id`, `name`, `department`, and `managerId`, find managers who have **at least 5 direct reports**. This is **LeetCode 570 — Managers with at Least 5 Direct Reports**.

### Sample Data

```
id  name      department  managerId
1   John      IT          null
2   Alice     IT          1
3   Bob       IT          1
4   Charlie   IT          1
5   Diana     IT          1
6   Eve       IT          1
7   Frank     Sales       1
8   Grace     Sales       null
9   Hank      Sales       8
10  Ivy       Sales       8
```

### Expected Output

| name |
|------|
| John |

**Explanation:** John (id=1) has 6 direct reports (ids 2-7). Grace has only 2.

---

## Method 1: GroupBy + Having + Join (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count

spark = SparkSession.builder.appName("ManagerReports").getOrCreate()

data = [
    (1, "John", "IT", None),
    (2, "Alice", "IT", 1),
    (3, "Bob", "IT", 1),
    (4, "Charlie", "IT", 1),
    (5, "Diana", "IT", 1),
    (6, "Eve", "IT", 1),
    (7, "Frank", "Sales", 1),
    (8, "Grace", "Sales", None),
    (9, "Hank", "Sales", 8),
    (10, "Ivy", "Sales", 8)
]

columns = ["id", "name", "department", "managerId"]
df = spark.createDataFrame(data, columns)

N = 5

# Count direct reports per manager
manager_counts = df.filter(col("managerId").isNotNull()) \
    .groupBy("managerId") \
    .agg(count("*").alias("report_count")) \
    .filter(col("report_count") >= N)

# Join back to get manager names
result = manager_counts.join(df, manager_counts["managerId"] == df["id"]) \
    .select(df["name"])

result.show()
```

### Step-by-Step Explanation

#### Step 1: Count reports per managerId
- **What happens:** Group employees by their `managerId` and count how many report to each.

  | managerId | report_count |
  |-----------|-------------|
  | 1         | 6           |
  | 8         | 2           |

#### Step 2: Filter managers with >= N reports
- **What happens:** Only managerId=1 passes with 6 ≥ 5.

  | managerId | report_count |
  |-----------|-------------|
  | 1         | 6           |

#### Step 3: Join back to get manager name
- **Output:** John

---

## Method 2: Using Left Semi Join

```python
from pyspark.sql.functions import col, count

# Managers with enough reports (as a subquery)
qualified_managers = df.filter(col("managerId").isNotNull()) \
    .groupBy(col("managerId").alias("mgr_id")) \
    .agg(count("*").alias("cnt")) \
    .filter(col("cnt") >= N)

# Semi join: keep only employees whose id appears as a qualified manager
result = df.join(qualified_managers, df["id"] == qualified_managers["mgr_id"], "left_semi") \
    .select("name")

result.show()
```

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("employee")

result = spark.sql("""
    SELECT e.name
    FROM employee e
    JOIN (
        SELECT managerId, COUNT(*) AS cnt
        FROM employee
        WHERE managerId IS NOT NULL
        GROUP BY managerId
        HAVING COUNT(*) >= 5
    ) m ON e.id = m.managerId
""")

result.show()

# Alternative: using IN subquery
result2 = spark.sql("""
    SELECT name
    FROM employee
    WHERE id IN (
        SELECT managerId
        FROM employee
        GROUP BY managerId
        HAVING COUNT(*) >= 5
    )
""")

result2.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| No one has >= N reports | Empty result | Correct behavior |
| CEO (managerId = NULL) | Excluded from groupBy | Filter NULLs before grouping |
| Manager not in employee table | managerId references missing id | Join returns no match — manager excluded |
| Self-managing (managerId = id) | Counts as own report | Unusual but works with same logic |

## Key Interview Talking Points

1. **GROUP BY + HAVING vs. window function:**
   - GROUP BY + HAVING is the natural fit here since we're counting per group and filtering.
   - Window functions would add a column to every row, then filter — unnecessary overhead.

2. **Why join back?**
   - The GROUP BY is on `managerId`, but we need the manager's `name`. The join resolves the id → name lookup.

3. **IN subquery vs. JOIN:**
   - `WHERE id IN (subquery)` is equivalent to a semi join — Spark optimizes both the same way.

4. **Follow-up: "Also return the report count?"**
   - Keep `report_count` in the join result: `.select(df["name"], manager_counts["report_count"])`.

5. **Generalization:**
   - This pattern (GROUP BY foreign key + HAVING + JOIN back) appears in many problems: "find X that has at least N related Y."
