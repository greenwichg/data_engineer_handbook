# PySpark Implementation: Pivot and Unpivot Data

## Problem Statement

Given a dataset of product sales across different quarters, **pivot** the data so that each quarter becomes a separate column showing the total sales. Then demonstrate how to **unpivot** (melt) the pivoted data back to its original long format. This is a very common interview question that tests your understanding of data reshaping in PySpark.

### Sample Data

```
product  quarter  sales
Phone    Q1       1000
Phone    Q2       1500
Phone    Q3       1200
Laptop   Q1       2000
Laptop   Q2       2500
Laptop   Q3       3000
Tablet   Q1       800
Tablet   Q2       900
Tablet   Q3       1100
```

### Expected Pivot Output

| product | Q1   | Q2   | Q3   |
|---------|------|------|------|
| Phone   | 1000 | 1500 | 1200 |
| Laptop  | 2000 | 2500 | 3000 |
| Tablet  | 800  | 900  | 1100 |

### Expected Unpivot Output (back to original)

| product | quarter | sales |
|---------|---------|-------|
| Phone   | Q1      | 1000  |
| Phone   | Q2      | 1500  |
| Phone   | Q3      | 1200  |
| Laptop  | Q1      | 2000  |
| Laptop  | Q2      | 2500  |
| Laptop  | Q3      | 3000  |
| Tablet  | Q1      | 800   |
| Tablet  | Q2      | 900   |
| Tablet  | Q3      | 1100  |

---

## Method 1: Pivot Using groupBy and pivot

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import sum, col

# Initialize Spark session
spark = SparkSession.builder.appName("PivotUnpivot").getOrCreate()

# Sample data
data = [
    ("Phone", "Q1", 1000),
    ("Phone", "Q2", 1500),
    ("Phone", "Q3", 1200),
    ("Laptop", "Q1", 2000),
    ("Laptop", "Q2", 2500),
    ("Laptop", "Q3", 3000),
    ("Tablet", "Q1", 800),
    ("Tablet", "Q2", 900),
    ("Tablet", "Q3", 1100)
]

columns = ["product", "quarter", "sales"]
df = spark.createDataFrame(data, columns)

# Pivot: Convert quarters from rows to columns
pivoted_df = df.groupBy("product").pivot("quarter").agg(sum("sales"))

pivoted_df.show()
```

### Step-by-Step Explanation

#### Step 1: Create DataFrame
- **What happens:** Creates a DataFrame with 9 rows (3 products x 3 quarters).
- **Output:**

  | product | quarter | sales |
  |---------|---------|-------|
  | Phone   | Q1      | 1000  |
  | Phone   | Q2      | 1500  |
  | Phone   | Q3      | 1200  |
  | Laptop  | Q1      | 2000  |
  | Laptop  | Q2      | 2500  |
  | Laptop  | Q3      | 3000  |
  | Tablet  | Q1      | 800   |
  | Tablet  | Q2      | 900   |
  | Tablet  | Q3      | 1100  |

#### Step 2: groupBy("product").pivot("quarter").agg(sum("sales"))
- **What happens:**
  1. `groupBy("product")` groups all rows by product.
  2. `.pivot("quarter")` takes the distinct values of the `quarter` column (Q1, Q2, Q3) and creates a new column for each.
  3. `.agg(sum("sales"))` fills each new column with the aggregated (summed) sales value.
- **Output (pivoted_df):**

  | product | Q1   | Q2   | Q3   |
  |---------|------|------|------|
  | Phone   | 1000 | 1500 | 1200 |
  | Laptop  | 2000 | 2500 | 3000 |
  | Tablet  | 800  | 900  | 1100 |

---

## Method 2: Pivot with Explicit Values (Performance Optimization)

```python
# Specifying pivot values explicitly avoids an extra scan to find distinct values
pivoted_df_optimized = df.groupBy("product") \
    .pivot("quarter", ["Q1", "Q2", "Q3"]) \
    .agg(sum("sales"))

pivoted_df_optimized.show()
```

- **Explanation:** When you pass the list of values `["Q1", "Q2", "Q3"]` to `pivot()`, Spark doesn't need to perform a full scan of the `quarter` column to discover distinct values. This is significantly faster on large datasets.

---

## Method 3: Unpivot Using stack()

```python
from pyspark.sql.functions import expr

# Start from the pivoted DataFrame
# Unpivot: Convert columns back to rows using stack()
unpivoted_df = pivoted_df.select(
    "product",
    expr("stack(3, 'Q1', Q1, 'Q2', Q2, 'Q3', Q3) as (quarter, sales)")
)

unpivoted_df.show()
```

### Step-by-Step Explanation

#### Step 1: Understanding stack()
- **Syntax:** `stack(n, val1, col1, val2, col2, ...)` where `n` is the number of column pairs.
- **What happens:** For each row in the pivoted DataFrame, `stack(3, ...)` generates 3 rows:
  - Row 1: quarter = 'Q1', sales = value from Q1 column
  - Row 2: quarter = 'Q2', sales = value from Q2 column
  - Row 3: quarter = 'Q3', sales = value from Q3 column

#### Step 2: Final Output
- **Output (unpivoted_df):**

  | product | quarter | sales |
  |---------|---------|-------|
  | Phone   | Q1      | 1000  |
  | Phone   | Q2      | 1500  |
  | Phone   | Q3      | 1200  |
  | Laptop  | Q1      | 2000  |
  | Laptop  | Q2      | 2500  |
  | Laptop  | Q3      | 3000  |
  | Tablet  | Q1      | 800   |
  | Tablet  | Q2      | 900   |
  | Tablet  | Q3      | 1100  |

---

## Method 4: Unpivot Using melt (PySpark 3.4+)

```python
# Available in PySpark 3.4 and above
unpivoted_melt = pivoted_df.melt(
    ids=["product"],
    values=["Q1", "Q2", "Q3"],
    variableColumnName="quarter",
    valueColumnName="sales"
)

unpivoted_melt.show()
```

- **Explanation:** The `melt()` function is the PySpark equivalent of pandas `melt()`. It converts wide-format data to long-format by turning specified columns into rows.

---

## Performance Tips

| Tip | Details |
|-----|---------|
| Specify pivot values | Always pass explicit values to `pivot()` to avoid a full scan |
| Limit pivot columns | Too many distinct values in the pivot column leads to wide DataFrames and poor performance |
| Use `stack()` for unpivot | `stack()` is a built-in SQL function and doesn't require UDFs |
| Filter before pivot | Reduce data volume before pivoting for better performance |

## Key Interview Talking Points

1. **Why is explicit pivot faster?** It avoids an additional aggregation job to discover distinct values.
2. **When to use pivot?** Reporting, cross-tabulation, feature engineering in ML pipelines.
3. **Null handling:** If a product doesn't have sales for a quarter, the pivot fills it with `null`. Use `.fillna(0)` to replace nulls.
4. **Multiple aggregations:** You can apply multiple agg functions: `.agg(sum("sales"), avg("sales"))` — this creates columns like `Q1_sum_sales`, `Q1_avg_sales`.

## Summary

| Operation | Method | Function |
|-----------|--------|----------|
| Pivot (long to wide) | `groupBy().pivot().agg()` | Reshapes rows into columns |
| Unpivot (wide to long) | `stack()` via `expr()` | Reshapes columns into rows |
| Unpivot (PySpark 3.4+) | `melt()` | Native DataFrame method |
