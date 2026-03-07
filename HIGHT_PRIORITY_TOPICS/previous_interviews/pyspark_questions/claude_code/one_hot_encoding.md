# PySpark Implementation: One-Hot Encoding Categorical Columns

## Problem Statement
Given a DataFrame of users and their preferred genre, convert the categorical `preferred_genre`
column into multiple binary indicator columns -- one per distinct category. The result should have
columns `is_A`, `is_B`, `is_C`, etc., where a `1` indicates the user belongs to that category and
`0` otherwise. Handle unknown categories gracefully and discuss strategies for high-cardinality
columns.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("OneHotEncoding").getOrCreate()

data = [
    (1, "Action"),
    (2, "Comedy"),
    (3, "Drama"),
    (4, "Action"),
    (5, "Comedy"),
    (6, "Action"),
    (7, "Drama"),
    (8, None),       # unknown / missing genre
]

df = spark.createDataFrame(data, ["user_id", "preferred_genre"])
df.show()
```

| user_id | preferred_genre |
|---------|-----------------|
| 1       | Action          |
| 2       | Comedy          |
| 3       | Drama           |
| 4       | Action          |
| 5       | Comedy          |
| 6       | Action          |
| 7       | Drama           |
| 8       | null            |

### Expected Output

| user_id | preferred_genre | is_Action | is_Comedy | is_Drama |
|---------|-----------------|-----------|-----------|----------|
| 1       | Action          | 1         | 0         | 0        |
| 2       | Comedy          | 0         | 1         | 0        |
| 3       | Drama           | 0         | 0         | 1        |
| 4       | Action          | 1         | 0         | 0        |
| 5       | Comedy          | 0         | 1         | 0        |
| 6       | Action          | 1         | 0         | 0        |
| 7       | Drama           | 0         | 0         | 1        |
| 8       | null            | 0         | 0         | 0        |

---

## Method 1: Dynamic Pivot with `groupBy` + `pivot` (Recommended)

```python
from pyspark.sql import functions as F

# Step 1 -- add a constant column that will become the cell value after pivot
df_flagged = df.withColumn("flag", F.lit(1))

# Step 2 -- pivot on the genre column
df_pivoted = (
    df_flagged
    .groupBy("user_id", "preferred_genre")
    .pivot("preferred_genre")
    .agg(F.first("flag"))
)

# Step 3 -- rename columns to is_<genre> and fill nulls with 0
genres = [c for c in df_pivoted.columns if c not in ("user_id", "preferred_genre", "null")]
for genre in genres:
    df_pivoted = df_pivoted.withColumnRenamed(genre, f"is_{genre}")

# Drop the spurious 'null' pivot column if it exists
if "null" in df_pivoted.columns:
    df_pivoted = df_pivoted.drop("null")

df_result = df_pivoted.fillna(0)
df_result.orderBy("user_id").show()
```

### Step-by-Step Explanation

**After Step 1** -- a constant `flag=1` is added so pivot has a value to aggregate:

| user_id | preferred_genre | flag |
|---------|-----------------|------|
| 1       | Action          | 1    |
| 2       | Comedy          | 1    |
| 8       | null            | 1    |

**After Step 2** -- `pivot` creates one column per distinct genre value:

| user_id | preferred_genre | Action | Comedy | Drama | null |
|---------|-----------------|--------|--------|-------|------|
| 1       | Action          | 1      | null   | null  | null |
| 2       | Comedy          | null   | 1      | null  | null |
| 8       | null            | null   | null   | null  | 1    |

**After Step 3** -- columns renamed and nulls filled with 0:

| user_id | preferred_genre | is_Action | is_Comedy | is_Drama |
|---------|-----------------|-----------|-----------|----------|
| 1       | Action          | 1         | 0         | 0        |
| 8       | null            | 0         | 0         | 0        |

---

## Method 2: Explicit `when/otherwise` with Known Categories

```python
from pyspark.sql import functions as F

# If categories are known ahead of time, build columns explicitly.
known_genres = ["Action", "Comedy", "Drama"]

df_encoded = df
for genre in known_genres:
    df_encoded = df_encoded.withColumn(
        f"is_{genre}",
        F.when(F.col("preferred_genre") == genre, 1).otherwise(0)
    )

df_encoded.orderBy("user_id").show()
```

This approach is simple and readable but requires you to know (or collect) the distinct
categories beforehand. For a fully dynamic version you can collect first:

```python
# Dynamic collection of categories
known_genres = (
    df.filter(F.col("preferred_genre").isNotNull())
    .select("preferred_genre")
    .distinct()
    .rdd.flatMap(lambda x: x)
    .collect()
)
# Then loop as above
```

---

## Method 3: MLlib StringIndexer + OneHotEncoder (ML Pipeline)

```python
from pyspark.ml.feature import StringIndexer, OneHotEncoder
from pyspark.ml import Pipeline

# Handle nulls first -- StringIndexer can handle them with handleInvalid="keep"
indexer = StringIndexer(
    inputCol="preferred_genre",
    outputCol="genre_index",
    handleInvalid="keep"          # unknown / null -> extra index
)

encoder = OneHotEncoder(
    inputCols=["genre_index"],
    outputCols=["genre_vec"],
    dropLast=False                # keep all categories
)

pipeline = Pipeline(stages=[indexer, encoder])
model = pipeline.fit(df)
df_ml = model.transform(df)

df_ml.select("user_id", "preferred_genre", "genre_index", "genre_vec").show(truncate=False)
```

> **Note:** This produces a SparseVector column, which is ideal for ML pipelines but less
> convenient for tabular reporting. Use Method 1 or 2 when the output must be separate columns.

---

## Key Interview Talking Points

1. **Pivot is the most idiomatic PySpark approach** -- it handles dynamic categories and produces
   clean column names with a single transformation chain.

2. **Always supply known pivot values when possible** -- `pivot("col", ["A","B","C"])` avoids an
   extra pass over the data to discover distinct values, significantly improving performance.

3. **High cardinality warning** -- one-hot encoding a column with thousands of distinct values
   creates thousands of columns. Consider feature hashing (`HashingTF`) or target encoding instead.

4. **Null handling matters** -- decide upfront whether null/unknown maps to all-zeros (treat as
   missing) or gets its own indicator column (`is_Unknown`).

5. **`when/otherwise` is O(categories) in code but executes in a single pass** -- it doesn't
   trigger a shuffle, unlike `pivot` which requires a `groupBy`.

6. **MLlib OneHotEncoder produces sparse vectors** -- great for downstream ML but not for writing
   to a relational table. Convert with `vector_to_array()` (Spark 3.0+) if needed.

7. **Determinism** -- `StringIndexer` assigns indices by frequency (most frequent = 0). Use
   `stringOrderType="alphabetAsc"` for deterministic ordering across runs.

8. **Memory consideration** -- `pivot` materializes all category columns in memory. For very wide
   pivots, prefer sparse representations or dictionary encoding.
