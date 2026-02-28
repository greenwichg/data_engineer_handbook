# PySpark Implementation: Explode Quantity into Individual Rows

## Problem Statement

Given an orders table where each row has a quantity value, **expand each row into N individual rows** (one per unit), each with quantity = 1. This is a classic `explode` + `array_repeat` problem that tests your understanding of array generation and row explosion.

### Sample Data

```
order  prd   quantitly
ord1   prd1  3
ord2   prd2  2
ord3   prd3  1
```

### Expected Output

| order | prd  | quantitly |
|-------|------|-----------|
| ord1  | prd1 | 1         |
| ord1  | prd1 | 1         |
| ord1  | prd1 | 1         |
| ord2  | prd2 | 1         |
| ord2  | prd2 | 1         |
| ord3  | prd3 | 1         |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import explode, array_repeat, lit

spark = SparkSession.builder.appName("ExplodeQuantity").getOrCreate()

data = [
    ("ord1", "prd1", 3),
    ("ord2", "prd2", 2),
    ("ord3", "prd3", 1)
]
columns = ["order", "prd", "quantitly"]
df = spark.createDataFrame(data, columns)

# Explode: create an array of 1s with length = quantity, then explode into rows
exploded_df = df.withColumn(
    "quantitly",
    explode(array_repeat(lit(1), df["quantitly"]))
)

exploded_df.show(truncate=False)
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Generate Array Using array_repeat()

- **What happens:** `array_repeat(lit(1), df["quantitly"])` creates an array column where the value `1` is repeated N times (N = the quantity value for that row).
- **Intermediate state (conceptual — array column added):**

  | order | prd  | quantitly | repeated_array |
  |-------|------|-----------|----------------|
  | ord1  | prd1 | 3         | [1, 1, 1]      |
  | ord2  | prd2 | 2         | [1, 1]         |
  | ord3  | prd3 | 1         | [1]            |

### Step 2: Explode Array into Rows

- **What happens:** `explode()` takes each array element and creates a separate row, duplicating the other columns (`order`, `prd`) for each element. The original `quantitly` column is replaced with the exploded value (always 1).
- **Output (exploded_df):**

  | order | prd  | quantitly |
  |-------|------|-----------|
  | ord1  | prd1 | 1         |
  | ord1  | prd1 | 1         |
  | ord1  | prd1 | 1         |
  | ord2  | prd2 | 1         |
  | ord2  | prd2 | 1         |
  | ord3  | prd3 | 1         |

  - ord1 had quantity 3 → 3 rows
  - ord2 had quantity 2 → 2 rows
  - ord3 had quantity 1 → 1 row

---

## Alternative: Using sequence() and explode()

```python
from pyspark.sql.functions import explode, sequence, lit, col

# sequence(1, quantity) generates [1, 2, 3, ...] — one element per unit
exploded_alt = df.withColumn(
    "unit_number",
    explode(sequence(lit(1), col("quantitly")))
).drop("quantitly") \
 .withColumn("quantitly", lit(1))

exploded_alt.show(truncate=False)
```

This uses `sequence(1, N)` to generate `[1, 2, 3, ..., N]`, then explodes it. The difference is that `sequence` gives you a natural row counter (useful if you need to number each unit), while `array_repeat` gives identical values.

---

## Key Interview Talking Points

1. **array_repeat vs sequence:** `array_repeat(lit(1), N)` creates `[1, 1, 1]` — same value repeated. `sequence(1, N)` creates `[1, 2, 3]` — sequential values. Choose based on whether you need a unit counter.

2. **Why lit(1)?** `lit()` creates a literal column value. Without it, PySpark would try to interpret `1` as a column name. `lit(1)` ensures it's treated as the constant integer 1.

3. **Null/zero handling:** If `quantitly` is 0 or null, `array_repeat` returns an empty array `[]`, and `explode` drops that row entirely. Use `explode_outer` if you want to keep rows with quantity 0 (they'd have null in the exploded column).

4. **Performance consideration:** Exploding can dramatically increase row count (e.g., 1M rows with avg quantity 10 → 10M rows). Ensure the cluster has enough memory. For very large quantities, consider whether the downstream logic truly needs individual rows.
