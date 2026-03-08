# PySpark Implementation: Fix Names (Title Case String Manipulation)

## Problem Statement

Given a `Users` table with `user_id` and `name`, fix the names so that only the **first letter is uppercase** and the rest are lowercase. This is **LeetCode 1667 — Fix Names in a Table**.

### Sample Data

```
user_id  name
1        aLICE
2        bOB
3        CHARLIE
4        diana
```

### Expected Output

| user_id | name    |
|---------|---------|
| 1       | Alice   |
| 2       | Bob     |
| 3       | Charlie |
| 4       | Diana   |

---

## Method 1: Using initcap() (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, initcap

spark = SparkSession.builder.appName("FixNames").getOrCreate()

data = [(1, "aLICE"), (2, "bOB"), (3, "CHARLIE"), (4, "diana")]
columns = ["user_id", "name"]
df = spark.createDataFrame(data, columns)

# initcap capitalizes first letter of each word, lowercases the rest
result = df.withColumn("name", initcap(col("name"))).orderBy("user_id")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Apply initcap()
- `initcap("aLICE")` → "Alice"
- `initcap("bOB")` → "Bob"
- `initcap("CHARLIE")` → "Charlie"
- `initcap("diana")` → "Diana"

**Note:** `initcap()` capitalizes the first letter of **each word** (space-delimited). If the name is "mary jane", it becomes "Mary Jane".

---

## Method 2: Using concat + upper + lower + substring

```python
from pyspark.sql.functions import col, upper, lower, concat, substring

# Manual approach: UPPER(first char) + LOWER(rest)
result = df.withColumn(
    "name",
    concat(
        upper(substring(col("name"), 1, 1)),
        lower(substring(col("name"), 2, 100))  # 100 as max length
    )
).orderBy("user_id")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Extract and transform parts
- `substring("aLICE", 1, 1)` → "a" → `upper` → "A"
- `substring("aLICE", 2, 100)` → "LICE" → `lower` → "lice"
- `concat("A", "lice")` → "Alice"

---

## Method 3: Using expr with SQL string functions

```python
from pyspark.sql.functions import expr

result = df.withColumn(
    "name",
    expr("CONCAT(UPPER(LEFT(name, 1)), LOWER(SUBSTRING(name, 2)))")
).orderBy("user_id")

result.show()
```

---

## Method 4: Spark SQL

```python
df.createOrReplaceTempView("users")

result = spark.sql("""
    SELECT user_id, INITCAP(name) AS name
    FROM users
    ORDER BY user_id
""")

result.show()

-- Manual approach in SQL
result2 = spark.sql("""
    SELECT user_id,
        CONCAT(UPPER(LEFT(name, 1)), LOWER(SUBSTRING(name, 2))) AS name
    FROM users
    ORDER BY user_id
""")

result2.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| Multi-word name ("mary jane") | initcap → "Mary Jane"; concat approach → "Mary jane" | Use initcap for multi-word; concat only fixes first char |
| Single character name ("a") | initcap → "A"; substring(2) → empty | Works correctly |
| Empty string | initcap → empty; concat → empty | No issue |
| Name with numbers ("3rd") | initcap → "3rd" (no letter to capitalize) | Works correctly |
| Unicode characters | Depends on locale settings | Test with specific characters |

## Key Interview Talking Points

1. **initcap() vs. manual approach:**
   - `initcap()` is the PySpark built-in — capitalizes first letter of EVERY word.
   - Manual concat approach only fixes the very first character.
   - For single-word names, both are equivalent.

2. **substring indexing:**
   - PySpark/SQL: `substring(col, 1, 1)` — 1-based indexing.
   - Python: `string[0]` — 0-based indexing.

3. **Follow-up: "What about names with special characters like O'Brien?"**
   - `initcap("o'brien")` → "O'Brien" (treats apostrophe as word separator in most implementations).
   - Manual approach → "O'brien" — only capitalizes position 1.

4. **Performance:**
   - String operations are computed per-row. For billions of rows, these are CPU-bound, not shuffle-bound.
