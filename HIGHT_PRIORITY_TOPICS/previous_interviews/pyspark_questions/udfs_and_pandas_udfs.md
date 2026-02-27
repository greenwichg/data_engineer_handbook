# PySpark Implementation: User-Defined Functions (UDFs) and Pandas UDFs

## Problem Statement

Implement custom transformations using **Python UDFs**, **Pandas UDFs (vectorized UDFs)**, and understand when to use each. Given a dataset of customer reviews, apply custom text processing that can't be done with built-in functions — such as sentiment scoring, custom parsing, and complex business logic. UDFs are asked in almost every PySpark interview.

### Sample Data

```
review_id  customer_name   review_text                              rating
R001       John Smith      This laptop is absolutely amazing!       5
R002       Jane Doe        Terrible product, broke in 2 days        1
R003       Bob Wilson      Average quality, nothing special          3
R004       Alice Brown     LOVE IT!!! Best purchase ever!!!         5
R005       Charlie Davis   not bad, could be better                  3
```

---

## Method 1: Basic Python UDF

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, udf
from pyspark.sql.types import StringType, IntegerType, FloatType, ArrayType

# Initialize Spark session
spark = SparkSession.builder.appName("UDFExamples").getOrCreate()

# Sample data
data = [
    ("R001", "John Smith", "This laptop is absolutely amazing!", 5),
    ("R002", "Jane Doe", "Terrible product, broke in 2 days", 1),
    ("R003", "Bob Wilson", "Average quality, nothing special", 3),
    ("R004", "Alice Brown", "LOVE IT!!! Best purchase ever!!!", 5),
    ("R005", "Charlie Davis", "not bad, could be better", 3)
]

columns = ["review_id", "customer_name", "review_text", "rating"]
df = spark.createDataFrame(data, columns)

# Define a simple Python UDF for sentiment classification
@udf(StringType())
def classify_sentiment(rating):
    """Classify review based on rating."""
    if rating is None:
        return "Unknown"
    elif rating >= 4:
        return "Positive"
    elif rating <= 2:
        return "Negative"
    else:
        return "Neutral"

# Apply UDF
df_sentiment = df.withColumn("sentiment", classify_sentiment(col("rating")))

df_sentiment.show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Define the UDF
- **What happens:** The `@udf(StringType())` decorator registers a Python function as a Spark UDF. The return type (`StringType()`) must be specified.
- Alternatively, register without decorator: `classify_sentiment_udf = udf(classify_sentiment, StringType())`

#### Step 2: Apply to DataFrame
- **Output:**

  | review_id | customer_name | review_text                        | rating | sentiment |
  |-----------|---------------|------------------------------------|--------|-----------|
  | R001      | John Smith    | This laptop is absolutely amazing! | 5      | Positive  |
  | R002      | Jane Doe      | Terrible product, broke in 2 days  | 1      | Negative  |
  | R003      | Bob Wilson    | Average quality, nothing special   | 3      | Neutral   |
  | R004      | Alice Brown   | LOVE IT!!! Best purchase ever!!!   | 5      | Positive  |
  | R005      | Charlie Davis | not bad, could be better           | 3      | Neutral   |

---

## Method 2: UDF Returning Complex Types

```python
# UDF that returns an array (multiple values)
@udf(ArrayType(StringType()))
def extract_keywords(text):
    """Extract words longer than 4 characters as keywords."""
    if text is None:
        return []
    words = text.lower().replace("!", "").replace(",", "").split()
    return [w for w in words if len(w) > 4]

df_keywords = df.withColumn("keywords", extract_keywords(col("review_text")))
df_keywords.select("review_id", "review_text", "keywords").show(truncate=False)
```

- **Output:**

  | review_id | review_text                        | keywords                           |
  |-----------|------------------------------------|------------------------------------|
  | R001      | This laptop is absolutely amazing! | [laptop, absolutely, amazing]      |
  | R002      | Terrible product, broke in 2 days  | [terrible, product, broke]         |
  | R003      | Average quality, nothing special   | [average, quality, nothing, special]|
  | R004      | LOVE IT!!! Best purchase ever!!!   | [purchase]                         |
  | R005      | not bad, could be better           | [could, better]                    |

---

## Method 3: UDF with Multiple Input Columns

```python
from pyspark.sql.types import StructType, StructField

# UDF taking multiple columns as input
@udf(StringType())
def create_review_summary(name, text, rating):
    """Create a summary string from multiple columns."""
    if name is None or text is None:
        return "N/A"
    stars = "*" * (rating if rating else 0)
    short_text = text[:30] + "..." if len(text) > 30 else text
    return f"{name} ({stars}): {short_text}"

df_summary = df.withColumn(
    "summary",
    create_review_summary(col("customer_name"), col("review_text"), col("rating"))
)

df_summary.select("review_id", "summary").show(truncate=False)
```

---

## Method 4: Pandas UDF (Vectorized UDF) — Much Faster

```python
import pandas as pd
from pyspark.sql.functions import pandas_udf

# Pandas UDF: processes data in batches using Apache Arrow
# Much faster than row-by-row Python UDFs

@pandas_udf(StringType())
def classify_sentiment_pandas(ratings: pd.Series) -> pd.Series:
    """Vectorized sentiment classification."""
    return ratings.apply(
        lambda r: "Positive" if r >= 4 else ("Negative" if r <= 2 else "Neutral")
    )

df_pandas_udf = df.withColumn("sentiment", classify_sentiment_pandas(col("rating")))
df_pandas_udf.show(truncate=False)
```

### Why Pandas UDFs Are Faster

| Aspect | Python UDF | Pandas UDF |
|--------|-----------|------------|
| Processing | Row-by-row | Batch (vectorized) |
| Serialization | Python pickle (slow) | Apache Arrow (fast) |
| Speed | 10-100x slower | Near-native speed |
| Data format | Individual values | pandas Series/DataFrame |
| Use when | Complex logic per row | Batch operations, math |

---

## Method 5: Pandas UDF with Multiple Columns (Grouped Map)

```python
from pyspark.sql.functions import pandas_udf, PandasUDFType

# Grouped Map UDF: apply function to each group
# Useful for per-group transformations

# Define output schema
output_schema = df.schema.add("normalized_rating", FloatType())

@pandas_udf(output_schema, PandasUDFType.GROUPED_MAP)
def normalize_ratings(pdf: pd.DataFrame) -> pd.DataFrame:
    """Normalize ratings within each sentiment group to 0-1 range."""
    min_r = pdf["rating"].min()
    max_r = pdf["rating"].max()
    if max_r == min_r:
        pdf["normalized_rating"] = 0.5
    else:
        pdf["normalized_rating"] = (pdf["rating"] - min_r) / (max_r - min_r)
    return pdf

# First add sentiment, then normalize within each sentiment group
df_with_sentiment = df.withColumn("sentiment", classify_sentiment(col("rating")))

# Note: applyInPandas is the modern API (Spark 3.0+)
def normalize_ratings_v2(pdf: pd.DataFrame) -> pd.DataFrame:
    min_r = pdf["rating"].min()
    max_r = pdf["rating"].max()
    if max_r == min_r:
        pdf["normalized_rating"] = 0.5
    else:
        pdf["normalized_rating"] = (pdf["rating"] - min_r) / (max_r - min_r)
    return pdf

result = df_with_sentiment.groupBy("sentiment").applyInPandas(
    normalize_ratings_v2,
    schema="review_id string, customer_name string, review_text string, rating int, sentiment string, normalized_rating float"
)

result.show(truncate=False)
```

---

## Method 6: Registering UDF for SQL Usage

```python
# Register UDF for use in Spark SQL
spark.udf.register("classify_sentiment_sql", classify_sentiment)

df.createOrReplaceTempView("reviews")

sql_result = spark.sql("""
    SELECT
        review_id,
        review_text,
        rating,
        classify_sentiment_sql(rating) AS sentiment
    FROM reviews
""")

sql_result.show(truncate=False)
```

---

## Common UDF Patterns in Interviews

### Pattern 1: Null-Safe UDF
```python
@udf(StringType())
def safe_upper(text):
    """Always handle None in UDFs — Spark passes nulls as Python None."""
    if text is None:
        return None
    return text.upper()
```

### Pattern 2: UDF with External Library
```python
import re

@udf(IntegerType())
def count_exclamations(text):
    """Count exclamation marks in text."""
    if text is None:
        return 0
    return len(re.findall(r'!', text))

df.withColumn("excitement", count_exclamations(col("review_text"))).show()
```

### Pattern 3: UDF Returning Struct
```python
from pyspark.sql.types import StructType, StructField

name_schema = StructType([
    StructField("first_name", StringType()),
    StructField("last_name", StringType())
])

@udf(name_schema)
def split_name(full_name):
    if full_name is None:
        return (None, None)
    parts = full_name.split(" ", 1)
    return (parts[0], parts[1] if len(parts) > 1 else None)

df.withColumn("name_parts", split_name(col("customer_name"))) \
    .select("customer_name", "name_parts.first_name", "name_parts.last_name") \
    .show()
```

- **Output:**

  | customer_name | first_name | last_name |
  |---------------|------------|-----------|
  | John Smith    | John       | Smith     |
  | Jane Doe      | Jane       | Doe       |
  | Bob Wilson    | Bob        | Wilson    |
  | Alice Brown   | Alice      | Brown     |
  | Charlie Davis | Charlie    | Davis     |

---

## Performance Comparison

```
Built-in functions  >>  Pandas UDF  >>  Python UDF

Example: Uppercasing 10M strings
- Built-in upper():    ~2 seconds
- Pandas UDF:          ~5 seconds
- Python UDF:          ~45 seconds
```

**Rule of thumb:** Always prefer built-in functions. Use Pandas UDFs when built-in functions can't handle the logic. Use Python UDFs only as a last resort.

---

## Key Interview Talking Points

1. **Why are Python UDFs slow?** Data must be serialized from JVM → Python (pickle), processed row-by-row, then sent back to JVM. This serialization overhead is massive.

2. **Why are Pandas UDFs faster?** They use Apache Arrow for efficient columnar data transfer and process data in batches (vectorized), avoiding per-row overhead.

3. **UDF types in PySpark 3.x:**
   - `@pandas_udf` with `pd.Series → pd.Series` (scalar)
   - `applyInPandas()` (grouped map — replaces GROUPED_MAP)
   - `mapInPandas()` (map — arbitrary transformation)
   - `cogrouped.applyInPandas()` (co-grouped — two DataFrames)

4. **Common pitfall:** Forgetting to handle nulls. Spark sends null values to UDFs as Python `None` — always add null checks.

5. **When NOT to use UDFs:**
   - If a built-in function exists (e.g., use `upper()` not a UDF)
   - For simple conditional logic (use `when().otherwise()` instead)
   - For type casting (use `cast()`)

6. **Broadcast variables in UDFs:** If your UDF needs to reference a lookup table, use a broadcast variable to avoid shipping it with every task.
