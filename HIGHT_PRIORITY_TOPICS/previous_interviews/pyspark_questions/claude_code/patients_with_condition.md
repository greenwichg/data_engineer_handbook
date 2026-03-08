# PySpark Implementation: Patients With a Condition (LIKE Pattern Matching)

## Problem Statement

Given a `Patients` table with `patient_id`, `patient_name`, and `conditions` (space-separated condition codes), find all patients who have **Type I Diabetes** (condition code starting with `DIAB1`). The code can appear anywhere in the conditions string. This is **LeetCode 1527 — Patients With a Condition**.

### Sample Data

```
patient_id  patient_name  conditions
1           Alice         ACNE DIAB100
2           Bob           DIAB100
3           Charlie       ACNE DIAB200
4           Diana         ACNE
5           Eve           DIAB150 FLU
```

### Expected Output

| patient_id | patient_name | conditions     |
|------------|-------------|----------------|
| 1          | Alice       | ACNE DIAB100   |
| 2          | Bob         | DIAB100        |
| 5          | Eve         | DIAB150 FLU    |

**Explanation:** DIAB100 and DIAB150 start with "DIAB1". DIAB200 does NOT start with "DIAB1".

---

## Method 1: Using rlike (Regex) (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col

spark = SparkSession.builder.appName("PatientsCondition").getOrCreate()

data = [
    (1, "Alice", "ACNE DIAB100"),
    (2, "Bob", "DIAB100"),
    (3, "Charlie", "ACNE DIAB200"),
    (4, "Diana", "ACNE"),
    (5, "Eve", "DIAB150 FLU")
]

columns = ["patient_id", "patient_name", "conditions"]
df = spark.createDataFrame(data, columns)

# Match DIAB1 at the start of a word (beginning of string or after space)
result = df.filter(col("conditions").rlike(r"(^|\s)DIAB1"))

result.show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Understand the regex pattern
- `(^|\s)` matches either the start of the string `^` OR a whitespace character `\s`.
- `DIAB1` matches the literal prefix.
- Together: finds "DIAB1" at the beginning of a word boundary.

#### Step 2: Apply filter
- "ACNE DIAB100" → space before DIAB1 ✓
- "DIAB100" → start of string before DIAB1 ✓
- "ACNE DIAB200" → has DIAB2, not DIAB1 ✗
- "ACNE" → no DIAB at all ✗
- "DIAB150 FLU" → start of string before DIAB1 ✓

---

## Method 2: Using LIKE with Two Conditions

```python
from pyspark.sql.functions import col

# DIAB1 at start of string OR preceded by a space
result = df.filter(
    col("conditions").like("DIAB1%") |
    col("conditions").like("% DIAB1%")
)

result.show(truncate=False)
```

### Why two LIKE conditions?
- `LIKE 'DIAB1%'` → matches when DIAB1 is the first condition.
- `LIKE '% DIAB1%'` → matches when DIAB1 appears after a space (not first).
- Together they cover all positions.

---

## Method 3: Using array_contains After Split

```python
from pyspark.sql.functions import col, split, exists as F_exists
from pyspark.sql.functions import expr

# Split conditions into array, check if any element starts with DIAB1
result = df.withColumn("cond_array", split(col("conditions"), " ")) \
    .filter(expr("exists(cond_array, x -> x LIKE 'DIAB1%')")) \
    .drop("cond_array")

result.show(truncate=False)
```

---

## Method 4: Spark SQL

```python
df.createOrReplaceTempView("patients")

# Using LIKE
result = spark.sql("""
    SELECT *
    FROM patients
    WHERE conditions LIKE 'DIAB1%'
       OR conditions LIKE '% DIAB1%'
""")

result.show(truncate=False)

# Using RLIKE (regex)
result2 = spark.sql("""
    SELECT *
    FROM patients
    WHERE conditions RLIKE '(^|\\\\s)DIAB1'
""")

result2.show(truncate=False)
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| DIAB1 in middle of another code (e.g., "XDIAB100") | Should NOT match | Word boundary regex `(^|\s)` prevents this |
| Condition is exactly "DIAB1" (no suffix) | Should match | Both LIKE and regex handle this |
| Multiple DIAB1 codes in same string | Match once is enough | Filter returns the row |
| NULL conditions | NULL LIKE anything = NULL (falsy) | Excluded automatically |
| Extra spaces between conditions | `LIKE '% DIAB1%'` still works; regex `\s` matches any whitespace | Regex is more robust |

## Key Interview Talking Points

1. **Why not just `LIKE '%DIAB1%'`?**
   - That would match "XDIAB100" — a code that CONTAINS "DIAB1" but doesn't START with it.
   - Must use word boundary: start of string OR preceded by space.

2. **LIKE vs. RLIKE:**
   - `LIKE` uses SQL wildcards (`%`, `_`) — simpler but less powerful.
   - `RLIKE` uses full regex — more flexible for complex patterns.
   - Two LIKEs vs. one regex — interviewer may prefer either.

3. **The `(^|\s)` pattern:**
   - `^` = start of string, `\s` = whitespace. This ensures we match at a word boundary.
   - Alternative: `\bDIAB1` using `\b` word boundary (but `\b` behavior varies by regex engine).

4. **Performance at scale:**
   - String pattern matching on every row is CPU-intensive.
   - If this is a frequent query, consider splitting conditions into a separate table (normalized schema) and using an equi-join.
