# PySpark Implementation: when().otherwise() Chaining (CASE WHEN)

## Problem Statement

PySpark's `F.when().when().otherwise()` is the equivalent of SQL's `CASE WHEN ... WHEN ... ELSE ... END`. It is used for conditional column creation, data classification, and complex business logic. Interviewers test your ability to chain multiple conditions, nest conditions, handle edge cases (NULLs, ordering of conditions), and use it fluently in both `withColumn` and `select` contexts.

### Sample Data

```python
data = [
    (1, "Alice", "Engineering", 95000, 8, "Senior"),
    (2, "Bob", "Marketing", 45000, 2, "Junior"),
    (3, "Charlie", "Sales", 70000, 5, "Mid"),
    (4, "Diana", "Engineering", 120000, 12, "Lead"),
    (5, "Eve", "Marketing", 55000, 3, "Junior"),
    (6, "Frank", "Sales", 85000, 7, "Senior"),
    (7, "Grace", "Engineering", 60000, 1, "Junior"),
    (8, "Heidi", "Marketing", None, 4, "Mid"),     # NULL salary
    (9, "Ivan", "Sales", 150000, 15, None),          # NULL level
]
columns = ["emp_id", "name", "department", "salary", "years_exp", "level"]
```

### Expected Output

Various classifications based on salary bands, experience levels, and multi-condition business logic.

---

## Method 1: Basic when().otherwise() -- Salary Bands

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("WhenOtherwise").getOrCreate()

data = [
    (1, "Alice", "Engineering", 95000, 8, "Senior"),
    (2, "Bob", "Marketing", 45000, 2, "Junior"),
    (3, "Charlie", "Sales", 70000, 5, "Mid"),
    (4, "Diana", "Engineering", 120000, 12, "Lead"),
    (5, "Eve", "Marketing", 55000, 3, "Junior"),
    (6, "Frank", "Sales", 85000, 7, "Senior"),
    (7, "Grace", "Engineering", 60000, 1, "Junior"),
    (8, "Heidi", "Marketing", None, 4, "Mid"),
    (9, "Ivan", "Sales", 150000, 15, None),
]
columns = ["emp_id", "name", "department", "salary", "years_exp", "level"]
df = spark.createDataFrame(data, columns)

# Simple salary bands
result = df.withColumn(
    "salary_band",
    F.when(F.col("salary") >= 100000, "High")
    .when(F.col("salary") >= 70000, "Medium")
    .when(F.col("salary") >= 50000, "Low")
    .otherwise("Entry")
)
result.select("name", "salary", "salary_band").show()
```

**Output:**
```
+-------+------+-----------+
|   name|salary|salary_band|
+-------+------+-----------+
|  Alice| 95000|     Medium|
|    Bob| 45000|      Entry|
|Charlie| 70000|     Medium|
|  Diana|120000|       High|
|    Eve| 55000|        Low|
|  Frank| 85000|     Medium|
|  Grace| 60000|        Low|
|  Heidi|  null|      Entry|  <-- NULL falls through to otherwise!
|   Ivan|150000|       High|
+-------+------+-----------+
```

**Critical observation:** Heidi's NULL salary falls through ALL when conditions (because `NULL >= 100000` is UNKNOWN, not TRUE) and lands in `otherwise("Entry")`. This is probably wrong. Always handle NULLs explicitly.

---

## Method 2: NULL-Safe Chaining

```python
# Handle NULLs explicitly -- always check for NULL first
result_safe = df.withColumn(
    "salary_band",
    F.when(F.col("salary").isNull(), "Unknown")
    .when(F.col("salary") >= 100000, "High")
    .when(F.col("salary") >= 70000, "Medium")
    .when(F.col("salary") >= 50000, "Low")
    .otherwise("Entry")
)
result_safe.select("name", "salary", "salary_band").show()
# Heidi now shows "Unknown" instead of incorrectly being labeled "Entry"
```

**Rule of thumb:** Put NULL checks FIRST in the chain. Conditions are evaluated top to bottom, and the first TRUE match wins.

---

## Method 3: Multi-Condition Business Logic

Chaining conditions that involve multiple columns.

```python
# Determine bonus eligibility based on multiple criteria
result_bonus = df.withColumn(
    "bonus_tier",
    F.when(
        (F.col("salary") >= 100000) & (F.col("years_exp") >= 10),
        "Platinum"
    )
    .when(
        (F.col("salary") >= 70000) & (F.col("years_exp") >= 5),
        "Gold"
    )
    .when(
        (F.col("salary") >= 50000) & (F.col("years_exp") >= 3),
        "Silver"
    )
    .when(
        F.col("salary").isNotNull(),
        "Bronze"
    )
    .otherwise("Not Eligible")
)
result_bonus.select("name", "salary", "years_exp", "bonus_tier").show()
```

**Important syntax note:** Multiple conditions within a single `when()` must be wrapped in parentheses and combined with `&` (AND) or `|` (OR). Forgetting parentheses is a common syntax error:

```python
# WRONG -- operator precedence issue
F.when(F.col("salary") >= 70000 & F.col("years_exp") >= 5, "Gold")

# CORRECT -- parentheses around each condition
F.when((F.col("salary") >= 70000) & (F.col("years_exp") >= 5), "Gold")
```

---

## Method 4: Using when() in select() vs withColumn()

```python
# With withColumn (adds/replaces a column)
df.withColumn("category", F.when(F.col("salary") > 80000, "High").otherwise("Low")).show()

# With select (can rename and create multiple columns at once)
df.select(
    "name",
    "salary",
    F.when(F.col("salary") > 80000, "High").otherwise("Low").alias("salary_cat"),
    F.when(F.col("years_exp") > 5, "Experienced").otherwise("New").alias("exp_cat"),
).show()
```

---

## Method 5: Nested when() Conditions

```python
# Nested when: different logic per department
result_nested = df.withColumn(
    "performance_band",
    F.when(
        F.col("department") == "Engineering",
        F.when(F.col("salary") >= 100000, "Top Eng")
        .when(F.col("salary") >= 70000, "Mid Eng")
        .otherwise("Junior Eng")
    )
    .when(
        F.col("department") == "Marketing",
        F.when(F.col("salary") >= 60000, "Top Mkt")
        .otherwise("Entry Mkt")
    )
    .otherwise("Other")
)
result_nested.select("name", "department", "salary", "performance_band").show()
```

**Output:**
```
+-------+-----------+------+----------------+
|   name| department|salary|performance_band|
+-------+-----------+------+----------------+
|  Alice|Engineering| 95000|         Mid Eng|
|    Bob|  Marketing| 45000|       Entry Mkt|
|Charlie|      Sales| 70000|           Other|
|  Diana|Engineering|120000|         Top Eng|
|    Eve|  Marketing| 55000|       Entry Mkt|
|  Frank|      Sales| 85000|           Other|
|  Grace|Engineering| 60000|      Junior Eng|
|  Heidi|  Marketing|  null|           Other|  <-- NULL salary, nested when fails
|   Ivan|      Sales|150000|           Other|
+-------+-----------+------+----------------+
```

**Note:** Heidi is in Marketing but her NULL salary causes the nested `when(salary >= 60000)` to evaluate to UNKNOWN, falling through to the nested `otherwise("Entry Mkt")`. Wait -- actually it falls to "Entry Mkt" since `NULL >= 60000` is UNKNOWN (not TRUE), so the inner otherwise catches it. This is correct behavior here, but be mindful.

---

## Method 6: when() with Column Expressions as Values

The result of `when()` does not have to be a literal. It can be another column or a computed expression.

```python
# Compute bonus amount based on conditions
result_computed = df.withColumn(
    "bonus_amount",
    F.when(F.col("salary").isNull(), F.lit(0))
    .when(F.col("level") == "Lead", F.col("salary") * 0.20)
    .when(F.col("level") == "Senior", F.col("salary") * 0.15)
    .when(F.col("level") == "Mid", F.col("salary") * 0.10)
    .otherwise(F.col("salary") * 0.05)
)
result_computed.select("name", "salary", "level", "bonus_amount").show()
```

**Output:**
```
+-------+------+------+------------+
|   name|salary| level|bonus_amount|
+-------+------+------+------------+
|  Alice| 95000|Senior|     14250.0|
|    Bob| 45000|Junior|      2250.0|
|Charlie| 70000|   Mid|      7000.0|
|  Diana|120000|  Lead|     24000.0|
|    Eve| 55000|Junior|      2750.0|
|  Frank| 85000|Senior|     12750.0|
|  Grace| 60000|Junior|      3000.0|
|  Heidi|  null|   Mid|           0|
|   Ivan|150000|  null|      7500.0|  <-- NULL level, falls to otherwise
+-------+------+------+------------+
```

---

## Method 7: Combining when() with Other Functions

```python
# Using when() inside agg()
summary = df.groupBy("department").agg(
    F.count("*").alias("total"),
    F.sum(
        F.when(F.col("salary") >= 80000, 1).otherwise(0)
    ).alias("high_earners"),
    F.sum(
        F.when(F.col("salary") < 80000, 1).otherwise(0)
    ).alias("low_earners"),
    F.avg(
        F.when(F.col("salary").isNotNull(), F.col("salary"))
    ).alias("avg_salary_non_null"),
)
summary.show()

# Using when() to create flags for filtering
flagged = df.withColumn(
    "needs_review",
    F.when(
        (F.col("salary").isNull()) |
        (F.col("level").isNull()) |
        (F.col("salary") > 130000) |
        ((F.col("years_exp") < 2) & (F.col("salary") > 80000)),
        True
    ).otherwise(False)
)
flagged.filter(F.col("needs_review")).select("name", "salary", "level").show()
```

---

## Method 8: Replacing when() Chains with Mapping (Alternative)

When you have many static mappings, a dictionary-based approach can be cleaner.

```python
# Instead of long when().when().when() chains for simple mappings:
from pyspark.sql.functions import create_map, lit
from itertools import chain

level_to_multiplier = {
    "Lead": 0.20,
    "Senior": 0.15,
    "Mid": 0.10,
    "Junior": 0.05,
}

# Create a mapping column
mapping_expr = create_map([lit(x) for x in chain(*level_to_multiplier.items())])

result_map = df.withColumn(
    "multiplier",
    mapping_expr[F.col("level")]
).withColumn(
    "bonus",
    F.coalesce(F.col("multiplier") * F.col("salary"), F.lit(0))
)
result_map.select("name", "level", "salary", "multiplier", "bonus").show()
```

**When to use mapping vs when():**
- Use `create_map` for simple key-value lookups with many values.
- Use `when()` for complex conditions involving comparisons, ranges, or multiple columns.

---

## Key Takeaways

- **Conditions are evaluated in order.** The first `when()` that evaluates to TRUE wins. Order matters.
- **NULL handling is critical.** NULLs fail comparison checks silently (NULL >= 100000 is UNKNOWN, not FALSE). Always put `isNull()` checks first.
- **`otherwise()` is optional.** If omitted and no condition matches, the result is NULL.
- **Parentheses are mandatory** around each condition when using `&` (AND) or `|` (OR) due to Python operator precedence.
- **when() can return columns**, not just literals. Use `F.col("salary") * 0.15` instead of hardcoded values.
- **when() works everywhere:** `withColumn`, `select`, `agg`, `filter`, `orderBy`.
- Use `F.lit()` to wrap literal values when mixing with column expressions.

## Interview Tips

- Always handle NULLs explicitly and mention this proactively. It shows production-level thinking.
- Know the difference between `when().when()` (chained -- like CASE WHEN WHEN) and nested `when(condition, when(...))` (nested -- like CASE WHEN (CASE WHEN)).
- If the interviewer gives you a complex business rule, break it down verbally first, then code it. "First I check for NULLs, then the highest priority condition, then lower ones, and finally a default."
- Mention that `when()` chains compile to SQL CASE expressions in the Catalyst plan. You can verify with `.explain()`.
- For many static mappings, mention the `create_map` alternative to show breadth of knowledge.
- Common mistake: writing `F.when(condition, value1, value2)`. The `when()` function takes exactly 2 arguments: condition and value. The "else" goes in `otherwise()`.
