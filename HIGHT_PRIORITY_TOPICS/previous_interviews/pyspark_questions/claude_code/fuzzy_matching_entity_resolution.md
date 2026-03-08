# PySpark Implementation: Fuzzy Matching and Entity Resolution

## Problem Statement
Given a customer table with messy data (typos, abbreviations, formatting differences), identify and group records that likely refer to the same real-world entity. This is a critical data quality pattern in data engineering — commonly asked in interviews for roles involving MDM (Master Data Management), deduplication, and data integration.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import IntegerType

spark = SparkSession.builder.appName("FuzzyMatching").getOrCreate()

data = [
    (1, "John Smith", "john.smith@gmail.com", "123 Main St"),
    (2, "Jon Smith", "jon.smith@gmail.com", "123 Main Street"),
    (3, "John Smyth", "john.smith@gmail.com", "123 Main St"),
    (4, "Jane Doe", "jane.doe@yahoo.com", "456 Oak Ave"),
    (5, "Jane M Doe", "janedoe@yahoo.com", "456 Oak Avenue"),
    (6, "Robert Johnson", "rob.j@outlook.com", "789 Pine Rd"),
    (7, "Bob Johnson", "rob.j@outlook.com", "789 Pine Road"),
]

columns = ["id", "name", "email", "address"]
df = spark.createDataFrame(data, columns)
df.show(truncate=False)
```

```
+---+--------------+----------------------+---------------+
|id |name          |email                 |address        |
+---+--------------+----------------------+---------------+
|1  |John Smith    |john.smith@gmail.com  |123 Main St    |
|2  |Jon Smith     |jon.smith@gmail.com   |123 Main Street|
|3  |John Smyth   |john.smith@gmail.com  |123 Main St    |
|4  |Jane Doe      |jane.doe@yahoo.com   |456 Oak Ave    |
|5  |Jane M Doe    |janedoe@yahoo.com    |456 Oak Avenue |
|6  |Robert Johnson|rob.j@outlook.com    |789 Pine Rd    |
|7  |Bob Johnson   |rob.j@outlook.com    |789 Pine Road  |
+---+--------------+----------------------+---------------+
```

### Expected Output (Matched Pairs)
```
+----+----+--------------+--------------+----------------+
|id_1|id_2|name_1        |name_2        |similarity_score|
+----+----+--------------+--------------+----------------+
|1   |2   |John Smith    |Jon Smith     |0.90            |
|1   |3   |John Smith    |John Smyth    |0.90            |
|4   |5   |Jane Doe      |Jane M Doe    |0.86            |
|6   |7   |Robert Johnson|Bob Johnson   |0.77            |
+----+----+--------------+--------------+----------------+
```

---

## Method 1: Levenshtein Distance (Built-in)

```python
# Step 1: Self-join to create all candidate pairs (id_1 < id_2 to avoid duplicates)
pairs = df.alias("a").crossJoin(df.alias("b")).filter(
    F.col("a.id") < F.col("b.id")
)

# Step 2: Compute Levenshtein distance on the name column
pairs_with_dist = pairs.select(
    F.col("a.id").alias("id_1"),
    F.col("b.id").alias("id_2"),
    F.col("a.name").alias("name_1"),
    F.col("b.name").alias("name_2"),
    F.levenshtein(
        F.lower(F.col("a.name")),
        F.lower(F.col("b.name"))
    ).alias("edit_distance"),
    F.greatest(F.length("a.name"), F.length("b.name")).alias("max_len"),
)

# Step 3: Convert distance to similarity score (0 to 1)
pairs_scored = pairs_with_dist.withColumn(
    "similarity",
    F.round(1 - (F.col("edit_distance") / F.col("max_len")), 2)
)

# Step 4: Filter by threshold
matches = pairs_scored.filter(F.col("similarity") >= 0.7)
matches.select("id_1", "id_2", "name_1", "name_2", "similarity").show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Create candidate pairs via cross join
- **What happens:** Generates all (n*(n-1)/2) unique pairs. Filter `id_1 < id_2` avoids comparing (A,B) and (B,A) and self-pairs.
- **Pairs created:** (1,2), (1,3), (1,4), (1,5), (1,6), (1,7), (2,3), ... (6,7) = 21 pairs total.

#### Step 2: Compute Levenshtein distance
- **What happens:** `levenshtein("john smith", "jon smith")` = 1 (one character deletion). Lower-case both names first for case-insensitive matching.

#### Step 3: Normalize to similarity score
- **What happens:** `similarity = 1 - (edit_distance / max_length)`. For "John Smith" vs "Jon Smith": `1 - (1/10) = 0.90`.

#### Step 4: Filter by threshold
- **What happens:** Keeps only pairs with similarity >= 0.70.

---

## Method 2: Soundex for Phonetic Matching

```python
# Soundex encodes names by how they sound, ignoring spelling variations
pairs_soundex = df.alias("a").crossJoin(df.alias("b")).filter(
    F.col("a.id") < F.col("b.id")
)

result_soundex = pairs_soundex.select(
    F.col("a.id").alias("id_1"),
    F.col("b.id").alias("id_2"),
    F.col("a.name").alias("name_1"),
    F.col("b.name").alias("name_2"),
    F.soundex(F.col("a.name")).alias("soundex_1"),
    F.soundex(F.col("b.name")).alias("soundex_2"),
).filter(
    F.col("soundex_1") == F.col("soundex_2")
)
result_soundex.show(truncate=False)
```

- **How Soundex works:** Encodes the first letter and maps subsequent consonants to digits. "Smith" and "Smyth" both encode to `S530`. Useful for names that sound similar but are spelled differently.

---

## Method 3: Multi-Field Scoring with Blocking

```python
# Step 1: Blocking — only compare records that share the same first letter of last name
# This dramatically reduces the number of comparisons
df_blocked = df.withColumn(
    "block_key",
    F.upper(F.substring(F.element_at(F.split("name", " "), -1), 1, 2))
)

# Step 2: Self-join within blocks only
blocked_pairs = (
    df_blocked.alias("a")
    .join(
        df_blocked.alias("b"),
        (F.col("a.block_key") == F.col("b.block_key")) & (F.col("a.id") < F.col("b.id")),
    )
)

# Step 3: Multi-field similarity scoring
scored = blocked_pairs.select(
    F.col("a.id").alias("id_1"),
    F.col("b.id").alias("id_2"),
    F.col("a.name").alias("name_1"),
    F.col("b.name").alias("name_2"),
    # Name similarity (Levenshtein-based)
    F.round(
        1 - F.levenshtein(F.lower(F.col("a.name")), F.lower(F.col("b.name")))
        / F.greatest(F.length("a.name"), F.length("b.name")),
        2,
    ).alias("name_sim"),
    # Email exact match (binary)
    F.when(F.col("a.email") == F.col("b.email"), 1.0).otherwise(0.0).alias("email_match"),
    # Address similarity
    F.round(
        1 - F.levenshtein(F.lower(F.col("a.address")), F.lower(F.col("b.address")))
        / F.greatest(F.length("a.address"), F.length("b.address")),
        2,
    ).alias("addr_sim"),
)

# Step 4: Weighted composite score
final = scored.withColumn(
    "composite_score",
    F.round(
        F.col("name_sim") * 0.4 + F.col("email_match") * 0.35 + F.col("addr_sim") * 0.25,
        2,
    ),
).filter(F.col("composite_score") >= 0.6)

final.orderBy(F.desc("composite_score")).show(truncate=False)
```

### Key Concepts in Method 3

1. **Blocking:** Instead of comparing every pair (O(n²)), only compare records that share a "block key" (e.g., first 2 letters of last name). Reduces comparisons dramatically.
2. **Multi-field scoring:** Combine similarity scores from multiple columns with weights to get a composite match score.
3. **Threshold tuning:** The 0.6 threshold is a starting point — in practice, manually review borderline cases to calibrate.

---

## Method 4: Spark SQL

```python
df.createOrReplaceTempView("customers")

result_sql = spark.sql("""
    SELECT
        a.id AS id_1,
        b.id AS id_2,
        a.name AS name_1,
        b.name AS name_2,
        ROUND(1 - levenshtein(LOWER(a.name), LOWER(b.name))
              / GREATEST(LENGTH(a.name), LENGTH(b.name)), 2) AS name_similarity
    FROM customers a
    CROSS JOIN customers b
    WHERE a.id < b.id
      AND (
          -- Name similarity check
          1 - levenshtein(LOWER(a.name), LOWER(b.name))
              / GREATEST(LENGTH(a.name), LENGTH(b.name)) >= 0.7
          -- OR same email
          OR a.email = b.email
      )
    ORDER BY name_similarity DESC
""")
result_sql.show(truncate=False)
```

---

## Comparison of Methods

| Method | Accuracy | Scalability | When to Use |
|--------|----------|-------------|-------------|
| Levenshtein | Good for typos | O(n²) without blocking | Small datasets, character-level errors |
| Soundex | Good for phonetic | O(n²) without blocking | Names that sound similar but spelled differently |
| Multi-field + blocking | Best overall | O(n²/k) where k = blocks | Production — combines multiple signals |
| Spark SQL | Same as Levenshtein | O(n²) | Quick prototyping |

## Key Interview Talking Points

1. **Blocking is essential at scale.** Without it, comparing 1M records requires 500B pair comparisons. With good blocking keys, you might reduce this to millions.
2. **Common blocking keys:** First letter of name, ZIP code, Soundex code, email domain — anything that similar records will share.
3. **Levenshtein is built into PySpark** (`F.levenshtein()`), but **Jaro-Winkler is not** — you'd need a UDF or a library like `jellyfish`.
4. **Transitive closure:** If A matches B and B matches C, then A, B, and C should all be in the same group. Use iterative connected-components or GraphFrames after matching.
5. In production, consider libraries like **Zingg**, **Splink**, or **dedupe** that provide ML-based entity resolution on Spark.
6. Always normalize before comparing: lowercase, trim whitespace, remove special characters, standardize abbreviations (St→Street, Ave→Avenue).
