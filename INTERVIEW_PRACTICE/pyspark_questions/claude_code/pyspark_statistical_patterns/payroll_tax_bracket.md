# PySpark Implementation: Payroll Tax Bracket Calculations

## Problem Statement

Implement progressive tax bracket calculations where different portions of income are taxed at different rates. Given a tax bracket table and employee salary data, compute the total tax owed by each employee by applying tiered rates to the appropriate income ranges. This is a common interview question that tests your ability to handle range-based calculations, which appears in payroll systems, financial platforms, and pricing engines.

### Sample Data

**Tax Brackets:**

| bracket_id | lower_bound | upper_bound | rate |
|------------|-------------|-------------|------|
| 1          | 0           | 10000       | 0.10 |
| 2          | 10000       | 40000       | 0.12 |
| 3          | 40000       | 85000       | 0.22 |
| 4          | 85000       | 165000      | 0.24 |
| 5          | 165000      | 215000      | 0.32 |
| 6          | 215000      | 540000      | 0.35 |
| 7          | 540000      | 999999999   | 0.37 |

**Employees:**

| emp_id | name    | annual_salary |
|--------|---------|---------------|
| 1      | Alice   | 55000         |
| 2      | Bob     | 120000        |
| 3      | Carol   | 8000          |
| 4      | Dave    | 250000        |

### Expected Output

| emp_id | name  | annual_salary | total_tax | effective_rate |
|--------|-------|---------------|-----------|----------------|
| 1      | Alice | 55000         | 7660.00   | 0.1393         |
| 2      | Bob   | 120000        | 19540.00  | 0.1628         |
| 3      | Carol | 8000          | 800.00    | 0.1000         |
| 4      | Dave  | 250000        | 52832.00  | 0.2113         |

---

## Method 1: Cross Join with Bracket Logic

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# Initialize Spark
spark = SparkSession.builder \
    .appName("Payroll Tax Bracket Calculations") \
    .master("local[*]") \
    .getOrCreate()

# --- Tax Bracket Data ---
brackets_data = [
    (1, 0, 10000, 0.10),
    (2, 10000, 40000, 0.12),
    (3, 40000, 85000, 0.22),
    (4, 85000, 165000, 0.24),
    (5, 165000, 215000, 0.32),
    (6, 215000, 540000, 0.35),
    (7, 540000, 999999999, 0.37),
]

brackets_df = spark.createDataFrame(
    brackets_data,
    ["bracket_id", "lower_bound", "upper_bound", "rate"]
)

# --- Employee Data ---
employees_data = [
    (1, "Alice", 55000),
    (2, "Bob", 120000),
    (3, "Carol", 8000),
    (4, "Dave", 250000),
]

employees_df = spark.createDataFrame(employees_data, ["emp_id", "name", "annual_salary"])

print("=== Tax Brackets ===")
brackets_df.show()
print("=== Employees ===")
employees_df.show()

# Cross join employees with all brackets
emp_brackets = employees_df.crossJoin(brackets_df)

# Calculate taxable amount in each bracket
# For each bracket, the taxable portion is:
#   min(salary, upper_bound) - lower_bound, but never negative
emp_brackets = emp_brackets.withColumn(
    "taxable_in_bracket",
    F.greatest(
        F.least(F.col("annual_salary"), F.col("upper_bound")) - F.col("lower_bound"),
        F.lit(0)
    )
).withColumn(
    "tax_in_bracket",
    F.round(F.col("taxable_in_bracket") * F.col("rate"), 2)
)

print("=== Bracket Breakdown for Each Employee ===")
emp_brackets.filter(F.col("taxable_in_bracket") > 0) \
    .select("emp_id", "name", "bracket_id", "lower_bound", "upper_bound",
            "rate", "taxable_in_bracket", "tax_in_bracket") \
    .orderBy("emp_id", "bracket_id") \
    .show(50)

# Aggregate total tax per employee
result = emp_brackets.groupBy("emp_id", "name", "annual_salary").agg(
    F.round(F.sum("tax_in_bracket"), 2).alias("total_tax")
).withColumn(
    "effective_rate",
    F.round(F.col("total_tax") / F.col("annual_salary"), 4)
).orderBy("emp_id")

print("=== Final Tax Summary ===")
result.show()

spark.stop()
```

## Method 2: SQL with Detailed Bracket Breakdown

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Tax Brackets - SQL") \
    .master("local[*]") \
    .getOrCreate()

# --- Data ---
brackets_data = [
    (1, 0, 10000, 0.10),
    (2, 10000, 40000, 0.12),
    (3, 40000, 85000, 0.22),
    (4, 85000, 165000, 0.24),
    (5, 165000, 215000, 0.32),
    (6, 215000, 540000, 0.35),
    (7, 540000, 999999999, 0.37),
]

employees_data = [
    (1, "Alice", 55000),
    (2, "Bob", 120000),
    (3, "Carol", 8000),
    (4, "Dave", 250000),
    (5, "Eve", 540001),
]

brackets_df = spark.createDataFrame(brackets_data, ["bracket_id", "lower_bound", "upper_bound", "rate"])
employees_df = spark.createDataFrame(employees_data, ["emp_id", "name", "annual_salary"])

brackets_df.createOrReplaceTempView("brackets")
employees_df.createOrReplaceTempView("employees")

# --- Detailed bracket-by-bracket tax computation ---
detailed_tax = spark.sql("""
    SELECT
        e.emp_id,
        e.name,
        e.annual_salary,
        b.bracket_id,
        b.lower_bound,
        b.upper_bound,
        b.rate,
        GREATEST(LEAST(e.annual_salary, b.upper_bound) - b.lower_bound, 0) AS taxable_in_bracket,
        ROUND(GREATEST(LEAST(e.annual_salary, b.upper_bound) - b.lower_bound, 0) * b.rate, 2) AS tax_in_bracket
    FROM employees e
    CROSS JOIN brackets b
    WHERE e.annual_salary > b.lower_bound
    ORDER BY e.emp_id, b.bracket_id
""")

print("=== Detailed Tax Breakdown ===")
detailed_tax.show(50)

# --- Summary with marginal and effective rates ---
summary = spark.sql("""
    WITH tax_detail AS (
        SELECT
            e.emp_id,
            e.name,
            e.annual_salary,
            b.bracket_id,
            b.rate AS bracket_rate,
            GREATEST(LEAST(e.annual_salary, b.upper_bound) - b.lower_bound, 0) AS taxable_in_bracket,
            ROUND(GREATEST(LEAST(e.annual_salary, b.upper_bound) - b.lower_bound, 0) * b.rate, 2) AS tax_in_bracket
        FROM employees e
        CROSS JOIN brackets b
        WHERE e.annual_salary > b.lower_bound
    ),
    marginal AS (
        SELECT emp_id, MAX(bracket_rate) AS marginal_rate
        FROM tax_detail
        WHERE taxable_in_bracket > 0
        GROUP BY emp_id
    )
    SELECT
        t.emp_id,
        t.name,
        t.annual_salary,
        ROUND(SUM(t.tax_in_bracket), 2) AS total_tax,
        ROUND(SUM(t.tax_in_bracket) / t.annual_salary, 4) AS effective_rate,
        m.marginal_rate
    FROM tax_detail t
    JOIN marginal m ON t.emp_id = m.emp_id
    GROUP BY t.emp_id, t.name, t.annual_salary, m.marginal_rate
    ORDER BY t.emp_id
""")

print("=== Tax Summary with Marginal vs Effective Rate ===")
summary.show()

spark.stop()
```

## Method 3: UDF Approach for Complex Tax Scenarios

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import DoubleType, ArrayType, StructType, StructField, IntegerType

spark = SparkSession.builder \
    .appName("Tax Brackets - UDF") \
    .master("local[*]") \
    .getOrCreate()

# Define brackets as a broadcast variable for efficiency
brackets = [
    (0, 10000, 0.10),
    (10000, 40000, 0.12),
    (40000, 85000, 0.22),
    (85000, 165000, 0.24),
    (165000, 215000, 0.32),
    (215000, 540000, 0.35),
    (540000, 999999999, 0.37),
]

broadcast_brackets = spark.sparkContext.broadcast(brackets)

@F.udf(DoubleType())
def compute_tax(salary):
    """Compute progressive tax for a given salary."""
    if salary is None or salary <= 0:
        return 0.0
    total_tax = 0.0
    for lower, upper, rate in broadcast_brackets.value:
        if salary <= lower:
            break
        taxable = min(salary, upper) - lower
        total_tax += taxable * rate
    return round(total_tax, 2)

employees_data = [
    (1, "Alice", 55000), (2, "Bob", 120000),
    (3, "Carol", 8000), (4, "Dave", 250000),
    (5, "Eve", 540001), (6, "Frank", 0),
]

employees_df = spark.createDataFrame(employees_data, ["emp_id", "name", "annual_salary"])

result = employees_df.withColumn(
    "total_tax", compute_tax(F.col("annual_salary"))
).withColumn(
    "effective_rate",
    F.when(F.col("annual_salary") > 0,
           F.round(F.col("total_tax") / F.col("annual_salary"), 4)
    ).otherwise(0.0)
).withColumn(
    "take_home", F.col("annual_salary") - F.col("total_tax")
)

print("=== Tax Results (UDF Approach) ===")
result.show()

spark.stop()
```

## Key Concepts

- **Progressive Tax**: Different portions of income are taxed at different rates. The key formula is: `taxable_in_bracket = max(0, min(salary, upper_bound) - lower_bound)`.
- **Marginal Rate**: The rate applied to the last dollar earned (highest applicable bracket rate).
- **Effective Rate**: Total tax divided by total income -- always lower than the marginal rate.
- **Cross Join Pattern**: Employee x Bracket cross join is the standard approach. Filter out brackets where salary <= lower_bound for efficiency.
- **Broadcast Variable**: For the UDF approach, broadcast the bracket table so every executor has a local copy.

## Interview Tips

- This pattern generalizes to any **tiered pricing** problem: shipping cost tiers, volume discounts, commission rates.
- Always validate with edge cases: salary exactly on a bracket boundary, salary of 0, salary in the highest bracket.
- The cross-join approach is parallelizable across employees. The UDF approach is simpler but runs in Python (slower). Mention this trade-off.
- In production, bracket tables change yearly -- mention the need to join on the **tax year** as well.
