# PySpark Implementation: Null-Safe Joins

## Problem Statement

When joining DataFrames in PySpark, null values in join keys cause rows to be dropped because `NULL != NULL` in standard SQL semantics. In many real-world scenarios, you need to match rows where both sides have null in a join column. PySpark provides `eqNullSafe` (equivalent to the SQL `<=>` operator) to handle this. This is a commonly tested interview topic that evaluates understanding of join semantics and null handling.

### Sample Data

**Employees Table:**
```
emp_id | name    | dept_id
1      | Alice   | 101
2      | Bob     | 102
3      | Charlie | NULL
4      | Diana   | 101
5      | Eve     | NULL
```

**Departments Table:**
```
dept_id | dept_name
101     | Engineering
102     | Marketing
NULL    | Unassigned
```

### Expected Output (Null-Safe Join)

| emp_id | name    | dept_id | dept_name   |
|--------|---------|---------|-------------|
| 1      | Alice   | 101     | Engineering |
| 2      | Bob     | 102     | Marketing   |
| 3      | Charlie | NULL    | Unassigned  |
| 4      | Diana   | 101     | Engineering |
| 5      | Eve     | NULL    | Unassigned  |

---

## Method 1: Using eqNullSafe

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("NullSafeJoins") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
emp_data = [
    (1, "Alice",   101),
    (2, "Bob",     102),
    (3, "Charlie", None),
    (4, "Diana",   101),
    (5, "Eve",     None),
]

dept_data = [
    (101, "Engineering"),
    (102, "Marketing"),
    (None, "Unassigned"),
]

employees = spark.createDataFrame(emp_data, ["emp_id", "name", "dept_id"])
departments = spark.createDataFrame(dept_data, ["dept_id", "dept_name"])

print("=== Standard Join (drops nulls) ===")
standard_join = employees.join(
    departments,
    employees["dept_id"] == departments["dept_id"],
    "left"
).select(
    employees["emp_id"],
    employees["name"],
    employees["dept_id"],
    departments["dept_name"]
)
standard_join.show()

print("=== Null-Safe Join (matches nulls) ===")
null_safe_join = employees.join(
    departments,
    employees["dept_id"].eqNullSafe(departments["dept_id"]),
    "inner"
).select(
    employees["emp_id"],
    employees["name"],
    employees["dept_id"],
    departments["dept_name"]
)
null_safe_join.show()

spark.stop()
```

## Method 2: Using Spark SQL with `<=>` Operator

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("NullSafeJoins_SQL") \
    .master("local[*]") \
    .getOrCreate()

emp_data = [
    (1, "Alice",   101),
    (2, "Bob",     102),
    (3, "Charlie", None),
    (4, "Diana",   101),
    (5, "Eve",     None),
]

dept_data = [
    (101, "Engineering"),
    (102, "Marketing"),
    (None, "Unassigned"),
]

employees = spark.createDataFrame(emp_data, ["emp_id", "name", "dept_id"])
departments = spark.createDataFrame(dept_data, ["dept_id", "dept_name"])

employees.createOrReplaceTempView("employees")
departments.createOrReplaceTempView("departments")

# The <=> operator is the null-safe equality operator in Spark SQL
result = spark.sql("""
    SELECT
        e.emp_id,
        e.name,
        e.dept_id,
        d.dept_name
    FROM employees e
    JOIN departments d
        ON e.dept_id <=> d.dept_id
    ORDER BY e.emp_id
""")

result.show()

spark.stop()
```

## Method 3: Coalesce Workaround (Sentinel Value)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, coalesce, lit, when

spark = SparkSession.builder \
    .appName("NullSafeJoins_Coalesce") \
    .master("local[*]") \
    .getOrCreate()

emp_data = [
    (1, "Alice",   101),
    (2, "Bob",     102),
    (3, "Charlie", None),
    (4, "Diana",   101),
    (5, "Eve",     None),
]

dept_data = [
    (101, "Engineering"),
    (102, "Marketing"),
    (None, "Unassigned"),
]

employees = spark.createDataFrame(emp_data, ["emp_id", "name", "dept_id"])
departments = spark.createDataFrame(dept_data, ["dept_id", "dept_name"])

# Replace NULL with a sentinel value before joining
SENTINEL = -999

employees_safe = employees.withColumn(
    "dept_id_safe", coalesce(col("dept_id"), lit(SENTINEL))
)
departments_safe = departments.withColumn(
    "dept_id_safe", coalesce(col("dept_id"), lit(SENTINEL))
)

result = employees_safe.join(
    departments_safe,
    employees_safe["dept_id_safe"] == departments_safe["dept_id_safe"],
    "inner"
).select(
    employees_safe["emp_id"],
    employees_safe["name"],
    employees_safe["dept_id"],
    departments_safe["dept_name"]
).orderBy("emp_id")

result.show()

spark.stop()
```

## Method 4: Multi-Column Null-Safe Join

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col
from functools import reduce
from operator import and_

spark = SparkSession.builder \
    .appName("NullSafeJoins_MultiColumn") \
    .master("local[*]") \
    .getOrCreate()

# Tables with multiple join keys that can be null
orders_data = [
    (1, "2024-01-01", "US",   "CA",   100),
    (2, "2024-01-02", "US",   None,   200),
    (3, "2024-01-03", None,   None,   150),
]

tax_rates_data = [
    ("US",   "CA",   0.08),
    ("US",   None,   0.05),  # Default US rate when state unknown
    (None,   None,   0.10),  # Default rate when country unknown
]

orders = spark.createDataFrame(orders_data, ["order_id", "date", "country", "state", "amount"])
tax_rates = spark.createDataFrame(tax_rates_data, ["country", "state", "tax_rate"])

# Multi-column null-safe join
join_cols = ["country", "state"]
join_condition = reduce(
    and_,
    [orders[c].eqNullSafe(tax_rates[c]) for c in join_cols]
)

result = orders.join(tax_rates, join_condition, "left").select(
    orders["order_id"],
    orders["country"],
    orders["state"],
    orders["amount"],
    tax_rates["tax_rate"],
    (orders["amount"] * tax_rates["tax_rate"]).alias("tax_amount")
)

result.show()

spark.stop()
```

## Key Concepts

- **Standard `==` join**: `NULL == NULL` evaluates to `NULL` (falsy), so null-keyed rows are dropped from inner joins and unmatched in left joins.
- **`eqNullSafe` / `<=>`**: `NULL <=> NULL` evaluates to `TRUE`, allowing null keys to match.
- **When to use**: Null-safe joins are essential when NULL represents a meaningful category (e.g., "Unassigned", "Unknown") rather than missing data.
- **Performance**: `eqNullSafe` can prevent broadcast join optimization in some Spark versions. Test performance with your data.
- **Sentinel approach**: An alternative that works with standard joins. Choose a sentinel value that cannot appear in real data.
- **Interview Tip**: Explain the semantic difference between NULL meaning "unknown" vs. NULL meaning "not applicable". Null-safe joins make sense for the latter case. Also mention that this is equivalent to `IS NOT DISTINCT FROM` in standard SQL.
