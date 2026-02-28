# PySpark Implementation: Employee Hierarchy (Recursive / Tree Traversal)

## Problem Statement

Given an employee table with a self-referencing `manager_id`, build the **full organizational hierarchy** showing each employee's level in the tree. This tests your ability to handle recursive/hierarchical data — a common pattern in HR systems, org charts, and bill-of-materials queries.

### Sample Data

```
id  employee_name  manager_id
1   Alice          null
2   Bob            1
3   Charlie        1
4   Diana          2
5   Eve            2
6   Frank          3
```

### Expected Output

| id | employee_name | manager_id | level |
|----|---------------|------------|-------|
| 1  | Alice         | null       | 0     |
| 2  | Bob           | 1          | 1     |
| 3  | Charlie       | 1          | 1     |
| 4  | Diana         | 2          | 2     |
| 5  | Eve           | 2          | 2     |
| 6  | Frank         | 3          | 2     |

### Organizational Chart

```
         Alice (1)               ← Level 0 (CEO)
         /      \
        /        \
    Bob (2)    Charlie (3)       ← Level 1
    /    \          \
   /      \          \
Diana (4) Eve (5)   Frank (6)    ← Level 2
```

---

## Method 1: SQL Recursive CTE (Spark SQL 3.4+)

```python
from pyspark.sql import SparkSession

# Initialize Spark session
spark = SparkSession.builder.appName("EmployeeHierarchy").getOrCreate()

# Sample data
data = [
    (1, "Alice", None),
    (2, "Bob", 1),
    (3, "Charlie", 1),
    (4, "Diana", 2),
    (5, "Eve", 2),
    (6, "Frank", 3)
]
columns = ["id", "employee_name", "manager_id"]
df = spark.createDataFrame(data, columns)
df.createOrReplaceTempView("employees")

# Recursive CTE (supported in Spark 3.4+)
hierarchy_sql = spark.sql("""
    WITH RECURSIVE EmployeeHierarchy AS (
        -- Base case: Top-level employees (no manager)
        SELECT
            id,
            employee_name,
            manager_id,
            0 AS level
        FROM employees
        WHERE manager_id IS NULL

        UNION ALL

        -- Recursive case: Find employees who report to current level
        SELECT
            e.id,
            e.employee_name,
            e.manager_id,
            eh.level + 1
        FROM employees e
        INNER JOIN EmployeeHierarchy eh ON e.manager_id = eh.id
    )
    SELECT * FROM EmployeeHierarchy
    ORDER BY level, id
""")

hierarchy_sql.show()
```

### Step-by-Step Explanation

#### Iteration 1 (Base Case)
- Find employees where `manager_id IS NULL` → Alice (level 0)

  | id | employee_name | manager_id | level |
  |----|---------------|------------|-------|
  | 1  | Alice         | null       | 0     |

#### Iteration 2 (First Recursion)
- Join employees on `manager_id = eh.id` where eh is the previous result
- Bob and Charlie report to Alice (id=1) → level 1

  | id | employee_name | manager_id | level |
  |----|---------------|------------|-------|
  | 2  | Bob           | 1          | 1     |
  | 3  | Charlie       | 1          | 1     |

#### Iteration 3 (Second Recursion)
- Diana and Eve report to Bob (id=2), Frank reports to Charlie (id=3) → level 2

  | id | employee_name | manager_id | level |
  |----|---------------|------------|-------|
  | 4  | Diana         | 2          | 2     |
  | 5  | Eve           | 2          | 2     |
  | 6  | Frank         | 3          | 2     |

#### Iteration 4
- No more employees to find → recursion stops

---

## Method 2: Iterative DataFrame API (Works on All Spark Versions)

```python
from pyspark.sql.functions import col, lit, broadcast

# Start with root nodes (no manager)
current_level = df.filter(col("manager_id").isNull()) \
    .withColumn("level", lit(0))

result = current_level
level = 0
max_depth = 20  # Safety limit to prevent infinite loops

# Iteratively find children at each level
while level < max_depth:
    level += 1

    # Find employees whose manager_id matches a parent's id
    parent_ids = current_level.select(col("id").alias("parent_id"))
    next_level = df.join(
        broadcast(parent_ids),
        col("manager_id") == col("parent_id"),
        "inner"
    ).drop("parent_id").withColumn("level", lit(level))

    # Check if there are any children at this level
    if next_level.count() == 0:
        break

    result = result.unionByName(next_level)
    current_level = next_level

result.orderBy("level", "id").show()
```

### How It Works

```
Iteration 0: Find roots          → Alice (level 0)
Iteration 1: Children of Alice   → Bob, Charlie (level 1)
Iteration 2: Children of Bob, Charlie → Diana, Eve, Frank (level 2)
Iteration 3: No more children    → STOP
```

- **Output:**

  | id | employee_name | manager_id | level |
  |----|---------------|------------|-------|
  | 1  | Alice         | null       | 0     |
  | 2  | Bob           | 1          | 1     |
  | 3  | Charlie       | 1          | 1     |
  | 4  | Diana         | 2          | 2     |
  | 5  | Eve           | 2          | 2     |
  | 6  | Frank         | 3          | 2     |

---

## Method 3: Building the Full Reporting Path

```python
from pyspark.sql.functions import concat_ws

# Start with root
current = df.filter(col("manager_id").isNull()) \
    .withColumn("level", lit(0)) \
    .withColumn("path", col("employee_name"))

result_path = current
level = 0

while level < 20:
    level += 1
    parent_ids = current.select(
        col("id").alias("parent_id"),
        col("path").alias("parent_path")
    )

    next_level = df.join(
        broadcast(parent_ids),
        col("manager_id") == col("parent_id"),
        "inner"
    ).withColumn("level", lit(level)) \
     .withColumn("path", concat_ws(" > ", col("parent_path"), col("employee_name"))) \
     .drop("parent_id", "parent_path")

    if next_level.count() == 0:
        break

    result_path = result_path.unionByName(next_level)
    current = next_level

result_path.orderBy("level", "id").show(truncate=False)
```

- **Output:**

  | id | employee_name | manager_id | level | path                    |
  |----|---------------|------------|-------|-------------------------|
  | 1  | Alice         | null       | 0     | Alice                   |
  | 2  | Bob           | 1          | 1     | Alice > Bob             |
  | 3  | Charlie       | 1          | 1     | Alice > Charlie         |
  | 4  | Diana         | 2          | 2     | Alice > Bob > Diana     |
  | 5  | Eve           | 2          | 2     | Alice > Bob > Eve       |
  | 6  | Frank         | 3          | 2     | Alice > Charlie > Frank |

---

## Key Interview Talking Points

1. **Recursive CTE support:** Spark 3.4+ supports `WITH RECURSIVE`. For older versions, use the iterative DataFrame approach (Method 2).

2. **Performance of iterative approach:** Each iteration requires a join + count action. For deep hierarchies (10+ levels), this means many Spark jobs. Broadcast the smaller DataFrame (parent IDs) to avoid shuffle.

3. **Max depth safety:** Always add a maximum depth check to prevent infinite loops in case of circular references in the data.

4. **Common variations:**
   - Find all reports (direct + indirect) for a manager
   - Calculate team size at each level
   - Find the reporting chain for a specific employee
   - Detect circular references

5. **Real-world use cases:**
   - Org charts and HR reporting hierarchies
   - Bill of materials (parts → sub-parts)
   - Category trees (parent category → child category)
   - File system directory structures
