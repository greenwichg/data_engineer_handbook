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

## Method 4: Unpivot Using create_map() + explode()

```python
from pyspark.sql.functions import create_map, lit, explode

# Build a map: {month_name -> sales_value}
# Using a second sample dataset with monthly columns
data_wide = [
    ("S001", "Laptop", 120, 95, 140),
    ("S002", "Phone", 200, 180, 210),
    ("S003", "Tablet", 80, None, 90)
]
columns_wide = ["store_id", "product", "jan_sales", "feb_sales", "mar_sales"]
df_wide = spark.createDataFrame(data_wide, columns_wide)

unpivoted_v2 = df_wide.select(
    "store_id",
    "product",
    explode(
        create_map(
            lit("Jan"), col("jan_sales"),
            lit("Feb"), col("feb_sales"),
            lit("Mar"), col("mar_sales")
        )
    ).alias("month", "sales")
)

unpivoted_v2.show(truncate=False)
```

### How create_map() + explode() Works

#### Step 1: create_map() builds a dictionary per row

| store_id | product | map_column                          |
|----------|---------|-------------------------------------|
| S001     | Laptop  | {Jan: 120, Feb: 95, Mar: 140}       |
| S002     | Phone   | {Jan: 200, Feb: 180, Mar: 210}      |

#### Step 2: explode() on a map produces key-value rows

Each map entry becomes its own row with `key` and `value` columns.

**Connection to quantity_explode:** Both patterns create a collection (array or map) and explode it. `quantity_explode` uses `array_repeat` -> `explode`. This uses `create_map` -> `explode`.

---

## Method 5: Unpivot Using array() + posexplode()

```python
from pyspark.sql.functions import array, posexplode, when

# Build array of values, use position as month index
unpivoted_v3 = df_wide.select(
    "store_id",
    "product",
    posexplode(
        array(col("jan_sales"), col("feb_sales"), col("mar_sales"))
    ).alias("month_idx", "sales")
)

# Map index to month name
unpivoted_v3 = unpivoted_v3.withColumn(
    "month",
    when(col("month_idx") == 0, "Jan")
    .when(col("month_idx") == 1, "Feb")
    .when(col("month_idx") == 2, "Mar")
).select("store_id", "product", "month", "sales")

unpivoted_v3.show(truncate=False)
```

`posexplode` is like `explode` but also returns the array index (0-based).

---

## Method 6: Unpivot Using SQL LATERAL VIEW

```python
df_wide.createOrReplaceTempView("sales_wide")

# Using stack with LATERAL VIEW syntax
spark.sql("""
    SELECT
        store_id,
        product,
        month,
        sales
    FROM sales_wide
    LATERAL VIEW stack(3,
        'Jan', jan_sales,
        'Feb', feb_sales,
        'Mar', mar_sales
    ) t AS month, sales
""").show(truncate=False)
```

---

## Method 7: Unpivot Using melt() / unpivot() (PySpark 3.4+)

```python
# melt() — PySpark equivalent of pandas melt()
unpivoted_melt = pivoted_df.melt(
    ids=["product"],
    values=["Q1", "Q2", "Q3"],
    variableColumnName="quarter",
    valueColumnName="sales"
)

unpivoted_melt.show()

# unpivot() — native API (also Spark 3.4+)
unpivoted_native = df_wide.unpivot(
    ids=["store_id", "product"],
    values=["jan_sales", "feb_sales", "mar_sales"],
    variableColumnName="month",
    valueColumnName="sales"
)

unpivoted_native.show(truncate=False)
```

- **Explanation:** `melt()` and `unpivot()` are the cleanest APIs for wide-to-long conversion, but require Spark 3.4+. In interviews, mention them but also know `stack()` and `create_map` + `explode` for older Spark versions.

---

## Practical Application: Unpivot + Re-Pivot for Cross-Tabulation

```python
# Round-trip: Wide -> Long -> Different Wide
# First unpivot, then pivot by a different dimension

# Unpivot to long format
long_df = df_wide.select(
    "store_id",
    "product",
    expr("stack(3, 'Jan', jan_sales, 'Feb', feb_sales, 'Mar', mar_sales) AS (month, sales)")
)

# Re-pivot: now pivot by store instead of month
from pyspark.sql.functions import first

repivoted = long_df.groupBy("product", "month").pivot("store_id").agg(
    first("sales")
).orderBy("product", "month")

repivoted.show(truncate=False)
```

---

## Practical Application: Unpivot Multiple Value Columns

```python
# What if you have both sales AND returns per month?
multi_data = [
    ("S001", "Laptop", 120, 10, 95, 8, 140, 12),
    ("S002", "Phone", 200, 15, 180, 20, 210, 18)
]
multi_cols = ["store_id", "product",
              "jan_sales", "jan_returns",
              "feb_sales", "feb_returns",
              "mar_sales", "mar_returns"]
multi_df = spark.createDataFrame(multi_data, multi_cols)

# Stack pairs of columns together
multi_unpivoted = multi_df.select(
    "store_id",
    "product",
    expr("""
        stack(3,
            'Jan', jan_sales, jan_returns,
            'Feb', feb_sales, feb_returns,
            'Mar', mar_sales, mar_returns
        ) AS (month, sales, returns)
    """)
)

multi_unpivoted.show(truncate=False)
```

- **Output:**

  | store_id | product | month | sales | returns |
  |----------|---------|-------|-------|---------|
  | S001     | Laptop  | Jan   | 120   | 10      |
  | S001     | Laptop  | Feb   | 95    | 8       |
  | S001     | Laptop  | Mar   | 140   | 12      |
  | S002     | Phone   | Jan   | 200   | 15      |
  | S002     | Phone   | Feb   | 180   | 20      |
  | S002     | Phone   | Mar   | 210   | 18      |

---

## Filtering Nulls After Unpivot

```python
# By default, stack() keeps null values. To drop them:
unpivoted_no_nulls = unpivoted_df.filter(col("sales").isNotNull())
unpivoted_no_nulls.show(truncate=False)

# With create_map + explode, nulls in map values are kept
# With explode_outer, nulls are also kept
# Use .filter() after to remove if needed
```

---

## Unpivot Method Comparison

| Method | Pros | Cons | Spark Version |
|--------|------|------|---------------|
| `stack()` | Fast, no serialization | SQL expression syntax | All |
| `create_map` + `explode` | Pure DataFrame API | Map doesn't allow null keys | All |
| `array` + `posexplode` | Gives position index | Requires manual index-to-name mapping | All |
| SQL `LATERAL VIEW` | Familiar to SQL users | Requires temp view | All |
| `melt()` / `unpivot()` native | Cleanest API, most readable | Spark 3.4+ only | 3.4+ |

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
3. **Null handling:** If a product doesn't have sales for a quarter, the pivot fills it with `null`. Use `.fillna(0)` to replace nulls. For unpivot, `stack()` preserves nulls by default — use `.filter()` to remove them.
4. **Multiple aggregations:** You can apply multiple agg functions: `.agg(sum("sales"), avg("sales"))` — this creates columns like `Q1_sum_sales`, `Q1_avg_sales`.
5. **Unpivot is the reverse of pivot:** `pivot` goes long-to-wide (rows-to-columns). `unpivot`/`melt` goes wide-to-long (columns-to-rows). Know both directions.
6. **`stack()` is the most interview-friendly:** It's compact, doesn't require imports, and works in both DataFrame and SQL contexts. `stack(N, k1, v1, k2, v2, ...)` creates N rows per input row.
7. **Connection to the explode family:**
   - `quantity_explode`: `array_repeat` -> `explode` (repeat a value N times)
   - `expand_date_ranges`: `sequence` -> `explode` (generate dates)
   - `unpivot`: `create_map` -> `explode` (columns to rows)
   - All follow the same pattern: **build a collection, then explode it**.
8. **When to unpivot in real projects:**
   - Converting Excel/CSV "wide" reports to database-friendly "long" format
   - Preparing data for time-series analysis (monthly columns -> date + value rows)
   - Normalizing denormalized tables for proper joins
   - ETL pipelines that ingest wide-format source data
9. **Mention `unpivot()` / `melt()` for modern Spark:** Shows you know the latest API. But always be prepared to write `stack()` for older versions.

## Summary

| Operation | Method | Function |
|-----------|--------|----------|
| Pivot (long to wide) | `groupBy().pivot().agg()` | Reshapes rows into columns |
| Unpivot (wide to long) | `stack()` via `expr()` | Reshapes columns into rows |
| Unpivot (wide to long) | `create_map()` + `explode()` | Pure DataFrame API approach |
| Unpivot (wide to long) | `array()` + `posexplode()` | With position index |
| Unpivot (wide to long) | SQL `LATERAL VIEW stack()` | SQL syntax approach |
| Unpivot (PySpark 3.4+) | `melt()` / `unpivot()` | Native DataFrame method |
