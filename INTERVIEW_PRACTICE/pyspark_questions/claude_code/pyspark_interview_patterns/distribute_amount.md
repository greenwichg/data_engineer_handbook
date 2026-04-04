# PySpark Implementation: Distribute Amount Across Rows

## Problem Statement
Given a table of orders where each order has a total amount and a requested number of
installments, generate one row per installment with the amount split equally. Any remainder
pennies (caused by amounts that don't divide evenly) must be distributed fairly — one extra
cent each to the first N installments until the remainder is exhausted.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("distribute_amount").getOrCreate()

data = [
    (1, 10.00, 3),
    (2, 100.00, 4),
    (3, 7.53, 2),
    (4, 1.00, 3),
]
columns = ["order_id", "total_amount", "num_installments"]
df = spark.createDataFrame(data, columns)
df.show()
```

| order_id | total_amount | num_installments |
|----------|-------------|-----------------|
| 1        | 10.00       | 3               |
| 2        | 100.00      | 4               |
| 3        | 7.53        | 2               |
| 4        | 1.00        | 3               |

### Expected Output

| order_id | installment_num | installment_amount |
|----------|-----------------|--------------------|
| 1        | 1               | 3.34               |
| 1        | 2               | 3.33               |
| 1        | 3               | 3.33               |
| 2        | 1               | 25.00              |
| 2        | 2               | 25.00              |
| 2        | 3               | 25.00              |
| 2        | 4               | 25.00              |
| 3        | 1               | 3.77               |
| 3        | 2               | 3.76               |
| 4        | 1               | 0.34               |
| 4        | 2               | 0.33               |
| 4        | 3               | 0.33               |

---

## Method 1: explode + Window Row Number (Recommended)

```python
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Step 1: Convert total to cents to avoid floating-point issues
df_cents = df.withColumn("total_cents", F.round(F.col("total_amount") * 100).cast("int"))

# Step 2: Compute base installment and remainder
df_calc = df_cents \
    .withColumn("base_cents", F.floor(F.col("total_cents") / F.col("num_installments")).cast("int")) \
    .withColumn("remainder_cents", (F.col("total_cents") % F.col("num_installments")).cast("int"))

# Step 3: Explode into one row per installment using sequence
df_exploded = df_calc \
    .withColumn("installment_num", F.explode(F.sequence(F.lit(1), F.col("num_installments"))))

# Step 4: Add one extra cent to the first `remainder_cents` installments
df_result = df_exploded \
    .withColumn(
        "installment_amount",
        F.when(
            F.col("installment_num") <= F.col("remainder_cents"),
            (F.col("base_cents") + 1) / 100
        ).otherwise(
            F.col("base_cents") / 100
        )
    ) \
    .select("order_id", "installment_num", "installment_amount") \
    .orderBy("order_id", "installment_num")

df_result.show()
```

### Step-by-Step Explanation

**After Step 1 — Convert to cents:**

| order_id | total_amount | num_installments | total_cents |
|----------|-------------|-----------------|-------------|
| 1        | 10.00       | 3               | 1000        |
| 4        | 1.00        | 3               | 100         |

**After Step 2 — Compute base and remainder:**

| order_id | total_cents | num_installments | base_cents | remainder_cents |
|----------|-------------|-----------------|------------|-----------------|
| 1        | 1000        | 3               | 333        | 1               |
| 2        | 10000       | 4               | 2500       | 0               |
| 3        | 753         | 2               | 376        | 1               |
| 4        | 100         | 3               | 33         | 1               |

**After Step 3 — Explode into installment rows:**

For order_id = 1 we get 3 rows with installment_num 1, 2, 3.

**After Step 4 — Assign amounts with penny distribution:**

For order_id = 1: remainder_cents = 1, so installment_num 1 gets 334 cents (3.34),
installments 2 and 3 get 333 cents (3.33). Total = 3.34 + 3.33 + 3.33 = 10.00.

---

## Method 2: UDF-Based Approach

```python
from pyspark.sql import functions as F
from pyspark.sql.types import ArrayType, StructType, StructField, IntegerType, DoubleType

schema = ArrayType(StructType([
    StructField("installment_num", IntegerType()),
    StructField("installment_amount", DoubleType()),
]))

@F.udf(schema)
def split_amount(total_amount, num_installments):
    total_cents = round(total_amount * 100)
    base = total_cents // num_installments
    remainder = total_cents % num_installments
    result = []
    for i in range(1, num_installments + 1):
        cents = base + (1 if i <= remainder else 0)
        result.append((i, cents / 100.0))
    return result

df_result_v2 = df \
    .withColumn("installments", F.explode(split_amount(F.col("total_amount"), F.col("num_installments")))) \
    .select(
        "order_id",
        F.col("installments.installment_num"),
        F.col("installments.installment_amount"),
    ) \
    .orderBy("order_id", "installment_num")

df_result_v2.show()
```

---

## Key Interview Talking Points

1. **Always work in integer cents** — floating-point arithmetic causes rounding errors
   (e.g., `10.00 / 3 = 3.3333...`). Converting to cents makes division exact.

2. **Remainder distribution** — after integer division, distribute one extra cent to the
   first R installments (where R = total_cents % num_installments). This guarantees
   the sum always equals the original total.

3. **`F.sequence` + `F.explode`** is the idiomatic PySpark way to generate N rows from
   one row without a UDF. It pushes work to the catalyst optimizer.

4. **UDF trade-offs** — the UDF approach is more readable and handles complex logic
   naturally, but it serialises data to Python and back, losing Catalyst optimizations.
   For large datasets the native approach is significantly faster.

5. **Validation** — in an interview, mention adding a check that the installment amounts
   sum back to the original total: `df.groupBy("order_id").agg(F.sum("installment_amount"))`.

6. **Edge cases to mention**: num_installments = 1, total_amount = 0, remainder larger
   than base amount (e.g., $0.05 split into 3 → 2 cents, 2 cents, 1 cent).

7. **`F.round` vs `F.floor`** — use `F.floor` for the base to ensure the remainder is
   always non-negative. Using `F.round` can cause under- or over-allocation.
