# PySpark Implementation: Split and Explode Comma-Separated Values

## Problem Statement 

Given a table where each row contains a **comma-separated list of products**, transform it so that each product gets its own row while maintaining the customer relationship. This tests your understanding of `split()` and `explode()` — two of the most commonly asked PySpark functions in interviews.

### Sample Data

```
customer_id  products
C001         Apple, Banana, Orange
C002         Laptop, Mouse
C003         Book
C004         Pen, Pencil, Eraser, Ruler
```

### Expected Output

| customer_id | product |
|-------------|---------|
| C001        | Apple   |
| C001        | Banana  |
| C001        | Orange  |
| C002        | Laptop  |
| C002        | Mouse   |
| C003        | Book    |
| C004        | Pen     |
| C004        | Pencil  |
| C004        | Eraser  |
| C004        | Ruler   |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import explode, split

spark = SparkSession.builder.appName("SplitExplode").getOrCreate()

data = [
    ("C001", "Apple, Banana, Orange"),
    ("C002", "Laptop, Mouse"),
    ("C003", "Book"),
    ("C004", "Pen, Pencil, Eraser, Ruler")
]

df = spark.createDataFrame(data, ["customer_id", "products"])

# Split the comma-separated string into an array, then explode into rows
exploded_df = df.select(
    "customer_id",
    explode(split("products", ", ")).alias("product")
)

exploded_df.show()
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: split() — Convert String to Array

- **What happens:** `split("products", ", ")` splits the string at each occurrence of `", "` (comma + space), producing an array column.
- **Intermediate state (conceptual — after split only):**

  | customer_id | product_array                        |
  |-------------|--------------------------------------|
  | C001        | [Apple, Banana, Orange]              |
  | C002        | [Laptop, Mouse]                      |
  | C003        | [Book]                               |
  | C004        | [Pen, Pencil, Eraser, Ruler]         |

  The delimiter `", "` must match exactly — if the data uses `","` (no space), adjust accordingly.

### Step 2: explode() — Convert Array to Rows

- **What happens:** `explode()` takes each array element and creates a separate row, duplicating `customer_id` for each element. C001 goes from 1 row with 3 products to 3 rows with 1 product each.
- **Output (exploded_df):**

  | customer_id | product |
  |-------------|---------|
  | C001        | Apple   |
  | C001        | Banana  |
  | C001        | Orange  |
  | C002        | Laptop  |
  | C002        | Mouse   |
  | C003        | Book    |
  | C004        | Pen     |
  | C004        | Pencil  |
  | C004        | Eraser  |
  | C004        | Ruler   |

  Row count: 4 input rows → 10 output rows.

---

## Alternative: Using explode_outer() to Preserve NULLs

```python
from pyspark.sql.functions import explode_outer

# Data with NULL and empty values
data_with_nulls = [
    ("C001", "Apple, Banana, Orange"),
    ("C002", "Laptop, Mouse"),
    ("C003", None),       # NULL products
    ("C004", ""),          # Empty string
    ("C005", "Book")
]

df_nulls = spark.createDataFrame(data_with_nulls, ["customer_id", "products"])

# explode_outer keeps rows with NULL/empty arrays
result = df_nulls.select(
    "customer_id",
    explode_outer(split("products", ", ")).alias("product")
)
result.show()
```

**Output comparison:**

| Function | C003 (NULL) | C004 (empty) | Total rows |
|----------|-------------|--------------|------------|
| `explode()` | Dropped | Dropped | 6 |
| `explode_outer()` | Kept (null) | Kept (empty) | 8 |

Use `explode_outer()` when you need to preserve all customers in the output — e.g., counting customers with zero products.

---

## Key Interview Talking Points

1. **split() + explode() is the standard pattern:** This two-function combo is the idiomatic way to normalize comma-separated values in PySpark. The equivalent Spark SQL is: `SELECT customer_id, explode(split(products, ', ')) AS product FROM table`.

2. **Delimiter precision matters:** `split("col", ", ")` (comma+space) differs from `split("col", ",")` (comma only). Mismatched delimiters produce values with leading spaces. Use `trim()` if spacing is inconsistent: `explode(split("products", ","))` followed by `.withColumn("product", trim(col("product")))`.

3. **explode() vs explode_outer():** `explode()` silently drops rows with NULL or empty arrays. `explode_outer()` preserves them with NULL values. In interviews, mentioning this edge case shows attention to data quality.

4. **Performance:** `explode()` can dramatically increase row count. For a table with 1M rows averaging 5 products each, the output is 5M rows. Plan downstream operations (joins, aggregations) accordingly and monitor memory usage.
