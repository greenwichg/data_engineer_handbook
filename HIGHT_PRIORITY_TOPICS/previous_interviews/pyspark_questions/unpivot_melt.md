# PySpark Implementation: Unpivot / Melt (Columns to Rows)

## Problem Statement 

Given a dataset with monthly sales stored as **separate columns** (`jan_sales`, `feb_sales`, `mar_sales`), transform it into a **long format** with one row per month. This is called **unpivot** (SQL term) or **melt** (pandas term) — the reverse of pivot. It uses `explode` on a constructed map/array, making it a close cousin of the `quantity_explode` pattern.

### Sample Data (Wide Format)

```
store_id  product   jan_sales  feb_sales  mar_sales
S001      Laptop    120        95         140
S002      Phone     200        180        210
S003      Tablet    80         null       90
```

### Expected Output (Long Format)

| store_id | product | month | sales |
|----------|---------|-------|-------|
| S001     | Laptop  | Jan   | 120   |
| S001     | Laptop  | Feb   | 95    |
| S001     | Laptop  | Mar   | 140   |
| S002     | Phone   | Jan   | 200   |
| S002     | Phone   | Feb   | 180   |
| S002     | Phone   | Mar   | 210   |
| S003     | Tablet  | Jan   | 80    |
| S003     | Tablet  | Feb   | null  |
| S003     | Tablet  | Mar   | 90    |

---

## Method 1: stack() Function (Recommended)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, expr

# Initialize Spark session
spark = SparkSession.builder.appName("Unpivot").getOrCreate()

# Sample data
data = [
    ("S001", "Laptop", 120, 95, 140),
    ("S002", "Phone", 200, 180, 210),
    ("S003", "Tablet", 80, None, 90)
]
columns = ["store_id", "product", "jan_sales", "feb_sales", "mar_sales"]
df = spark.createDataFrame(data, columns)

# Unpivot using stack()
# stack(N, key1, val1, key2, val2, ..., keyN, valN)
# N = number of key-value pairs
unpivoted = df.select(
    "store_id",
    "product",
    expr("""
        stack(3,
            'Jan', jan_sales,
            'Feb', feb_sales,
            'Mar', mar_sales
        ) AS (month, sales)
    """)
)

unpivoted.show(truncate=False)
```

### How stack() Works

`stack(N, key1, val1, key2, val2, ...)` creates N rows from each input row:

| Input Row | stack Output |
|-----------|-------------|
| S001, Laptop, 120, 95, 140 | (Jan, 120), (Feb, 95), (Mar, 140) → 3 rows |
| S002, Phone, 200, 180, 210 | (Jan, 200), (Feb, 180), (Mar, 210) → 3 rows |

Each pair `(key, value)` becomes a new row with columns named in the `AS` clause.

- **Output:**

  | store_id | product | month | sales |
  |----------|---------|-------|-------|
  | S001     | Laptop  | Jan   | 120   |
  | S001     | Laptop  | Feb   | 95    |
  | S001     | Laptop  | Mar   | 140   |
  | S002     | Phone   | Jan   | 200   |
  | S002     | Phone   | Feb   | 180   |
  | S002     | Phone   | Mar   | 210   |
  | S003     | Tablet  | Jan   | 80    |
  | S003     | Tablet  | Feb   | null  |
  | S003     | Tablet  | Mar   | 90    |

---

## Method 2: create_map() + explode() (The explode Pattern)

```python
from pyspark.sql.functions import create_map, lit, explode

# Build a map: {month_name -> sales_value}
unpivoted_v2 = df.select(
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

**Connection to quantity_explode:** Both patterns create a collection (array or map) and explode it. `quantity_explode` uses `array_repeat` → `explode`. This uses `create_map` → `explode`.

---

## Method 3: array() + posexplode() (With Index)

```python
from pyspark.sql.functions import array, posexplode

# Build array of values, use position as month index
months = ["Jan", "Feb", "Mar"]

unpivoted_v3 = df.select(
    "store_id",
    "product",
    posexplode(
        array(col("jan_sales"), col("feb_sales"), col("mar_sales"))
    ).alias("month_idx", "sales")
)

# Map index to month name
from pyspark.sql.functions import when

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

## Method 4: Using SQL

```python
df.createOrReplaceTempView("sales_wide")

# Using stack
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

## Method 5: Using unpivot() (Spark 3.4+)

```python
# Native unpivot (available in Spark 3.4 and later)
unpivoted_native = df.unpivot(
    ids=["store_id", "product"],
    values=["jan_sales", "feb_sales", "mar_sales"],
    variableColumnName="month",
    valueColumnName="sales"
)

unpivoted_native.show(truncate=False)
```

- **Note:** The native `unpivot()` is the cleanest API but requires Spark 3.4+. In interviews, mention it but also know `stack()` and `create_map` + `explode` for older Spark versions.

---

## Practical Application: Unpivot + Re-Pivot for Cross-Tabulation

```python
# Round-trip: Wide → Long → Different Wide
# First unpivot, then pivot by a different dimension

# Unpivot to long format
long_df = df.select(
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
unpivoted_no_nulls = unpivoted.filter(col("sales").isNotNull())
unpivoted_no_nulls.show(truncate=False)

# With create_map + explode, nulls in map values are kept
# With explode_outer, nulls are also kept
# Use .filter() after to remove if needed
```

---

## Method Comparison

| Method | Pros | Cons | Spark Version |
|--------|------|------|---------------|
| `stack()` | Fast, no serialization | SQL expression syntax | All |
| `create_map` + `explode` | Pure DataFrame API | Map doesn't allow null keys | All |
| `array` + `posexplode` | Gives position index | Requires manual index→name mapping | All |
| `unpivot()` native | Cleanest API, most readable | Spark 3.4+ only | 3.4+ |

---

## Key Interview Talking Points

1. **Unpivot is the reverse of pivot:** `pivot` goes long→wide (rows→columns). `unpivot`/`melt` goes wide→long (columns→rows). Know both directions.

2. **`stack()` is the most interview-friendly:** It's compact, doesn't require imports, and works in both DataFrame and SQL contexts. `stack(N, k1, v1, k2, v2, ...)` creates N rows per input row.

3. **Connection to the explode family:**
   - `quantity_explode`: `array_repeat` → `explode` (repeat a value N times)
   - `expand_date_ranges`: `sequence` → `explode` (generate dates)
   - `unpivot`: `create_map` → `explode` (columns to rows)
   - All follow the same pattern: **build a collection, then explode it**.

4. **When to unpivot in real projects:**
   - Converting Excel/CSV "wide" reports to database-friendly "long" format
   - Preparing data for time-series analysis (monthly columns → date + value rows)
   - Normalizing denormalized tables for proper joins
   - ETL pipelines that ingest wide-format source data

5. **Mention `unpivot()` for modern Spark:** Shows you know the latest API. But always be prepared to write `stack()` for older versions.
