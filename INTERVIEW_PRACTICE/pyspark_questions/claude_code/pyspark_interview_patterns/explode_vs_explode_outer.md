# PySpark Implementation: explode() vs explode_outer() vs posexplode() vs posexplode_outer()

## Problem Statement

When working with array and map columns in PySpark, you often need to flatten them into individual rows. PySpark provides four explode variants, each with different behavior regarding NULL/empty arrays and positional indexing:

| Function | Drops NULL/Empty? | Provides Position? |
|---|---|---|
| `explode()` | Yes | No |
| `explode_outer()` | No (preserves as NULL row) | No |
| `posexplode()` | Yes | Yes |
| `posexplode_outer()` | No (preserves as NULL row) | Yes |

**Key Gotcha (Interview Favorite):** `explode()` silently drops rows where the array/map column is NULL or empty. This can cause data loss if you are not careful. `explode_outer()` preserves those rows with NULL values, which is usually what you want in production pipelines.

---

## Setup

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, ArrayType, MapType
)

spark = SparkSession.builder \
    .appName("Explode Variants Comparison") \
    .master("local[*]") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")
```

---

## Part 1: Exploding Arrays

### Sample Data

```python
data = [
    (1, "Alice",   ["Python", "Scala", "Java"]),
    (2, "Bob",     ["PySpark"]),
    (3, "Charlie", []),          # empty array
    (4, "Diana",   None),        # NULL array
    (5, "Eve",     ["SQL", "R"]),
]

schema = StructType([
    StructField("id", IntegerType(), False),
    StructField("name", StringType(), False),
    StructField("skills", ArrayType(StringType()), True),
])

df = spark.createDataFrame(data, schema)
df.show(truncate=False)
```

```
+---+-------+----------------------+
|id |name   |skills                |
+---+-------+----------------------+
|1  |Alice  |[Python, Scala, Java] |
|2  |Bob    |[PySpark]             |
|3  |Charlie|[]                    |
|4  |Diana  |null                  |
|5  |Eve    |[SQL, R]              |
+---+-------+----------------------+
```

### Method 1: explode() -- Drops NULL and Empty Arrays

```python
df_explode = df.select("id", "name", F.explode("skills").alias("skill"))
df_explode.show(truncate=False)
```

### Expected Output

```
+---+-----+------+
|id |name |skill |
+---+-----+------+
|1  |Alice|Python|
|1  |Alice|Scala |
|1  |Alice|Java  |
|2  |Bob  |PySpark|
|5  |Eve  |SQL   |
|5  |Eve  |R     |
+---+-----+------+
```

**Notice:** Charlie (empty array) and Diana (NULL) are completely missing. This is 2 out of 5 rows silently dropped.

### Method 2: explode_outer() -- Preserves NULL and Empty Arrays

```python
df_explode_outer = df.select(
    "id", "name", F.explode_outer("skills").alias("skill")
)
df_explode_outer.show(truncate=False)
```

### Expected Output

```
+---+-------+-------+
|id |name   |skill  |
+---+-------+-------+
|1  |Alice  |Python |
|1  |Alice  |Scala  |
|1  |Alice  |Java   |
|2  |Bob    |PySpark|
|3  |Charlie|null   |
|4  |Diana  |null   |
|5  |Eve    |SQL    |
|5  |Eve    |R      |
+---+-------+-------+
```

**Notice:** Charlie and Diana are preserved with NULL in the skill column.

### Method 3: posexplode() -- With Position Index, Drops NULL/Empty

```python
df_posexplode = df.select(
    "id", "name", F.posexplode("skills").alias("pos", "skill")
)
df_posexplode.show(truncate=False)
```

### Expected Output

```
+---+-----+---+-------+
|id |name |pos|skill  |
+---+-----+---+-------+
|1  |Alice|0  |Python |
|1  |Alice|1  |Scala  |
|1  |Alice|2  |Java   |
|2  |Bob  |0  |PySpark|
|5  |Eve  |0  |SQL    |
|5  |Eve  |1  |R      |
+---+-----+---+-------+
```

### Method 4: posexplode_outer() -- With Position Index, Preserves NULL/Empty

```python
df_posexplode_outer = df.select(
    "id", "name", F.posexplode_outer("skills").alias("pos", "skill")
)
df_posexplode_outer.show(truncate=False)
```

### Expected Output

```
+---+-------+----+-------+
|id |name   |pos |skill  |
+---+-------+----+-------+
|1  |Alice  |0   |Python |
|1  |Alice  |1   |Scala  |
|1  |Alice  |2   |Java   |
|2  |Bob    |0   |PySpark|
|3  |Charlie|null|null   |
|4  |Diana  |null|null   |
|5  |Eve    |0   |SQL    |
|5  |Eve    |1   |R      |
+---+-------+----+-------+
```

---

## Part 2: Exploding Maps

### Sample Data

```python
map_data = [
    (1, "Alice",   {"math": 95, "science": 88}),
    (2, "Bob",     {"english": 72}),
    (3, "Charlie", {}),       # empty map
    (4, "Diana",   None),     # NULL map
]

map_schema = StructType([
    StructField("id", IntegerType(), False),
    StructField("name", StringType(), False),
    StructField("scores", MapType(StringType(), IntegerType()), True),
])

df_map = spark.createDataFrame(map_data, map_schema)
df_map.show(truncate=False)
```

```
+---+-------+------------------------------+
|id |name   |scores                        |
+---+-------+------------------------------+
|1  |Alice  |{math -> 95, science -> 88}   |
|2  |Bob    |{english -> 72}               |
|3  |Charlie|{}                            |
|4  |Diana  |null                          |
+---+-------+------------------------------+
```

### explode() on Maps

```python
df_map.select(
    "id", "name", F.explode("scores").alias("subject", "score")
).show(truncate=False)
```

### Expected Output

```
+---+-----+-------+-----+
|id |name |subject|score|
+---+-----+-------+-----+
|1  |Alice|math   |95   |
|1  |Alice|science|88   |
|2  |Bob  |english|72   |
+---+-----+-------+-----+
```

### explode_outer() on Maps

```python
df_map.select(
    "id", "name", F.explode_outer("scores").alias("subject", "score")
).show(truncate=False)
```

### Expected Output

```
+---+-------+-------+-----+
|id |name   |subject|score|
+---+-------+-------+-----+
|1  |Alice  |math   |95   |
|1  |Alice  |science|88   |
|2  |Bob    |english|72   |
|3  |Charlie|null   |null |
|4  |Diana  |null   |null |
+---+-------+-------+-----+
```

---

## Part 3: Row Count Verification (Interview Proof)

```python
print("=== Array DataFrame Row Counts ===")
print(f"Original:           {df.count()}")
print(f"explode:            {df.select(F.explode('skills')).count()}")
print(f"explode_outer:      {df.select('id', F.explode_outer('skills')).count()}")
print(f"posexplode:         {df.select(F.posexplode('skills')).count()}")
print(f"posexplode_outer:   {df.select('id', F.posexplode_outer('skills')).count()}")
```

### Expected Output

```
=== Array DataFrame Row Counts ===
Original:           5
explode:            6
explode_outer:      8
posexplode:         6
posexplode_outer:   8
```

---

## Part 4: Practical Use Case -- Rebuilding Arrays After Filtering

A common interview pattern is: explode, filter, then re-aggregate.

```python
# Scenario: Remove "Java" from everyone's skills, keep all people
df_filtered = (
    df
    .select("id", "name", F.explode_outer("skills").alias("skill"))
    .filter((F.col("skill") != "Java") | F.col("skill").isNull())
    .groupBy("id", "name")
    .agg(F.collect_list("skill").alias("skills"))
)

df_filtered.show(truncate=False)
```

### Expected Output

```
+---+-------+---------------+
|id |name   |skills         |
+---+-------+---------------+
|1  |Alice  |[Python, Scala]|
|2  |Bob    |[PySpark]      |
|3  |Charlie|[]             |
|4  |Diana  |[]             |
|5  |Eve    |[SQL, R]       |
+---+-------+---------------+
```

**Note:** Using `explode_outer` ensures Charlie and Diana are not lost during the transformation.

---

## Part 5: Combining posexplode with Other Operations

```python
# Use position to get only the first skill of each person
df_first_skill = (
    df.select("id", "name", F.posexplode_outer("skills").alias("pos", "skill"))
    .filter((F.col("pos") == 0) | F.col("pos").isNull())
    .drop("pos")
)

df_first_skill.show(truncate=False)
```

### Expected Output

```
+---+-------+-------+
|id |name   |skill  |
+---+-------+-------+
|1  |Alice  |Python |
|2  |Bob    |PySpark|
|3  |Charlie|null   |
|4  |Diana  |null   |
|5  |Eve    |SQL    |
+---+-------+-------+
```

---

## Part 6: inline() and inline_outer() for Arrays of Structs

```python
struct_data = [
    (1, "Alice",   [("Python", 5), ("Scala", 3)]),
    (2, "Bob",     [("PySpark", 2)]),
    (3, "Charlie", []),
    (4, "Diana",   None),
]

struct_schema = StructType([
    StructField("id", IntegerType()),
    StructField("name", StringType()),
    StructField("skill_details", ArrayType(
        StructType([
            StructField("skill", StringType()),
            StructField("years", IntegerType()),
        ])
    )),
])

df_struct = spark.createDataFrame(struct_data, struct_schema)

# inline() flattens array of structs into columns directly
df_struct.select("id", "name", F.inline("skill_details")).show(truncate=False)

# inline_outer() preserves NULL/empty
df_struct.select("id", "name", F.inline_outer("skill_details")).show(truncate=False)
```

### Expected Output (inline_outer)

```
+---+-------+-------+-----+
|id |name   |skill  |years|
+---+-------+-------+-----+
|1  |Alice  |Python |5    |
|1  |Alice  |Scala  |3    |
|2  |Bob    |PySpark|2    |
|3  |Charlie|null   |null |
|4  |Diana  |null   |null |
+---+-------+-------+-----+
```

---

## Key Takeaways

1. **Default to `explode_outer()`** in production code. Using `explode()` silently drops rows, which is a common source of data quality bugs.

2. **`posexplode()` variants** give you a 0-based position index, which is useful for ordering or filtering by position within the array.

3. **Empty arrays `[]` and NULL arrays `None`** are both dropped by `explode()` and `posexplode()`. The `_outer` variants treat them the same way -- both produce a single NULL row.

4. **Maps explode into two columns** (key and value) rather than one.

5. **`inline()` / `inline_outer()`** are the struct-aware equivalents for arrays of structs -- they flatten struct fields directly into columns.

6. **Interview tip:** If asked "what happens when you explode a NULL array?", the answer depends on the variant. Always clarify which function you mean, and mention that `explode_outer` is the safer choice.

7. **Performance note:** All explode variants can dramatically increase row count. If you have arrays with millions of elements across your dataset, be prepared for memory pressure and potential shuffles downstream.
