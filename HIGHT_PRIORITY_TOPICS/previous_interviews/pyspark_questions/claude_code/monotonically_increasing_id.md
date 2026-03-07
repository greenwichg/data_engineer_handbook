# PySpark Implementation: Monotonically Increasing ID

## Problem Statement

Given a DataFrame without a unique identifier, generate unique row IDs using `monotonically_increasing_id()`. Understand its behavior, guarantees, limitations, and alternatives. This comes up in interviews around surrogate key generation and data pipeline design.

### Sample Data

```
name       department   salary
Alice      Engineering  90000
Bob        Marketing    65000
Charlie    Engineering  85000
Diana      Marketing    70000
Eve        Finance      95000
```

### Expected Output

| row_id | name    | department  | salary |
|--------|---------|-------------|--------|
| 0      | Alice   | Engineering | 90000  |
| 1      | Bob     | Marketing   | 65000  |
| 2      | Charlie | Engineering | 85000  |
| 3      | Diana   | Marketing   | 70000  |
| 4      | Eve     | Finance     | 95000  |

---

## Method 1: Using monotonically_increasing_id()

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import monotonically_increasing_id

spark = SparkSession.builder.appName("MonotonicallyIncreasingID").getOrCreate()

data = [
    ("Alice", "Engineering", 90000),
    ("Bob", "Marketing", 65000),
    ("Charlie", "Engineering", 85000),
    ("Diana", "Marketing", 70000),
    ("Eve", "Finance", 95000),
]
df = spark.createDataFrame(data, ["name", "department", "salary"])

# Add monotonically increasing ID
df_with_id = df.withColumn("row_id", monotonically_increasing_id())
df_with_id.show()
```

### Output (example — IDs may vary across runs)

```
+-------+-----------+------+----------+
|   name| department|salary|    row_id|
+-------+-----------+------+----------+
|  Alice|Engineering| 90000|         0|
|    Bob|  Marketing| 65000|         1|
|Charlie|Engineering| 85000|8589934592|
|  Diana|  Marketing| 70000|8589934593|
|    Eve|    Finance| 95000|8589934594|
+-------+-----------+------+----------+
```

### Key Behavior

- IDs are **unique** and **monotonically increasing** (each subsequent row gets a larger ID)
- IDs are **NOT consecutive** — there can be large gaps between partitions
- The ID is composed of: `(partition_id << 33) + row_number_within_partition`
- **Not deterministic** — IDs may change if the DataFrame is recomputed

---

## Method 2: Consecutive IDs Using row_number()

```python
from pyspark.sql.functions import row_number, lit
from pyspark.sql.window import Window

# row_number() gives consecutive IDs but requires an orderBy
df_consecutive = df.withColumn(
    "row_id",
    row_number().over(Window.orderBy(lit(1))) - 1  # 0-indexed
)
df_consecutive.show()
```

**Output:**
```
+-------+-----------+------+------+
|   name| department|salary|row_id|
+-------+-----------+------+------+
|  Alice|Engineering| 90000|     0|
|    Bob|  Marketing| 65000|     1|
|Charlie|Engineering| 85000|     2|
|  Diana|  Marketing| 70000|     3|
|    Eve|    Finance| 95000|     4|
+-------+-----------+------+------+
```

**Warning:** `Window.orderBy(lit(1))` forces all data into a single partition — this will fail on large datasets. Use a meaningful orderBy column instead.

---

## Method 3: zipWithIndex via RDD (Consecutive + Distributed)

```python
# Convert to RDD, zip with index, convert back
rdd_with_index = df.rdd.zipWithIndex()

# Map back to Row with the index
from pyspark.sql import Row

df_zipped = rdd_with_index.map(
    lambda row_idx: Row(
        row_id=row_idx[1],
        name=row_idx[0]["name"],
        department=row_idx[0]["department"],
        salary=row_idx[0]["salary"]
    )
).toDF()

df_zipped.show()
```

**Output:**
```
+------+-------+-----------+------+
|row_id|   name| department|salary|
+------+-------+-----------+------+
|     0|  Alice|Engineering| 90000|
|     1|    Bob|  Marketing| 65000|
|     2|Charlie|Engineering| 85000|
|     3|  Diana|  Marketing| 70000|
|     4|    Eve|    Finance| 95000|
+------+-------+-----------+------+
```

**Advantage:** Truly consecutive IDs, works at scale.
**Disadvantage:** Requires two passes over the data (one to count partition sizes, one to assign IDs).

---

## Method 4: UUID Generation

```python
from pyspark.sql.functions import expr

# Generate universally unique IDs (not sequential)
df_uuid = df.withColumn("uuid", expr("uuid()"))
df_uuid.show(truncate=False)
```

**Output:**
```
+-------+-----------+------+------------------------------------+
|name   |department |salary|uuid                                |
+-------+-----------+------+------------------------------------+
|Alice  |Engineering|90000 |550e8400-e29b-41d4-a716-446655440000|
|Bob    |Marketing  |65000 |6ba7b810-9dad-11d1-80b4-00c04fd430c8|
|...    |...        |...   |...                                 |
+-------+-----------+------+------------------------------------+
```

---

## Method 5: Hash-Based Surrogate Key

```python
from pyspark.sql.functions import sha2, concat_ws

# Deterministic surrogate key based on business columns
df_hash = df.withColumn(
    "surrogate_key",
    sha2(concat_ws("||", col("name"), col("department"), col("salary")), 256)
)
df_hash.select("name", "surrogate_key").show(truncate=40)
```

**Advantage:** Same input always produces the same key — idempotent and reproducible.

---

## Comparison Table

| Method | Consecutive? | Deterministic? | Scalable? | Use Case |
|--------|-------------|---------------|-----------|----------|
| monotonically_increasing_id() | No | No | Yes | Quick unique IDs, join keys |
| row_number() | Yes | With order | No* | Small datasets, ranking |
| zipWithIndex | Yes | With order | Yes | Large datasets needing consecutive IDs |
| uuid() | No | No | Yes | Globally unique identifiers |
| sha2() hash | N/A | Yes | Yes | Surrogate keys, deduplication |

*row_number() with `orderBy(lit(1))` forces single partition

---

## Key Interview Talking Points

1. **monotonically_increasing_id() is NOT consecutive:** IDs have gaps between partitions. The formula is `(partition_id << 33) + index_within_partition`. This is by design for distributed computation.

2. **Not deterministic:** If the DataFrame is recomputed (e.g., after a cache eviction), IDs may change. Always persist/cache the result if you need stable IDs.

3. **When to use zipWithIndex:** When you need truly consecutive IDs (0, 1, 2, ...) at scale. It requires an extra pass but gives guaranteed sequential numbering.

4. **row_number() pitfall:** Using `orderBy(lit(1))` or any constant moves all data to one partition — this causes OOM on large datasets. Always use a meaningful ordering column.

5. **Hash-based keys for idempotency:** In data pipelines, hash-based surrogate keys are preferred because re-running the pipeline produces the same keys, making operations idempotent.

6. **Real-world usage:** `monotonically_increasing_id()` is often used as a temporary join key when you need to join a DataFrame back to itself after transformation, not as a permanent identifier.
